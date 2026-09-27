import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../config/openrouter_models.dart';

/// Supported app language definition
class AppLanguage {
  final String displayName;
  final String nativeName;
  final TranslateLanguage mlKitCode;
  final String onlineCode;

  const AppLanguage({
    required this.displayName,
    required this.nativeName,
    required this.mlKitCode,
    required this.onlineCode,
  });
}

/// All languages the app supports for translation.
class SupportedLanguages {
  static final List<AppLanguage> all = [
    const AppLanguage(
      displayName: 'English',
      nativeName: 'English',
      mlKitCode: TranslateLanguage.english,
      onlineCode: 'en',
    ),
    const AppLanguage(
      displayName: 'Hindi',
      nativeName: 'हिन्दी',
      mlKitCode: TranslateLanguage.hindi,
      onlineCode: 'hi',
    ),
    const AppLanguage(
      displayName: 'Marathi',
      nativeName: 'मराठी',
      mlKitCode: TranslateLanguage.marathi,
      onlineCode: 'mr',
    ),
    const AppLanguage(
      displayName: 'Gujarati',
      nativeName: 'ગુજરાતી',
      mlKitCode: TranslateLanguage.gujarati,
      onlineCode: 'gu',
    ),
    const AppLanguage(
      displayName: 'Bengali',
      nativeName: 'বাংলা',
      mlKitCode: TranslateLanguage.bengali,
      onlineCode: 'bn',
    ),
    const AppLanguage(
      displayName: 'Tamil',
      nativeName: 'தமிழ்',
      mlKitCode: TranslateLanguage.tamil,
      onlineCode: 'ta',
    ),
    const AppLanguage(
      displayName: 'Telugu',
      nativeName: 'తెలుగు',
      mlKitCode: TranslateLanguage.telugu,
      onlineCode: 'te',
    ),
    const AppLanguage(
      displayName: 'Kannada',
      nativeName: 'ಕನ್ನಡ',
      mlKitCode: TranslateLanguage.kannada,
      onlineCode: 'kn',
    ),
    const AppLanguage(
      displayName: 'Urdu',
      nativeName: 'اردو',
      mlKitCode: TranslateLanguage.urdu,
      onlineCode: 'ur',
    ),
    const AppLanguage(
      displayName: 'Arabic',
      nativeName: 'العربية',
      mlKitCode: TranslateLanguage.arabic,
      onlineCode: 'ar',
    ),
    const AppLanguage(
      displayName: 'Chinese (Simplified)',
      nativeName: '中文',
      mlKitCode: TranslateLanguage.chinese,
      onlineCode: 'zh',
    ),
    const AppLanguage(
      displayName: 'Japanese',
      nativeName: '日本語',
      mlKitCode: TranslateLanguage.japanese,
      onlineCode: 'ja',
    ),
    const AppLanguage(
      displayName: 'Spanish',
      nativeName: 'Español',
      mlKitCode: TranslateLanguage.spanish,
      onlineCode: 'es',
    ),
    const AppLanguage(
      displayName: 'French',
      nativeName: 'Français',
      mlKitCode: TranslateLanguage.french,
      onlineCode: 'fr',
    ),
    const AppLanguage(
      displayName: 'German',
      nativeName: 'Deutsch',
      mlKitCode: TranslateLanguage.german,
      onlineCode: 'de',
    ),
    const AppLanguage(
      displayName: 'Russian',
      nativeName: 'Русский',
      mlKitCode: TranslateLanguage.russian,
      onlineCode: 'ru',
    ),
  ];

  static AppLanguage get english => all[0];
  static AppLanguage get hindi => all[1];

  static AppLanguage byCode(TranslateLanguage code) {
    return all.firstWhere(
      (l) => l.mlKitCode == code,
      orElse: () => all[0],
    );
  }
}

/// Translation progress state sent via stream
enum TranslationStatus {
  idle,
  checkingModel,
  downloadingModel,
  translating,
  done,
  error,
}

class TranslationProgress {
  final TranslationStatus status;
  final String? result;
  final String? errorMessage;
  final double downloadProgress; // 0.0 – 1.0
  final bool isOnlineFallback;

  const TranslationProgress({
    required this.status,
    this.result,
    this.errorMessage,
    this.downloadProgress = 0.0,
    this.isOnlineFallback = false,
  });
}

/// Robust hybrid translation service:
/// 1. Uses fast on-device Google ML Kit translation if models are ready.
/// 2. If model needs downloading, attempts download with mobile data enabled (isWifiRequired: false).
/// 3. If model download takes > 4 seconds or fails, seamlessly falls back to high-speed online translation so the user NEVER gets stuck at 60%.
class TranslationService {
  final Map<String, OnDeviceTranslator> _translatorCache = {};
  final ModelManager _modelManager = OnDeviceTranslatorModelManager();

  /// Translates [text] from [from] to [to].
  Stream<TranslationProgress> translate(
    String text, {
    required AppLanguage from,
    required AppLanguage to,
  }) async* {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      yield const TranslationProgress(
        status: TranslationStatus.error,
        errorMessage: 'Input text is empty.',
      );
      return;
    }

