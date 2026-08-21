import 'package:flutter/painting.dart' show Rect;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Scan type enum for filtering history
enum ScanType { ocr, qrCode, barcode, translation, billAnalysis }

/// Individual text line with its bounding box
class OcrLineItem {
  final String text;
  final Rect? boundingBox;
  OcrLineItem({required this.text, this.boundingBox});
}

/// Individual text block from OCR
class OcrBlock {
  final String text;
  final List<String> lines;
  final List<OcrLineItem> lineItems;
  /// Bounding box on the original image (in image-pixel coordinates).
  /// Null if not available (e.g. reconstructed from history).
  final Rect? boundingBox;

  OcrBlock({
    required this.text,
    required this.lines,
    this.lineItems = const [],
    this.boundingBox,
  });
}

/// Result of OCR on an image
class OcrResult {
  final String fullText;
  final List<OcrBlock> blocks;
  final String imagePath;
  final DateTime timestamp;

  OcrResult({
    required this.fullText,
    required this.blocks,
    required this.imagePath,
    required this.timestamp,
  });

  bool get isEmpty => fullText.trim().isEmpty;

  /// All individual line items across all blocks
  List<OcrLineItem> get allLines {
    final list = <OcrLineItem>[];
    for (final b in blocks) {
      if (b.lineItems.isNotEmpty) {
        list.addAll(b.lineItems);
      } else {
        for (final l in b.lines) {
          list.add(OcrLineItem(text: l, boundingBox: b.boundingBox));
        }
      }
    }
    return list;
  }

  /// Build from ML Kit RecognizedText — captures bounding boxes per block and per line.
  factory OcrResult.fromMlKit(RecognizedText recognized, String imagePath) {
    final blocks = recognized.blocks.map((b) {
      // Convert ML Kit boundingBox to Flutter Rect.
      final r = b.boundingBox;
      final rect = Rect.fromLTWH(
        r.left.toDouble(),
        r.top.toDouble(),
        r.width.toDouble(),
        r.height.toDouble(),
      );

      final lineItems = b.lines.map((l) {
        final lr = l.boundingBox;
        final lRect = Rect.fromLTWH(
          lr.left.toDouble(),
          lr.top.toDouble(),
          lr.width.toDouble(),
          lr.height.toDouble(),
        );
        return OcrLineItem(text: l.text, boundingBox: lRect);
      }).toList();

      return OcrBlock(
        text: b.text,
        lines: b.lines.map((l) => l.text).toList(),
        lineItems: lineItems,
        boundingBox: rect,
      );
    }).toList();

    return OcrResult(
      fullText: recognized.text,
      blocks: blocks,
      imagePath: imagePath,
      timestamp: DateTime.now(),
    );
  }
}

/// Result of a barcode / QR code scan
class BarcodeResult {
  final String rawValue;
  final String format; // e.g. "QR Code", "EAN-13"
  final String displayType; // e.g. "URL", "Text", "Phone", "Email", "Wi-Fi"
  final DateTime timestamp;
  final String? imagePath; // null if scanned live

  BarcodeResult({
    required this.rawValue,
    required this.format,
    required this.displayType,
    required this.timestamp,
    this.imagePath,
  });

  bool get isUrl {
    final lower = rawValue.trim().toLowerCase();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('www.') ||
        (lower.contains('.') &&
            !lower.contains(' ') &&
            (lower.endsWith('.com') ||
                lower.endsWith('.org') ||
                lower.endsWith('.net') ||
                lower.endsWith('.in') ||
                lower.endsWith('.io') ||
                lower.endsWith('.gov') ||
                lower.endsWith('.edu') ||
                lower.endsWith('.co')));
  }

  bool get isPhone =>
      rawValue.trim().toLowerCase().startsWith('tel:') ||
      (rawValue.trim().startsWith('+') && rawValue.trim().length >= 10);

  bool get isEmail =>
      rawValue.trim().toLowerCase().startsWith('mailto:') ||
      (rawValue.trim().contains('@') &&
          rawValue.trim().contains('.') &&
          !rawValue.trim().contains(' '));

