import 'package:flutter/material.dart';
import 'config/app_settings.dart';
import 'theme/app_theme.dart';
import 'screens/main_navigation.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.load();
  runApp(const ScanSureApp());
}

class ScanSureApp extends StatefulWidget {
  final bool showSplash;
  final Duration splashDuration;

  const ScanSureApp({
    super.key,
    this.showSplash = true,
    this.splashDuration = const Duration(seconds: 2),
  });

  @override
  State<ScanSureApp> createState() => _ScanSureAppState();
}

class _ScanSureAppState extends State<ScanSureApp> {
  // Theme state: true = Default Light Blue Theme, false = Dark Vibrant Theme
  bool _isLightMode = true;
  late bool _showSplash;

  @override
  void initState() {
    super.initState();
    _showSplash = widget.showSplash;
  }

  void _onSplashComplete() {
    if (mounted) {
      setState(() {
        _showSplash = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScanSure',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightBlueTheme,
      darkTheme: AppTheme.darkVibrantTheme,
      // Map true to ThemeMode.light (Default Blue) and false to ThemeMode.dark (Dark Vibrant)
      themeMode: _isLightMode ? ThemeMode.light : ThemeMode.dark,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _showSplash
            ? SplashScreen(
                key: const ValueKey('splash_screen'),
                isLightMode: _isLightMode,
                duration: widget.splashDuration,
                onSplashComplete: _onSplashComplete,
              )
            : MainNavigation(
                key: const ValueKey('main_navigation'),
                isLightMode: _isLightMode,
                onThemeChanged: (bool value) {
                  setState(() {
                    _isLightMode = value;
                  });
                },
              ),
      ),
    );
  }
}
