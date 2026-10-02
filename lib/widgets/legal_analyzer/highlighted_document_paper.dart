import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/legal/models/legal_finding.dart';

/// Interactive Paper Document Viewer with exact word/clause highlighting (Sections 57–84).
///
/// Features:
/// - Exact word/phrase-level highlighting within lines (Sections 57, 62).
/// - Multi-line clause continuity without highlighting surrounding margin whitespace (Section 63).
/// - Translucent severity overlays (Section 64) and subtle left accent borders / underlines (Section 65).
/// - Tap-to-inspect interaction opening the finding detail sheet (Section 66, 80).
/// - Navigation controls (← Previous 1 of N Next →) (Section 67).
/// - Compact legend (🔴 High, 🟡 Medium, 🔵 Informational) (Section 68).
/// - Two-way sync: auto-scroll to exact line and finding (Sections 69, 70).
/// - 1-time pulse animation on selection (Section 76).
/// - Compact severity filter chips [All] [High] [Medium] [Low] (Section 77).
/// - Section 78 UI layout with floating bottom issue card ("Tap for details").
/// - Section 81 validation alert if exact document location could not be determined.
/// - Full pinch-to-zoom and pan support via InteractiveViewer (Sections 74, 75).
class HighlightedDocumentPaper extends StatefulWidget {
  final String rawText;
  final List<LegalFinding> findings;
  final Function(LegalFinding finding)? onFindingTap;
  final String? initialFindingId;
  final bool showHeader;

  const HighlightedDocumentPaper({
    super.key,
    required this.rawText,
    required this.findings,
    this.onFindingTap,
    this.initialFindingId,
    this.showHeader = true,
  });

  @override
  State<HighlightedDocumentPaper> createState() => _HighlightedDocumentPaperState();
}

