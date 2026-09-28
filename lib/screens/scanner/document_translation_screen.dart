import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:archive/archive.dart';
import '../../services/translation_service.dart';
import '../../services/ocr_service.dart';
import '../../services/scan_history_service.dart';
import '../../widgets/language_picker_sheet.dart';

/// Represents a single structured section/paragraph of a document
class DocumentSection {
  final int pageNumber;
  final String originalText;
  String? translatedText;
  final bool isHeading;
  final bool isBullet;

  DocumentSection({
    required this.pageNumber,
    required this.originalText,
    this.translatedText,
    this.isHeading = false,
    this.isBullet = false,
  });
}

/// Dedicated Multi-Format Document Translation Screen
/// Supports PDF (Digital & Scanned), Word (DOCX / DOC), TXT, RTF, and Document Images
/// with structured page-by-page translation, side-by-side view, and translated PDF export.
class DocumentTranslationScreen extends StatefulWidget {
  final String? initialFilePath;
  final String? initialFileName;
  final bool autoPickFile;
  final ScanHistoryService historyService;
  final OcrService? ocrService;

  const DocumentTranslationScreen({
    super.key,
    this.initialFilePath,
    this.initialFileName,
    this.autoPickFile = false,
    required this.historyService,
    this.ocrService,
  });

  @override
  State<DocumentTranslationScreen> createState() =>
      _DocumentTranslationScreenState();
}