    // Same language check
    if (from.mlKitCode == to.mlKitCode) {
      yield TranslationProgress(
        status: TranslationStatus.done,
        result: trimmed,
        downloadProgress: 1.0,
      );
      return;
    }

    yield const TranslationProgress(status: TranslationStatus.checkingModel);

    bool sourceReady = false;
    bool targetReady = false;

    try {
      sourceReady = await _modelManager.isModelDownloaded(from.mlKitCode.bcpCode);
      targetReady = await _modelManager.isModelDownloaded(to.mlKitCode.bcpCode);
    } catch (e) {
      debugPrint('Error checking models: $e');
    }

    // If both models are already downloaded on-device, translate immediately!
    if (sourceReady && targetReady) {
      yield const TranslationProgress(
        status: TranslationStatus.translating,
        downloadProgress: 1.0,
      );
      try {
        final translator = _getOrCreateTranslator(from.mlKitCode, to.mlKitCode);
        final result = await translator.translateText(trimmed);
        yield TranslationProgress(
          status: TranslationStatus.done,
          result: result,
          downloadProgress: 1.0,
        );
        return;
      } catch (e) {
        debugPrint('On-device translation error: $e, falling back to online...');
      }
    }

    // Models need downloading or on-device failed.
    // Show progressive download status while trying download with a timeout.
    yield const TranslationProgress(
      status: TranslationStatus.downloadingModel,
      downloadProgress: 0.3,
    );

    bool mlKitSuccess = false;
    String? mlKitResult;

    try {
      // Start model downloads with isWifiRequired: false so cellular users aren't blocked!
      final downloadFuture = () async {
        if (!sourceReady) {
          final sOk = await _modelManager.downloadModel(
            from.mlKitCode.bcpCode,
            isWifiRequired: false,
          );
          if (!sOk) return false;
        }
        if (!targetReady) {
          final tOk = await _modelManager.downloadModel(
            to.mlKitCode.bcpCode,
            isWifiRequired: false,
          );
          if (!tOk) return false;
        }
        final translator = _getOrCreateTranslator(from.mlKitCode, to.mlKitCode);
        mlKitResult = await translator.translateText(trimmed);
        return true;
      }();

      // Give ML Kit 4 seconds to complete model download & translation
      yield const TranslationProgress(
        status: TranslationStatus.downloadingModel,
        downloadProgress: 0.6,
      );

      mlKitSuccess = await downloadFuture.timeout(
        const Duration(seconds: 4),
        onTimeout: () => false,
      );
    } catch (e) {
      debugPrint('ML Kit download / translation error: $e');
      mlKitSuccess = false;
    }

    if (mlKitSuccess && mlKitResult != null && mlKitResult!.isNotEmpty) {
      yield TranslationProgress(
        status: TranslationStatus.done,
        result: mlKitResult,
        downloadProgress: 1.0,
      );
      return;
    }

    // ML Kit download is taking longer or stalled.
    // Perform fast online translation fallback so user gets instant result without waiting!
    yield const TranslationProgress(
      status: TranslationStatus.translating,
      downloadProgress: 0.85,
      isOnlineFallback: true,
    );

    try {
      final onlineResult = await translateOnline(
        trimmed,
        fromCode: from.onlineCode,
        toCode: to.onlineCode,
      );

      if (onlineResult != null && onlineResult.trim().isNotEmpty) {
        // Trigger background offline model download for future offline use
        _triggerBackgroundDownload(from.mlKitCode.bcpCode);
        _triggerBackgroundDownload(to.mlKitCode.bcpCode);

        yield TranslationProgress(
          status: TranslationStatus.done,
          result: onlineResult,
          downloadProgress: 1.0,
          isOnlineFallback: true,
        );
        return;
      }
    } catch (e) {
      debugPrint('Online translation failed: $e');
    }

    // If online also failed and ML kit was still downloading, give ML Kit one last chance
    if (mlKitResult != null && mlKitResult!.isNotEmpty) {
      yield TranslationProgress(
        status: TranslationStatus.done,
        result: mlKitResult,
        downloadProgress: 1.0,
      );
      return;
    }

