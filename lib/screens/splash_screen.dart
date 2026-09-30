import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_startup_service.dart';

/// Clean, professional, and minimal Splash Screen for ScanSure.
/// Displays the centered ScanSure logo for exactly 2 seconds while
/// preloading and initializing essential background services in parallel.
class SplashScreen extends StatefulWidget {
  final bool isLightMode;
  final VoidCallback onSplashComplete;
  final Duration duration;

  const SplashScreen({
    super.key,
    required this.isLightMode,
    required this.onSplashComplete,
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startStartupSequence();
  }

  /// Runs the 2-second minimum timer concurrently with background preloading.
  Future<void> _startStartupSequence() async {
    // 1. Two-second minimum display timer
    final minimumTimerFuture = Future.delayed(widget.duration);

    // 2. Concurrently run non-UI background preloading
    final backgroundInitFuture = AppStartupService.initialize();

    // 3. Wait until both the 2-second duration has elapsed and initialization completes
    try {
      await Future.wait([minimumTimerFuture, backgroundInitFuture]);
    } catch (e, stack) {
      debugPrint('[SplashScreen] Startup sequence exception: $e\n$stack');
    }

    // 4. Safely transition to Home screen
    if (!mounted) return;
    widget.onSplashComplete();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = !widget.isLightMode ||
        Theme.of(context).brightness == Brightness.dark;

    // Background matching ScanSure's theme
    final backgroundColor =
        isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FF);
    final titleColor =
        isDark ? Colors.white : const Color(0xFF0B1C30);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: backgroundColor,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ScanSure Emblem
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF6366F1)],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.security_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ScanSure Wordmark
              Text(
                'ScanSure',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: titleColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 28,
                  letterSpacing: -0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
