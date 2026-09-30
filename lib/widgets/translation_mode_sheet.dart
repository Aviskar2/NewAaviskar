import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ocr_service.dart';
import '../services/scan_history_service.dart';
import '../utils/permissions.dart';
import '../screens/scanner/image_overlay_translation_screen.dart';
import '../screens/scanner/document_translation_screen.dart';

enum TranslationTargetMode {
  camera,
  browseFiles,
  imageOverlay,
  document,
  text,
}

/// Simple, Modern & Trustworthy Translation Bottom Sheet for ScanSure.
/// Presents ONLY two primary choices:
/// 1) Camera — Translate text using camera (direct capture & in-place structure translation)
/// 2) Browse Files — Choose a PDF, Word document, image, or other file (opens Android file picker)
class TranslationModeSheet extends StatefulWidget {
  final OcrService ocrService;
  final ScanHistoryService historyService;
  final String? initialImagePath;
  final String? documentName;

  const TranslationModeSheet({
    super.key,
    required this.ocrService,
    required this.historyService,
    this.initialImagePath,
    this.documentName,
  });

  static Future<void> show(
    BuildContext context, {
    required OcrService ocrService,
    required ScanHistoryService historyService,
    String? initialImagePath,
    String? documentName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TranslationModeSheet(
        ocrService: ocrService,
        historyService: historyService,
        initialImagePath: initialImagePath,
        documentName: documentName,
      ),
    );
  }

  @override
  State<TranslationModeSheet> createState() => _TranslationModeSheetState();
}

class _TranslationModeSheetState extends State<TranslationModeSheet> {
  bool _isProcessing = false;
  String _processingMessage = '';

  @override
  void initState() {
    super.initState();
  }

  /// Option 1: Open camera capture and process for in-place translation
  Future<void> _handleCameraTap() async {
    HapticFeedback.lightImpact();

    final granted = await PermissionsUtil.requestCamera(context);
    if (!granted) return;

    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 95,
    );

    if (photo != null && mounted) {
      await _processImageOverlay(photo.path);
    }
  }

  /// Option 2: Open file picker for PDF, DOCX, DOC, Images, etc.
  void _handleBrowseFilesTap() {
    HapticFeedback.lightImpact();
    final navigator = Navigator.of(context);
    Navigator.pop(context); // Close sheet

    navigator.push(
      MaterialPageRoute(
        builder: (_) => DocumentTranslationScreen(
          autoPickFile: true,
          historyService: widget.historyService,
          ocrService: widget.ocrService,
        ),
      ),
    );
  }

  /// Runs OCR on the captured camera photo and navigates to ImageOverlayTranslationScreen
  Future<void> _processImageOverlay(String imagePath) async {
    setState(() {
      _isProcessing = true;
      _processingMessage = 'Analyzing text structure with OCR…';
    });

    try {
      await widget.ocrService.validateFile(imagePath);
      final ocrResult = await widget.ocrService.recognizeFromPath(imagePath);
      await widget.historyService.addOcr(ocrResult);

      if (!mounted) return;
      final navigator = Navigator.of(context);
      Navigator.pop(context); // Close sheet

      navigator.push(
        MaterialPageRoute(
          builder: (_) => ImageOverlayTranslationScreen(
            ocrResult: ocrResult,
            ocrService: widget.ocrService,
            historyService: widget.historyService,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process image: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // ScanSure Brand Accent Colors
    const primaryBlue = Color(0xFF2563EB);
    final iconBgColor =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131722) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: SafeArea(
        top: false,
        child: _isProcessing
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _processingMessage,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white24
                            : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Header Title & Subtitle
                  Text(
                    'How would you like to translate?',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 18.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose a camera or file to get started.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Option 1: Camera
                  _buildChoiceCard(
                    context: context,
                    icon: Icons.photo_camera_rounded,
                    iconBgColor: iconBgColor,
                    primaryColor: primaryBlue,
                    title: 'Camera',
                    description: 'Translate text using your camera',
                    onTap: _handleCameraTap,
                  ),

                  const SizedBox(height: 12),

                  // Option 2: Browse Files
                  _buildChoiceCard(
                    context: context,
                    icon: Icons.folder_open_rounded,
                    iconBgColor: iconBgColor,
                    primaryColor: primaryBlue,
                    title: 'Browse Files',
                    description: 'Choose a PDF, Word document, image, or other file',
                    metadata: 'PDF • DOC • DOCX • JPG • PNG',
                    onTap: _handleBrowseFilesTap,
                  ),

                  const SizedBox(height: 6),
                ],
              ),
      ),
    );
  }

  /// Clean, professional choice card with consistent visual design for ScanSure
  Widget _buildChoiceCard({
    required BuildContext context,
    required IconData icon,
    required Color iconBgColor,
    required Color primaryColor,
    required String title,
    required String description,
    String? metadata,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBgColor =
        isDark ? const Color(0xFF1E2330) : const Color(0xFFF8FAFC);
    final borderColor =
        isDark ? const Color(0xFF2C3549) : const Color(0xFFE2E8F0);
    final titleColor =
        isDark ? Colors.white : const Color(0xFF0F172A);
    final descriptionColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final chevronColor =
        isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: primaryColor.withValues(alpha: 0.08),
        highlightColor: primaryColor.withValues(alpha: 0.04),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: borderColor,
              width: 1.2,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon Container
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: primaryColor,
                    size: 23,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Title, Description & Optional Metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                        color: titleColor,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: descriptionColor,
                        height: 1.3,
                      ),
                    ),
                    if (metadata != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        metadata,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? const Color(0xFF60A5FA)
                              : primaryColor.withValues(alpha: 0.85),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Chevron Right Indicator
              Icon(
                Icons.chevron_right_rounded,
                color: chevronColor,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
