import 'package:flutter/material.dart';
import '../../core/legal/models/legal_finding.dart';

class HighlightedDocumentPaper extends StatefulWidget {
  final String rawText;
  final List<LegalFinding> findings;
  final Function(LegalFinding finding)? onFindingTap;
  final String? initialFindingId;

  const HighlightedDocumentPaper({
    super.key,
    required this.rawText,
    required this.findings,
    this.onFindingTap,
    this.initialFindingId,
  });

  @override
  State<HighlightedDocumentPaper> createState() => _HighlightedDocumentPaperState();
}

class _HighlightedDocumentPaperState extends State<HighlightedDocumentPaper> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _findingKeys = {};
  String? _activeFindingId;

  @override
  void initState() {
    super.initState();
    _activeFindingId = widget.initialFindingId;
    for (final f in widget.findings) {
      _findingKeys[f.id] = GlobalKey();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToFinding(String findingId) {
    setState(() => _activeFindingId = findingId);
    final key = _findingKeys[findingId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.25,
      );
    }
  }

  LegalFinding? _matchFindingForLine(String line) {
    final cleanLine = line.trim().toLowerCase();
    if (cleanLine.length < 5) return null;

    for (final f in widget.findings) {
      final cleanExcerpt = f.rawExcerpt.trim().toLowerCase();
      if (cleanExcerpt.isEmpty) continue;

      if (cleanExcerpt.contains(cleanLine) || cleanLine.contains(cleanExcerpt)) {
        return f;
      }

      // Check word overlap if line is substantial
      final words = cleanExcerpt.split(' ').where((w) => w.length > 3).toList();
      if (words.length >= 3) {
        int matchCount = 0;
        for (final w in words) {
          if (cleanLine.contains(w)) matchCount++;
        }
        if (matchCount >= (words.length * 0.7).ceil()) {
          return f;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lines = widget.rawText.split('\n');

    return Column(
      children: [
        // Quick Jump & Legend Bar
        if (widget.findings.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white12 : const Color(0xFFBFDBFE),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.highlight_alt_rounded, size: 16, color: Color(0xFFDC2626)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${widget.findings.length} Flagged Clauses Highlighted in Paper',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                ),
                // Quick jump dropdown menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.filter_list_rounded, size: 20, color: Color(0xFF2563EB)),
                  tooltip: 'Jump to Flagged Clause',
                  onSelected: _scrollToFinding,
                  itemBuilder: (context) {
                    return widget.findings.map((f) {
                      return PopupMenuItem<String>(
                        value: f.id,
                        child: Row(
                          children: [
                            Text(f.severity.emoji, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                f.title,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: f.severity.color,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList();
                  },
                ),
              ],
            ),
          ),

        // Document Paper Sheet
        Expanded(
          child: Container(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: isDark ? Colors.white10 : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
                    itemCount: lines.length,
                    itemBuilder: (context, index) {
                      final line = lines[index];
                      final trimmed = line.trim();

                      // Blank line
                      if (trimmed.isEmpty) {
                        return const SizedBox(height: 10);
                      }

                      // Check if line contains a flagged clause
                      final finding = _matchFindingForLine(line);

                      if (finding != null) {
                        final isSelected = finding.id == _activeFindingId;
                        final isHigh = finding.severity == LegalRiskSeverity.high;
                        final highlightColor = isHigh
                            ? (isDark ? const Color(0xFF991B1B).withValues(alpha: 0.45) : const Color(0xFFFECACA))
                            : (isDark ? const Color(0xFF854D0E).withValues(alpha: 0.45) : const Color(0xFFFEF08A));
                        final borderColor = isHigh ? const Color(0xFFDC2626) : const Color(0xFFEA580C);

                        // Highlighted directly on the text on page
                        return Container(
                          key: _findingKeys[finding.id],
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          child: InkWell(
                            onTap: () {
                              setState(() => _activeFindingId = finding.id);
                              widget.onFindingTap?.call(finding);
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: highlightColor,
                                borderRadius: BorderRadius.circular(4),
                                border: Border(
                                  bottom: BorderSide(color: borderColor, width: 2.0),
                                  left: BorderSide(
                                    color: borderColor,
                                    width: isSelected ? 4.5 : 3.0,
                                  ),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Line number on left
                                  SizedBox(
                                    width: 26,
                                    child: Text(
                                      '${index + 1}'.padLeft(2, '0'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: borderColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // The text highlighted on the page
                                  Expanded(
                                    child: Text(
                                      line,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        height: 1.45,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Subtle pill badge on the page margin
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: borderColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isHigh ? 'RISK ALERT' : 'WARNING',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 8.5,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      // Normal document text line
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 26,
                              child: Text(
                                '${index + 1}'.padLeft(2, '0'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                line,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
