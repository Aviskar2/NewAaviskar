import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/legal/models/legal_finding.dart';
import '../../core/legal/models/ocr_document.dart';
import '../../widgets/legal_analyzer/document_highlight_painter.dart';
import '../../widgets/legal_analyzer/highlighted_document_paper.dart';
import 'sheets/interactive_clause_sheet.dart';

/// Fullscreen / Interactive Document Viewer supporting digital text & scanned document overlays (Sections 61, 74, 75).
class InteractiveDocumentViewer extends StatefulWidget {
  final OcrDocument document;
  final List<LegalFinding> findings;
  final String? initialFindingId;

  const InteractiveDocumentViewer({
    super.key,
    required this.document,
    required this.findings,
    this.initialFindingId,
  });

  @override
  State<InteractiveDocumentViewer> createState() => _InteractiveDocumentViewerState();
}

class _InteractiveDocumentViewerState extends State<InteractiveDocumentViewer>
    with SingleTickerProviderStateMixin {
  int _currentPage = 0;
  String? _selectedFindingId;
  bool _showImageView = false;
  LegalRiskSeverity? _selectedSeverityFilter;

  final TransformationController _transformController = TransformationController();
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _selectedFindingId = widget.initialFindingId;

    // Single-shot pulse controller (Section 76)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    // Auto-navigate to page containing initial finding (Section 70)
    if (_selectedFindingId != null) {
      final initialFinding = widget.findings
          .where((f) => f.id == _selectedFindingId)
          .firstOrNull;
      if (initialFinding != null && widget.document.pages.isNotEmpty) {
        _currentPage = initialFinding.pageIndex.clamp(0, widget.document.pages.length - 1);
        _triggerPulse();
      }
    }

    final page = widget.document.pages.isNotEmpty
        ? widget.document.pages.first
        : null;
    _showImageView = page?.imagePath != null && File(page!.imagePath!).existsSync();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _triggerPulse() {
    _pulseController.forward(from: 0.0);
  }

  void _onTapHighlight(TapUpDetails details, Size layoutSize) {
    final localPos = details.localPosition;
    final normX = localPos.dx / layoutSize.width;
    final normY = localPos.dy / layoutSize.height;

    for (final f in widget.findings) {
      if (f.pageIndex == _currentPage) {
        // Tap hit-testing using discrete multi-line rectangles (Section 63)
        final highlight = f.highlight;
        bool hit = false;
        if (highlight != null && highlight.rectangles.isNotEmpty) {
          for (final r in highlight.rectangles) {
            if (r.containsNormalized(normX, normY)) {
              hit = true;
              break;
            }
          }
        } else if (f.boundingBox != null) {
          final box = f.boundingBox!;
          if (normX >= box.left &&
              normX <= box.right &&
              normY >= box.top &&
              normY <= box.bottom) {
            hit = true;
          }
        }

        if (hit) {
          setState(() => _selectedFindingId = f.id);
          _triggerPulse();
          _showFindingSheet(f);
          return;
        }
      }
    }
  }

  void _showFindingSheet(LegalFinding finding) {
    InteractiveClauseSheet.show(
      context,
      finding: finding,
      onViewInDocument: () {
        setState(() {
          _selectedFindingId = finding.id;
          _currentPage = finding.pageIndex.clamp(0, widget.document.pages.length - 1);
        });
        _triggerPulse();
      },
    );
  }

  List<LegalFinding> get _visibleFindings {
    if (_selectedSeverityFilter == null) return widget.findings;
    return widget.findings.where((f) => f.severity == _selectedSeverityFilter).toList();
  }

  int get _activeFindingIndex {
    final list = _visibleFindings;
    if (_selectedFindingId == null || list.isEmpty) return 0;
    final idx = list.indexWhere((f) => f.id == _selectedFindingId);
    return idx == -1 ? 0 : idx;
  }

  void _goToPreviousFinding() {
    final list = _visibleFindings;
    if (list.isEmpty) return;
    final current = _activeFindingIndex;
    final prev = (current - 1 + list.length) % list.length;
    final targetFinding = list[prev];
    setState(() {
      _selectedFindingId = targetFinding.id;
      _currentPage = targetFinding.pageIndex.clamp(0, widget.document.pages.length - 1);
    });
    _triggerPulse();
  }

  void _goToNextFinding() {
    final list = _visibleFindings;
    if (list.isEmpty) return;
    final current = _activeFindingIndex;
    final next = (current + 1) % list.length;
    final targetFinding = list[next];
    setState(() {
      _selectedFindingId = targetFinding.id;
      _currentPage = targetFinding.pageIndex.clamp(0, widget.document.pages.length - 1);
    });
    _triggerPulse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final page = widget.document.pages.isNotEmpty
        ? widget.document.pages[_currentPage]
        : null;
    final hasImage = page?.imagePath != null && File(page!.imagePath!).existsSync();

    final visibleFindings = _visibleFindings;
    final totalIssues = widget.findings.length;
    final activeIndex = _activeFindingIndex;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Highlighted Document View'),
        actions: [
          if (hasImage)
            IconButton(
              icon: Icon(
                _showImageView ? Icons.article_outlined : Icons.image_outlined,
              ),
              tooltip: _showImageView
                  ? 'Switch to Highlighted Text'
                  : 'Switch to Scanned Image',
              onPressed: () => setState(() => _showImageView = !_showImageView),
            ),
          IconButton(
            icon: const Icon(Icons.zoom_out_map),
            tooltip: 'Reset Zoom',
            onPressed: () => _transformController.value = Matrix4.identity(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner with instruction & Quick Nav in Image View mode
          if (_showImageView && hasImage)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
              child: Row(
                children: [
                  if (visibleFindings.isNotEmpty) ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_rounded, size: 14),
                      visualDensity: VisualDensity.compact,
                      onPressed: _goToPreviousFinding,
                    ),
                    Text(
                      '${activeIndex + 1} of ${visibleFindings.length} issues',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      visualDensity: VisualDensity.compact,
                      onPressed: _goToNextFinding,
                    ),
                  ] else ...[
                    Text('0 of $totalIssues issues', style: const TextStyle(fontSize: 12)),
                  ],
                  const Spacer(),
                  const Icon(
                    Icons.touch_app_outlined,
                    size: 16,
                    color: Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Pinch to zoom · Tap highlights',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),

          // Main View: Either HighlightedDocumentPaper or Image Overlay
          Expanded(
            child: _showImageView && hasImage
                ? InteractiveViewer(
                    transformationController: _transformController,
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return GestureDetector(
                              onTapUp: (details) => _onTapHighlight(
                                details,
                                Size(constraints.maxWidth, constraints.maxHeight),
                              ),
                              child: AnimatedBuilder(
                                animation: _pulseAnimation,
                                builder: (context, child) {
                                  return CustomPaint(
                                    foregroundPainter: DocumentHighlightPainter(
                                      findings: widget.findings,
                                      selectedFindingId: _selectedFindingId,
                                      pageIndex: _currentPage,
                                      pulseProgress: _pulseAnimation.value,
                                      severityFilter: _selectedSeverityFilter,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(
                                        File(page.imagePath!),
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  )
                : HighlightedDocumentPaper(
                    rawText: widget.document.rawText,
                    findings: widget.findings,
                    initialFindingId: _selectedFindingId,
                    onFindingTap: _showFindingSheet,
                  ),
          ),

          // Multi-page bottom bar
          if (widget.document.pages.length > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _currentPage > 0
                        ? () => setState(() => _currentPage--)
                        : null,
                  ),
                  Text(
                    'Page ${_currentPage + 1} of ${widget.document.pages.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _currentPage < widget.document.pages.length - 1
                        ? () => setState(() => _currentPage++)
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
