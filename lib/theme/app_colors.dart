import 'package:flutter/material.dart';

/// Semantic color tokens for Aura AI.
/// Usage: Theme.of(context).extension<AppColors>()!.success
@immutable
class AppColors extends ThemeExtension<AppColors> {
  // ─── Semantic Status Colors ──────────────────────────────────────────────
  final Color success;
  final Color successContainer;
  final Color warning;
  final Color warningContainer;
  final Color error;
  final Color errorContainer;
  final Color info;
  final Color infoContainer;

  // ─── Brand Accent Colors ─────────────────────────────────────────────────
  final Color aiPurple;
  final Color aiPurpleContainer;
  final Color scannerCyan;
  final Color scannerCyanContainer;

  // ─── Surface Layers (dark mode) ──────────────────────────────────────────
  final Color surfaceElevated;
  final Color surfaceOverlay;
  final Color surfaceBorder;
  final Color surfaceSubtle;

  // ─── Tab / Navigation Active Indicator ────────────────────────────────────
  final Color navActiveBg;
  final Color navInactiveFg;

  const AppColors({
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.error,
    required this.errorContainer,
    required this.info,
    required this.infoContainer,
    required this.aiPurple,
    required this.aiPurpleContainer,
    required this.scannerCyan,
    required this.scannerCyanContainer,
    required this.surfaceElevated,
    required this.surfaceOverlay,
    required this.surfaceBorder,
    required this.surfaceSubtle,
    required this.navActiveBg,
    required this.navInactiveFg,
  });

  static const light = AppColors(
    success: Color(0xFF16A34A),
    successContainer: Color(0xFFDCFCE7),
    warning: Color(0xFFD97706),
    warningContainer: Color(0xFFFEF3C7),
    error: Color(0xFFDC2626),
    errorContainer: Color(0xFFFEE2E2),
    info: Color(0xFF2563EB),
    infoContainer: Color(0xFFDBEAFE),
    aiPurple: Color(0xFF7C3AED),
    aiPurpleContainer: Color(0xFFEDE9FE),
    scannerCyan: Color(0xFF06B6D4),
    scannerCyanContainer: Color(0xFFCFFAFE),
    surfaceElevated: Colors.white,
    surfaceOverlay: Color(0xFFF8F9FF),
    surfaceBorder: Color(0xFFE5EEFF),
    surfaceSubtle: Color(0xFFF1F5F9),
    navActiveBg: Color(0xFFEFF6FF),
    navInactiveFg: Color(0xFF94A3B8),
  );

  static const dark = AppColors(
    success: Color(0xFF4ADE80),
    successContainer: Color(0xFF052E16),
    warning: Color(0xFFFBBF24),
    warningContainer: Color(0xFF451A03),
    error: Color(0xFFF87171),
    errorContainer: Color(0xFF450A0A),
    info: Color(0xFF60A5FA),
    infoContainer: Color(0xFF1E3A5F),
    aiPurple: Color(0xFFA78BFA),
    aiPurpleContainer: Color(0xFF2E1065),
    scannerCyan: Color(0xFF22D3EE),
    scannerCyanContainer: Color(0xFF083344),
    surfaceElevated: Color(0xFF1E0C2B),
    surfaceOverlay: Color(0xFF22062C),
    surfaceBorder: Color(0xFF32113D),
    surfaceSubtle: Color(0xFF1A0525),
    navActiveBg: Color(0xFF32113D),
    navInactiveFg: Color(0xFF6B7280),
  );

  @override
  AppColors copyWith({
    Color? success,
    Color? successContainer,
    Color? warning,
    Color? warningContainer,
    Color? error,
    Color? errorContainer,
    Color? info,
    Color? infoContainer,
    Color? aiPurple,
    Color? aiPurpleContainer,
    Color? scannerCyan,
    Color? scannerCyanContainer,
    Color? surfaceElevated,
    Color? surfaceOverlay,
    Color? surfaceBorder,
    Color? surfaceSubtle,
    Color? navActiveBg,
    Color? navInactiveFg,
  }) {
    return AppColors(
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      error: error ?? this.error,
      errorContainer: errorContainer ?? this.errorContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
      aiPurple: aiPurple ?? this.aiPurple,
      aiPurpleContainer: aiPurpleContainer ?? this.aiPurpleContainer,
      scannerCyan: scannerCyan ?? this.scannerCyan,
      scannerCyanContainer: scannerCyanContainer ?? this.scannerCyanContainer,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceOverlay: surfaceOverlay ?? this.surfaceOverlay,
      surfaceBorder: surfaceBorder ?? this.surfaceBorder,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      navActiveBg: navActiveBg ?? this.navActiveBg,
      navInactiveFg: navInactiveFg ?? this.navInactiveFg,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      error: Color.lerp(error, other.error, t)!,
      errorContainer: Color.lerp(errorContainer, other.errorContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      aiPurple: Color.lerp(aiPurple, other.aiPurple, t)!,
      aiPurpleContainer: Color.lerp(
        aiPurpleContainer,
        other.aiPurpleContainer,
        t,
      )!,
      scannerCyan: Color.lerp(scannerCyan, other.scannerCyan, t)!,
      scannerCyanContainer: Color.lerp(
        scannerCyanContainer,
        other.scannerCyanContainer,
        t,
      )!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceOverlay: Color.lerp(surfaceOverlay, other.surfaceOverlay, t)!,
      surfaceBorder: Color.lerp(surfaceBorder, other.surfaceBorder, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      navActiveBg: Color.lerp(navActiveBg, other.navActiveBg, t)!,
      navInactiveFg: Color.lerp(navInactiveFg, other.navInactiveFg, t)!,
    );
  }
}
