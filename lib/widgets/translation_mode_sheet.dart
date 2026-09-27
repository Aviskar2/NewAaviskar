import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ocr_service.dart';
import '../services/scan_history_service.dart';
import '../utils/permissions.dart';
import '../screens/scanner/translation_screen.dart';
import '../screens/scanner/image_overlay_translation_screen.dart';
import '../screens/scanner/document_translation_screen.dart';

enum TranslationTargetMode {
  imageOverlay,
  document,
  text,
}

/// Simple, Modern Translation Modal with 3 Clear, Dedicated Modes:
/// 1) Image & Camera Translation (In-Place Structure Replacement)
/// 2) Document Translation (PDF, Word DOCX, TXT with page layout & PDF export)
/// 3) Text Translation (Direct bilingual typing & speech)
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

  Future<void> _pickImageFromCamera() async {
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

  Future<void> _pickImageFromGallery() async {
    final granted = await PermissionsUtil.requestStorage(context);
    if (!granted) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );

    if (image != null && mounted) {
      await _processImageOverlay(image.path);
    }
  }

  Future<void> _processImageOverlay(String imagePath) async {
    setState(() {
      _isProcessing = true;
      _processingMessage = 'Analyzing image structure with OCR…';
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

  void _openDocumentTranslation() {
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

  void _openTextTranslation() {
    HapticFeedback.lightImpact();
    final navigator = Navigator.of(context);
    Navigator.pop(context); // Close sheet

    navigator.push(
      MaterialPageRoute(
        builder: (_) => TranslationScreen(
          initialText: '',
          historyService: widget.historyService,
          ocrService: widget.ocrService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141721) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 25,
            spreadRadius: 5,
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        child: _isProcessing
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _processingMessage,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
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
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header Title
                  Text(
                    'Choose Translation Feature',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Option 1: Image & Camera In-Place Structure Translation
                  _buildFeatureOptionCard(
                    context: context,
                    icon: Icons.camera_enhance_rounded,
                    title: '1) Camera & Image Translation',
                    badge: 'In-Place Overlay',
                    color: const Color(0xFF2563EB),
                    onTap: () {
                      _showImageSourcePicker();
                    },
                  ),

                  const SizedBox(height: 12),

                  // Option 2: Dedicated Document Translation (PDF, Word, TXT)
                  _buildFeatureOptionCard(
                    context: context,
                    icon: Icons.picture_as_pdf_rounded,
                    title: '2) Document Translation (PDF / Word)',
                    badge: 'Multi-Page & PDF Export',
                    color: const Color(0xFF9D00FF),
                    onTap: _openDocumentTranslation,
                  ),

                  const SizedBox(height: 12),

                  // Option 3: Text Translation
                  _buildFeatureOptionCard(
                    context: context,
                    icon: Icons.translate_rounded,
                    title: '3) Text & Speech Translation',
                    badge: 'Instant Typing',
                    color: const Color(0xFF16A34A),
                    onTap: _openTextTranslation,
                  ),

                  const SizedBox(height: 10),
                ],
              ),
      ),
    );
  }

  void _showImageSourcePicker() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Image & Camera Translation',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select image source to translate in-place on the image:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),

                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded,
                      color: Color(0xFF2563EB), size: 24),
                  title: const Text('Capture with Camera',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Take photo of document or signboard'),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImageFromCamera();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded,
                      color: Color(0xFF9D00FF), size: 24),
                  title: const Text('Choose from Gallery',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Select existing photo or screenshot'),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImageFromGallery();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureOptionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    required String badge,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasSubtitle = subtitle != null && subtitle.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark
                ? color.withValues(alpha: 0.12)
                : color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.35 : 0.22),
              width: 1.3,
            ),
          ),
          child: Row(
            crossAxisAlignment:
                hasSubtitle ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                              color: isDark ? Colors.white : color,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (hasSubtitle) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
