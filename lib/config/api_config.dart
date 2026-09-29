import 'app_settings.dart';

class ApiConfig {
  /// OpenRouter API key.
  ///
  /// ⚠️ SECURITY: this repository has a PUBLIC GitHub remote.
  /// A key committed here is visible to everyone and will be scraped by
  /// bots within hours of pushing. Before publishing this repo:
  ///   1. Make the repo private, OR clear this field and rotate the key at
  ///      https://openrouter.ai/keys, OR rely on the runtime key entered in
  ///      Settings → AI Features (stored only on-device).
  ///
  /// Priority order: runtime key (AppSettings) wins over this compile-time key.
  /// Primary cloud AI API key (supports NVIDIA NIM, OpenRouter, OpenCode).
  static const String openRouterApiKey =
      String.fromEnvironment('OPENROUTER_API_KEY',
          defaultValue: '');

  /// Base URL dynamically selected based on whether an NVIDIA NIM, OpenCode, or OpenRouter key is active.
  static String get openRouterBaseUrl {
    final key = effectiveApiKey;
    if (key.startsWith('nvapi-')) {
      return 'https://integrate.api.nvidia.com/v1';
    } else if (key.startsWith('oc_sk_')) {
      return 'https://opencode.ai/zen/v1';
    }
    return 'https://openrouter.ai/api/v1';
  }

  /// Default model when NVIDIA NIM is active.
  static const String nvidiaNimModel = 'z-ai/glm-5.3-flash';

  /// Default OpenCode model.
  static const String openCodeModel = 'mimo-v2.6-flash-free';

  /// Master switch for cloud AI enhancement. Integration tests set this to
  /// false so analysis pipelines stay deterministic and offline; production
  /// builds never touch it.
  static bool aiEnhancementEnabled = true;

  /// True when a usable API key is configured (runtime or compile-time).
  /// Pure key-presence check — does not consider [aiEnhancementEnabled].
  static bool get hasApiKey =>
      AppSettings.hasApiKey ||
      (openRouterApiKey.isNotEmpty && !openRouterApiKey.contains('<YOUR_'));

  /// True when cloud AI calls should actually be attempted.
  /// Services must gate on this (not [hasApiKey]) so the test kill-switch works.
  static bool get aiActive => aiEnhancementEnabled && hasApiKey;

  /// The API key to use for requests, or '' when unconfigured.
  static String get effectiveApiKey =>
      AppSettings.hasApiKey ? AppSettings.openRouterApiKey : openRouterApiKey;

  /// Site identification for OpenRouter
  static const String appSiteUrl = 'https://scansure.app';
  static const String appName = 'ScanSure Universal Safety Engine';

  // ─── Google Gemini AI Configuration ──────────────────────────────────────
  /// Dedicated Google Gemini API key for real-time Fraud & Scam Detection.
  static const String geminiApiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta';

  /// Candidate Gemini models in fallback order.
  static const List<String> geminiCandidateModels = [
    'gemini-3.6-flash',
    'gemini-3.5-flash',
    'gemini-3.8-flash',
    'gemini-3.5-flash-lite',
    'gemini-2.5-flash-lite',
    'gemini-flash-latest',
  ];

  /// Optimal fast model with native reasoning, high OCR visual acuity & Indian law capability.
  static const String geminiModel = 'gemini-3.6-flash';

  /// True when Gemini API key is configured and available.
  static bool get hasGeminiKey =>
      AppSettings.hasGeminiApiKey ||
      (geminiApiKey.isNotEmpty && !geminiApiKey.contains('<YOUR_'));

  /// True when Gemini AI fraud analysis calls should actually be attempted.
  static bool get geminiActive => aiEnhancementEnabled && hasGeminiKey;

  /// Effective Gemini API key (runtime setting overrides default key).
  static String get effectiveGeminiApiKey => AppSettings.hasGeminiApiKey
      ? AppSettings.geminiApiKey
      : geminiApiKey;
}
