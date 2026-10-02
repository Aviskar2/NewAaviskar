import '../../../core/legal/models/ocr_document.dart';

/// Represents a distinct, stable segmented clause in a legal document.
class SegmentedClause {
  final String id; // e.g. clause_001
  final String? heading;
  final String text;
  final int startOffset;
  final int endOffset;
  final int pageIndex;
  final int startLine;
  final int endLine;
  final OcrBoundingBox? boundingBox;

  const SegmentedClause({
    required this.id,
    this.heading,
    required this.text,
    required this.startOffset,
    required this.endOffset,
    this.pageIndex = 0,
    required this.startLine,
    required this.endLine,
    this.boundingBox,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'heading': heading,
    'text': text,
    'startOffset': startOffset,
    'endOffset': endOffset,
    'pageIndex': pageIndex,
    'startLine': startLine,
    'endLine': endLine,
    'boundingBox': boundingBox?.toJson(),
  };

  factory SegmentedClause.fromJson(Map<String, dynamic> json) => SegmentedClause(
    id: json['id'] as String,
    heading: json['heading'] as String?,
    text: json['text'] as String,
    startOffset: (json['startOffset'] as num?)?.toInt() ?? 0,
    endOffset: (json['endOffset'] as num?)?.toInt() ?? 0,
    pageIndex: (json['pageIndex'] as num?)?.toInt() ?? 0,
    startLine: (json['startLine'] as num?)?.toInt() ?? 0,
    endLine: (json['endLine'] as num?)?.toInt() ?? 0,
    boundingBox: json['boundingBox'] != null
        ? OcrBoundingBox.fromJson(json['boundingBox'] as Map<String, dynamic>)
        : null,
  );
}

/// Step 5 of Document Analysis Pipeline: Clause Segmentation.
///
/// Segments a legal document into logical clauses with stable sequential IDs
/// (`clause_001`, `clause_002`, ...) while recording exact character offsets
/// and line numbers for highlighting in Interactive Paper view.
class ClauseSegmentationService {
  /// Regular expressions identifying beginning of legal clauses or numbered paragraphs.
  static final RegExp _clauseHeaderPattern = RegExp(
    r'^(?:'
    r'(?:clause|section|article|point|para|item)\s*(?:no\.?|#)?\s*\d+[a-z]?' // Clause 1, Section 2.1
    r'|\d+[\.\)]\s+' // 1. or 1)
    r'|\([a-z0-9]+\)\s+' // (a) or (1) or (i)
    r'|[A-Z][A-Z\s]{3,30}:' // ALL CAPS HEADER:
    r'|WHEREAS\b|NOW THEREFORE\b|IN WITNESS WHEREOF\b'
    r')',
    caseSensitive: false,
  );

  /// Segments an [OcrDocument] or normalized raw text into indexed clauses.
  List<SegmentedClause> segmentDocument(String normalizedText, {OcrDocument? doc}) {
    if (normalizedText.trim().isEmpty) return [];

    final lines = normalizedText.split('\n');
    final clauses = <SegmentedClause>[];

    int clauseIndex = 1;
    final currentClauseLines = <String>[];
    String? currentHeading;
    int clauseStartOffset = 0;
    int clauseStartLine = 0;
    int currentOffset = 0;

    void commitCurrentClause(int lineEndIndex) {
      if (currentClauseLines.isEmpty) return;

      final joinedText = currentClauseLines.join('\n').trim();
      if (joinedText.isNotEmpty) {
        final id = 'clause_${clauseIndex.toString().padLeft(3, '0')}';
        final endOffset = clauseStartOffset + joinedText.length;

        // Estimate bounding box if doc has lines
        OcrBoundingBox? box;
        int pageIndex = 0;
        if (doc != null && doc.pages.isNotEmpty) {
          final page = doc.pages.first;
          final totalLines = lines.length.clamp(1, 1000);
          final top = (clauseStartLine / totalLines).clamp(0.0, 1.0);
          final height = ((lineEndIndex - clauseStartLine + 1) / totalLines).clamp(0.01, 1.0);
          box = OcrBoundingBox(left: 0.05, top: top, width: 0.90, height: height);
          pageIndex = page.pageIndex;
        }

        clauses.add(SegmentedClause(
          id: id,
          heading: currentHeading,
          text: joinedText,
          startOffset: clauseStartOffset,
          endOffset: endOffset,
          pageIndex: pageIndex,
          startLine: clauseStartLine,
          endLine: lineEndIndex,
          boundingBox: box,
        ));
        clauseIndex++;
      }
      currentClauseLines.clear();
      currentHeading = null;
    }

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        // Empty lines can serve as paragraph breaks if the clause has enough content
        if (currentClauseLines.length >= 2 || (currentClauseLines.isNotEmpty && currentClauseLines.first.length > 80)) {
          commitCurrentClause(i - 1);
          clauseStartOffset = currentOffset + line.length + 1;
          clauseStartLine = i + 1;
        }
        currentOffset += line.length + 1;
        continue;
      }

      final isHeader = _clauseHeaderPattern.hasMatch(trimmed);

      if (isHeader && currentClauseLines.isNotEmpty) {
        // End the previous clause and start a new one
        commitCurrentClause(i - 1);
        clauseStartOffset = currentOffset;
        clauseStartLine = i;
        currentHeading = trimmed.length > 50 ? trimmed.substring(0, 50) : trimmed;
      } else if (currentClauseLines.isEmpty) {
        clauseStartOffset = currentOffset;
        clauseStartLine = i;
        if (isHeader) {
          currentHeading = trimmed.length > 50 ? trimmed.substring(0, 50) : trimmed;
        }
      }

      currentClauseLines.add(line);
      currentOffset += line.length + 1;
    }

    // Commit any trailing clause
    commitCurrentClause(lines.length - 1);

    // Fallback: If document was too dense and produced no split, segment by paragraphs
    if (clauses.isEmpty && normalizedText.trim().isNotEmpty) {
      clauses.add(SegmentedClause(
        id: 'clause_001',
        text: normalizedText.trim(),
        startOffset: 0,
        endOffset: normalizedText.length,
        pageIndex: 0,
        startLine: 0,
        endLine: lines.length - 1,
        boundingBox: const OcrBoundingBox(left: 0.05, top: 0.05, width: 0.90, height: 0.90),
      ));
    }

    return clauses;
  }

  /// Locates the best matching [SegmentedClause] containing the specified excerpt.
  SegmentedClause? findClauseForExcerpt(List<SegmentedClause> clauses, String excerpt) {
    if (excerpt.trim().isEmpty || clauses.isEmpty) return null;

    final cleanExcerpt = excerpt.trim().toLowerCase();

    // Exact match
    for (final c in clauses) {
      if (c.text.toLowerCase().contains(cleanExcerpt)) {
        return c;
      }
    }

    // Partial match on first 30 chars
    final prefix = cleanExcerpt.length > 30 ? cleanExcerpt.substring(0, 30) : cleanExcerpt;
    for (final c in clauses) {
      if (c.text.toLowerCase().contains(prefix)) {
        return c;
      }
    }

    return null;
  }
}
