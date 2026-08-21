import 'dart:ui';

/// Represents a bounding box in both absolute pixel and normalized [0.0 - 1.0] coordinates.
class OcrBoundingBox {
  final double left;
  final double top;
  final double width;
  final double height;

  const OcrBoundingBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  double get right => left + width;
  double get bottom => top + height;

  Rect toRect() => Rect.fromLTWH(left, top, width, height);

  /// Scales normalized coordinates (0..1) to actual pixel dimensions.
  Rect toAbsoluteRect(Size size) {
    return Rect.fromLTWH(
      left * size.width,
      top * size.height,
      width * size.width,
      height * size.height,
    );
  }

  factory OcrBoundingBox.fromRect(Rect rect, {Size? pageSize}) {
    if (pageSize != null && pageSize.width > 0 && pageSize.height > 0) {
      return OcrBoundingBox(
        left: (rect.left / pageSize.width).clamp(0.0, 1.0),
        top: (rect.top / pageSize.height).clamp(0.0, 1.0),
        width: (rect.width / pageSize.width).clamp(0.0, 1.0),
        height: (rect.height / pageSize.height).clamp(0.0, 1.0),
      );
    }
    return OcrBoundingBox(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
    );
  }

  Map<String, dynamic> toJson() => {
    'left': left,
    'top': top,
    'width': width,
    'height': height,
  };

  factory OcrBoundingBox.fromJson(Map<String, dynamic> json) => OcrBoundingBox(
    left: (json['left'] as num).toDouble(),
    top: (json['top'] as num).toDouble(),
    width: (json['width'] as num).toDouble(),
    height: (json['height'] as num).toDouble(),
  );
}

/// Represents a recognized single word/token.
class OcrToken {
  final String text;
  final double confidence;
  final OcrBoundingBox boundingBox;
  final int pageIndex;

  const OcrToken({
    required this.text,
    required this.confidence,
    required this.boundingBox,
    required this.pageIndex,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'confidence': confidence,
    'boundingBox': boundingBox.toJson(),
    'pageIndex': pageIndex,
  };
}

/// Represents a recognized line of text.
class OcrLine {
  final String text;
  final double confidence;
  final OcrBoundingBox boundingBox;
  final int pageIndex;
  final List<OcrToken> tokens;

  const OcrLine({
    required this.text,
    required this.confidence,
    required this.boundingBox,
    required this.pageIndex,
    this.tokens = const [],
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'confidence': confidence,
    'boundingBox': boundingBox.toJson(),
    'pageIndex': pageIndex,
    'tokens': tokens.map((t) => t.toJson()).toList(),
  };
}

/// Represents a document page with its image and OCR elements.
class OcrPage {
  final int pageIndex;
  final String? imagePath;
  final Size pageSize;
  final List<OcrLine> lines;
  final double averageConfidence;

  const OcrPage({
    required this.pageIndex,
    this.imagePath,
    required this.pageSize,
    required this.lines,
    required this.averageConfidence,
  });

  String get fullText => lines.map((l) => l.text).join('\n');
}

/// Represents the full scanned document with multi-page structure.
class OcrDocument {
  final List<OcrPage> pages;
  final String rawText;
  final double overallConfidence;
  final DateTime scannedAt;

  const OcrDocument({
    required this.pages,
    required this.rawText,
    required this.overallConfidence,
    required this.scannedAt,
  });

  bool get isLowConfidence => overallConfidence < 0.65;
}
