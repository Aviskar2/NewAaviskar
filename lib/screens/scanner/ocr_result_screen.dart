import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/scan_result_model.dart';
import '../../services/scan_history_service.dart';
import '../../services/ocr_service.dart';
import '../bill_analyzer/bill_analyzer_entry_screen.dart';
import 'universal_product_entry_screen.dart';
import 'image_overlay_translation_screen.dart';
import 'translation_screen.dart';

/// Full-screen OCR result view.
///
/// Shows:
/// - Recognized text (editable)
/// - Source image thumbnail
/// - Block/line count stats
/// - Copy to clipboard
/// - Translate button → opens TranslationScreen
class OcrResultScreen extends StatefulWidget {
  final OcrResult result;
  final ScanHistoryService historyService;
  final bool autoTranslate;
  final OcrService? ocrService;

  const OcrResultScreen({
    super.key,
    required this.result,
    required this.historyService,
    this.autoTranslate = false,
    this.ocrService,
  });

  @override
  State<OcrResultScreen> createState() => _OcrResultScreenState();
}

class _OcrResultScreenState extends State<OcrResultScreen> {
  late final TextEditingController _textController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.result.fullText);
    if (widget.autoTranslate && !widget.result.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openTranslation());
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _copyAll() {
    Clipboard.setData(ClipboardData(text: _textController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Text copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _openTranslation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TranslationScreen(
          initialText: _textController.text,
          historyService: widget.historyService,
        ),
      ),
    );
  }

  void _openImageTranslation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageOverlayTranslationScreen(
          ocrResult: widget.result,
          ocrService: widget.ocrService,
          historyService: widget.historyService,
        ),
      ),
    );
  }

  void _openBillAnalyzer() {
    final ocrService = widget.ocrService;
    if (ocrService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bill Analyzer not available'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BillAnalyzerEntryScreen(
          ocrService: ocrService,
          historyService: widget.historyService,
          existingOcrResult: widget.result,
        ),
      ),
    );
  }

  void _openUniversalProductSafety() {
    final ocrService = widget.ocrService;
    if (ocrService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product Safety not available'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UniversalProductEntryScreen(
          ocrService: ocrService,
          historyService: widget.historyService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasText = !widget.result.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR Result'),
        centerTitle: true,
        actions: [
          // Edit toggle
          IconButton(
            icon: Icon(_isEditing ? Icons.check_rounded : Icons.edit_rounded),
            tooltip: _isEditing ? 'Done editing' : 'Edit text',
            onPressed: () => setState(() => _isEditing = !_isEditing),
          ),
          // Copy all
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy all text',
            onPressed: hasText ? _copyAll : null,
          ),
        ],
      ),
      body: Column(
        children: [
          // Image + stats bar
          _ImageStatsBar(result: widget.result, isDark: isDark, theme: theme),

          // Text area
          Expanded(
            child: hasText
                ? _TextArea(
                    controller: _textController,
                    isEditing: _isEditing,
                    theme: theme,
                    isDark: isDark,
                  )
                : _EmptyState(theme: theme),
          ),

          // Translate button
          if (hasText)
            SafeArea(
              top: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Analyze Bill and Universal Product & Safety action buttons
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _openBillAnalyzer,
                            icon: const Icon(Icons.receipt_long_rounded, size: 16),
                            label: const Text('Audit Bill'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _openUniversalProductSafety,
                            icon: const Icon(Icons.verified_user_rounded, size: 16),
                            label: const Text('Product & Safety'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _openTranslation,
                            icon: const Icon(Icons.translate_rounded, size: 18),
                            label: const Text('Translate Text'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _openImageTranslation,
                            icon: const Icon(Icons.photo_filter_rounded, size: 18),
                            label: const Text('Image Translation'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF9D00FF),
                              side: const BorderSide(
                                  color: Color(0xFF9D00FF), width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImageStatsBar extends StatelessWidget {
  final OcrResult result;
  final bool isDark;
  final ThemeData theme;

  const _ImageStatsBar({
    required this.result,
    required this.isDark,
    required this.theme,
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
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 52,
              height: 52,
              child: File(result.imagePath).existsSync()
                  ? Image.file(File(result.imagePath), fit: BoxFit.cover)
                  : Container(
                      color: theme.colorScheme.primaryContainer,
                      child: Icon(Icons.image_outlined,
                          color: theme.colorScheme.primary),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.isEmpty
                      ? 'No text detected'
                      : '${result.fullText.length} characters extracted',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${result.blocks.length} block(s) · '
                  '${result.fullText.split('\n').where((l) => l.isNotEmpty).length} line(s)',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TextArea extends StatelessWidget {
  final TextEditingController controller;
  final bool isEditing;
  final ThemeData theme;
  final bool isDark;

  const _TextArea({
    required this.controller,
    required this.isEditing,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (isEditing) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: controller,
          maxLines: null,
          expands: true,
          autofocus: true,
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.7),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: theme.colorScheme.outline),
            ),
            contentPadding: const EdgeInsets.all(16),
            hintText: 'Recognized text...',
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: SelectableText(
        controller.text,
        style: theme.textTheme.bodyLarge?.copyWith(height: 1.7),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ThemeData theme;
  const _EmptyState({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.text_fields_rounded,
              size: 56, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text('No Text Detected',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'ML Kit could not find readable text in this image. '
              'Try a clearer image with better contrast.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Try Another Image'),
          ),
        ],
      ),
    );
  }
}
