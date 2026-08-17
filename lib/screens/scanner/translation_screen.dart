import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/translation_service.dart';
import '../../services/scan_history_service.dart';
import '../../widgets/language_picker_sheet.dart';

/// Full translation screen powered by Google ML Kit on-device translation
/// with automatic high-speed cloud fallback so translation never hangs.
class TranslationScreen extends StatefulWidget {
  final String initialText;
  final ScanHistoryService historyService;

  const TranslationScreen({
    Key? key,
    required this.initialText,
    required this.historyService,
  }) : super(key: key);

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  final TranslationService _translationService = TranslationService();

  AppLanguage _sourceLang = SupportedLanguages.english;
  AppLanguage _targetLang = SupportedLanguages.hindi;

  TranslationStatus _status = TranslationStatus.idle;
  double _downloadProgress = 0.0;
  String? _translatedText;
  String? _errorMessage;
  bool _isOnlineFallback = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    // Automatically start translation on screen entry if text is present
    if (widget.initialText.trim().isNotEmpty) {
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
        widget.initialText,
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
                  // Original text card
                  _TextCard(
                    label: _sourceLang.displayName,
                    text: widget.initialText,
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
