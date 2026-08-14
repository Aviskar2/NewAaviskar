import 'package:flutter/material.dart';

class AppTheme {
  // Default Light Blue Theme (Stitch default theme)
  static ThemeData get lightBlueTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: const Color(0xFF2563EB),
      scaffoldBackgroundColor: const Color(0xFFF8F9FF),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF2563EB),
        primaryContainer: Color(0xFFE5EEFF),
        secondary: Color(0xFF006686),
        secondaryContainer: Color(0xFFD3E4FE),
        surface: const Color(0xFFF8F9FF),
        surfaceContainerHighest: const Color(0xFFE5EEFF),
        onPrimary: Colors.white,
        onPrimaryContainer: const Color(0xFF00174B),
        onSecondary: Colors.white,
        onSurface: const Color(0xFF0B1C30),
        onSurfaceVariant: const Color(0xFF434655),
        outline: const Color(0xFF737686),
        outlineVariant: const Color(0xFFC3C6D7),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0B1C30),
          letterSpacing: -0.8,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0B1C30),
          letterSpacing: -0.4,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0B1C30),
        ),
        titleMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0B1C30),
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: Color(0xFF0B1C30),
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: Color(0xFF434655),
          height: 1.4,
        ),
        labelMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF737686),
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Color(0xFFE5EEFF),
            width: 1,
          ),
        ),
      ),
    );
  }

  // Premium Dark Vibrant Theme (Stitch Vibrant theme)
  static ThemeData get darkVibrantTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: const Color(0xFF9D00FF),
      scaffoldBackgroundColor: const Color(0xFF13041F),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF9D00FF),
        primaryContainer: Color(0xFF32113D),
        secondary: Color(0xFF00E3FD),
        secondaryContainer: Color(0xFF003A42),
        surface: const Color(0xFF1B0424),
        surfaceContainerHighest: const Color(0xFF2A0B35),
        onPrimary: Colors.white,
        onPrimaryContainer: const Color(0xFFFDBFFF),
        onSecondary: const Color(0xFF0B1C30),
        onSurface: const Color(0xFFFBDBFF),
        onSurfaceVariant: const Color(0xFFC39FCA),
        outline: const Color(0xFF8A6A92),
        outlineVariant: const Color(0xFF5A3D62),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Color(0xFFFBDBFF),
          letterSpacing: -0.8,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Color(0xFFFBDBFF),
          letterSpacing: -0.4,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFFFBDBFF),
        ),
        titleMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFFFBDBFF),
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: Color(0xFFFBDBFF),
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: Color(0xFFC39FCA),
          height: 1.4,
        ),
        labelMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF8A6A92),
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF22062C),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Color(0xFF32113D),
            width: 1,
          ),
        ),
      ),
    );
  }
}
