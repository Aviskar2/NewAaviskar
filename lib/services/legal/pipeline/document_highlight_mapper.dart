import 'dart:math' as math;
import '../../../core/legal/models/document_highlight.dart';
import '../../../core/legal/models/legal_finding.dart';
import '../../../core/legal/models/ocr_document.dart';
import 'clause_segmentation_service.dart';

/// Maps AI and legal findings to physical coordinates in the document (Sections 58, 59, 60, 62, 63, 71, 72, 81).
///
/// Implements the principle:
/// "The AI identifies the text. The document parser identifies its exact location."
/// Calculates word-level and multi-line bounding boxes directly from OCR / PDF extraction layers.
class DocumentHighlightMapper {
  const DocumentHighlightMapper();

  /// Maps a list of [LegalFinding]s to [DocumentHighlight]s, attaching them directly
  /// to the findings and returning the enriched findings list.
  List<LegalFinding> mapFindings({
    required OcrDocument document,
    required List<LegalFinding> findings,
    List<SegmentedClause> clauses = const [],
  }) {
    if (findings.isEmpty) return [];

    final enrichedFindings = <LegalFinding>[];
    int highlightIndex = 1;

    for (final finding in findings) {
      final highlight = createHighlightForFinding(
        document: document,
        finding: finding,
        highlightId: 'highlight_${highlightIndex.toString().padLeft(3, '0')}',
        clauses: clauses,
      );

      highlightIndex++;

      // Update finding with exact mapped coordinates and highlight reference
      enrichedFindings.add(finding.copyWith(
        pageIndex: highlight.pageIndex,
        startOffset: highlight.startOffset,
        endOffset: highlight.endOffset,
        boundingBox: highlight.rectangles.isNotEmpty
            ? OcrBoundingBox(
                left: highlight.boundingBox.x,
                top: highlight.boundingBox.y,
                width: highlight.boundingBox.width,
                height: highlight.boundingBox.height,
              )
            : finding.boundingBox,
        highlight: highlight,
      ));
    }

    return enrichedFindings;
  }

  /// Creates a single [DocumentHighlight] for a given [LegalFinding].
  DocumentHighlight createHighlightForFinding({
    required OcrDocument document,
    required LegalFinding finding,
    required String highlightId,
    List<SegmentedClause> clauses = const [],
  }) {
    // 1. Identify target search query (prefer exact excerpt, fallback to evidence)
    final query = finding.rawExcerpt.trim().isNotEmpty
        ? finding.rawExcerpt.trim()
        : (finding.evidence?.trim().isNotEmpty == true
            ? finding.evidence!.trim()
            : finding.title.trim());

    if (query.isEmpty || document.pages.isEmpty) {
      return _createUnmappedHighlight(
        finding: finding,
        highlightId: highlightId,
        query: query,
      );
    }

    // 2. Identify target page and occurrence using context disambiguation (Section 71)
    final matchLocation = _locateBestOccurrence(
      document: document,
      finding: finding,
      query: query,
      clauses: clauses,
    );

    if (matchLocation == null) {
      // Mapping failed (Section 81): return without faking coordinates
      return _createUnmappedHighlight(
        finding: finding,
        highlightId: highlightId,
        query: query,
      );
    }

    // 3. Generate multi-line highlight rectangles for the matched span (Section 63)
    final targetPage = document.pages[matchLocation.pageIndex];
    final rectangles = _generateHighlightRectangles(
      page: targetPage,
      matchedLineIndices: matchLocation.lineIndices,
      startCharIndex: matchLocation.startCharInFirstLine,
      endCharIndex: matchLocation.endCharInLastLine,
    );

    // 4. Validate rectangles (Section 81)
    final validRectangles = rectangles.where((r) {
      return r.x >= 0.0 &&
          r.x <= 1.0 &&
          r.y >= 0.0 &&
          r.y <= 1.0 &&
          r.width > 0.0 &&
          r.height > 0.0;
    }).toList();

    if (validRectangles.isEmpty) {
      return _createUnmappedHighlight(
        finding: finding,
        highlightId: highlightId,
        query: query,
        pageIndex: matchLocation.pageIndex,
      );
    }

    // Determine highlightType
    final highlightType = query.split(RegExp(r'\s+')).length <= 5
        ? 'word'
        : (query.contains('.') ? 'clause' : 'sentence');

    return DocumentHighlight(
      id: highlightId,
      findingId: finding.id,
      clauseId: finding.clauseId,
      pageNumber: matchLocation.pageIndex + 1, // 1-indexed for UI display
      exactText: matchLocation.exactMatchedText,
      normalizedText: _normalizeText(matchLocation.exactMatchedText),
      rectangles: validRectangles,
      severity: finding.severity,
      confidence: finding.confidence,
      category: finding.category ?? 'risk_indicator',
      highlightType: highlightType,
      startOffset: matchLocation.globalStartOffset,
      endOffset: matchLocation.globalEndOffset,
      occurrenceIndex: matchLocation.occurrenceIndex,
      hasValidLocation: true,
    );
  }

