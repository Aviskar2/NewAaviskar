import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:archive/archive.dart';
import '../../services/translation_service.dart';
import '../../services/ocr_service.dart';
import '../../services/scan_history_service.dart';
import '../../widgets/language_picker_sheet.dart';
import '../../models/scan_result_model.dart';
import 'image_overlay_translation_screen.dart';
import 'document_translation_screen.dart';

/// Full translation screen powered by Google ML Kit on-device translation
/// with automatic high-speed cloud fallback so translation never hangs.
/// Supports text input, image OCR, and PDF extraction.
class TranslationScreen extends StatefulWidget {
  final String initialText;
  final ScanHistoryService historyService;
  final OcrService? ocrService;

  const TranslationScreen({
    super.key,
    required this.initialText,
    required this.historyService,
    this.ocrService,
  });

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  final TranslationService _translationService = TranslationService();
  late final OcrService _ocrService;

  AppLanguage _sourceLang = SupportedLanguages.english;
  AppLanguage _targetLang = SupportedLanguages.hindi;

  TranslationStatus _status = TranslationStatus.idle;
  double _downloadProgress = 0.0;
  String? _translatedText;
  String? _errorMessage;
  bool _isOnlineFallback = false;
  bool _saved = false;

  // Track current input text and image (for image overlay translation)
  late String _inputText;
  OcrResult? _lastOcrResult;
  bool _isExtractingText = false;

