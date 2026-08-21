import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ocr_service.dart';
import '../services/scan_history_service.dart';
import '../utils/permissions.dart';
import '../screens/scanner/translation_screen.dart';
import '../screens/scanner/image_overlay_translation_screen.dart';

enum TranslationTargetMode {
  text,
  image,
}

/// Simple, modern translation modal with:
/// 1) Upload Image option at the start
/// 2) Exactly two translation options: Text Translation & Image Translation
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
  String? _currentImagePath;
  String? _currentImageName;
  bool _isProcessing = false;
  String _processingMessage = '';

  @override
  void initState() {
    super.initState();
    _currentImagePath = widget.initialImagePath;
    _currentImageName = widget.documentName;
  }

  Future<void> _pickImageFromCamera({TranslationTargetMode? directMode}) async {
    final granted = await PermissionsUtil.requestCamera(context);
    if (!granted) return;

    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 95,
    );

    if (photo != null && mounted) {
      final name = photo.path.split(Platform.pathSeparator).last;
      setState(() {
        _currentImagePath = photo.path;
        _currentImageName = name;
      });

      if (directMode != null) {
        await _processAndNavigate(imagePath: photo.path, mode: directMode);
      }
    }
  }

  Future<void> _pickImageFromGallery({TranslationTargetMode? directMode}) async {
    final granted = await PermissionsUtil.requestStorage(context);
    if (!granted) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );

    if (image != null && mounted) {
      final name = image.path.split(Platform.pathSeparator).last;
      setState(() {
        _currentImagePath = image.path;
        _currentImageName = name;
      });

      if (directMode != null) {
        await _processAndNavigate(imagePath: image.path, mode: directMode);
      }
    }
  }

  Future<void> _processAndNavigate({
    required String imagePath,
    required TranslationTargetMode mode,
  }) async {
    setState(() {
      _isProcessing = true;
      _processingMessage = mode == TranslationTargetMode.text
          ? 'Extracting text for translation…'
          : 'Preparing image translation…';
    });

    try {
      await widget.ocrService.validateFile(imagePath);
      final ocrResult = await widget.ocrService.recognizeFromPath(imagePath);
      await widget.historyService.addOcr(ocrResult);

      if (!mounted) return;

      Navigator.pop(context); // Close modal

      if (mode == TranslationTargetMode.text) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TranslationScreen(
              initialText: ocrResult.fullText,
              historyService: widget.historyService,
              ocrService: widget.ocrService,
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ImageOverlayTranslationScreen(
              ocrResult: ocrResult,
            ),
          ),
        );
      }
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

  void _onSelectMode(TranslationTargetMode mode) async {
    HapticFeedback.mediumImpact();

    if (_currentImagePath != null &&
        _currentImagePath!.isNotEmpty &&
        File(_currentImagePath!).existsSync()) {
      await _processAndNavigate(
        imagePath: _currentImagePath!,
        mode: mode,
      );
      return;
    }

    // No image selected yet -> show source picker
    _showSourcePicker(mode);
  }

  void _showSourcePicker(TranslationTargetMode mode) {
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
                  'Upload Document Image',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose how you want to upload your document:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),

                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF2563EB)),
                  title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w600)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImageFromCamera(directMode: mode);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF9D00FF)),
                  title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImageFromGallery(directMode: mode);
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
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
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
                    'Document Translation',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Upload your document and choose how to translate:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 1) UPLOAD IMAGE SECTION AT THE START
                  if (_currentImagePath == null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2230) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.upload_file_rounded, color: Color(0xFF2563EB), size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Step 1: Upload Document Image',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickImageFromCamera(),
                                  icon: const Icon(Icons.camera_alt_rounded, size: 18),
                                  label: const Text('Camera'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF2563EB),
                                    side: const BorderSide(color: Color(0xFF2563EB)),
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickImageFromGallery(),
                                  icon: const Icon(Icons.photo_library_rounded, size: 18),
                                  label: const Text('Gallery'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF9D00FF),
                                    side: const BorderSide(color: Color(0xFF9D00FF)),
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Image already attached preview
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_currentImagePath!),
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.image_rounded,
                                color: Color(0xFF2563EB),
                                size: 28,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentImageName ?? 'Document attached',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Ready for translation',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF2563EB),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _currentImagePath = null;
                                _currentImageName = null;
                              });
                            },
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // SECTION 2: THE TWO TRANSLATION OPTIONS
                  Text(
                    'Step 2: Choose Translation Mode',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Option 1: Text Translation
                  _buildSimpleOptionTile(
                    context: context,
                    icon: Icons.text_snippet_rounded,
                    title: '1) Text Translation',
                    subtitle: 'Converts document text into clean, readable translated text',
                    color: const Color(0xFF2563EB),
                    onTap: () => _onSelectMode(TranslationTargetMode.text),
                  ),

                  const SizedBox(height: 10),

                  // Option 2: Image Translation
                  _buildSimpleOptionTile(
                    context: context,
                    icon: Icons.photo_filter_rounded,
                    title: '2) Image Translation',
                    subtitle: 'Translates directly onto the image with exact font size & layout',
                    color: const Color(0xFF9D00FF),
                    onTap: () => _onSelectMode(TranslationTargetMode.image),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
      ),
    );
  }

  Widget _buildSimpleOptionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2230) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.35 : 0.25),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