  /// Locates the best occurrence across all pages, handling multi-occurrence disambiguation (Section 71)
  /// and fuzzy OCR typo tolerance (Section 72).
  _MatchLocation? _locateBestOccurrence({
    required OcrDocument document,
    required LegalFinding finding,
    required String query,
    required List<SegmentedClause> clauses,
  }) {
    final normalizedQuery = _normalizeText(query);
    if (normalizedQuery.isEmpty) return null;

    final queryWords = normalizedQuery.split(RegExp(r'\s+')).where((w) => w.length >= 2).toList();
    if (queryWords.isEmpty) return null;

    // Collect all candidate occurrences across all pages
    final candidates = <_MatchLocation>[];
    int globalOffsetCounter = 0;

    for (int p = 0; p < document.pages.length; p++) {
      final page = document.pages[p];

      // Check each line and consecutive multi-line sequences
      for (int i = 0; i < page.lines.length; i++) {
        // Try matching within a window of 1 to 5 lines
        for (int window = 1; window <= 5 && (i + window) <= page.lines.length; window++) {
          final spanLines = page.lines.sublist(i, i + window);
          final spanText = spanLines.map((l) => l.text).join(' ');
          final normalizedSpan = _normalizeText(spanText);

          // 1. Exact or normalized substring match
          final matchIndex = normalizedSpan.indexOf(normalizedQuery);
          if (matchIndex != -1) {
            final loc = _buildMatchLocationFromSpan(
              pageIndex: p,
              startLineIndex: i,
              spanLines: spanLines,
              matchOffsetInSpan: matchIndex,
              matchLength: normalizedQuery.length,
              exactQuery: query,
              globalOffset: globalOffsetCounter,
            );
            if (loc != null) candidates.add(loc);
            continue;
          }

          // 2. Fuzzy match: Check if >= 80% of query keywords appear in order
          int matchedKeywordCount = 0;
          for (final kw in queryWords) {
            if (normalizedSpan.contains(kw)) matchedKeywordCount++;
          }

          final matchRatio = matchedKeywordCount / queryWords.length;
          if (matchRatio >= 0.75 && queryWords.length >= 3) {
            final loc = _buildFuzzyLocationFromSpan(
              pageIndex: p,
              startLineIndex: i,
              spanLines: spanLines,
              queryWords: queryWords,
              matchRatio: matchRatio,
              globalOffset: globalOffsetCounter,
            );
            if (loc != null) candidates.add(loc);
          }
        }

        globalOffsetCounter += page.lines[i].text.length + 1;
      }
    }

    if (candidates.isEmpty) return null;

    // Disambiguate if multiple occurrences exist (Section 71)
    if (candidates.length == 1) {
      return candidates.first;
    }

    // Rank candidates using context similarity with finding explanation and clause ID
    _MatchLocation best = candidates.first;
    double bestScore = -1.0;

    for (int idx = 0; idx < candidates.length; idx++) {
      final candidate = candidates[idx];
      candidate.occurrenceIndex = idx;

      double score = candidate.qualityScore;

      // Prefer pageIndex matching finding.pageIndex if specified
      if (candidate.pageIndex == finding.pageIndex) {
        score += 3.0;
      }

      // Check context overlap with clause text
      if (finding.clauseId != null) {
        final matchingClause = clauses.where((c) => c.id == finding.clauseId).firstOrNull;
        if (matchingClause != null) {
          final clauseNorm = _normalizeText(matchingClause.text);
          final candNorm = _normalizeText(candidate.exactMatchedText);
          if (clauseNorm.contains(candNorm) || candNorm.contains(clauseNorm)) {
            score += 5.0;
          }
        }
      }

      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }

    return best;
  }