    yield const TranslationProgress(
      status: TranslationStatus.error,
      errorMessage:
          'Unable to complete translation. Please check your internet connection and try again.',
    );
  }

  /// High-speed online translation using Google GTX translation endpoint with MyMemory fallback
  Future<String?> translateOnline(
    String text, {
    required String fromCode,
    required String toCode,
    int retryCount = 1,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';

    // 1. Google GTX API via HTTP POST (robust against URL length limits)
    try {
      final url = Uri.parse('https://translate.googleapis.com/translate_a/single');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'User-Agent': 'Mozilla/5.0',
        },
        body: {
          'client': 'gtx',
          'sl': fromCode,
          'tl': toCode,
          'dt': 't',
          'q': trimmed,
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty && data[0] is List) {
          final buffer = StringBuffer();
          for (final item in (data[0] as List)) {
            if (item is List && item.isNotEmpty && item[0] != null) {
              buffer.write(item[0].toString());
            }
          }
          final res = buffer.toString().trim();
          if (res.isNotEmpty) return res;
        }
      }
    } catch (e) {
      debugPrint('Google GTX POST API error: $e');
    }

    // 1b. Google GTX API via GET fallback (for smaller chunks)
    if (trimmed.length <= 1500) {
      try {
        final url = Uri.parse(
          'https://translate.googleapis.com/translate_a/single?client=gtx&sl=$fromCode&tl=$toCode&dt=t&q=${Uri.encodeComponent(trimmed)}',
        );
        final response = await http.get(url).timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          final dynamic data = jsonDecode(response.body);
          if (data is List && data.isNotEmpty && data[0] is List) {
            final buffer = StringBuffer();
            for (final item in (data[0] as List)) {
              if (item is List && item.isNotEmpty && item[0] != null) {
                buffer.write(item[0].toString());
              }
            }
            final res = buffer.toString().trim();
            if (res.isNotEmpty) return res;
          }
        }
      } catch (e) {
        debugPrint('Google GTX GET API error: $e');
      }
    }

    // 2. MyMemory Translation API fallback
    try {
      final langPair = '$fromCode|$toCode';
      final url = Uri.parse(
        'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(text)}&langpair=$langPair',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is Map && data['responseData'] != null) {
          final translated = data['responseData']['translatedText'];
          if (translated != null && translated.toString().isNotEmpty) {
            return translated.toString();
          }
        }
      }
    } catch (e) {
      debugPrint('MyMemory API error: $e');
    }

    // 3. OpenRouter Free LLM Fallback
    try {
      if (ApiConfig.aiActive) {
        final candidates = await OpenRouterModelDirectory.textCandidates();
        for (final model in candidates.take(3)) {
          final uri = Uri.parse('${ApiConfig.openRouterBaseUrl}/chat/completions');
          final response = await http.post(
            uri,
            headers: {
              'Authorization': 'Bearer ${ApiConfig.effectiveApiKey}',
              'HTTP-Referer': ApiConfig.appSiteUrl,
              'X-Title': ApiConfig.appName,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': model,
              'temperature': 0.1,
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'Translate the following text accurately into the language code "$toCode". Return ONLY the translated string with no explanations or notes.',
                },
                {'role': 'user', 'content': text},
              ],
            }),
          ).timeout(const Duration(seconds: 8));

          if (response.statusCode == 200) {
            final decoded = jsonDecode(response.body);
            final translated =
                decoded['choices']?[0]?['message']?['content']?.toString().trim();
            if (translated != null && translated.isNotEmpty) {
              return translated;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('OpenRouter translation error: $e');
    }

    return null;
  }

  /// Fast parallel translation of a list of text blocks.
  Future<Map<int, String>> translateBatch(
    List<String> texts, {
    required AppLanguage from,
    required AppLanguage to,
  }) async {
    final results = <int, String>{};
    final futures = <Future<void>>[];

    for (int i = 0; i < texts.length; i++) {
      final text = texts[i].trim();
      if (text.isEmpty) continue;
      final index = i;

      futures.add(() async {
        try {
          // Try fast online first for instant response
          final online = await translateOnline(
            text,
            fromCode: from.onlineCode,
            toCode: to.onlineCode,
          );
          if (online != null && online.trim().isNotEmpty) {
            results[index] = online.trim();
            return;
          }

          // Fallback to single translate stream
          await for (final progress in translate(text, from: from, to: to)) {
            if (progress.status == TranslationStatus.done && progress.result != null) {
              results[index] = progress.result!;
              break;
            }
          }
        } catch (_) {}
      }());
    }

    await Future.wait(futures);
    return results;
  }

  void _triggerBackgroundDownload(String bcpCode) {
    _modelManager.downloadModel(bcpCode, isWifiRequired: false).catchError((_) => false);
  }

  /// Checks whether the model for [language] has already been downloaded.
  Future<bool> isModelReady(AppLanguage language) async {
    return _modelManager.isModelDownloaded(language.mlKitCode.bcpCode);
  }

  /// Pre-downloads a language model (e.g. on settings screen).
  Future<bool> downloadModel(AppLanguage language) async {
    return _modelManager.downloadModel(
      language.mlKitCode.bcpCode,
      isWifiRequired: false,
    );
  }

  /// Deletes a downloaded language model to free storage.
  Future<bool> deleteModel(AppLanguage language) async {
    return _modelManager.deleteModel(language.mlKitCode.bcpCode);
  }

  OnDeviceTranslator _getOrCreateTranslator(
    TranslateLanguage source,
    TranslateLanguage target,
  ) {
    final key = '${source.bcpCode}_${target.bcpCode}';
    if (!_translatorCache.containsKey(key)) {
      _translatorCache[key] = OnDeviceTranslator(
        sourceLanguage: source,
        targetLanguage: target,
      );
    }
    return _translatorCache[key]!;
  }

  Future<void> dispose() async {
    for (final t in _translatorCache.values) {
      await t.close();
    }
    _translatorCache.clear();
  }
}