class _HighlightedDocumentPaperState extends State<HighlightedDocumentPaper>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TransformationController _transformController = TransformationController();
  final Map<String, GlobalKey> _findingKeys = {};

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  String? _activeFindingId;
  LegalRiskSeverity? _selectedSeverityFilter; // null represents 'All'

  @override
  void initState() {
    super.initState();
    _activeFindingId = widget.initialFindingId;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    for (final f in widget.findings) {
      _findingKeys[f.id] = GlobalKey();
    }

    if (_activeFindingId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToFinding(_activeFindingId!);
      });
    }
  }

  @override
  void didUpdateWidget(covariant HighlightedDocumentPaper oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final f in widget.findings) {
      _findingKeys.putIfAbsent(f.id, () => GlobalKey());
    }

    if (widget.initialFindingId != null && widget.initialFindingId != oldWidget.initialFindingId) {
      _scrollToFinding(widget.initialFindingId!);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scrollController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _triggerPulse() {
    _pulseController.forward(from: 0.0);
  }

  void _scrollToFinding(String findingId) {
    setState(() => _activeFindingId = findingId);
    _triggerPulse();

    final key = _findingKeys[findingId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.25,
      );
    }
  }

  List<LegalFinding> get _visibleFindings {
    if (_selectedSeverityFilter == null) return widget.findings;
    return widget.findings.where((f) => f.severity == _selectedSeverityFilter).toList();
  }

  int get _activeFindingIndex {
    final list = _visibleFindings;
    if (_activeFindingId == null || list.isEmpty) return 0;
    final idx = list.indexWhere((f) => f.id == _activeFindingId);
    return idx == -1 ? 0 : idx;
  }

  void _goToPreviousFinding() {
    final list = _visibleFindings;
    if (list.isEmpty) return;
    final current = _activeFindingIndex;
    final prev = (current - 1 + list.length) % list.length;
    _scrollToFinding(list[prev].id);
  }

  void _goToNextFinding() {
    final list = _visibleFindings;
    if (list.isEmpty) return;
    final current = _activeFindingIndex;
    final next = (current + 1) % list.length;
    _scrollToFinding(list[next].id);
  }

  /// Finds non-overlapping highlight spans within a single line of text (Sections 57, 62, 63, 72).
  List<_LineSpan> _findSpansForLine(String line, int lineIndex) {
    if (line.trim().isEmpty) return [];

    final spans = <_LineSpan>[];
    final lineLower = line.toLowerCase();

    for (final finding in _visibleFindings) {
      // Section 81: Do not display fake highlight if mapping failed
      final highlight = finding.highlight;
      if (highlight != null && !highlight.hasValidLocation) continue;

      // 1. Identify query candidates: exactText, rawExcerpt, or evidence
      final candidates = <String>[];
      if (highlight != null && highlight.exactText.trim().isNotEmpty) {
        candidates.add(highlight.exactText.trim());
      }
      if (finding.rawExcerpt.trim().isNotEmpty) {
        candidates.add(finding.rawExcerpt.trim());
      }
      if (finding.evidence != null && finding.evidence!.trim().isNotEmpty) {
        candidates.add(finding.evidence!.trim());
      }

      int bestStart = -1;
      int bestLength = 0;

      for (final candidate in candidates) {
        final queryLower = candidate.toLowerCase();

        // Exact substring match within this line
        final exactIdx = lineLower.indexOf(queryLower);
        if (exactIdx != -1) {
          bestStart = exactIdx;
          bestLength = queryLower.length;
          break;
        }

        // Check if query spans across multiple lines and part of it is in this line (Section 63)
        final words = candidate.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
        if (words.length >= 2) {
          // Look for 2+ word sequences matching in line
          for (int wLen = words.length; wLen >= 2; wLen--) {
            for (int wStart = 0; wStart <= words.length - wLen; wStart++) {
              final subPhrase = words.sublist(wStart, wStart + wLen).join(' ').toLowerCase();
              final subIdx = lineLower.indexOf(subPhrase);
              if (subIdx != -1 && subPhrase.length > bestLength) {
                bestStart = subIdx;
                bestLength = subPhrase.length;
              }
            }
            if (bestStart != -1) break;
          }
        }
        if (bestStart != -1) break;
      }

      // Fuzzy / OCR tolerant matching (Section 72):
      // Example: "₹50,OOO" in line matching "₹50,000" in finding
      if (bestStart == -1 && candidates.isNotEmpty) {
        final normLine = _fuzzyNormalize(line);
        for (final candidate in candidates) {
          final normCandidate = _fuzzyNormalize(candidate);
          if (normCandidate.isNotEmpty) {
            final fuzIdx = normLine.indexOf(normCandidate);
            if (fuzIdx != -1) {
              // Estimate character location in original line
              final startRatio = fuzIdx / math.max(1, normLine.length);
              final endRatio = (fuzIdx + normCandidate.length) / math.max(1, normLine.length);
              bestStart = (startRatio * line.length).floor().clamp(0, line.length - 1);
              final bestEnd = (endRatio * line.length).ceil().clamp(bestStart + 1, line.length);
              bestLength = bestEnd - bestStart;
              break;
            }
          }
        }
      }

      if (bestStart != -1 && bestLength > 0) {
        final actualEnd = (bestStart + bestLength).clamp(0, line.length);
        spans.add(_LineSpan(
          start: bestStart,
          end: actualEnd,
          finding: finding,
        ));
      }
    }

    if (spans.isEmpty) return [];

    // Sort spans by start offset
    spans.sort((a, b) => a.start.compareTo(b.start));

    // Remove overlapping spans (favoring earlier or higher severity)
    final nonOverlapping = <_LineSpan>[];
    int currentEnd = 0;
    for (final span in spans) {
      if (span.start >= currentEnd) {
        nonOverlapping.add(span);
        currentEnd = span.end;
      }
    }

    return nonOverlapping;
  }

  String _fuzzyNormalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[₹$,.\s/\\:;_\-]'), '')
        .replaceAll("'", '')
        .replaceAll('"', '')
        .replaceAll('o', '0')
        .replaceAll('l', '1');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lines = widget.rawText.split('\n');

    final visibleFindings = _visibleFindings;
    final totalIssues = widget.findings.length;
    final activeIndex = _activeFindingIndex;
    final activeFinding = visibleFindings.isNotEmpty
        ? visibleFindings[activeIndex.clamp(0, visibleFindings.length - 1)]
        : (widget.findings.isNotEmpty ? widget.findings.first : null);

    // Track unmapped findings for Section 81 validation display
    final unmappedFindings = widget.findings
        .where((f) => f.highlight != null && !f.highlight!.hasValidLocation)
        .toList();

    // Determine primary line for each finding GlobalKey
    final Map<String, int> findingPrimaryLineIndex = {};
    for (int i = 0; i < lines.length; i++) {
      final spans = _findSpansForLine(lines[i], i);
      for (final s in spans) {
        if (!findingPrimaryLineIndex.containsKey(s.finding.id)) {
          findingPrimaryLineIndex[s.finding.id] = i;
        }
      }
    }

    final highCount = widget.findings.where((f) => f.severity == LegalRiskSeverity.high).length;
    final medCount = widget.findings.where((f) => f.severity == LegalRiskSeverity.medium).length;
    final lowCount = widget.findings
        .where((f) => f.severity == LegalRiskSeverity.low || f.severity == LegalRiskSeverity.safe)
        .length;

    return Column(
      children: [
        // ====================================================================
        // Section 67, 68 & 77: Top Control Bar (Legend, Nav, Filters)
        // ====================================================================
        if (widget.showHeader && widget.findings.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Column(
              children: [
                // Top Row: Previous / Next navigation & Legend dots
                Row(
                  children: [
                    // Navigation: ← Previous 1 of 3 Next → (Section 67)
                    if (visibleFindings.isNotEmpty) ...[
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_rounded, size: 14),
                        tooltip: 'Previous finding',
                        visualDensity: VisualDensity.compact,
                        onPressed: _goToPreviousFinding,
                      ),
                      Text(
                        '${activeIndex + 1} of ${visibleFindings.length} issues',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        tooltip: 'Next finding',
                        visualDensity: VisualDensity.compact,
                        onPressed: _goToNextFinding,
                      ),
                    ] else ...[
                      Text(
                        '0 of $totalIssues issues',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],

                    const Spacer(),

                    // Compact Legend (Section 68): 🔴 High risk  🟡 Medium risk  🔵 Informational
                    _LegendDot(
                      color: const Color(0xFFDC2626),
                      label: 'High risk ($highCount)',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _LegendDot(
                      color: const Color(0xFFD97706),
                      label: 'Medium risk ($medCount)',
                      isDark: isDark,
                    ),
                    if (lowCount > 0) ...[
                      const SizedBox(width: 8),
                      _LegendDot(
                        color: const Color(0xFF2563EB),
                        label: 'Info ($lowCount)',
                        isDark: isDark,
                      ),
                    ],

                    const SizedBox(width: 6),
                    // Reset zoom button
                    IconButton(
                      icon: const Icon(Icons.zoom_out_map, size: 16),
                      tooltip: 'Reset Zoom',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _transformController.value = Matrix4.identity(),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                // Filter chips (Section 77): [All] [High] [Medium] [Low]
                Row(
                  children: [
                    _FilterChip(
                      label: 'All ($totalIssues)',
                      isSelected: _selectedSeverityFilter == null,
                      onTap: () => setState(() => _selectedSeverityFilter = null),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: 'High ($highCount)',
                      isSelected: _selectedSeverityFilter == LegalRiskSeverity.high,
                      onTap: () => setState(() => _selectedSeverityFilter = LegalRiskSeverity.high),
                      isDark: isDark,
                      accentColor: const Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: 'Medium ($medCount)',
                      isSelected: _selectedSeverityFilter == LegalRiskSeverity.medium,
                      onTap: () => setState(() => _selectedSeverityFilter = LegalRiskSeverity.medium),
                      isDark: isDark,
                      accentColor: const Color(0xFFD97706),
                    ),
                    if (lowCount > 0) ...[
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: 'Low ($lowCount)',
                        isSelected: _selectedSeverityFilter == LegalRiskSeverity.low,
                        onTap: () => setState(() => _selectedSeverityFilter = LegalRiskSeverity.low),
                        isDark: isDark,
                        accentColor: const Color(0xFF2563EB),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],

        // ====================================================================
        // Section 81: Validation Fallback Alert
        // ====================================================================
        if (unmappedFindings.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.15 : 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Color(0xFFD97706)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Finding detected, but exact document location could not be determined.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => widget.onFindingTap?.call(unmappedFindings.first),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  child: const Text(
                    'View finding',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

        // ====================================================================
        // Sections 74 & 75: Interactive Paper Canvas with Zoom Support
        // ====================================================================
        Expanded(
          child: Container(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
            child: InteractiveViewer(
              transformationController: _transformController,
              minScale: 0.8,
              maxScale: 3.5,
              boundaryMargin: const EdgeInsets.all(32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
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

                        if (trimmed.isEmpty) {
                          return const SizedBox(height: 10);
                        }

                        final spans = _findSpansForLine(line, index);

                        // Attach key if any finding has its primary anchor on this line
                        Key? lineKey;
                        for (final s in spans) {
                          if (findingPrimaryLineIndex[s.finding.id] == index) {
                            lineKey = _findingKeys.putIfAbsent(s.finding.id, () => GlobalKey());
                            break;
                          }
                        }

                        return Container(
                          key: lineKey,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Line number gutter on left
                              SizedBox(
                                width: 28,
                                child: Text(
                                  '${index + 1}'.padLeft(2, '0'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: spans.isNotEmpty
                                        ? spans.first.finding.severity.color
                                        : (isDark ? Colors.white30 : const Color(0xFF94A3B8)),
                                    fontWeight: spans.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Text content with exact word/phrase highlighting
                              Expanded(
                                child: spans.isEmpty
                                    ? Text(
                                        line,
                                        style: TextStyle(
                                          fontSize: 13,
                                          height: 1.5,
                                          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                                        ),
                                      )
                                    : _buildHighlightedLine(
                                        line: line,
                                        spans: spans,
                                        isDark: isDark,
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
        ),

        // ====================================================================
        // Section 78: Floating Bottom Issue Card ("Tap for details")
        // ====================================================================
        if (activeFinding != null) ...[
          GestureDetector(
            onTap: () => widget.onFindingTap?.call(activeFinding),
            child: Container(
              margin: const EdgeInsets.fromLTRB(14, 6, 14, 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(
                  color: activeFinding.severity == LegalRiskSeverity.high
                      ? const Color(0xFFDC2626).withValues(alpha: 0.35)
                      : const Color(0xFFD97706).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: (activeFinding.severity == LegalRiskSeverity.high
                              ? const Color(0xFFDC2626)
                              : const Color(0xFFD97706))
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: activeFinding.severity == LegalRiskSeverity.high
                          ? const Color(0xFFDC2626)
                          : const Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          activeFinding.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Page ${activeFinding.pageIndex + 1} · ${activeFinding.severity.displayName} · Tap for details',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 20, color: Color(0xFF2563EB)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Builds a line of text where only the exact flagged phrase is highlighted (Sections 57, 62, 64, 65).
  Widget _buildHighlightedLine({
    required String line,
    required List<_LineSpan> spans,
    required bool isDark,
  }) {
    final inlineSpans = <InlineSpan>[];
    int currentOffset = 0;

    final defaultStyle = TextStyle(
      fontSize: 13,
      height: 1.5,
      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
    );

    for (final span in spans) {
      // 1. Unhighlighted leading text before this phrase (Section 62)
      if (span.start > currentOffset) {
        inlineSpans.add(TextSpan(
          text: line.substring(currentOffset, span.start),
          style: defaultStyle,
        ));
      }

      // 2. Exact highlighted phrase
      final phraseText = line.substring(span.start, span.end);
      final finding = span.finding;
      final isSelected = finding.id == _activeFindingId;

      final Color baseColor;
      switch (finding.severity) {
        case LegalRiskSeverity.high:
          baseColor = const Color(0xFFDC2626);
          break;
        case LegalRiskSeverity.medium:
          baseColor = const Color(0xFFD97706);
          break;
        case LegalRiskSeverity.low:
        case LegalRiskSeverity.safe:
          baseColor = const Color(0xFF2563EB);
          break;
      }

      // Interactive highlighted widget span with 1-time pulse animation (Section 76)
      inlineSpans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: InkWell(
            onTap: () {
              setState(() => _activeFindingId = finding.id);
              _triggerPulse();
              widget.onFindingTap?.call(finding);
            },
            borderRadius: BorderRadius.circular(4),
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                final pulse = isSelected ? _pulseAnimation.value : 0.0;
                final pulseAlpha = math.sin(pulse * math.pi) * 0.20;

                final fillAlpha = (isSelected ? 0.32 : 0.18) + pulseAlpha;
                final borderAlpha = (isSelected ? 0.95 : 0.65) + pulseAlpha;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: baseColor.withValues(alpha: fillAlpha.clamp(0.10, 0.50)),
                    borderRadius: BorderRadius.circular(3),
                    // Subtle left border & underline (Section 65)
                    border: Border(
                      bottom: BorderSide(
                        color: baseColor.withValues(alpha: borderAlpha.clamp(0.40, 1.0)),
                        width: isSelected ? 2.0 : 1.4,
                      ),
                      left: BorderSide(
                        color: baseColor.withValues(alpha: borderAlpha.clamp(0.50, 1.0)),
                        width: isSelected ? 3.5 : 2.5,
                      ),
                    ),
                  ),
                  child: Text(
                    phraseText,
                    style: defaultStyle.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      currentOffset = span.end;
    }

    // 3. Unhighlighted trailing text after all phrases (Section 62)
    if (currentOffset < line.length) {
      inlineSpans.add(TextSpan(
        text: line.substring(currentOffset),
        style: defaultStyle,
      ));
    }

    return Text.rich(
      TextSpan(children: inlineSpans),
    );
  }
}

class _LineSpan {
  final int start;
  final int end;
  final LegalFinding finding;

  const _LineSpan({
    required this.start,
    required this.end,
    required this.finding,
  });
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool isDark;

  const _LegendDot({
    required this.color,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;
  final Color? accentColor;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = accentColor ?? const Color(0xFF2563EB);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: isDark ? 0.25 : 0.15)
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? activeColor : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? activeColor
                : (isDark ? Colors.white70 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }
}