  /// Builds match location from a multi-line span.
  _MatchLocation? _buildMatchLocationFromSpan({
    required int pageIndex,
    required int startLineIndex,
    required List<OcrLine> spanLines,
    required int matchOffsetInSpan,
    required int matchLength,
    required String exactQuery,
    required int globalOffset,
  }) {
    if (spanLines.isEmpty) return null;

    // Find which lines in the span contain the match
    int currentOffset = 0;
    int firstLineInMatch = -1;
    int startCharInFirstLine = 0;
    int endCharInLastLine = 0;

    final matchedLineIndices = <int>[];

    for (int s = 0; s < spanLines.length; s++) {
      final lineLen = spanLines[s].text.length;
      final lineEndOffset = currentOffset + lineLen;

      final matchEnd = matchOffsetInSpan + matchLength;

      // Does this line strictly overlap with [matchOffsetInSpan, matchEnd]?
      if (lineEndOffset > matchOffsetInSpan && currentOffset < matchEnd) {
        if (firstLineInMatch == -1) {
          firstLineInMatch = startLineIndex + s;
          startCharInFirstLine = (matchOffsetInSpan - currentOffset).clamp(0, lineLen);
        }
        endCharInLastLine = (matchEnd - currentOffset).clamp(0, lineLen);
        matchedLineIndices.add(startLineIndex + s);
      }

      currentOffset = lineEndOffset + 1; // +1 for the space separator in spanText
    }

    if (matchedLineIndices.isEmpty) return null;

    final score = matchedLineIndices.length == 1 ? 15.0 : 10.0;

    return _MatchLocation(
      pageIndex: pageIndex,
      lineIndices: matchedLineIndices,
      startCharInFirstLine: startCharInFirstLine,
      endCharInLastLine: endCharInLastLine,
      exactMatchedText: exactQuery,
      globalStartOffset: globalOffset + matchOffsetInSpan,
      globalEndOffset: globalOffset + matchOffsetInSpan + matchLength,
      qualityScore: score,
    );
  }

  /// Builds fuzzy match location for OCR typo tolerance.
  _MatchLocation? _buildFuzzyLocationFromSpan({
    required int pageIndex,
    required int startLineIndex,
    required List<OcrLine> spanLines,
    required List<String> queryWords,
    required double matchRatio,
    required int globalOffset,
  }) {
    final matchedIndices = List.generate(spanLines.length, (idx) => startLineIndex + idx);
    final text = spanLines.map((l) => l.text).join(' ');

    return _MatchLocation(
      pageIndex: pageIndex,
      lineIndices: matchedIndices,
      startCharInFirstLine: 0,
      endCharInLastLine: spanLines.last.text.length,
      exactMatchedText: text,
      globalStartOffset: globalOffset,
      globalEndOffset: globalOffset + text.length,
      qualityScore: matchRatio * 8.0,
    );
  }

