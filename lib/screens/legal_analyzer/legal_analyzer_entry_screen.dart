import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:archive/archive.dart';
import '../../config/api_config.dart';
import '../../core/legal/models/legal_document_type.dart';
import '../../core/legal/models/ocr_document.dart';
import '../../models/scan_result_model.dart';
import '../../services/legal/legal_orchestrator.dart';
import '../../services/ocr_service.dart';
import '../../services/scan_history_service.dart';
import 'legal_analysis_screen.dart';
import 'offer_letter_comparison_screen.dart';

class LegalAnalyzerEntryScreen extends StatefulWidget {
  final OcrService ocrService;
  final ScanHistoryService historyService;

  const LegalAnalyzerEntryScreen({
    super.key,
    required this.ocrService,
    required this.historyService,
  });

  @override
  State<LegalAnalyzerEntryScreen> createState() =>
      _LegalAnalyzerEntryScreenState();
}

class _LegalAnalyzerEntryScreenState extends State<LegalAnalyzerEntryScreen> {
  final LegalOrchestrator _orchestrator = LegalOrchestrator();
  bool _isAnalyzing = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    // Silent 24-hour background legal update
    _orchestrator.liveUpdateService.syncIfNeeded();
  }

  void _openOfferLetterComparison() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OfferLetterComparisonScreen(
          ocrService: widget.ocrService,
        ),
      ),
    );
  }

  Future<void> _analyzeRawText(
    String text, {
    String? imagePath,
    List<String>? imagePaths,
    LegalDocumentType? forcedType,
  }) async {
    // Gemini can analyze images directly even without pre-extracted text
    final hasImages = (imagePaths != null && imagePaths.isNotEmpty) ||
        (imagePath != null && imagePath.isNotEmpty);
    if (text.trim().isEmpty && !hasImages) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No readable text found in this document. Please ensure good lighting and clear focus.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final aiName = ApiConfig.aiActive && ApiConfig.effectiveApiKey.startsWith('nvapi-')
        ? 'NVIDIA NIM AI'
        : 'AI';
    setState(() {
      _isAnalyzing = true;
      _statusMessage = 'Analyzing document with $aiName…';
    });

    // Collect all image paths for Gemini multimodal analysis
    final allImagePaths = <String>[
      ...?imagePaths,
      if (imagePath != null && imagePath.isNotEmpty &&
          (imagePaths == null || !imagePaths.contains(imagePath)))
        imagePath,
    ];

    try {
      final doc = _orchestrator.createDocumentFromText(
        text,
        imagePath: imagePath,
      );
      final result = await _orchestrator
          .analyze(
            doc,
            forcedType: forcedType,
            imagePaths: allImagePaths.isNotEmpty ? allImagePaths : null,
          )
          .timeout(const Duration(seconds: 35));

      if (!mounted) return;
      setState(() => _isAnalyzing = false);

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LegalAnalysisScreen(result: result)),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _analyzeOcrDocument(
    OcrDocument doc, {
    LegalDocumentType? forcedType,
    List<String>? imagePaths,
  }) async {
    // Gemini can analyze images directly even without OCR text
    final hasImages = imagePaths != null && imagePaths.isNotEmpty;
    if (doc.rawText.trim().isEmpty && !hasImages) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No readable text found in this document. Please ensure clear focus and lighting.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final aiName = ApiConfig.aiActive && ApiConfig.effectiveApiKey.startsWith('nvapi-')
        ? 'NVIDIA NIM AI'
        : 'AI';
    setState(() {
      _isAnalyzing = true;
      _statusMessage =
          'Analyzing ${doc.pages.length} page(s) with $aiName…';
    });

    try {
      final result = await _orchestrator
          .analyze(
            doc,
            forcedType: forcedType,
            imagePaths: imagePaths,
          )
          .timeout(const Duration(seconds: 40));

      if (!mounted) return;
      setState(() => _isAnalyzing = false);

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LegalAnalysisScreen(result: result)),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Processes multiple images through OCR + Gemini AI multimodal analysis.
  Future<void> _processMultipleImages(List<String> imagePaths) async {
    if (imagePaths.isEmpty) return;

    setState(() {
      _isAnalyzing = true;
      _statusMessage = 'Running OCR on page 1 of ${imagePaths.length}…';
    });

    try {
      final ocrResults = <OcrResult>[];
      for (int i = 0; i < imagePaths.length; i++) {
        if (!mounted) return;
        setState(() {
          _statusMessage =
              'Running OCR on page ${i + 1} of ${imagePaths.length}…';
        });
        final ocrRes = await widget.ocrService.recognizeFromPath(imagePaths[i]);
        ocrResults.add(ocrRes);
      }

      final doc = _orchestrator.createDocumentFromOcrResults(ocrResults);
      // Pass original image paths for Gemini multimodal analysis
      await _analyzeOcrDocument(doc, imagePaths: imagePaths);
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OCR detection failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Static helper for background isolate PDF text extraction (avoids UI frame drops).
  static List<String> _extractPdfPagesSync(List<int> bytes) {
    final pdfDocument = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(pdfDocument);
    final pageTexts = <String>[];
    for (int i = 0; i < pdfDocument.pages.count; i++) {
      final text = extractor
          .extractText(startPageIndex: i, endPageIndex: i)
          .trim();
      if (text.isNotEmpty) {
        pageTexts.add(text);
      }
    }
    pdfDocument.dispose();
    return pageTexts;
  }

  /// Static helper for background isolate DOCX XML decompression.
  static String _extractDocxTextSync(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final docFile = archive.files.firstWhere(
      (f) => f.name == 'word/document.xml',
      orElse: () => archive.files.first,
    );
    final xmlContent = String.fromCharCodes(docFile.content as List<int>);
    return xmlContent
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Extracts all pages from a PDF document using syncfusion_flutter_pdf in background isolate.
  Future<void> _processPdfFile(String path) async {
    setState(() {
      _isAnalyzing = true;
      _statusMessage = 'Extracting pages from PDF…';
    });

    try {
      final file = File(path);
      final bytes = await file.readAsBytes();

      // Run heavy PDF decompression & text extraction off the main UI thread
      final pageTexts = await compute(_extractPdfPagesSync, bytes);

      if (pageTexts.isEmpty) {
        throw Exception(
          'No readable text found in PDF. If this is an image-only scanned PDF, please upload the pages as photos.',
        );
      }

      setState(() {
        _statusMessage =
            'Auditing ${pageTexts.length} PDF page(s) under Indian Law…';
      });

      final doc = _orchestrator.createDocumentFromTextPages(pageTexts);
      await _analyzeOcrDocument(doc);
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF extraction failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Reads plain text or parses docx XML content off the main UI thread.
  Future<void> _processTextOrDocxFile(String path) async {
    setState(() {
      _isAnalyzing = true;
      _statusMessage = 'Reading document file…';
    });

    try {
      String text = '';
      if (path.toLowerCase().endsWith('.docx')) {
        final bytes = await File(path).readAsBytes();
        text = await compute(_extractDocxTextSync, bytes);
      } else {
        text = await File(path).readAsString();
      }

      await _analyzeRawText(text);
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File reading failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Camera capture supporting continuous multi-page scanning.
  /// Captured images are sent directly to Gemini AI for multimodal analysis.
  Future<void> _startCameraCapture() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
      );
      if (image == null) return;

      final capturedImages = <String>[image.path];
      if (!mounted) return;

      _showMultiPageCaptureSheet(capturedImages);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Camera error: $e')));
      }
    }
  }

  /// Interactive sheet allowing users to add subsequent pages or analyze immediately.
  void _showMultiPageCaptureSheet(List<String> currentImages) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.photo_library_rounded,
                              color: Color(0xFFDC2626),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${currentImages.length} Page${currentImages.length > 1 ? 's' : ''} Scanned',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'You can add more pages of this agreement or proceed to analyze.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 85,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: currentImages.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (_, index) {
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(currentImages[index]),
                                  width: 65,
                                  height: 85,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                bottom: 3,
                                left: 3,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.75),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'P${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: InkWell(
                                  onTap: () {
                                    if (currentImages.length == 1) {
                                      Navigator.pop(ctx);
                                    } else {
                                      setSheetState(() {
                                        currentImages.removeAt(index);
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picker = ImagePicker();
                              final nextImage = await picker.pickImage(
                                source: ImageSource.camera,
                                imageQuality: 95,
                              );
                              if (nextImage != null) {
                                setSheetState(() {
                                  currentImages.add(nextImage.path);
                                });
                              }
                            },
                            icon: const Icon(
                              Icons.add_a_photo_rounded,
                              size: 18,
                            ),
                            label: const Text('+ Add Page'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _processMultipleImages(currentImages);
                            },
                            icon: const Icon(Icons.bolt_rounded, size: 18),
                            label: Text('Analyze (${currentImages.length})'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Browse Document sheet offering PDF, multiple photos from gallery, or docx/text files.
  Future<void> _browseDocument() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Browse Document or Photos',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Choose PDF, Word document, or multiple photos for detection',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  title: const Text(
                    'PDF Document (.pdf)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Extracts and analyzes all pages in one document',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickPdfFile();
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.photo_library_rounded,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  title: const Text(
                    'Multiple Photos / Gallery',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Select multiple photos of contract pages from gallery',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickMultiplePhotos();
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.description_rounded,
                      color: Color(0xFF059669),
                    ),
                  ),
                  title: const Text(
                    'Word / Text File (.docx, .txt)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Scan drafted legal files or raw text contracts',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickDocxOrTxt();
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.content_paste_rounded,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  title: const Text(
                    'Paste Agreement Text',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Paste text directly from clipboard or document',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showPasteDialog();
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

  Future<void> _pickPdfFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.first.path;
      if (path != null) {
        await _processPdfFile(path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open PDF picker: $e')),
        );
      }
    }
  }

  Future<void> _pickMultiplePhotos() async {
    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage(imageQuality: 95);
      if (images.isEmpty) return;
      await _processMultipleImages(images.map((img) => img.path).toList());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed picking photos: $e')));
      }
    }
  }

  Future<void> _pickDocxOrTxt() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['docx', 'txt', 'rtf'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.first.path;
      if (path != null) {
        await _processTextOrDocxFile(path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open document picker: $e')),
        );
      }
    }
  }

  void _showPasteDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paste Agreement Text'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'Paste contract, agreement, or legal clauses here...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text;
              Navigator.pop(ctx);
              if (text.trim().isNotEmpty) {
                _analyzeRawText(text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Analyze'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Widget _buildProtectionItem({
    required IconData icon,
    required Color color,
    required String title,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isAnalyzing) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 24),
                Text(
                  _statusMessage,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Powered by ${ApiConfig.aiActive && ApiConfig.effectiveApiKey.startsWith('nvapi-') ? 'NVIDIA NIM AI' : 'AI Engine'} • Cross-referencing India Code & statutory precedents',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isAnalyzing = false;
                    });
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Cancel'),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Document Analyzer'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Primary Actions
          Text(
            'CAPTURE OR UPLOAD',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionTile(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera Scan',
                  subtitle: 'Multi-page capture',
                  color: const Color(0xFFDC2626),
                  onTap: _startCameraCapture,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionTile(
                  icon: Icons.folder_open_rounded,
                  label: 'Browse Document',
                  subtitle: 'PDF, Photos & Docs',
                  color: const Color(0xFF2563EB),
                  onTap: _browseDocument,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.balance_rounded,
            label: 'Offer Letter Comparison',
            subtitle: 'Compare previous & new offer letters to find beneficial terms',
            color: const Color(0xFF7C3AED),
            onTap: _openOfferLetterComparison,
            horizontal: true,
          ),
          const SizedBox(height: 24),

          // Legal Risk Scope Info Card
          Text(
            'WHAT WE AUDIT & PROTECT',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProtectionItem(
                  icon: Icons.dangerous_rounded,
                  color: const Color(0xFFDC2626),
                  title: 'Upfront Fee & Recruitment Traps',
                ),
                const Divider(height: 20),
                _buildProtectionItem(
                  icon: Icons.gavel_rounded,
                  color: const Color(0xFFEA580C),
                  title: 'Void Non-Compete Clauses',
                ),
                const Divider(height: 20),
                _buildProtectionItem(
                  icon: Icons.account_balance_rounded,
                  color: const Color(0xFF9333EA),
                  title: 'Court & Jurisdiction Waivers',
                ),
                const Divider(height: 20),
                _buildProtectionItem(
                  icon: Icons.domain_rounded,
                  color: const Color(0xFF0284C7),
                  title: 'RERA & Model Tenancy Protection',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool horizontal;

  const _ActionTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.color,
    required this.onTap,
    this.horizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: horizontal
            ? const EdgeInsets.symmetric(vertical: 16, horizontal: 16)
            : const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: horizontal
            ? Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 24, color: color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: color,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: color,
                  ),
                ],
              )
            : Column(
                children: [
                  Icon(icon, size: 30, color: color),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: color,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
