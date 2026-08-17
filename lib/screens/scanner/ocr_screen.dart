import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/ocr_service.dart';
import '../../services/scan_history_service.dart';
import '../../utils/permissions.dart';
import 'ocr_result_screen.dart';

/// OCR entry screen — lets user pick an image from camera or gallery,
/// then runs ML Kit text recognition and opens OcrResultScreen.
class OcrScreen extends StatefulWidget {
  final ScanHistoryService historyService;
  final OcrService ocrService;
  /// If provided, OCR runs immediately on this image path on open.
  final String? initialImagePath;
  /// If true, opens TranslationScreen immediately after OCR.
  final bool autoTranslate;

  const OcrScreen({
    Key? key,
    required this.historyService,
    required this.ocrService,
    this.initialImagePath,
    this.autoTranslate = false,
  }) : super(key: key);

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialImagePath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processImage(widget.initialImagePath!);
      });
    }
  }

  Future<void> _processImage(String path) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      await widget.ocrService.validateFile(path);
      final result = await widget.ocrService.recognizeFromPath(path);
      await widget.historyService.addOcr(result);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OcrResultScreen(
            result: result,
            historyService: widget.historyService,
            autoTranslate: widget.autoTranslate,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'OCR failed: $e';
          _isProcessing = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickFromCamera() async {
    final granted = await PermissionsUtil.requestCamera(context);
    if (!granted) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 95,
    );

    if (image != null && mounted) {
      await _processImage(image.path);
    }
  }

  Future<void> _pickFromGallery() async {
    final granted = await PermissionsUtil.requestStorage(context);
    if (!granted) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );

    if (image != null && mounted) {
      await _processImage(image.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // If we were given an initial path, show loading or error
    if (widget.initialImagePath != null) {
      return Scaffold(
        body: _isProcessing
            ? _ProcessingView(message: 'Running OCR...')
            : _errorMessage != null
                ? _ErrorView(
                    message: _errorMessage!,
                    onRetry: () => _processImage(widget.initialImagePath!),
                  )
                : const SizedBox.shrink(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Text Recognition (OCR)'),
        centerTitle: true,
      ),
      body: _isProcessing
          ? _ProcessingView(message: 'Recognizing text...')
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hero illustration
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: const Color(0xFF9D00FF)
                                    .withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.document_scanner_rounded,
                                size: 56,
                                color: Color(0xFF9D00FF),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'OCR Text Recognition',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Capture or upload any image — printed documents, '
                              'handwritten notes, signs, receipts — and extract '
                              'all readable text instantly.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.6,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.red.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline,
                                        color: Colors.red, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                            color: Colors.red, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Supported formats chip row
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        'Printed text', 'Handwriting', 'Hindi/Marathi',
                        'Receipts', 'Signs', 'IDs'
                      ]
                          .map((t) => Chip(
                                label: Text(t,
                                    style:
                                        const TextStyle(fontSize: 12)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 28),

                    // Camera button
                    FilledButton.icon(
                      onPressed: _pickFromCamera,
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: const Text('Capture with Camera'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Gallery button
                    OutlinedButton.icon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Choose from Gallery'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Processing indicator view
class _ProcessingView extends StatelessWidget {
  final String message;
  const _ProcessingView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(message, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

/// Error view with retry button
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