  /// Generates discrete highlight rectangles for each affected line (Section 63).
  List<HighlightRect> _generateHighlightRectangles({
    required OcrPage page,
    required List<int> matchedLineIndices,
    required int startCharIndex,
    required int endCharIndex,
  }) {
    final rects = <HighlightRect>[];

    for (int i = 0; i < matchedLineIndices.length; i++) {
      final lineIdx = matchedLineIndices[i];
      if (lineIdx < 0 || lineIdx >= page.lines.length) continue;

      final line = page.lines[lineIdx];
      final isFirstLine = (i == 0);
      final isLastLine = (i == matchedLineIndices.length - 1);

      // Check if word-level tokens exist in this line
      if (line.tokens.isNotEmpty) {
        final startChar = isFirstLine ? startCharIndex : 0;
        final endChar = isLastLine ? endCharIndex : line.text.length;

        final matchingTokens = <OcrToken>[];
        int charCursor = 0;

        for (final token in line.tokens) {
          final tokenStart = charCursor;
          final tokenEnd = charCursor + token.text.length;

          if (tokenEnd > startChar && tokenStart < endChar) {
            matchingTokens.add(token);
          }

          charCursor = tokenEnd + 1; // +1 space
        }

        if (matchingTokens.isNotEmpty) {
          double minX = matchingTokens.first.boundingBox.left;
          double minY = matchingTokens.first.boundingBox.top;
          double maxX = matchingTokens.first.boundingBox.right;
          double maxY = matchingTokens.first.boundingBox.bottom;

          for (final t in matchingTokens) {
            minX = math.min(minX, t.boundingBox.left);
            minY = math.min(minY, t.boundingBox.top);
            maxX = math.max(maxX, t.boundingBox.right);
            maxY = math.max(maxY, t.boundingBox.bottom);
          }

          rects.add(HighlightRect(
            x: minX.clamp(0.0, 1.0),
            y: minY.clamp(0.0, 1.0),
            width: (maxX - minX).clamp(0.01, 1.0),
            height: (maxY - minY).clamp(0.005, 1.0),
          ));
          continue;
        }
      }

      // Fallback: Slice line bounding box horizontally based on character proportions
      final lineBox = line.boundingBox;
      final lineLen = math.max(1, line.text.length);

      final startRatio = isFirstLine ? (startCharIndex / lineLen).clamp(0.0, 1.0) : 0.0;
      final endRatio = isLastLine ? (endCharIndex / lineLen).clamp(0.0, 1.0) : 1.0;

      final sliceLeft = lineBox.left + (startRatio * lineBox.width);
      final sliceWidth = (endRatio - startRatio).clamp(0.05, 1.0) * lineBox.width;

      rects.add(HighlightRect(
        x: sliceLeft.clamp(0.0, 1.0),
        y: lineBox.top.clamp(0.0, 1.0),
        width: sliceWidth.clamp(0.01, 1.0),
        height: lineBox.height.clamp(0.005, 1.0),
      ));
    }

    return rects;
  }

  /// Normalizes text for robust fuzzy comparison without modifying displayed text (Section 72).
  String _normalizeText(String input) {
    var text = input.toLowerCase();

    // Normalize common Indian currency prefixes
    text = text.replaceAll('₹', 'rs');
    text = text.replaceAll('inr', 'rs');
    text = text.replaceAll('rs.', 'rs');

    // Normalize OCR digit/letter confusions in numbers (e.g. 50,OOO -> 50,000)
    text = text.replaceAllMapped(RegExp(r'(\d+)[oO]+'), (m) => '${m.group(1)}000');

    // Normalize quotes and punctuation
    text = text.replaceAll('“', '"').replaceAll('”', '"').replaceAll('’', "'").replaceAll('‘', "'");
    text = text.replaceAll(RegExp(r'[\.,;:\-_]'), ' ');

    // Normalize whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return text;
  }

  /// Creates a fallback highlight representation when exact document coordinates
  /// cannot be determined (Section 81).
  DocumentHighlight _createUnmappedHighlight({
    required LegalFinding finding,
    required String highlightId,
    required String query,
    int pageIndex = 0,
  }) {
    return DocumentHighlight(
      id: highlightId,
      findingId: finding.id,
      clauseId: finding.clauseId,
      pageNumber: pageIndex + 1,
      exactText: query,
      normalizedText: _normalizeText(query),
      rectangles: const [], // Empty rectangles indicates unmapped location
      severity: finding.severity,
      confidence: finding.confidence,
      category: finding.category ?? 'risk_indicator',
      highlightType: 'sentence',
      hasValidLocation: false, // Flagged false per Section 81
    );
  }
}

/// Internal helper storing candidate match coordinates.
class _MatchLocation {
  final int pageIndex;
  final List<int> lineIndices;
  final int startCharInFirstLine;
  final int endCharInLastLine;
  final String exactMatchedText;
  final int globalStartOffset;
  final int globalEndOffset;
  final double qualityScore;
  int occurrenceIndex = 0;

  _MatchLocation({
    required this.pageIndex,
    required this.lineIndices,
    required this.startCharInFirstLine,
    required this.endCharInLastLine,
    required this.exactMatchedText,
    required this.globalStartOffset,
    required this.globalEndOffset,
    required this.qualityScore,
  });
}
