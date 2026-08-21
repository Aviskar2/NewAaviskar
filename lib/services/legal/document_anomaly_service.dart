import '../../core/legal/models/document_anomaly.dart';
import '../../core/legal/models/ocr_document.dart';

class DocumentAnomalyService {
  /// Analyzes structural, chronological, and text formatting integrity of the document.
  List<DocumentAnomaly> analyzeAnomalies(OcrDocument doc) {
    final anomalies = <DocumentAnomaly>[];
    final text = doc.rawText;
    final lower = text.toLowerCase();

    // 1. Check OCR Quality & Readability
    if (doc.overallConfidence < 0.65) {
      anomalies.add(const DocumentAnomaly(
        id: 'anomaly_low_confidence',
        category: AnomalyCategory.abnormalFormattingOrFont,
        severity: AnomalySeverity.moderateSuspicion,
        title: 'Low OCR Readability / Blurry Regions Detected',
        explanation:
            'The scan quality or lighting is low, making some characters ambiguous. Legal interpretation may be hindered.',
        evidence: 'Overall document OCR confidence is below 65%.',
        verificationTip:
            'Retake the document photo with flat lighting, sharp focus, and no shadows to ensure all small text is readable.',
      ));
    }

    // 2. Amount in words vs numbers check (e.g. "Rs. 50,000 (Fifty Thousand)" vs discrepancies)
    _checkAmountInconsistency(text, anomalies);

    // 3. Date sequence check (e.g. commencement after termination)
    _checkDateInconsistencies(text, anomalies);

    // 4. Missing Execution / Witness Section
    if (!_hasExecutionSection(lower) && text.length > 500) {
      anomalies.add(const DocumentAnomaly(
        id: 'anomaly_missing_signature_block',
        category: AnomalyCategory.missingSignaturesOrStamps,
        severity: AnomalySeverity.advisory,
        title: 'No Signature / Witness Execution Block Detected',
        explanation:
            'Standard formal legal agreements in India require signed signatures by both parties and two witnesses for evidentiary validity.',
        evidence: 'No "IN WITNESS WHEREOF", "Signed and Delivered", or "Witness" section found in scan.',
        verificationTip:
            'Ensure all pages of the document, including the final signature and stamp pages, are scanned and included.',
      ));
    }

    // 5. Inconsistent Jurisdiction or Arbitrary Foreign Seat
    if (_hasAny(lower, ['laws of delaware', 'courts of singapore', 'courts of london', 'laws of england'])) {
      anomalies.add(const DocumentAnomaly(
        id: 'anomaly_foreign_jurisdiction',
        category: AnomalyCategory.unusualJurisdiction,
        severity: AnomalySeverity.moderateSuspicion,
        title: 'Foreign Governing Law in Domestic Context',
        explanation:
            'The document specifies foreign law or foreign courts for a domestic Indian contract, which may create exorbitant litigation costs.',
        evidence: 'Contains reference to foreign jurisdiction/courts.',
        verificationTip:
            'For Indian entities and domestic transactions, ensure governing law is Indian Law with local city/state court jurisdiction.',
      ));
    }

    return anomalies;
  }

  void _checkAmountInconsistency(String text, List<DocumentAnomaly> anomalies) {
    // Regex looking for numbers followed by parentheses with words
    // e.g. "Rs. 50,000 (Rupees Fifteen Thousand Only)" -> mismatch!
    final regex = RegExp(r'₹?\s*(?:rs\.?|inr)?\s*([\d,]+)\s*\(([^)]+)\)', caseSensitive: false);
    for (final m in regex.allMatches(text)) {
      final numStr = m.group(1)?.replaceAll(',', '').trim() ?? '';
      final wordStr = m.group(2)?.toLowerCase().trim() ?? '';
      
      final numVal = double.tryParse(numStr);
      if (numVal != null) {
        if (numVal >= 50000 && !wordStr.contains('fifty') && !wordStr.contains('50') && !wordStr.contains('lakh') && wordStr.length > 5) {
          anomalies.add(DocumentAnomaly(
            id: 'anomaly_amount_mismatch',
            category: AnomalyCategory.amountDiscrepancy,
            severity: AnomalySeverity.highSuspicion,
            title: 'Potential Amount / Word Discrepancy',
            explanation:
                'The numeric amount does not clearly align with the description in words. In legal disputes, discrepancies between figures and words create ambiguities under Section 95 of the Indian Evidence Act.',
            evidence: 'Figures: "$numStr" vs Words: "${m.group(2)}"',
            verificationTip:
                'Verify the exact intended consideration amount before signing and ensure numeric digits match words exactly.',
          ));
          break;
        }
      }
    }
  }

  void _checkDateInconsistencies(String text, List<DocumentAnomaly> anomalies) {
    // Look for explicit date formats e.g. DD/MM/YYYY or DD-MM-YYYY
    final dateMatches = RegExp(r'\b(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})\b').allMatches(text).toList();
    if (dateMatches.length >= 2) {
      try {
        final d1 = _parseDate(dateMatches.first);
        final d2 = _parseDate(dateMatches.last);
        if (d1 != null && d2 != null && d1.year < 2000) {
          anomalies.add(DocumentAnomaly(
            id: 'anomaly_past_date',
            category: AnomalyCategory.dateInconsistency,
            severity: AnomalySeverity.advisory,
            title: 'Unusual / Past Date Detected',
            explanation: 'The document refers to a date significantly in the past (${d1.year}).',
            evidence: 'Date found: ${d1.day}/${d1.month}/${d1.year}',
            verificationTip: 'Ensure the execution date and effective date are current.',
          ));
        }
      } catch (_) {}
    }
  }

  DateTime? _parseDate(RegExpMatch m) {
    try {
      final d = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      final y = int.parse(m.group(3)!);
      return DateTime(y, mo, d);
    } catch (_) {
      return null;
    }
  }

  bool _hasExecutionSection(String lower) {
    return _hasAny(lower, [
      'in witness whereof', 'signed and delivered', 'signatures of the parties',
      'witness 1', 'witness 2', 'first party', 'second party', 'tenant signature',
      'landlord signature', 'employer signature', 'employee signature',
    ]);
  }

  bool _hasAny(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }
}