  @override
  void initState() {
    super.initState();
    _ocrService = widget.ocrService ?? OcrService();
    _inputText = widget.initialText;
    if (_inputText.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _translate();
      });
    }
  }

  @override
  void dispose() {
    _translationService.dispose();
    super.dispose();
  }

  Future<void> _translate() async {
    final text = _inputText.trim();
    if (text.isEmpty) return;
    setState(() {
      _status = TranslationStatus.checkingModel;
      _downloadProgress = 0.1;
      _translatedText = null;
      _errorMessage = null;
      _saved = false;
      _isOnlineFallback = false;
    });

    try {
      await for (final progress in _translationService.translate(
        text,
        from: _sourceLang,
        to: _targetLang,
      )) {
        if (!mounted) return;
        setState(() {
          _status = progress.status;
          _downloadProgress = progress.downloadProgress;
          _isOnlineFallback = progress.isOnlineFallback;
          if (progress.result != null) _translatedText = progress.result;
          if (progress.errorMessage != null) _errorMessage = progress.errorMessage;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = TranslationStatus.error;
          _errorMessage = 'Translation failed: $e';
        });
      }
    }
  }

  Future<void> _saveToHistory() async {
    if (_translatedText == null) return;
    await widget.historyService.addTranslation(
      originalText: widget.initialText,
      translatedText: _translatedText!,
      sourceLang: _sourceLang.displayName,
      targetLang: _targetLang.displayName,
    );
    setState(() => _saved = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Translation saved to history'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Pick document (image, PDF, DOCX, TXT) and extract text
  Future<void> _pickAndExtract() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'jpg', 'jpeg', 'png', 'webp', 'bmp',
        'pdf', 'docx', 'doc', 'txt',
      ],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final path = file.path;
    if (path == null || !mounted) return;

    final ext = (file.extension ?? '').toLowerCase();

    setState(() {
      _isExtractingText = true;
      _errorMessage = null;
      _translatedText = null;
    });

    try {
      String extractedText = '';

      if (ext == 'pdf') {
        extractedText = await _extractTextFromPdf(path);
      } else if (ext == 'docx' || ext == 'doc') {
        extractedText = await _extractTextFromDocx(path);
      } else if (ext == 'txt') {
        extractedText = await File(path).readAsString();
      } else {
        // Image: use OCR
        final ocr = await _ocrService.recognizeFromPath(path);
        await widget.historyService.addOcr(ocr);
        extractedText = ocr.fullText;
        if (mounted) {
          setState(() {
            _lastOcrResult = ocr;
          });
        }
      }

      if (!mounted) return;

      if (extractedText.trim().isEmpty) {
        setState(() {
          _isExtractingText = false;
          _errorMessage = 'No readable text found in this document.';
        });
        return;
      }

      setState(() {
        _inputText = extractedText;
        _isExtractingText = false;
      });
      _translate();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExtractingText = false;
          _errorMessage = 'Failed to extract text: $e';
        });
      }
    }
  }

  /// Extract text from PDF using syncfusion_flutter_pdf
  Future<String> _extractTextFromPdf(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      final PdfTextExtractor extractor = PdfTextExtractor(document);
      final String text = extractor.extractText();
      document.dispose();
      return text;
    } catch (e) {
      throw Exception('PDF text extraction failed: $e');
    }
  }

  /// Extract text from DOCX (Office Open XML) by parsing the XML content
  Future<String> _extractTextFromDocx(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Find the main document XML file
      final docFile = archive.files.firstWhere(
        (f) => f.name == 'word/document.xml',
        orElse: () => archive.files.first,
      );

      final xmlContent = String.fromCharCodes(docFile.content as List<int>);

      // Extract text from XML tags (strip XML tags, keep text content)
      final textContent = xmlContent
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      return textContent;
    } catch (e) {
      throw Exception('DOCX text extraction failed: $e');
    }
  }

  Future<void> _captureFromCamera() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 95,
    );
    if (photo == null || !mounted) return;
    setState((){
      _isExtractingText = true;
      _errorMessage = null;
      _translatedText = null;
    });
    try {
      final ocr = await _ocrService.recognizeFromPath(photo.path);
      await widget.historyService.addOcr(ocr);
      if (!mounted) return;
      setState(() {
        _inputText = ocr.fullText;
        _lastOcrResult = ocr;
        _isExtractingText = false;
      });
      _translate();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExtractingText = false;
          _errorMessage = 'OCR error: $e';
        });
      }
    }
  }

  void _openImageOverlay() {
    final ocrResult = _lastOcrResult;
    if (ocrResult == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageOverlayTranslationScreen(
          ocrResult: ocrResult,
          ocrService: _ocrService,
        ),
      ),
    );
  }
  void _showUploadSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Upload to Translate',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined,
                      color: Color(0xFF2563EB)),
                  title: const Text('Image (JPG, PNG, WEBP)'),
                  subtitle: const Text('Text extracted via OCR'),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndExtract();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined,
                      color: Color(0xFF9D00FF)),
                  title: const Text('Take photo with camera'),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _captureFromCamera();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf_outlined,
                      color: Color(0xFFFF4081)),
                  title: const Text('PDF / Word Document Translation'),
                  subtitle: const Text('Structured page translation & PDF export'),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DocumentTranslationScreen(
                          historyService: widget.historyService,
                          ocrService: _ocrService,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined,
                      color: Color(0xFF16A34A)),
                  title: const Text('Import Text / DOCX File'),
                  subtitle: const Text('Extracts text from files into text translator'),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndExtract();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickSourceLang() async {
    final picked = await LanguagePickerSheet.show(
      context,
      languages: SupportedLanguages.all,
      selected: _sourceLang,
      title: 'Source Language',
    );
    if (picked != null && mounted) {
      setState(() {
        _sourceLang = picked;
        _translatedText = null;
      });
      _translate();
    }
  }

  Future<void> _pickTargetLang() async {
    final picked = await LanguagePickerSheet.show(
      context,
      languages: SupportedLanguages.all,
      selected: _targetLang,
      title: 'Target Language',
    );
    if (picked != null && mounted) {
      setState(() {
        _targetLang = picked;
        _translatedText = null;
      });
      _translate();
    }
  }

  void _swapLanguages() {
    setState(() {
      final tmp = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = tmp;
      _translatedText = null;
    });
    _translate();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isTranslating = _status == TranslationStatus.translating ||
        _status == TranslationStatus.checkingModel ||
        _status == TranslationStatus.downloadingModel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Translate'),
        centerTitle: true,
        actions: [
          // Upload PDF/Image button
          IconButton(
            icon: const Icon(Icons.upload_file_outlined),
            tooltip: 'Upload image or PDF to translate',
            onPressed: _isExtractingText ? null : _showUploadSheet,
          ),
          if (_lastOcrResult != null)
            IconButton(
              icon: const Icon(Icons.image_search_outlined),
              tooltip: 'View translation on image',
              onPressed: _openImageOverlay,
            ),
          if (_translatedText != null && !_saved)
            IconButton(
              icon: const Icon(Icons.bookmark_add_outlined),
              tooltip: 'Save to history',
              onPressed: _saveToHistory,
            ),
          if (_saved)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(Icons.bookmark_rounded, color: Color(0xFF2563EB)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Language selector row
          _LanguageSelectorBar(
            sourceLang: _sourceLang,
            targetLang: _targetLang,
            onPickSource: _pickSourceLang,
            onPickTarget: _pickTargetLang,
            onSwap: _swapLanguages,
            theme: theme,
            isDark: isDark,
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Original text card — shows text from upload or initial
                  _isExtractingText
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Column(
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 12),
                                Text('Extracting text from image…'),
                              ],
                            ),
                          ),
                        )
                      : _TextCard(
                          label: _sourceLang.displayName,
                          text: _inputText.isNotEmpty
                              ? _inputText
                              : widget.initialText,
                          isOriginal: true,
                          theme: theme,
                          isDark: isDark,
                        ),
                  const SizedBox(height: 16),

                  // Status / progress / result
                  if (isTranslating)
                    _StatusCard(
                      status: _status,
                      progress: _downloadProgress,
                      theme: theme,
                      isDark: isDark,
                    )
                  else if (_errorMessage != null)
                    _ErrorCard(
                      message: _errorMessage!,
                      onRetry: _translate,
                      theme: theme,
                    )
                  else if (_translatedText != null) ...[
                    _TextCard(
                      label: _targetLang.displayName,
                      text: _translatedText!,
                      isOriginal: false,
                      theme: theme,
                      isDark: isDark,
                      isOnlineFallback: _isOnlineFallback,
                    ),
                  ] else
                    _PlaceholderCard(
                      targetLang: _targetLang.displayName,
                      theme: theme,
                      isDark: isDark,
                    ),
                ],
              ),
            ),
          ),

          // Translate button
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isTranslating ? null : _translate,
                  icon: isTranslating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.translate_rounded),
                  label: Text(isTranslating
                      ? _statusLabel(_status)
                      : _translatedText != null
                          ? 'Re-translate'
                          : 'Translate'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(TranslationStatus status) {
    switch (status) {
      case TranslationStatus.checkingModel:
        return 'Connecting translation engine...';
      case TranslationStatus.downloadingModel:
        final pct = (_downloadProgress * 100).toInt();
        return 'Downloading model ($pct%)...';
      case TranslationStatus.translating:
        return 'Translating...';
      default:
        return 'Translate';
    }
  }
}

