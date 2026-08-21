class ApiConfig {
  /// OpenRouter API Key
  /// ⚠️  Do NOT hardcode your key here. Set it via a local secrets file or
  ///     environment variable and keep that file out of version control.
  /// Example: create a `lib/config/api_config.local.dart` (gitignored) and
  ///          override this value there.
  static const String openRouterApiKey = '';

  static const String openRouterBaseUrl = 'https://openrouter.ai/api/v1';

  /// Site identification for OpenRouter
  static const String appSiteUrl = 'https://aura-ai.app';
  static const String appName = 'Aura AI Universal Safety Engine';
}
