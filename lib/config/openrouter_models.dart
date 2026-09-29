import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

/// Discovers currently-available free models on OpenRouter at runtime.
///
/// Free model IDs rotate frequently (old ones 404, new ones appear), so a
/// hardcoded list silently breaks AI features. This directory queries
/// `/api/v1/models`, caches the result in memory, and falls back to a small
/// curated list when the network request fails.
class OpenRouterModelDirectory {
  OpenRouterModelDirectory._();

  static const Duration _refreshInterval = Duration(hours: 6);

  static List<String>? _visionModels;
  static List<String>? _textModels;
  static DateTime? _fetchedAt;
  static Future<void>? _inFlight;

  /// Models that returned hard errors (403 gating, 404 gone) this session —
  /// skipped in future candidate lists so retries reach working models.
  static final Set<String> _blocked = <String>{};

  /// Models that returned 429 (shared free pool congested). Cooldown is short
  /// because congestion clears within minutes; blocked permanently never.
  static final Map<String, DateTime> _cooldownUntil = <String, DateTime>{};

  /// Call when a model returns an unrecoverable error (e.g. HTTP 403/404).
  static void blockModel(String id) => _blocked.add(id);

  /// Temporarily deprioritize a rate-limited model.
  static void coolDown(String id, {Duration duration = const Duration(seconds: 90)}) {
    _cooldownUntil[id] = DateTime.now().add(duration);
  }

  static bool _usable(String id) =>
      !_blocked.contains(id) &&
      !(_cooldownUntil[id]?.isAfter(DateTime.now()) ?? false);

  /// Curated fallbacks used only when live discovery ([_discover]) fails or
  /// times out. Free-tier model IDs on OpenRouter rotate frequently, so this
  /// list should be treated as a best-effort snapshot, not a guarantee that
  /// every entry is currently live — always prefer the discovered list when
  /// available.
  static const List<String> fallbackVisionModels = [
    'z-ai/glm-5.3-flash',
    'meta/llama-3.2-11b-vision-instruct',
    'mimo-v2.6-flash-free',
    'google/gemma-4-31b-it:free',
    'minimax/minimax-m3:free',
    'thinkingmachines/inkling-small:free',
    'dots-studio/dots-3-note-preview:free',
    'google/gemma-4-26b-a4b-it:free',
  ];

  static const List<String> fallbackTextModels = [
    'z-ai/glm-5.3-flash',
    'meta/llama-3.2-11b-vision-instruct',
    'nvidia/llama-3.1-nemotron-70b-instruct',
    'mimo-v2.6-flash-free',
    'z-ai/glm-5.2:free',
    'nvidia/nemotron-3-super-120b-a12b:free',
    'google/gemma-4-31b-it:free',
    'minimax/minimax-m3:free',
  ];

  /// Returns free models that accept image input (for bill/receipt scans).
  static Future<List<String>> visionCandidates() =>
      _candidates(preferVision: true);

  /// Returns free text models (legal review, translation fallback).
  static Future<List<String>> textCandidates() =>
      _candidates(preferVision: false);

  static Future<List<String>> _candidates({required bool preferVision}) async {
    await _ensureFresh();
    final vision = (_visionModels ?? const <String>[])
        .where(_usable)
        .toList(growable: false);
    final text = (_textModels ?? const <String>[])
        .where(_usable)
        .toList(growable: false);
    final base = text.isEmpty ? fallbackTextModels : text;
    if (preferVision) {
      // Vision models first, then capable text models as extra fallbacks.
      return [
        ...(vision.isEmpty ? fallbackVisionModels : vision),
        ...base.where((m) => !(vision.isEmpty ? fallbackVisionModels : vision).contains(m)),
      ];
    }
    return base;
  }

  static Future<void> _ensureFresh() async {
    final isFresh = _fetchedAt != null &&
        DateTime.now().difference(_fetchedAt!) < _refreshInterval;
    if (isFresh) return;

    // Coalesce concurrent refreshes.
    _inFlight ??= _discover().whenComplete(() => _inFlight = null);
    try {
      await _inFlight!.timeout(const Duration(seconds: 5));
    } catch (_) {
      // Discovery failed — keep whatever we have (or fall back below).
    }

    if (_textModels == null) {
      _textModels = fallbackTextModels;
      _fetchedAt ??= DateTime.now();
    }
    _visionModels ??= fallbackVisionModels;
  }

  static Future<void> _discover() async {
    final uri = Uri.parse('${ApiConfig.openRouterBaseUrl}/models');
    final response = await http.get(
      uri,
      headers: {
        if (ApiConfig.effectiveApiKey.isNotEmpty)
          'Authorization': 'Bearer ${ApiConfig.effectiveApiKey}',
      },
    ).timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return;

    final decoded = jsonDecode(response.body);
    final models = decoded['data'];
    if (models is! List) return;
    _fetchedAt = DateTime.now();

    final vision = <String>[];
    final text = <String>[];
    final isNim = ApiConfig.effectiveApiKey.startsWith('nvapi-');
    for (final m in models) {
      if (m is! Map) continue;
      final id = m['id']?.toString();
      if (id == null) continue;
      final isFree = id.endsWith(':free') || id.endsWith('-free');
      if (!isNim && !isFree) continue;
      final arch = m['architecture'];
      final input = arch is Map ? arch['input_modalities'] : null;
      final supportsImage = (input is List && input.contains('image')) ||
          id.contains('vision') ||
          id.contains('mimo');
      if (supportsImage) {
        vision.add(id);
      } else {
        text.add(id);
      }
    }

    // Rank by family reliability — proven instruction-followers first — then
    // keep provider order within a family.
    int rank(String id) {
      final lower = id.toLowerCase();
      if (lower.contains('glm-5.3-flash') || lower.contains('glm-5.3')) return -3;
      if (lower.contains('llama-3.2-11b') || lower.contains('11b-vision')) return -2;
      if (lower.contains('mimo')) return -1;
      if (lower.startsWith('google/gemma')) return 0;
      if (lower.startsWith('google/')) return 1;
      if (lower.startsWith('z-ai/') || lower.contains('glm')) return 2;
      // Fast, reliable variants first; heavyweight reasoning models last.
      final heavy = lower.contains('ultra') ||
          lower.contains('reasoning') ||
          lower.contains('-xl') ||
          lower.contains('lightning');
      if (lower.contains('nemotron') && lower.contains('super')) return 3;
      if (heavy) return 7;
      if (lower.startsWith('minimax/')) return 4;
      if (lower.startsWith('qwen/')) return 5;
      if (lower.startsWith('meta-llama/')) return 6;
      return 8;
    }

    vision.sort((a, b) => rank(a).compareTo(rank(b)));
    text.sort((a, b) => rank(a).compareTo(rank(b)));
    if (vision.isNotEmpty) _visionModels = vision;
    if (text.isNotEmpty) _textModels = text;
  }

  /// Test hook: reset cached state.
  static void resetCache() {
    _visionModels = null;
    _textModels = null;
    _fetchedAt = null;
    _inFlight = null;
    _blocked.clear();
    _cooldownUntil.clear();
  }
}
