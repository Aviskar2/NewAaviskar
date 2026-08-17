import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/scan_result_model.dart';
import '../../services/scan_history_service.dart';
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

  const OcrResultScreen({
    Key? key,
    required this.result,
    required this.historyService,
    this.autoTranslate = false,
  }) : super(key: key);

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
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _openTranslation,
                    icon: const Icon(Icons.translate_rounded),
                    label: const Text('Translate This Text'),
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