// ─── Language selector bar ───────────────────────────────────────────────────

class _LanguageSelectorBar extends StatelessWidget {
  final AppLanguage sourceLang;
  final AppLanguage targetLang;
  final VoidCallback onPickSource;
  final VoidCallback onPickTarget;
  final VoidCallback onSwap;
  final ThemeData theme;
  final bool isDark;

  const _LanguageSelectorBar({
    required this.sourceLang,
    required this.targetLang,
    required this.onPickSource,
    required this.onPickTarget,
    required this.onSwap,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B0424) : const Color(0xFFF0F4FF),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? const Color(0xFF32113D)
                : const Color(0xFFDDE7FF),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onPickSource,
              child: _LangChip(
                lang: sourceLang,
                theme: theme,
                isDark: isDark,
              ),
            ),
          ),
          IconButton(
            onPressed: onSwap,
            icon: const Icon(Icons.swap_horiz_rounded),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.primary,
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onPickTarget,
              child: _LangChip(
                lang: targetLang,
                theme: theme,
                isDark: isDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  final AppLanguage lang;
  final ThemeData theme;
  final bool isDark;

  const _LangChip({required this.lang, required this.theme, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              lang.displayName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.arrow_drop_down_rounded,
              color: theme.colorScheme.primary, size: 18),
        ],
      ),
    );
  }
}

// ─── Text display card ───────────────────────────────────────────────────────

class _TextCard extends StatelessWidget {
  final String label;
  final String text;
  final bool isOriginal;
  final ThemeData theme;
  final bool isDark;
  final bool isOnlineFallback;

  const _TextCard({
    required this.label,
    required this.text,
    required this.isOriginal,
    required this.theme,
    required this.isDark,
    this.isOnlineFallback = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isOriginal
        ? theme.colorScheme.onSurfaceVariant
        : const Color(0xFF2563EB);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF22062C) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF32113D) : const Color(0xFFE5EEFF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
            child: Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: accent,
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                ),
                if (!isOriginal) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isOnlineFallback
                          ? Colors.blue.withValues(alpha: 0.12)
                          : Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOnlineFallback ? Icons.cloud_done_rounded : Icons.offline_pin_rounded,
                          size: 12,
                          color: isOnlineFallback ? Colors.blue.shade700 : Colors.green.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isOnlineFallback ? 'Instant Online' : 'On-Device',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isOnlineFallback ? Colors.blue.shade700 : Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Text
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: SelectableText(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.65,
                fontWeight: isOriginal ? FontWeight.normal : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Status / progress card ──────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final TranslationStatus status;
  final double progress;
  final ThemeData theme;
  final bool isDark;

  const _StatusCard({
    required this.status,
    required this.progress,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isDownloading = status == TranslationStatus.downloadingModel;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF22062C) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF32113D) : const Color(0xFFE5EEFF),
        ),
      ),
      child: Column(
        children: [
          if (isDownloading) ...[
            Row(
              children: [
                const Icon(Icons.cloud_download_outlined, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Preparing translation...',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Translating seamlessly with instant fallback...',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ] else ...[
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            Text(
              status == TranslationStatus.translating
                  ? 'Translating text...'
                  : 'Preparing translation engine...',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Error card ──────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final ThemeData theme;

  const _ErrorCard({
    required this.message,
    required this.onRetry,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 36),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: Colors.red.shade700),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }
}

// ─── Placeholder card before translation ─────────────────────────────────────

class _PlaceholderCard extends StatelessWidget {
  final String targetLang;
  final ThemeData theme;
  final bool isDark;

  const _PlaceholderCard({
    required this.targetLang,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF22062C) : const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF32113D) : const Color(0xFFE5EEFF),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.translate_rounded,
            size: 40,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'Translation in $targetLang will appear here',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
