import 'dart:async';
import 'package:flutter/foundation.dart';
import '../config/app_settings.dart';
import 'scan_history_service.dart';
import 'scheme_service.dart';
import 'scheme_database.dart';
import 'legal/live_legal_update_service.dart';

/// Preloads and warms up non-UI resources, databases, and background services
/// for ScanSure during the 2-second splash screen without blocking the UI thread.
class AppStartupService {
  static bool _isInitialized = false;

  /// Returns true if startup preloading has completed.
  static bool get isInitialized => _isInitialized;

  /// Resets initialization state for testing purposes.
  @visibleForTesting
  static void resetForTesting() {
    _isInitialized = false;
  }

  /// Runs asynchronous, non-blocking background initialization tasks.
  /// Each task runs in parallel and is safely isolated with error handling
  /// so that any isolated failure allows the app to proceed with defaults.
  static Future<void> initialize() async {
    if (_isInitialized) return;

    final stopwatch = Stopwatch()..start();
    debugPrint('[AppStartupService] Starting background preloading tasks...');

    await Future.wait([
      // 1. Load application configurations & API keys
      _runSafely('AppSettings', () => AppSettings.load()),

      // 2. Preload persistent scan history cache
      _runSafely('ScanHistoryService', () => ScanHistoryService().load()),

      // 3. Preload government scheme bookmarks and applications
      _runSafely('SchemeService', () => SchemeService().load()),

      // 4. Preload cached consumer law updates
      _runSafely(
        'LiveLegalUpdateService',
        () => LiveLegalUpdateService().initialize(),
      ),

      // 5. Pre-warm static database models in memory
      _runSafely('SchemeDatabase Warmup', () async {
        final count = SchemeDatabase.schemes.length;
        if (kDebugMode) {
          debugPrint('[AppStartupService] Pre-warmed $count government schemes in memory.');
        }
      }),
    ]);

    _isInitialized = true;
    debugPrint(
      '[AppStartupService] Background initialization completed in ${stopwatch.elapsedMilliseconds}ms',
    );
  }

  /// Wraps an async task in a try/catch to guarantee app resilience.
  static Future<void> _runSafely(
    String taskName,
    FutureOr<void> Function() task,
  ) async {
    try {
      await task();
    } catch (error, stackTrace) {
      debugPrint('[AppStartupService] Warning: Failed to preload $taskName: $error');
      if (kDebugMode) {
        debugPrint(stackTrace.toString());
      }
    }
  }
}
