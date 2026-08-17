import 'package:flutter/material.dart';
import '../services/translation_service.dart';

/// Bottom sheet for selecting source and target languages.
class LanguagePickerSheet extends StatefulWidget {
  final List<AppLanguage> languages;
  final AppLanguage selected;
  final String title;

  const LanguagePickerSheet({
    Key? key,
    required this.languages,
    required this.selected,
    required this.title,
  }) : super(key: key);

  /// Shows the picker and returns the selected [AppLanguage], or null if dismissed.
  static Future<AppLanguage?> show(
    BuildContext context, {
    required List<AppLanguage> languages,
    required AppLanguage selected,
    required String title,
  }) {
    return showModalBottomSheet<AppLanguage>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LanguagePickerSheet(
        languages: languages,
        selected: selected,
        title: title,
      ),
    );
  }

  @override
  State<LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<LanguagePickerSheet> {
  String _query = '';
  late List<AppLanguage> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.languages;
  }

  void _onSearch(String q) {
    setState(() {
      _query = q;
      _filtered = widget.languages
          .where((l) =>
              l.displayName.toLowerCase().contains(q.toLowerCase()) ||
              l.nativeName.contains(q))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1B0424) : Colors.white;
    final maxHeight = MediaQuery.of(context).size.height * 0.75;

    return Container(
      margin: const EdgeInsets.all(10),
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF32113D) : const Color(0xFFE5EEFF),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: false,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Search language...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark
                        ? const Color(0xFF32113D)
                        : const Color(0xFFDDE7FF),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark
                        ? const Color(0xFF32113D)
                        : const Color(0xFFDDE7FF),
                  ),
                ),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF2A0B35)
                    : const Color(0xFFF0F4FF),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Language list
          Flexible(
            child: _filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      'No language found for "$_query"',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: _filtered.length,
                    itemBuilder: (ctx, i) {
                      final lang = _filtered[i];
                      final isSelected =
                          lang.mlKitCode == widget.selected.mlKitCode;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        tileColor: isSelected
                            ? theme.colorScheme.primary.withValues(alpha: 0.1)
                            : null,
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            lang.nativeName.characters.first,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        title: Text(
                          lang.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(lang.nativeName),
                        trailing: isSelected
                            ? Icon(Icons.check_circle_rounded,
                                color: theme.colorScheme.primary)
                            : null,
                        onTap: () => Navigator.pop(ctx, lang),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
