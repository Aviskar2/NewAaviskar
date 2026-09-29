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
  static const String openRouterApiKey =
      String.fromEnvironment('OPENROUTER_API_KEY', defaultValue: '');

  static const String openRouterBaseUrl = 'https://openrouter.ai/api/v1';

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

  /// Single source of truth for the Gemini model fallback chain.
  ///
  /// Every service that calls the Gemini API (bill fraud audit, legal document
  /// audit, offer letter comparison) must iterate over THIS list instead of
  /// declaring its own — previously each service hardcoded a separate, drifted
  /// list of model IDs, several of which pointed at models Google has already
  /// deprecated/shut down (gemini-1.5-flash, gemini-2.0-flash, gemini-2.5-flash).
  /// Ordered most-capable/current first; `gemini-flash-latest` is kept last as a
  /// safe rolling alias that always resolves to Google's current default Flash
  /// model, so it should never itself go stale.
  /// See: https://ai.google.dev/gemini-api/docs/generate-content/latest-model
  static const List<String> geminiCandidateModels = [
    'gemini-3.8-flash',
    'gemini-3.6-flash',
    'gemini-flash-latest',
  ];

  /// Primary/default model — the first entry attempted in [geminiCandidateModels].
  /// Kept for display purposes and backwards compatibility.
  static String get geminiModel => geminiCandidateModels.first;

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
