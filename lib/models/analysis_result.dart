/// Bill analysis result models.
/// Contains findings, GSTIN verification, government sources.

import 'bill_model.dart';

// ─── Severity ────────────────────────────────────────────────────────────────

enum FindingSeverity {
  ok,       // ✅ Correct
  verify,   // ⚠️ Needs verification
  suspicious, // 🚨 Suspicious
  error,    // ❌ Mathematical / format error
}

extension FindingSeverityLabel on FindingSeverity {
  String get emoji {
    switch (this) {
      case FindingSeverity.ok: return '✅';
      case FindingSeverity.verify: return '⚠️';
      case FindingSeverity.suspicious: return '🚨';
      case FindingSeverity.error: return '❌';
    }
  }

  String get label {
    switch (this) {
      case FindingSeverity.ok: return 'Correct';
      case FindingSeverity.verify: return 'Needs Verification';
      case FindingSeverity.suspicious: return 'Suspicious';
      case FindingSeverity.error: return 'Error';
    }
  }
}

// ─── Government Source ────────────────────────────────────────────────────────

enum SourceVerificationStatus { live, cached, unverified }

class GovernmentSource {
  final String title;
  final String description;
  final String url;
  final String organization;
  final String? effectiveDate;
  final DateTime lastVerified;
  final SourceVerificationStatus status;
  final double confidence; // 0.0–1.0

  const GovernmentSource({
    required this.title,
    required this.description,
    required this.url,
    required this.organization,
    this.effectiveDate,
    required this.lastVerified,
    this.status = SourceVerificationStatus.cached,
    this.confidence = 0.9,
  });

  String get statusLabel {
    switch (status) {
      case SourceVerificationStatus.live: return '🟢 LIVE';
      case SourceVerificationStatus.cached: return '🟡 CACHED';
      case SourceVerificationStatus.unverified: return '⚪ UNVERIFIED';
    }
  }
}

// ─── GSTIN Verification ───────────────────────────────────────────────────────

enum GstinStatus { valid, invalid, formatError, verificationFailed, notChecked }

class GstinVerification {
  final String gstin;
  final GstinStatus status;
  final String? legalName;
  final String? tradeName;
  final String? registrationStatus;
  final String? registrationDate;
  final String? stateCode;
  final bool? stateMatchesBill;
  final bool nameMatchesSeller;
  final String? errorMessage;
  final bool isLiveVerified;

  const GstinVerification({
    required this.gstin,
    required this.status,
    this.legalName,
    this.tradeName,
    this.registrationStatus,
    this.registrationDate,
    this.stateCode,
    this.stateMatchesBill,
    this.nameMatchesSeller = false,
    this.errorMessage,
    this.isLiveVerified = false,
  });

  String get emoji {
    switch (status) {
      case GstinStatus.valid: return '✅';
      case GstinStatus.invalid: return '❌';
      case GstinStatus.formatError: return '❌';
      case GstinStatus.verificationFailed: return '⚠️';
      case GstinStatus.notChecked: return '⚪';
    }
  }

  String get statusText {
    switch (status) {
      case GstinStatus.valid: return 'GSTIN appears valid';
      case GstinStatus.invalid: return 'GSTIN invalid';
      case GstinStatus.formatError: return 'GSTIN format error';
      case GstinStatus.verificationFailed: return 'Could not verify online';
      case GstinStatus.notChecked: return 'Not checked';
    }
  }
}

// ─── Individual Finding ───────────────────────────────────────────────────────

class AnalysisFinding {
  final String id;
  final FindingSeverity severity;
  final String title;
  final String explanation;       // plain language
  final String? whatFound;
  final String? whatExpected;
  final double? difference;       // monetary difference if applicable
  final String? recommendation;   // what the consumer should do
  final GovernmentSource? source;
  final String category;          // 'GST', 'Service Charge', 'Arithmetic', 'GSTIN', 'QR', 'Item'
  final String? relatedItemName;

  const AnalysisFinding({
    required this.id,
    required this.severity,
    required this.title,
    required this.explanation,
    this.whatFound,
    this.whatExpected,
    this.difference,
    this.recommendation,
    this.source,
    required this.category,
    this.relatedItemName,
  });
}

// ─── Item-level Analysis ──────────────────────────────────────────────────────

class ItemAnalysisResult {
  final BillItem item;
  final double? expectedTax;
  final double? printedTax;
  final double? taxDifference;
  final FindingSeverity status;
  final String? note;

  const ItemAnalysisResult({
    required this.item,
    this.expectedTax,
    this.printedTax,
    this.taxDifference,
    required this.status,
    this.note,
  });
}

// ─── Overall Bill Analysis Result ─────────────────────────────────────────────

enum OverallResult { looksCorrect, needsVerification, suspiciousCharges }

class BillAnalysisResult {
  final StructuredBill bill;
  final OverallResult overallResult;

  // Monetary summary
  final double? printedTotal;
  final double? computedTotal;
  final double? totalDiscrepancy;
  final double? potentialExcess;

  // Findings grouped by severity
  final List<AnalysisFinding> findings;

  // Item-level
  final List<ItemAnalysisResult> itemResults;

  // GSTIN
  final GstinVerification? gstinVerification;

  // Government sources referenced
  final List<GovernmentSource> sources;

  // Timestamps
  final DateTime analyzedAt;

  // Is online verification available?
  final bool isOnlineVerified;

  const BillAnalysisResult({
    required this.bill,
    required this.overallResult,
    this.printedTotal,
    this.computedTotal,
    this.totalDiscrepancy,
    this.potentialExcess,
    required this.findings,
    required this.itemResults,
    this.gstinVerification,
    required this.sources,
    required this.analyzedAt,
    this.isOnlineVerified = false,
  });

  List<AnalysisFinding> get okFindings =>
      findings.where((f) => f.severity == FindingSeverity.ok).toList();

  List<AnalysisFinding> get verifyFindings =>
      findings.where((f) => f.severity == FindingSeverity.verify).toList();

  List<AnalysisFinding> get suspiciousFindings =>
      findings.where((f) => f.severity == FindingSeverity.suspicious).toList();

  List<AnalysisFinding> get errorFindings =>
      findings.where((f) => f.severity == FindingSeverity.error).toList();

  String get overallEmoji {
    switch (overallResult) {
      case OverallResult.looksCorrect: return '✅';
      case OverallResult.needsVerification: return '⚠️';
      case OverallResult.suspiciousCharges: return '🚨';
    }
  }

  String get overallLabel {
    switch (overallResult) {
      case OverallResult.looksCorrect: return 'LOOKS CORRECT';
      case OverallResult.needsVerification: return 'NEEDS VERIFICATION';
      case OverallResult.suspiciousCharges: return 'SUSPICIOUS CHARGES FOUND';
    }
  }
}
