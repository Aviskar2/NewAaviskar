import 'package:flutter/material.dart';
import 'config/app_settings.dart';
import 'theme/app_theme.dart';
import 'screens/main_navigation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.load();
  runApp(const ScanSureApp());
}

class ScanSureApp extends StatefulWidget {
  const ScanSureApp({Key? key}) : super(key: key);

  @override
  State<ScanSureApp> createState() => _ScanSureAppState();
}

class _ScanSureAppState extends State<ScanSureApp> {
  // Theme state: true = Default Light Blue Theme, false = Dark Vibrant Theme
  bool _isLightMode = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScanSure',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightBlueTheme,
      darkTheme: AppTheme.darkVibrantTheme,
      // Map true to ThemeMode.light (Default Blue) and false to ThemeMode.dark (Dark Vibrant)
      themeMode: _isLightMode ? ThemeMode.light : ThemeMode.dark,
      home: MainNavigation(
        isLightMode: _isLightMode,
        onThemeChanged: (bool value) {
          setState(() {
            _isLightMode = value;
          });
        },
      ),
    );
  }
}
