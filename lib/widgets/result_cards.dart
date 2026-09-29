import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/scan_result_model.dart';

// ──────────────────────────────────────────────────────────────────────────────
// OCR Result Card — shown in the chat message list
// ──────────────────────────────────────────────────────────────────────────────

class OcrResultCard extends StatelessWidget {
  final OcrResult result;
  final VoidCallback? onTranslate;
  final VoidCallback? onViewFull;

  const OcrResultCard({
    super.key,
    required this.result,
    this.onTranslate,
    this.onViewFull,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = const Color(0xFF9D00FF);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF22062C) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF32113D) : const Color(0xFFE5EEFF),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Icon(Icons.document_scanner_rounded,
                    color: accent, size: 18),
                const SizedBox(width: 8),
                Text(
                  'OCR Result',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: accent,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                _CopyBtn(text: result.fullText),
              ],
            ),
          ),
          // Extracted text preview (max 6 lines)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: result.isEmpty
                ? Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      Text('No text detected in image',
                          style: theme.textTheme.bodyMedium),
                    ],
                  )
                : Text(
                    result.fullText,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
                  ),
          ),
          // Stats row
          if (!result.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                '${result.blocks.length} block(s) · '
                '${result.fullText.split('\n').length} line(s)',
                style: theme.textTheme.labelMedium,
              ),
            ),
          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Row(
              children: [
                if (onViewFull != null)
                  TextButton.icon(
                    onPressed: onViewFull,
                    icon: const Icon(Icons.open_in_full_rounded, size: 16),
                    label: const Text('View Full'),
                    style: TextButton.styleFrom(
                      foregroundColor: accent,
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                if (onTranslate != null && !result.isEmpty) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onTranslate,
                    icon: const Icon(Icons.translate_rounded, size: 16),
                    label: const Text('Translate'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Barcode / QR Result Card
// ──────────────────────────────────────────────────────────────────────────────

class BarcodeResultCard extends StatelessWidget {
  final BarcodeResult result;
  final VoidCallback? onOpenUrl;

  const BarcodeResultCard({
    super.key,
    required this.result,
    this.onOpenUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isQr = result.format.toLowerCase().contains('qr');
    final accent = isQr ? const Color(0xFF9D00FF) : const Color(0xFF2563EB);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF22062C) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF32113D) : const Color(0xFFE5EEFF),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Icon(
                  isQr ? Icons.qr_code_2_rounded : Icons.barcode_reader,
                  color: accent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  result.format,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: accent,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    result.displayType,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: accent),
                  ),
                ),
                const Spacer(),
                _CopyBtn(text: result.rawValue),
              ],
            ),
          ),
          // Value
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SelectableText(
              result.rawValue,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ),
          // Open URL action
          if (result.isUrl && onOpenUrl != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: TextButton.icon(
                onPressed: onOpenUrl,
                icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                label: const Text('Open URL'),
                style: TextButton.styleFrom(
                  foregroundColor: accent,
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            )
          else
            const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Translation Result Card
// ──────────────────────────────────────────────────────────────────────────────

class TranslationResultCard extends StatelessWidget {
  final String originalText;
  final String translatedText;
  final String sourceLang;
  final String targetLang;

  const TranslationResultCard({
    super.key,
    required this.originalText,
    required this.translatedText,
    required this.sourceLang,
    required this.targetLang,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const accent = Color(0xFF2563EB);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF22062C) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF32113D) : const Color(0xFFE5EEFF),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                const Icon(Icons.translate_rounded, color: accent, size: 18),
                const SizedBox(width: 8),
                Text(
                  '$sourceLang → $targetLang',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: accent,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                _CopyBtn(text: translatedText),
              ],
            ),
          ),
          // Original
          _LangSection(
            label: sourceLang,
            text: originalText,
            isDark: isDark,
            theme: theme,
            isOriginal: true,
          ),
          // Divider with arrow
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                    child: Divider(color: theme.colorScheme.outlineVariant)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.arrow_downward_rounded,
                      size: 16, color: theme.colorScheme.outlineVariant),
                ),
                Expanded(
                    child: Divider(color: theme.colorScheme.outlineVariant)),
              ],
            ),
          ),
          // Translated
          _LangSection(
            label: targetLang,
            text: translatedText,
            isDark: isDark,
            theme: theme,
            isOriginal: false,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _LangSection extends StatelessWidget {
  final String label;
  final String text;
  final bool isDark;
  final ThemeData theme;
  final bool isOriginal;

  const _LangSection({
    required this.label,
    required this.text,
    required this.isDark,
    required this.theme,
    required this.isOriginal,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: isOriginal
                  ? theme.colorScheme.onSurfaceVariant
                  : const Color(0xFF2563EB),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.55,
              color: isOriginal
                  ? theme.textTheme.bodyMedium?.color
                  : theme.textTheme.bodyLarge?.color,
              fontWeight:
                  isOriginal ? FontWeight.normal : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Shared helper: Copy to clipboard icon button
// ──────────────────────────────────────────────────────────────────────────────

class _CopyBtn extends StatelessWidget {
  final String text;
  const _CopyBtn({required this.text});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.copy_rounded, size: 18),
      tooltip: 'Copy',
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
    );
  }
}