  bool get isWifi => rawValue.trim().toUpperCase().startsWith('WIFI:');
  bool get isGeo => rawValue.trim().toLowerCase().startsWith('geo:');
  bool get isUpi => rawValue.trim().toLowerCase().startsWith('upi://');
}

/// A persisted history entry (serialisable to JSON for SharedPreferences)
class ScanHistoryItem {
  final String id;
  final ScanType type;
  final String title;
  final String summary;
  final DateTime timestamp;

  // OCR fields
  final String? ocrText;
  final String? imagePath;

  // Barcode fields
  final String? barcodeValue;
  final String? barcodeFormat;

  // Translation fields
  final String? translatedText;
  final String? sourceLang;
  final String? targetLang;

  ScanHistoryItem({
    required this.id,
    required this.type,
    required this.title,
    required this.summary,
    required this.timestamp,
    this.ocrText,
    this.imagePath,
    this.barcodeValue,
    this.barcodeFormat,
    this.translatedText,
    this.sourceLang,
    this.targetLang,
  });

  /// Icon label for the history tile
  String get typeLabel {
    switch (type) {
      case ScanType.ocr:
        return 'OCR';
      case ScanType.qrCode:
        return 'QR Code';
      case ScanType.barcode:
        return 'Barcode';
      case ScanType.translation:
        return 'Translation';
      case ScanType.billAnalysis:
        return 'Bill Analysis';
    }
  }

  // ── Serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'title': title,
        'summary': summary,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'ocrText': ocrText,
        'imagePath': imagePath,
        'barcodeValue': barcodeValue,
        'barcodeFormat': barcodeFormat,
        'translatedText': translatedText,
        'sourceLang': sourceLang,
        'targetLang': targetLang,
      };

  factory ScanHistoryItem.fromJson(Map<String, dynamic> json) {
    return ScanHistoryItem(
      id: json['id'] as String,
      type: ScanType.values[json['type'] as int],
      title: json['title'] as String,
      summary: json['summary'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      ocrText: json['ocrText'] as String?,
      imagePath: json['imagePath'] as String?,
      barcodeValue: json['barcodeValue'] as String?,
      barcodeFormat: json['barcodeFormat'] as String?,
      translatedText: json['translatedText'] as String?,
      sourceLang: json['sourceLang'] as String?,
      targetLang: json['targetLang'] as String?,
    );
  }

  // ── Factory helpers ────────────────────────────────────────────────────────

  factory ScanHistoryItem.fromOcr(OcrResult result) {
    final preview = result.fullText.length > 80
        ? '${result.fullText.substring(0, 77)}...'
        : result.fullText;
    return ScanHistoryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: ScanType.ocr,
      title: 'OCR Scan',
      summary: preview.isEmpty ? 'No text detected' : preview,
      timestamp: result.timestamp,
      ocrText: result.fullText,
      imagePath: result.imagePath,
    );
  }

  factory ScanHistoryItem.fromBarcode(BarcodeResult result) {
    return ScanHistoryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: result.format == 'QR Code' ? ScanType.qrCode : ScanType.barcode,
      title: '${result.format} Scan',
      summary: result.rawValue.length > 80
          ? '${result.rawValue.substring(0, 77)}...'
          : result.rawValue,
      timestamp: result.timestamp,
      barcodeValue: result.rawValue,
      barcodeFormat: result.format,
    );
  }

  factory ScanHistoryItem.fromTranslation({
    required String originalText,
    required String translatedText,
    required String sourceLang,
    required String targetLang,
  }) {
    final preview = originalText.length > 60
        ? '${originalText.substring(0, 57)}...'
        : originalText;
    return ScanHistoryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: ScanType.translation,
      title: '$sourceLang → $targetLang',
      summary: preview,
      timestamp: DateTime.now(),
      ocrText: originalText,
      translatedText: translatedText,
      sourceLang: sourceLang,
      targetLang: targetLang,
    );
  }
}