class _DocumentTranslationScreenState extends State<DocumentTranslationScreen>
    with SingleTickerProviderStateMixin {
  final TranslationService _translationService = TranslationService();
  late final OcrService _ocrService;

  AppLanguage _sourceLang = SupportedLanguages.english;
  AppLanguage _targetLang = SupportedLanguages.hindi;

  String? _filePath;
  String? _fileName;
  String? _fileExt;

  bool _isExtracting = false;
  bool _isTranslating = false;
  double _translationProgress = 0.0;
  String? _errorMessage;

  List<DocumentSection> _sections = [];
  int _currentPage = 1;
  int _totalPages = 1;

  bool _savedToHistory = false;
  bool _isExportingPdf = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _ocrService = widget.ocrService ?? OcrService();
    _tabController = TabController(length: 3, vsync: this);

    if (widget.initialFilePath != null &&
        File(widget.initialFilePath!).existsSync()) {
      _filePath = widget.initialFilePath;
      _fileName = widget.initialFileName ??
          widget.initialFilePath!.split(Platform.pathSeparator).last;
      _fileExt = _fileName?.split('.').last.toLowerCase() ?? '';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _extractAndTranslate();
      });
    } else if (widget.autoPickFile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pickDocument();
      });
    }
  }

  @override
  void dispose() {
    _translationService.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    try {
      FilePickerResult? result;
      try {
        result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: [
            'pdf',
            'docx',
            'doc',
            'txt',
            'rtf',
            'csv',
            'md',
            'jpg',
            'jpeg',
            'png',
            'webp',
            'bmp',
          ],
          allowMultiple: false,
        );
      } catch (e) {
        debugPrint('Custom file picker failed: $e, falling back to FileType.any...');
        result = await FilePicker.pickFiles(
          type: FileType.any,
          allowMultiple: false,
        );
      }

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final path = file.path;
      if (path == null || !mounted) return;

      setState(() {
        _filePath = path;
        _fileName = file.name;
        _fileExt = (file.extension ?? path.split('.').last).toLowerCase();
        _sections.clear();
        _errorMessage = null;
        _savedToHistory = false;
        _currentPage = 1;
      });

      await _extractAndTranslate();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to open file picker: $e';
        });
      }
    }
  }

  Future<void> _extractAndTranslate() async {
    if (_filePath == null || !File(_filePath!).existsSync()) return;

    setState(() {
      _isExtracting = true;
      _errorMessage = null;
      _sections.clear();
    });

    try {
      final ext = _fileExt ?? '';
      List<DocumentSection> extracted = [];

      if (ext == 'pdf') {
        extracted = await _parsePdf(_filePath!);
      } else if (ext == 'docx') {
        extracted = await _parseDocx(_filePath!);
      } else if (ext == 'doc') {
        extracted = await _parseDoc(_filePath!);
      } else if (ext == 'rtf') {
        extracted = await _parseRtf(_filePath!);
      } else if (['jpg', 'jpeg', 'png', 'webp', 'bmp'].contains(ext)) {
        extracted = await _parseImage(_filePath!);
      } else {
        extracted = await _parseTxt(_filePath!);
      }

      // If text extraction yielded nothing, try OCR fallback
      if (extracted.isEmpty) {
        extracted = await _tryOcrFallback(_filePath!);
      }

      if (extracted.isEmpty) {
        setState(() {
          _isExtracting = false;
          _errorMessage =
              'No readable text could be extracted from this document. Please ensure the file is not password protected.';
        });
        return;
      }

      // Calculate total pages
      final maxPage = extracted
          .map((s) => s.pageNumber)
          .fold(1, (a, b) => a > b ? a : b);

      if (!mounted) return;
      setState(() {
        _sections = extracted;
        _totalPages = maxPage;
        _isExtracting = false;
      });

      // Automatically start translating
      await _translateAllSections();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExtracting = false;
          _errorMessage = 'Failed to extract document: $e';
        });
      }
    }
  }

  /// PDF Parser with robust multi-page sentence extraction
  Future<List<DocumentSection>> _parsePdf(String path) async {
    final List<DocumentSection> sections = [];

    try {
      final bytes = await File(path).readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);

      for (int i = 0; i < document.pages.count; i++) {
        final pageNum = i + 1;
        final pageText =
            extractor.extractText(startPageIndex: i, endPageIndex: i).trim();

        if (pageText.isNotEmpty) {
          final pageSections = _splitIntoStructuredSections(pageText, pageNum);
          sections.addAll(pageSections);
        }
      }

      document.dispose();
    } catch (e) {
      debugPrint('Syncfusion PDF extraction error: $e. Trying raw stream fallback...');
      final rawSections = await _extractPdfRawStream(path);
      if (rawSections.isNotEmpty) {
        return rawSections;
      }
    }

    return sections;
  }

  /// Raw stream text extractor for encrypted/non-standard PDFs
  Future<List<DocumentSection>> _extractPdfRawStream(String path) async {
    final List<DocumentSection> sections = [];
    try {
      final bytes = await File(path).readAsBytes();
      final content = latin1.decode(bytes);

      // Extract text inside Tj and TJ operators
      final tjRegex = RegExp(r'\((.*?)\)\s*Tj');
      final tjMatches = tjRegex.allMatches(content);

      final buffer = StringBuffer();
      for (final m in tjMatches) {
        final snippet = m.group(1) ?? '';
        if (snippet.trim().isNotEmpty) {
          buffer.write('$snippet ');
        }
      }

      final text = buffer.toString().trim();
      if (text.isNotEmpty) {
        sections.addAll(_splitIntoStructuredSections(text, 1));
      }
    } catch (e) {
      debugPrint('Raw PDF stream extraction error: $e');
    }
    return sections;
  }

  /// DOCX Parser (Word OpenXML)
  Future<List<DocumentSection>> _parseDocx(String path) async {
    final bytes = await File(path).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // Find main document file
    final docFile = archive.files.firstWhere(
      (f) => f.name == 'word/document.xml',
      orElse: () => archive.files.firstWhere(
        (f) => f.name.endsWith('.xml'),
        orElse: () => archive.files.first,
      ),
    );

    final xmlContent =
        utf8.decode(docFile.content as List<int>, allowMalformed: true);

    final paragraphRegex = RegExp(r'<w:p(?:[^>]*)>(.*?)</w:p>', dotAll: true);
    final textRegex = RegExp(r'<w:t(?:[^>]*)>(.*?)</w:t>', dotAll: true);

    final matches = paragraphRegex.allMatches(xmlContent);
    final List<DocumentSection> sections = [];
    int estimatedPage = 1;
    int sectionCounter = 0;

    for (final m in matches) {
      final pXml = m.group(1) ?? '';

      // Replace tabs and line breaks
      final normalizedXml = pXml
          .replaceAll('<w:tab/>', '    ')
          .replaceAll('<w:br/>', '\n');

      final tMatches = textRegex.allMatches(normalizedXml);
      final pText = tMatches
          .map((tm) => tm.group(1) ?? '')
          .map((t) => t.replaceAll(RegExp(r'<[^>]+>'), ''))
          .join('')
          .trim();

      if (pText.isNotEmpty) {
        sectionCounter++;
        if (sectionCounter > 12) {
          estimatedPage++;
          sectionCounter = 0;
        }

        final isHeading = pXml.contains('Heading') ||
            (pText.length < 55 && !pText.endsWith('.'));
        final isBullet = pXml.contains('numPr') ||
            pText.startsWith('•') ||
            pText.startsWith('-') ||
            RegExp(r'^\d+[\.\)]').hasMatch(pText);

        sections.add(DocumentSection(
          pageNumber: estimatedPage,
          originalText: pText,
          isHeading: isHeading,
          isBullet: isBullet,
        ));
      }
    }

    return sections;
  }

  /// DOC Parser for Word 97-2003 Binary Format
  Future<List<DocumentSection>> _parseDoc(String path) async {
    final bytes = await File(path).readAsBytes();
    final List<DocumentSection> sections = [];

    final buffer = StringBuffer();
    final List<String> extractedParagraphs = [];

    for (int i = 0; i < bytes.length; i++) {
      final byte = bytes[i];
      if ((byte >= 32 && byte <= 126) || byte == 10 || byte == 13) {
        buffer.writeCharCode(byte);
      } else {
        if (buffer.length >= 10) {
          final str = buffer.toString().trim();
          if (str.length >= 15 &&
              !str.startsWith('Microsoft') &&
              !str.startsWith('Word.Document')) {
            extractedParagraphs.add(str);
          }
        }
        buffer.clear();
      }
    }

    if (buffer.length >= 10) {
      extractedParagraphs.add(buffer.toString().trim());
    }

    int pageNum = 1;
    for (int i = 0; i < extractedParagraphs.length; i++) {
      if (i > 0 && i % 10 == 0) pageNum++;
      final p = extractedParagraphs[i];
      sections.add(DocumentSection(
        pageNumber: pageNum,
        originalText: p,
        isHeading: p.length < 50 && !p.endsWith('.'),
        isBullet: p.startsWith('•') || p.startsWith('-'),
      ));
    }

    return sections;
  }

  /// RTF Parser
  Future<List<DocumentSection>> _parseRtf(String path) async {
    final bytes = await File(path).readAsBytes();
    String content = utf8.decode(bytes, allowMalformed: true);

    content = content
        .replaceAll(RegExp(r'\\[a-z0-9]+', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'[\{\}]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return _splitIntoStructuredSections(content, 1);
  }

  /// Document Image Parser (OCR)
  Future<List<DocumentSection>> _parseImage(String path) async {
    final ocr = await _ocrService.recognizeFromPath(path);
    await widget.historyService.addOcr(ocr);
    if (ocr.fullText.trim().isNotEmpty) {
      return _splitIntoStructuredSections(ocr.fullText, 1);
    }
    return [];
  }

  /// Plain Text Parser
  Future<List<DocumentSection>> _parseTxt(String path) async {
    final bytes = await File(path).readAsBytes();
    String text;
    try {
      text = utf8.decode(bytes);
    } catch (_) {
      text = latin1.decode(bytes);
    }

    return _splitIntoStructuredSections(text, 1);
  }

  /// OCR Fallback for scanned documents
  Future<List<DocumentSection>> _tryOcrFallback(String path) async {
    final List<DocumentSection> sections = [];
    try {
      final ocr = await _ocrService.recognizeFromPath(path);
      if (ocr.fullText.trim().isNotEmpty) {
        sections.addAll(_splitIntoStructuredSections(ocr.fullText, 1));
      }
    } catch (e) {
      debugPrint('OCR fallback error on document: $e');
    }
    return sections;
  }

  /// Splits raw text into readable, structured paragraphs
  List<DocumentSection> _splitIntoStructuredSections(
      String text, int initialPage) {
    final List<DocumentSection> result = [];
    final rawParagraphs = text.split(RegExp(r'\r?\n\s*\r?\n'));

    int currentPage = initialPage;
    int sectionCount = 0;

    for (final rawP in rawParagraphs) {
      final trimmed = rawP.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.length > 800) {
        final sentences = trimmed.split(RegExp(r'(?<=[.!?])\s+'));
        StringBuffer sentenceChunk = StringBuffer();

        for (final s in sentences) {
          if (sentenceChunk.length + s.length > 500 &&
              sentenceChunk.isNotEmpty) {
            sectionCount++;
            if (sectionCount > 10) {
              currentPage++;
              sectionCount = 0;
            }
            result.add(DocumentSection(
              pageNumber: currentPage,
              originalText: sentenceChunk.toString().trim(),
            ));
            sentenceChunk.clear();
          }
          if (sentenceChunk.isNotEmpty) sentenceChunk.write(' ');
          sentenceChunk.write(s);
        }

        if (sentenceChunk.isNotEmpty) {
          sectionCount++;
          result.add(DocumentSection(
            pageNumber: currentPage,
            originalText: sentenceChunk.toString().trim(),
          ));
        }
      } else {
        sectionCount++;
        if (sectionCount > 10) {
          currentPage++;
          sectionCount = 0;
        }

        final isHeading = trimmed.length < 60 &&
            !trimmed.endsWith('.') &&
            !trimmed.contains('\n');
        final isBullet = trimmed.startsWith('•') ||
            trimmed.startsWith('-') ||
            RegExp(r'^\d+[\.\)]').hasMatch(trimmed);

        result.add(DocumentSection(
          pageNumber: currentPage,
          originalText: trimmed,
          isHeading: isHeading,
          isBullet: isBullet,
        ));
      }
    }

    return result;
  }

  Future<void> _translateAllSections() async {
    if (_sections.isEmpty) return;

    setState(() {
      _isTranslating = true;
      _translationProgress = 0.0;
      _errorMessage = null;
    });

    try {
      final texts = _sections.map((s) => s.originalText).toList();
      final total = texts.length;
      int completed = 0;

      const batchSize = 4;
      for (int i = 0; i < texts.length; i += batchSize) {
        if (!mounted) return;
        final end = (i + batchSize < total) ? i + batchSize : total;
        final chunk = texts.sublist(i, end);

        final results = await _translationService.translateBatch(
          chunk,
          from: _sourceLang,
          to: _targetLang,
        );

        for (int j = 0; j < chunk.length; j++) {
          final sIndex = i + j;
          final translated = results[j];
          if (translated != null && translated.trim().isNotEmpty) {
            _sections[sIndex].translatedText = translated.trim();
          } else {
            try {
              final fallback = await _translationService.translateOnline(
                chunk[j],
                fromCode: _sourceLang.onlineCode,
                toCode: _targetLang.onlineCode,
              );
              _sections[sIndex].translatedText =
                  fallback?.trim() ?? _sections[sIndex].originalText;
            } catch (_) {
              _sections[sIndex].translatedText = _sections[sIndex].originalText;
            }
          }
          completed++;
        }

        if (mounted) {
          setState(() {
            _translationProgress = (completed / total).clamp(0.0, 1.0);
          });
        }
      }

      if (mounted) {
        setState(() => _isTranslating = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTranslating = false;
          _errorMessage = 'Translation error: $e';
        });
      }
    }
  }

  Future<void> _exportAsPdf() async {
    if (_sections.isEmpty || _isExportingPdf) return;

    setState(() => _isExportingPdf = true);

    try {
      final PdfDocument document = PdfDocument();

      // Group sections by page
      final Map<int, List<DocumentSection>> pages = {};
      for (final s in _sections) {
        pages.putIfAbsent(s.pageNumber, () => []).add(s);
      }

      // Standard A4 dimensions in points: 595 x 842
      const double a4Width = 595.0;
      const double a4Height = 842.0;
      const double scale = 2.0; // 2x high-resolution DPI
      final int canvasWidth = (a4Width * scale).toInt();
      final int canvasHeight = (a4Height * scale).toInt();
      const double padding = 36.0 * scale;
      final double contentWidth = canvasWidth - (padding * 2);

      for (final pageNum in pages.keys) {
        final ui.PictureRecorder recorder = ui.PictureRecorder();
        final Canvas canvas = Canvas(recorder);

        // Draw clean white background
        final Paint bgPaint = Paint()..color = Colors.white;
        canvas.drawRect(
            Rect.fromLTWH(
                0, 0, canvasWidth.toDouble(), canvasHeight.toDouble()),
            bgPaint);

        // Draw top header
        final headerPainter = TextPainter(
          text: TextSpan(
            text:
                'Translated Document (${_targetLang.displayName}) — Page $pageNum',
            style: const TextStyle(
              fontSize: 10.0 * scale,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        headerPainter.layout(maxWidth: contentWidth);
        headerPainter.paint(canvas, Offset(padding, 20.0 * scale));

        // Draw subtle separator line
        final Paint linePaint = Paint()
          ..color = const Color(0xFFE2E8F0)
          ..strokeWidth = 1.0 * scale;
        canvas.drawLine(
          Offset(padding, 34.0 * scale),
          Offset(canvasWidth - padding, 34.0 * scale),
          linePaint,
        );

        double yPos = 44.0 * scale;
        final pageSections = pages[pageNum] ?? [];

        for (final section in pageSections) {
          final text = section.translatedText ?? section.originalText;
          if (text.trim().isEmpty) continue;

          final isHeading = section.isHeading;
          final isBullet = section.isBullet;

          final textPainter = TextPainter(
            text: TextSpan(
              text: isBullet ? '•  $text' : text,
              style: TextStyle(
                fontSize: (isHeading ? 13.5 : 10.0) * scale,
                fontWeight: isHeading ? FontWeight.w800 : FontWeight.w500,
                color: isHeading
                    ? const Color(0xFF1E3A8A)
                    : const Color(0xFF0F172A),
                height: 1.45,
              ),
            ),
            textDirection: TextDirection.ltr,
          );

          textPainter.layout(maxWidth: contentWidth);

          // Prevent overflow past bottom margin
          if (yPos + textPainter.height > canvasHeight - (28.0 * scale)) {
            break;
          }

          textPainter.paint(canvas, Offset(padding, yPos));
          yPos += textPainter.height + (isHeading ? 10.0 * scale : 6.0 * scale);
        }

        // Draw bottom footer
        final footerPainter = TextPainter(
          text: TextSpan(
            text: 'ScanSure Document Translator • Verified',
            style: const TextStyle(
              fontSize: 8.5 * scale,
              color: Color(0xFF94A3B8),
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        footerPainter.layout(maxWidth: contentWidth);
        footerPainter.paint(
          canvas,
          Offset(padding, canvasHeight - (20.0 * scale)),
        );

        final ui.Picture picture = recorder.endRecording();
        final ui.Image renderedImage =
            await picture.toImage(canvasWidth, canvasHeight);
        final ByteData? byteData =
            await renderedImage.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) continue;

        final pngBytes = byteData.buffer.asUint8List();
        final PdfPage pdfPage = document.pages.add();
        final PdfBitmap pdfBitmap = PdfBitmap(pngBytes);
        pdfPage.graphics.drawImage(
          pdfBitmap,
          Rect.fromLTWH(0, 0, pdfPage.getClientSize().width,
              pdfPage.getClientSize().height),
        );
      }

      final List<int> bytes = await document.save();
      document.dispose();

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/translated_doc_$timestamp.pdf');
      await file.writeAsBytes(bytes, flush: true);

      if (mounted) {
        setState(() => _isExportingPdf = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.greenAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('PDF saved successfully to:\n${file.path}',
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
        setState(() => _isExportingPdf = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _copyAllTranslatedText() {
    final buffer = StringBuffer();
    for (final s in _sections) {
      final text = s.translatedText ?? s.originalText;
      if (s.isHeading) {
        buffer.writeln('\n### $text\n');
      } else if (s.isBullet) {
        buffer.writeln('• $text');
      } else {
        buffer.writeln('$text\n');
      }
    }

    final text = buffer.toString().trim();
    if (text.isEmpty) return;

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All translated text copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveToHistory() async {
    if (_sections.isEmpty || _savedToHistory) return;

    final originalFull = _sections.map((s) => s.originalText).join('\n\n');
    final translatedFull =
        _sections.map((s) => s.translatedText ?? s.originalText).join('\n\n');

    await widget.historyService.addTranslation(
      originalText: '[$_fileName]\n$originalFull',
      translatedText: translatedFull,
      sourceLang: _sourceLang.displayName,
      targetLang: _targetLang.displayName,
    );

    setState(() => _savedToHistory = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document translation saved to History'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _swapLanguages() {
    setState(() {
      final temp = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = temp;
      for (final s in _sections) {
        s.translatedText = null;
      }
    });
    _translateAllSections();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _fileName != null ? 'Document: $_fileName' : 'Document Translation',
          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Open Another Document',
            onPressed: _pickDocument,
          ),
          if (_sections.isNotEmpty) ...[
            IconButton(
              icon: _isExportingPdf
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Export as Translated PDF',
              onPressed: _exportAsPdf,
            ),
            IconButton(
              icon: Icon(
                _savedToHistory
                    ? Icons.bookmark_added_rounded
                    : Icons.bookmark_add_outlined,
                color: _savedToHistory ? const Color(0xFF2563EB) : null,
              ),
              tooltip: 'Save to History',
              onPressed: _saveToHistory,
            ),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(102),
          child: Column(
            children: [
              // Language Selector Bar
              _buildLanguageBar(theme, isDark),
              // View Mode Tabs
              TabBar(
                controller: _tabController,
                indicatorColor: theme.colorScheme.primary,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                tabs: const [
                  Tab(
                      icon: Icon(Icons.menu_book_rounded, size: 18),
                      text: 'Translated Doc'),
                  Tab(
                      icon: Icon(Icons.vertical_split_rounded, size: 18),
                      text: 'Side-by-Side'),
                  Tab(
                      icon: Icon(Icons.history_edu_rounded, size: 18),
                      text: 'Original Text'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _buildBody(theme, isDark),
      bottomNavigationBar:
          _sections.isNotEmpty ? _buildBottomBar(theme, isDark) : null,
    );
  }

  Widget _buildLanguageBar(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B0424) : const Color(0xFFF0F4FF),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF32113D) : const Color(0xFFDDE7FF),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final picked = await LanguagePickerSheet.show(
                  context,
                  languages: SupportedLanguages.all,
                  selected: _sourceLang,
                  title: 'Source Language',
                );
                if (picked != null && mounted) {
                  setState(() => _sourceLang = picked);
                  _translateAllSections();
                }
              },
              child: _buildLangChip(_sourceLang.displayName, theme),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded),
            onPressed: _swapLanguages,
            tooltip: 'Swap Languages',
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.primary,
              padding: const EdgeInsets.all(8),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final picked = await LanguagePickerSheet.show(
                  context,
                  languages: SupportedLanguages.all,
                  selected: _targetLang,
                  title: 'Target Language',
                );
                if (picked != null && mounted) {
                  setState(() => _targetLang = picked);
                  _translateAllSections();
                }
              },
              child: _buildLangChip(_targetLang.displayName, theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLangChip(String name, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.arrow_drop_down_rounded,
              color: theme.colorScheme.primary, size: 16),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    if (_isExtracting) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Parsing document structure & pages…',
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                _fileName ?? '',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.primary),
              ),
            ],
          ),
        ),
      );
    }

    if (_filePath == null) {
      return _buildEmptyPickerState(theme, isDark);
    }

    if (_errorMessage != null && _sections.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              Text('Extraction Notice',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(_errorMessage!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _pickDocument,
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('Choose Another File'),
              ),
            ],
          ),
        ),
      );
    }

    final pageSections =
        _sections.where((s) => s.pageNumber == _currentPage).toList();

    return Column(
      children: [
        // Translation Progress Banner
        if (_isTranslating)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF2563EB).withValues(alpha: 0.12),
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Translating document structure (${(_translationProgress * 100).toInt()}%)...',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
                Text(
                  '${(_translationProgress * 100).toInt()}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ),

        // Page Navigation Indicator
        if (_totalPages > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141721) : const Color(0xFFF8FAFC),
              border: Border(
                  bottom: BorderSide(
                      color: isDark ? Colors.white10 : Colors.black12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: _currentPage > 1
                      ? () => setState(() => _currentPage--)
                      : null,
                  tooltip: 'Previous Page',
                ),
                Text(
                  'Page $_currentPage of $_totalPages',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: _currentPage < _totalPages
                      ? () => setState(() => _currentPage++)
                      : null,
                  tooltip: 'Next Page',
                ),
              ],
            ),
          ),

        // Document Content View
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // 1: Formatted Reader View (Translated)
              _buildReaderView(pageSections, theme, isDark,
                  showTranslated: true),
              // 2: Side-by-Side Dual View
              _buildSideBySideView(pageSections, theme, isDark),
              // 3: Original Document View
              _buildReaderView(pageSections, theme, isDark,
                  showTranslated: false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyPickerState(ThemeData theme, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.document_scanner_rounded,
                color: Color(0xFF2563EB),
                size: 44,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Document Translation',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload PDF, Word (DOCX/DOC), TXT, RTF, or Photos.\nPreserves paragraphs, headings, lists, and exports translated PDF.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.white60 : Colors.black54,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _pickDocument,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Choose Document or Image'),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReaderView(
    List<DocumentSection> sections,
    ThemeData theme,
    bool isDark, {
    required bool showTranslated,
  }) {
    if (sections.isEmpty) {
      return const Center(child: Text('No content on this page'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      itemCount: sections.length,
      itemBuilder: (ctx, index) {
        final s = sections[index];
        final text = (showTranslated ? s.translatedText : s.originalText) ??
            s.originalText;

        if (s.isHeading) {
          return Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Text(
              text,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF2563EB),
                fontSize: 16,
              ),
            ),
          );
        }

        if (s.isBullet) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Expanded(
                  child: SelectableText(
                    text,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2230) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              ),
            ),
            child: SelectableText(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.6,
                fontSize: 13.5,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSideBySideView(
    List<DocumentSection> sections,
    ThemeData theme,
    bool isDark,
  ) {
    if (sections.isEmpty) {
      return const Center(child: Text('No content on this page'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: sections.length,
      itemBuilder: (ctx, index) {
        final s = sections[index];
        final translated = s.translatedText ?? 'Translating…';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2230) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Original snippet (Top)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF252A3D)
                      : const Color(0xFFF1F5F9),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Row(
                  children: [
                    Text(
                      'ORIGINAL (${_sourceLang.displayName})',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Copy original',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: s.originalText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Original text copied'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  s.originalText,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                ),
              ),

              const Divider(height: 1),

              // Translated snippet (Bottom)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                child: Row(
                  children: [
                    Text(
                      'TRANSLATED (${_targetLang.displayName})',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded,
                          size: 14, color: Color(0xFF2563EB)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Copy translation',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: translated));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Translated text copied'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  translated,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2230) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _copyAllTranslatedText,
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy All Text'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _exportAsPdf,
                icon: _isExportingPdf
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.picture_as_pdf_rounded, size: 16),
                label: const Text('Export PDF'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
