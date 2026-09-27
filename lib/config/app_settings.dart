import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight runtime settings persisted locally.
/// Currently stores the optional OpenRouter API key used by the
/// AI-enhanced analysis features (bill vision audit, legal AI review).
class AppSettings {
  static const String _apiKeyKey = 'openrouter_api_key';
  static const String _geminiApiKeyKey = 'gemini_api_key';

  /// Loaded once at app startup via [load].
  static String _openRouterApiKey = '';
  static String _geminiApiKey = '';

  static String get openRouterApiKey => _openRouterApiKey;
  static bool get hasApiKey => _openRouterApiKey.trim().isNotEmpty;

  static String get geminiApiKey => _geminiApiKey;
  static bool get hasGeminiApiKey => _geminiApiKey.trim().isNotEmpty;

  /// Call from main() before runApp so AI features see the saved key.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _openRouterApiKey = prefs.getString(_apiKeyKey) ?? '';
      _geminiApiKey = prefs.getString(_geminiApiKeyKey) ?? '';
    } catch (_) {
      _openRouterApiKey = '';
      _geminiApiKey = '';
    }
  }

  /// Saves a new API key (trimmed). Empty string clears it.
  static Future<void> setApiKey(String value) async {
    _openRouterApiKey = value.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_apiKeyKey, _openRouterApiKey);
    } catch (_) {}
  }

  /// Saves a custom Gemini API key (trimmed).
  static Future<void> setGeminiApiKey(String value) async {
    _geminiApiKey = value.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_geminiApiKeyKey, _geminiApiKey);
    } catch (_) {}
  }

  /// Masked preview like "sk-or-…a1b2" for display in settings UI.
  static String get maskedApiKey {
    final k = _openRouterApiKey.trim();
    if (k.isEmpty) return 'Not configured';
    if (k.length <= 8) return '${k.substring(0, 1)}••••';
    return '${k.substring(0, 6)}••••${k.substring(k.length - 4)}';
  }

  /// Masked preview for Gemini API Key.
  static String get maskedGeminiApiKey {
    final k = _geminiApiKey.trim();
    if (k.isEmpty) return 'Default Gemini Key Active';
    if (k.length <= 8) return '${k.substring(0, 2)}••••';
    return '${k.substring(0, 5)}••••${k.substring(k.length - 4)}';
  }
}
