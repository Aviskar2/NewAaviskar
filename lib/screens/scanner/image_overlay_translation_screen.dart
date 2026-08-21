import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/scan_result_model.dart';
import '../../services/translation_service.dart';
import '../../widgets/language_picker_sheet.dart';

/// High-Fidelity Image Translation Screen.
/// Translates text line-by-line directly on the document image, preserving the original
/// font size, line spacing, and paper background so it looks like the original image.
class ImageOverlayTranslationScreen extends StatefulWidget {
  final OcrResult ocrResult;

  const ImageOverlayTranslationScreen({super.key, required this.ocrResult});

  @override
  State<ImageOverlayTranslationScreen> createState() =>
      _ImageOverlayTranslationScreenState();
}

class _ImageOverlayTranslationScreenState
    extends State<ImageOverlayTranslationScreen> {
  final TranslationService _translationService = TranslationService();
  final GlobalKey _repaintBoundaryKey = GlobalKey();

  AppLanguage _sourceLang = SupportedLanguages.english;
  AppLanguage _targetLang = SupportedLanguages.hindi;

  bool _showTranslated = true;
  bool _isTranslating = false;

  /// Translated text per line index (index → translated string)
  final Map<int, String> _translatedLines = {};

  ui.Image? _loadedImage;
  bool _imageLoaded = false;
  bool _isSavingImage = false;

  @override
  void initState() {
    super.initState();
    _loadImage().then((_) {
      _startAutoTranslation();
    });
  }

  @override
  void dispose() {
    _translationService.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    final path = widget.ocrResult.imagePath;
    if (path.isEmpty || !File(path).existsSync()) return;
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _loadedImage = frame.image;
          _imageLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading image for overlay: $e');
    }
  }

  Future<void> _startAutoTranslation() async {
    if (!mounted) return;
    setState(() {
      _isTranslating = true;
      _translatedLines.clear();
      _showTranslated = true;
    });

    final allLines = widget.ocrResult.allLines;
    final texts = allLines.map((l) => l.text).toList();

    try {
      // Parallel batch translation per line for exact bounding box matching
      final results = await _translationService.translateBatch(
        texts,
        from: _sourceLang,
        to: _targetLang,
      );

      if (mounted) {
        setState(() {
          _translatedLines.addAll(results);
          _isTranslating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTranslating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Translation error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _swapLanguages() {
    setState(() {
      final temp = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = temp;
      _translatedLines.clear();
    });
    _startAutoTranslation();
  }

  String _getFullTranslatedText() {
    final allLines = widget.ocrResult.allLines;
    final buffer = StringBuffer();
    for (int i = 0; i < allLines.length; i++) {
      final translated = _translatedLines[i] ?? allLines[i].text;
      if (translated.trim().isNotEmpty) {
        buffer.writeln(translated.trim());
      }
    }
    return buffer.toString();
  }

  void _copyAllText() {
    final text = _getFullTranslatedText();
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Translated text copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveTranslatedImage() async {
    if (_isSavingImage) return;
    setState(() => _isSavingImage = true);

    try {
      final boundary = _repaintBoundaryKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Visual tree not ready');

      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to generate image bytes');

      final pngBytes = byteData.buffer.asUint8List();
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/translated_doc_$timestamp.png');
      await file.writeAsBytes(pngBytes);

      if (mounted) {
        setState(() => _isSavingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
                SizedBox(width: 10),
                Expanded(child: Text('Translated image saved to device!')),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving translated image: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.ocrResult.allLines;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      body: Stack(
        children: [
          // Main Interactive Image Canvas
          Positioned.fill(
            child: _buildMainViewer(lines),
          ),

          // Simple, Sleek Top Control Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: _buildSimpleTopBar(),
            ),
          ),

          // Translation Loading Indicator
          if (_isTranslating)
            Positioned(
              top: 75,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 10,
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Translating on image…',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Simple Bottom Action Bar
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: SafeArea(
              child: _buildSimpleBottomBar(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleTopBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2230).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back',
          ),

          // Language Selector Pill
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2B3247),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final picked = await LanguagePickerSheet.show(
                        context,
                        languages: SupportedLanguages.all,
                        selected: _sourceLang,
                        title: 'Source Language',
                      );
                      if (picked != null && mounted) {
                        setState(() => _sourceLang = picked);
                        _startAutoTranslation();
                      }
                    },
                    child: Text(
                      _sourceLang.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF60A5FA), size: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    constraints: const BoxConstraints(),
                    onPressed: _swapLanguages,
                  ),
                  GestureDetector(
                    onTap: () async {
                      final picked = await LanguagePickerSheet.show(
                        context,
                        languages: SupportedLanguages.all,
                        selected: _targetLang,
                        title: 'Target Language',
                      );
                      if (picked != null && mounted) {
                        setState(() => _targetLang = picked);
                        _startAutoTranslation();
                      }
                    },
                    child: Text(
                      _targetLang.displayName,
                      style: const TextStyle(
                        color: Color(0xFF93C5FD),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 4),

          // Toggle Original vs Translated
          IconButton(
            icon: Icon(
              _showTranslated ? Icons.translate_rounded : Icons.image_outlined,
              color: _showTranslated ? const Color(0xFF60A5FA) : Colors.white60,
              size: 21,
            ),
            tooltip: _showTranslated ? 'Viewing Translated' : 'Viewing Original',
            onPressed: () => setState(() => _showTranslated = !_showTranslated),
          ),

          // Save Image Button
          IconButton(
            icon: _isSavingImage
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.file_download_outlined, color: Colors.white, size: 22),
            tooltip: 'Save Translated Image',
            onPressed: _saveTranslatedImage,
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2230).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 15,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton.icon(
            onPressed: _copyAllText,
            icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF93C5FD)),
            label: const Text(
              'Copy Text',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Container(height: 20, width: 1, color: Colors.white24),
          TextButton.icon(
            onPressed: _saveTranslatedImage,
            icon: const Icon(Icons.save_alt_rounded, size: 18, color: Color(0xFF93C5FD)),
            label: const Text(
              'Save Image',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainViewer(List<OcrLineItem> lines) {
    if (widget.ocrResult.imagePath.isEmpty ||
        !File(widget.ocrResult.imagePath).existsSync()) {
      return Center(
        child: Text(
          'No image available',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        ),
      );
    }

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 6.0,
      child: Center(
        child: RepaintBoundary(
          key: _repaintBoundaryKey,
          child: _imageLoaded && _loadedImage != null
              ? CustomPaint(
                  foregroundPainter: _showTranslated && _translatedLines.isNotEmpty
                      ? _PreciseDocumentLineOverlayPainter(
                          lines: lines,
                          translations: _translatedLines,
                          imageSize: Size(
                            _loadedImage!.width.toDouble(),
                            _loadedImage!.height.toDouble(),
                          ),
                        )
                      : null,
                  child: Image.file(
                    File(widget.ocrResult.imagePath),
                    fit: BoxFit.contain,
                  ),
                )
              : Image.file(
                  File(widget.ocrResult.imagePath),
                  fit: BoxFit.contain,
                ),
        ),
      ),
    );
  }
}

/// Precise line-by-line document inpainting and overlay painter.
/// Sets the text size proportionally to match the original line height exactly,
/// without overlaps, giant fonts, or clutter.
class _PreciseDocumentLineOverlayPainter extends CustomPainter {
  final List<OcrLineItem> lines;
  final Map<int, String> translations;
  final Size imageSize;

  const _PreciseDocumentLineOverlayPainter({
    required this.lines,
    required this.translations,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.width <= 0 || imageSize.height <= 0) return;

    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final translated = translations[i];
      if (translated == null || translated.trim().isEmpty) continue;

      Rect lineRect;
      if (line.boundingBox != null) {
        lineRect = Rect.fromLTWH(
          line.boundingBox!.left * scaleX,
          line.boundingBox!.top * scaleY,
          line.boundingBox!.width * scaleX,
          line.boundingBox!.height * scaleY,
        );
      } else {
        final yFraction = (i / lines.length).clamp(0.0, 0.9);
        lineRect = Rect.fromLTWH(
          size.width * 0.08,
          size.height * yFraction + 10,
          size.width * 0.84,
          20,
        );
      }

      // Step 1: Clean inpainting patch to mask the original line cleanly
      final inpaintRect = Rect.fromLTRB(
        lineRect.left - 1.5,
        lineRect.top - 1.0,
        lineRect.right + 1.5,
        lineRect.bottom + 1.0,
      );

      final inpaintBgPaint = Paint()
        ..color = const Color(0xFFFFFFFF) // Crisp white clean paper mask
        ..style = PaintingStyle.fill;

      canvas.drawRect(inpaintRect, inpaintBgPaint);

      // Step 2: Proportional font sizing matching the original line height
      final lineH = inpaintRect.height;
      // Target font size: standard typography is ~65-70% of line box height
      double fontSize = (lineH * 0.68).clamp(8.0, 16.0);

      // Test layout to ensure it fits the width
      TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: translated.trim(),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F172A), // Sharp dark document ink
            height: 1.1,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      );

      textPainter.layout();

      // If translated text is longer than the line width, scale font size proportionally
      if (textPainter.width > inpaintRect.width && inpaintRect.width > 20) {
        final scaleRatio = (inpaintRect.width / textPainter.width).clamp(0.65, 1.0);
        fontSize = (fontSize * scaleRatio).clamp(7.5, 16.0);

        textPainter = TextPainter(
          text: TextSpan(
            text: translated.trim(),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
              height: 1.1,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        );
        textPainter.layout(maxWidth: inpaintRect.width);
      }

      // Paint text vertically centered within the line rectangle
      final xOffset = inpaintRect.left + 1.0;
      final yOffset = inpaintRect.top + (inpaintRect.height - textPainter.height) / 2;

      textPainter.paint(canvas, Offset(xOffset, yOffset));
    }
  }

  @override
  bool shouldRepaint(covariant _PreciseDocumentLineOverlayPainter oldDelegate) =>
      oldDelegate.translations != translations ||
      oldDelegate.lines != lines;
}
