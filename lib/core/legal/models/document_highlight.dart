import 'dart:ui';
import 'legal_finding.dart';

/// Represents a single bounding rectangle in normalized document/page coordinates (0.0 to 1.0).
///
/// Using normalized coordinates ensures that highlighting remains accurately positioned
/// regardless of zoom level, device pixel ratio, page scaling, or rotation (Sections 74 & 75).
class HighlightRect {
  final double x;
  final double y;
  final double width;
  final double height;

  const HighlightRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  double get left => x;
  double get top => y;
  double get right => x + width;
  double get bottom => y + height;

  /// Converts normalized coordinates to absolute screen/canvas pixels given a rendered [pageSize].
  Rect toRect(Size pageSize) {
    return Rect.fromLTWH(
      x * pageSize.width,
      y * pageSize.height,
      width * pageSize.width,
      height * pageSize.height,
    );
  }

  /// Tests whether a normalized point [normX, normY] falls within this rectangle.
  bool containsNormalized(double normX, double normY) {
    return normX >= x && normX <= (x + width) && normY >= y && normY <= (y + height);
  }

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };

  factory HighlightRect.fromJson(Map<String, dynamic> json) => HighlightRect(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
      );
}

/// Structured document highlight linking an AI/legal finding directly to
/// physical locations in the document (Sections 58, 63, 73).
class DocumentHighlight {
  final String id; // e.g. highlight_001
  final String findingId; // e.g. finding_001
  final String? clauseId; // e.g. clause_014
  final int pageNumber; // 1-indexed for user display (Section 58)
  final String exactText; // Actual text from document (never AI-hallucinated)
  final String normalizedText; // Normalized version used for fuzzy matching
  final List<HighlightRect> rectangles; // Discrete rectangles for multi-line clauses (Section 63)
  final LegalRiskSeverity severity;
  final double confidence;
  final String category;
  final String highlightType; // 'word', 'sentence', 'clause'
  final int startOffset;
  final int endOffset;
  final int occurrenceIndex; // Distinguishes duplicate phrases (Section 71)
  final bool hasValidLocation; // False if mapping failed (Section 81)

  int get pageIndex => pageNumber - 1;

  const DocumentHighlight({
    required this.id,
    required this.findingId,
    this.clauseId,
    required this.pageNumber,
    required this.exactText,
    required this.normalizedText,
    required this.rectangles,
    required this.severity,
    this.confidence = 1.0,
    this.category = 'risk_indicator',
    this.highlightType = 'sentence',
    this.startOffset = 0,
    this.endOffset = 0,
    this.occurrenceIndex = 0,
    this.hasValidLocation = true,
  });

  /// Primary bounding rectangle encompassing all multi-line rectangles.
  HighlightRect get boundingBox {
    if (rectangles.isEmpty) {
      return const HighlightRect(x: 0, y: 0, width: 0, height: 0);
    }
    double minX = rectangles.first.x;
    double minY = rectangles.first.y;
    double maxX = rectangles.first.right;
    double maxY = rectangles.first.bottom;

    for (final r in rectangles) {
      if (r.x < minX) minX = r.x;
      if (r.y < minY) minY = r.y;
      if (r.right > maxX) maxX = r.right;
      if (r.bottom > maxY) maxY = r.bottom;
    }

    return HighlightRect(
      x: minX,
      y: minY,
      width: (maxX - minX).clamp(0.0, 1.0),
      height: (maxY - minY).clamp(0.0, 1.0),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'findingId': findingId,
        'clauseId': clauseId,
        'pageNumber': pageNumber,
        'exactText': exactText,
        'normalizedText': normalizedText,
        'rectangles': rectangles.map((r) => r.toJson()).toList(),
        'severity': severity.name,
        'confidence': confidence,
        'category': category,
        'highlightType': highlightType,
        'startOffset': startOffset,
        'endOffset': endOffset,
        'occurrenceIndex': occurrenceIndex,
        'hasValidLocation': hasValidLocation,
      };

  factory DocumentHighlight.fromJson(Map<String, dynamic> json) {
    LegalRiskSeverity sev = LegalRiskSeverity.medium;
    final sevStr = json['severity']?.toString().toLowerCase();
    if (sevStr == 'high') {
      sev = LegalRiskSeverity.high;
    } else if (sevStr == 'low') {
      sev = LegalRiskSeverity.low;
    } else if (sevStr == 'safe') {
      sev = LegalRiskSeverity.safe;
    }

    final rectList = (json['rectangles'] as List?)
            ?.map((r) => HighlightRect.fromJson(r as Map<String, dynamic>))
            .toList() ??
        [];

    return DocumentHighlight(
      id: json['id'] as String? ?? 'highlight_unknown',
      findingId: json['findingId'] as String? ?? '',
      clauseId: json['clauseId'] as String?,
      pageNumber: json['pageNumber'] as int? ?? 1,
      exactText: json['exactText'] as String? ?? '',
      normalizedText: json['normalizedText'] as String? ?? '',
      rectangles: rectList,
      severity: sev,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      category: json['category'] as String? ?? 'risk_indicator',
      highlightType: json['highlightType'] as String? ?? 'sentence',
      startOffset: json['startOffset'] as int? ?? 0,
      endOffset: json['endOffset'] as int? ?? 0,
      occurrenceIndex: json['occurrenceIndex'] as int? ?? 0,
      hasValidLocation: json['hasValidLocation'] as bool? ?? true,
    );
  }
}
