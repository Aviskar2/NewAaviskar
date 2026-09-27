import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/legal/models/legal_finding.dart';
import '../../core/legal/models/ocr_document.dart';
import '../../widgets/legal_analyzer/document_highlight_painter.dart';
import '../../widgets/legal_analyzer/highlighted_document_paper.dart';
import 'legal_finding_detail_sheet.dart';

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
  State<InteractiveDocumentViewer> createState() =>
      _InteractiveDocumentViewerState();
}

class _InteractiveDocumentViewerState extends State<InteractiveDocumentViewer> {
  int _currentPage = 0;
  String? _selectedFindingId;
  bool _showImageView = false;
  final TransformationController _transformController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    _selectedFindingId = widget.initialFindingId;
    final page = widget.document.pages.isNotEmpty
        ? widget.document.pages.first
        : null;
    _showImageView =
        page?.imagePath != null && File(page!.imagePath!).existsSync();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _onTapHighlight(TapUpDetails details, Size layoutSize) {
    final localPos = details.localPosition;
    final normX = localPos.dx / layoutSize.width;
    final normY = localPos.dy / layoutSize.height;

    for (final f in widget.findings) {
      if (f.pageIndex == _currentPage && f.boundingBox != null) {
        final box = f.boundingBox!;
        if (normX >= box.left &&
            normX <= box.right &&
            normY >= box.top &&
            normY <= box.bottom) {
          setState(() => _selectedFindingId = f.id);
          _showFindingSheet(f);
          return;
        }
      }
    }
  }

  void _showFindingSheet(LegalFinding finding) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LegalFindingDetailSheet(finding: finding),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final page = widget.document.pages.isNotEmpty
        ? widget.document.pages[_currentPage]
        : null;
    final hasImage =
        page?.imagePath != null && File(page!.imagePath!).existsSync();

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
          // Banner with instruction
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            child: Row(
              children: [
                const Icon(
                  Icons.touch_app_outlined,
                  size: 16,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _showImageView
                        ? 'Pinch to zoom image. Tap highlighted boxes to view Indian law citations.'
                        : 'Tap any highlighted statement to inspect the law, legal risk, and advice.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
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
                                Size(
                                  constraints.maxWidth,
                                  constraints.maxHeight,
                                ),
                              ),
                              child: CustomPaint(
                                foregroundPainter: DocumentHighlightPainter(
                                  findings: widget.findings,
                                  selectedFindingId: _selectedFindingId,
                                  pageIndex: _currentPage,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    File(page.imagePath!),
                                    fit: BoxFit.contain,
                                  ),
                                ),
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
