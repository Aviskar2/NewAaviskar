import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/scan_result_model.dart';
import '../../services/translation_service.dart';
import '../../services/ocr_service.dart';
import '../../services/scan_history_service.dart';
import '../../widgets/language_picker_sheet.dart';
import '../../utils/permissions.dart';
import 'document_translation_screen.dart';

/// In-Place Image & Camera Structure Translation Screen.
/// Translates text directly onto the document photo in its exact original structure,
/// seamlessly covering/replacing original sentences with clean background masks
/// and properly scaled translated typography.
class ImageOverlayTranslationScreen extends StatefulWidget {
  final OcrResult ocrResult;
  final OcrService? ocrService;
  final ScanHistoryService? historyService;

  const ImageOverlayTranslationScreen({
    super.key,
    required this.ocrResult,
    this.ocrService,
    this.historyService,
  });

  @override
  State<ImageOverlayTranslationScreen> createState() =>
      _ImageOverlayTranslationScreenState();
}

class _ImageOverlayTranslationScreenState
    extends State<ImageOverlayTranslationScreen> {
  final TranslationService _translationService = TranslationService();
  final GlobalKey _repaintBoundaryKey = GlobalKey();

  late OcrResult _currentOcrResult;
  late final OcrService _ocrService;
  late final ScanHistoryService _historyService;

  AppLanguage _sourceLang = SupportedLanguages.english;
  AppLanguage _targetLang = SupportedLanguages.hindi;

  // View modes: 0: Translated In-Place, 1: Original Image, 2: Split View
  int _displayMode = 0;
  bool _isTranslating = false;

  /// Translated text per line index: lineIndex -> translated line text
  final Map<int, String> _translatedLines = {};

  /// Translated text per block index: blockIndex -> translated block text
  final Map<int, String> _translatedBlocks = {};

  ui.Image? _loadedImage;
  bool _imageLoaded = false;
  bool _isSavingImage = false;

  @override
  void initState() {
    super.initState();
    _currentOcrResult = widget.ocrResult;
    _ocrService = widget.ocrService ?? OcrService();
    _historyService = widget.historyService ?? ScanHistoryService();

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
    final path = _currentOcrResult.imagePath;
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

  Future<void> _captureWithCamera() async {
    final granted = await PermissionsUtil.requestCamera(context);
    if (!granted) return;

    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 95,
    );

    if (photo != null && mounted) {
      await _processNewImagePath(photo.path);
    }
  }

  Future<void> _pickFromGallery() async {
    final granted = await PermissionsUtil.requestStorage(context);
    if (!granted) return;

    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );

    if (photo != null && mounted) {
      await _processNewImagePath(photo.path);
    }
  }

  Future<void> _processNewImagePath(String path) async {
    setState(() {
      _isTranslating = true;
      _imageLoaded = false;
      _loadedImage = null;
      _translatedLines.clear();
      _translatedBlocks.clear();
    });

    try {
      final ocr = await _ocrService.recognizeFromPath(path);
      await _historyService.addOcr(ocr);

      if (!mounted) return;
      setState(() {
        _currentOcrResult = ocr;
      });

      await _loadImage();
      await _startAutoTranslation();
    } catch (e) {
      if (mounted) {
        setState(() => _isTranslating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing photo: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _startAutoTranslation() async {
    if (!mounted) return;
    setState(() {
      _isTranslating = true;
      _translatedLines.clear();
      _translatedBlocks.clear();
    });

    final allLines = _currentOcrResult.allLines;

    try {
      // 1. First translate block-level context for better linguistic coherence
      final blocks = _currentOcrResult.blocks;
      final blockTexts = blocks.map((b) => b.text.trim()).toList();
      final nonEmptyBlockIdxs = <int>[];
      final nonEmptyBlockTexts = <String>[];

      for (int i = 0; i < blockTexts.length; i++) {
        if (blockTexts[i].isNotEmpty) {
          nonEmptyBlockIdxs.add(i);
          nonEmptyBlockTexts.add(blockTexts[i]);
        }
      }

      if (nonEmptyBlockTexts.isNotEmpty) {
        final blockResults = await _translationService.translateBatch(
          nonEmptyBlockTexts,
          from: _sourceLang,
          to: _targetLang,
        );

        for (int i = 0; i < nonEmptyBlockIdxs.length; i++) {
          final bIdx = nonEmptyBlockIdxs[i];
          final trans = blockResults[i];
          if (trans != null && trans.trim().isNotEmpty) {
            _translatedBlocks[bIdx] = trans.trim();
          }
        }
      }

      // 2. Translate line-by-line for exact geometric in-place replacement
      final lineTexts = allLines.map((l) => l.text.trim()).toList();
      final nonEmptyIndices = <int>[];
      final nonEmptyTexts = <String>[];

      for (int i = 0; i < lineTexts.length; i++) {
        if (lineTexts[i].isNotEmpty) {
          nonEmptyIndices.add(i);
          nonEmptyTexts.add(lineTexts[i]);
        }
      }

      if (nonEmptyTexts.isNotEmpty) {
        final results = await _translationService.translateBatch(
          nonEmptyTexts,
          from: _sourceLang,
          to: _targetLang,
        );

        if (mounted) {
          setState(() {
            for (int idx = 0; idx < nonEmptyIndices.length; idx++) {
              final lineIdx = nonEmptyIndices[idx];
              final translated = results[idx];
              if (translated != null && translated.trim().isNotEmpty) {
                _translatedLines[lineIdx] = translated.trim();
              }
            }
          });
        }
      }

      if (mounted) {
        setState(() => _isTranslating = false);
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
      _translatedBlocks.clear();
    });
    _startAutoTranslation();
  }

  String _getFullTranslatedText() {
    final allLines = _currentOcrResult.allLines;
    final buffer = StringBuffer();
    for (int i = 0; i < allLines.length; i++) {
      final translated = _translatedLines[i];
      if (translated != null && translated.trim().isNotEmpty) {
        buffer.writeln(translated.trim());
      } else {
        final original = allLines[i].text.trim();
        if (original.isNotEmpty) buffer.writeln(original);
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

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to generate image bytes');

      final pngBytes = byteData.buffer.asUint8List();
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/translated_image_$timestamp.png');
      await file.writeAsBytes(pngBytes);

      if (mounted) {
        setState(() => _isSavingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.greenAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Translated image saved to:\n${file.path}',
                      style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
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

  void _openDocumentTranslation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentTranslationScreen(
          historyService: _historyService,
          ocrService: _ocrService,
        ),
      ),
    );
  }

  void _showSentenceInspectorSheet(int lineIndex) {
    final lines = _currentOcrResult.allLines;
    if (lineIndex < 0 || lineIndex >= lines.length) return;

    final original = lines[lineIndex].text.trim();
    final translated = _translatedLines[lineIndex] ?? original;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2230),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.translate_rounded,
                        color: Color(0xFF60A5FA), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Sentence Inspection (Line ${lineIndex + 1})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded,
                          color: Colors.white70, size: 18),
                      tooltip: 'Copy translation',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: translated));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied sentence translation'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B3247),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ORIGINAL (${_sourceLang.displayName}):',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        original,
                        style: const TextStyle(color: Colors.white70, fontSize: 13.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TRANSLATED (${_targetLang.displayName}):',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF93C5FD),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        translated,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lines = _currentOcrResult.allLines;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      body: Stack(
        children: [
          Positioned.fill(
            child: _buildMainViewer(lines),
          ),
          // Top Control Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: _buildTopControlBar(),
            ),
          ),
          // Translation Progress Pill
          if (_isTranslating)
            Positioned(
              top: 75,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
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
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Translating image structure...',
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
          // Bottom Actions Bar
          Positioned(
            bottom: 18,
            left: 14,
            right: 14,
            child: SafeArea(
              child: _buildBottomActionsBar(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopControlBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            icon: const Icon(Icons.arrow_back_rounded,
                color: Colors.white, size: 22),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back',
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2B3247),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
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
                    icon: const Icon(Icons.swap_horiz_rounded,
                        color: Color(0xFF60A5FA), size: 18),
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
          // View Mode Switcher
          IconButton(
            icon: Icon(
              _displayMode == 0
                  ? Icons.auto_fix_high_rounded
                  : _displayMode == 1
                      ? Icons.image_rounded
                      : Icons.compare_rounded,
              color: const Color(0xFF60A5FA),
              size: 20,
            ),
            tooltip: _displayMode == 0
                ? 'Mode: Structure Replaced'
                : _displayMode == 1
                    ? 'Mode: Original Image'
                    : 'Mode: Split Comparison',
            onPressed: () {
              setState(() {
                _displayMode = (_displayMode + 1) % 3;
              });
            },
          ),
          // Save image
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
                : const Icon(Icons.file_download_outlined,
                    color: Colors.white, size: 22),
            tooltip: 'Save Translated Image',
            onPressed: _saveTranslatedImage,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2230).withValues(alpha: 0.95),
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
          // Camera
          IconButton(
            onPressed: _captureWithCamera,
            icon: const Icon(Icons.camera_alt_rounded,
                color: Color(0xFF60A5FA), size: 20),
            tooltip: 'Snap Camera',
          ),
          // Gallery
          IconButton(
            onPressed: _pickFromGallery,
            icon: const Icon(Icons.photo_library_rounded,
                color: Color(0xFF9D00FF), size: 20),
            tooltip: 'Pick Image',
          ),
          Container(height: 20, width: 1, color: Colors.white24),
          // Doc Translation shortcut
          TextButton.icon(
            onPressed: _openDocumentTranslation,
            icon: const Icon(Icons.description_outlined,
                size: 16, color: Color(0xFF38BDF8)),
            label: const Text(
              'PDF/Docs',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5),
            ),
          ),
          Container(height: 20, width: 1, color: Colors.white24),
          // Copy text
          IconButton(
            onPressed: _copyAllText,
            icon: const Icon(Icons.copy_rounded,
                color: Color(0xFF93C5FD), size: 19),
            tooltip: 'Copy All Text',
          ),
        ],
      ),
    );
  }

  Widget _buildMainViewer(List<OcrLineItem> lines) {
    if (_currentOcrResult.imagePath.isEmpty ||
        !File(_currentOcrResult.imagePath).existsSync()) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_not_supported_rounded,
                color: Colors.white38, size: 48),
            const SizedBox(height: 12),
            const Text(
              'No image available',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _captureWithCamera,
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Capture Photo'),
            ),
          ],
        ),
      );
    }

    if (_displayMode == 2) {
      // Split view: Left = Original, Right = Replaced
      return Row(
        children: [
          Expanded(
            child: InteractiveViewer(
              child: Center(
                child: Image.file(
                  File(_currentOcrResult.imagePath),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Container(width: 2, color: const Color(0xFF38BDF8)),
          Expanded(
            child: InteractiveViewer(
              child: Center(
                child: _buildRepaintCanvas(lines, showTranslated: true),
              ),
            ),
          ),
        ],
      );
    }

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 6.0,
      child: Center(
        child: _buildRepaintCanvas(
          lines,
          showTranslated: _displayMode == 0,
        ),
      ),
    );
  }

  Widget _buildRepaintCanvas(List<OcrLineItem> lines,
      {required bool showTranslated}) {
    return RepaintBoundary(
      key: _repaintBoundaryKey,
      child: _imageLoaded && _loadedImage != null
          ? GestureDetector(
              onTapUp: (details) {
                // Find which line was tapped for interactive inspector
                final RenderBox? box =
                    context.findRenderObject() as RenderBox?;
                if (box == null) return;
                final localOffset = details.localPosition;
                final size = box.size;
                final scaleX = size.width / _loadedImage!.width;
                final scaleY = size.height / _loadedImage!.height;

                for (int i = 0; i < lines.length; i++) {
                  final line = lines[i];
                  if (line.boundingBox != null) {
                    final r = Rect.fromLTWH(
                      line.boundingBox!.left * scaleX,
                      line.boundingBox!.top * scaleY,
                      line.boundingBox!.width * scaleX,
                      line.boundingBox!.height * scaleY,
                    );
                    if (r.contains(localOffset)) {
                      _showSentenceInspectorSheet(i);
                      break;
                    }
                  }
                }
              },
              child: CustomPaint(
                foregroundPainter: showTranslated && _translatedLines.isNotEmpty
                    ? _InPlaceStructureOverlayPainter(
                        lines: lines,
                        translatedLines: _translatedLines,
                        imageSize: Size(
                          _loadedImage!.width.toDouble(),
                          _loadedImage!.height.toDouble(),
                        ),
                      )
                    : null,
                child: Image.file(
                  File(_currentOcrResult.imagePath),
                  fit: BoxFit.contain,
                ),
              ),
            )
          : Image.file(
              File(_currentOcrResult.imagePath),
              fit: BoxFit.contain,
            ),
    );
  }
}

/// Structure-Preserving In-Place Painter.
/// 1. Draws clean background patch masks over the original text bounding boxes
///    to completely hide and erase the original text.
/// 2. Paints the translated text scaled, fitted, and formatted directly into
///    the exact geometry and structure of the original image.
class _InPlaceStructureOverlayPainter extends CustomPainter {
  final List<OcrLineItem> lines;
  final Map<int, String> translatedLines;
  final Size imageSize;

  const _InPlaceStructureOverlayPainter({
    required this.lines,
    required this.translatedLines,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.width <= 0 || imageSize.height <= 0) return;

    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    final Paint maskPaint = Paint()
      ..color = const Color(0xFFF8FAFC) // Clean light background patch
      ..style = PaintingStyle.fill;

    final Paint maskBorderPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final translatedText = translatedLines[i];
      if (translatedText == null || translatedText.trim().isEmpty) continue;

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

      // Slightly inflate rect to cover original text ascenders/descenders completely
      final patchRect = Rect.fromLTRB(
        (lineRect.left - 2).clamp(0.0, size.width),
        (lineRect.top - 1.5).clamp(0.0, size.height),
        (lineRect.right + 2).clamp(0.0, size.width),
        (lineRect.bottom + 1.5).clamp(0.0, size.height),
      );

      final rrect = RRect.fromRectAndRadius(patchRect, const Radius.circular(3.0));

      // 1. Draw inpainting mask to completely erase original text
      canvas.drawRRect(rrect, maskPaint);
      canvas.drawRRect(rrect, maskBorderPaint);

      // 2. Measure & scale font to fit bounding box
      final lineH = patchRect.height;
      double fontSize = (lineH * 0.72).clamp(7.0, 20.0);

      TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: translatedText.trim(),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A), // High contrast dark text on clean patch
            fontFamily: 'Inter',
            height: 1.1,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      );

      textPainter.layout(maxWidth: patchRect.width);

      // Scale down if translation is longer than bounding box
      if (textPainter.width > patchRect.width && patchRect.width > 20) {
        final ratio = (patchRect.width / textPainter.width).clamp(0.45, 1.0);
        fontSize = (fontSize * ratio).clamp(6.0, 20.0);

        textPainter = TextPainter(
          text: TextSpan(
            text: translatedText.trim(),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
              fontFamily: 'Inter',
              height: 1.1,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        );
        textPainter.layout(maxWidth: patchRect.width);
      }

      // Vertical centering inside patch
      final yOffset = patchRect.top + (patchRect.height - textPainter.height) / 2;
      final xOffset = patchRect.left + 2;

      textPainter.paint(
        canvas,
        Offset(xOffset, yOffset.clamp(0, size.height - textPainter.height)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _InPlaceStructureOverlayPainter oldDelegate) =>
      oldDelegate.translatedLines != translatedLines ||
      oldDelegate.lines != lines;
}
