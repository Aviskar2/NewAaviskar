enum AnomalyCategory {
  dateInconsistency,
  partyMismatch,
  amountDiscrepancy,
  missingStandardClause,
  abnormalFormattingOrFont,
  missingSignaturesOrStamps,
  invalidLegalReference,
  unusualJurisdiction,
}

extension AnomalyCategoryExt on AnomalyCategory {
  String get displayName {
    switch (this) {
      case AnomalyCategory.dateInconsistency: return 'Date Discrepancy';
      case AnomalyCategory.partyMismatch: return 'Party Name Mismatch';
      case AnomalyCategory.amountDiscrepancy: return 'Amount Mismatch';
      case AnomalyCategory.missingStandardClause: return 'Missing Standard Protection';
      case AnomalyCategory.abnormalFormattingOrFont: return 'Formatting Discrepancy';
      case AnomalyCategory.missingSignaturesOrStamps: return 'Missing Stamp / Signature';
      case AnomalyCategory.invalidLegalReference: return 'Invalid Statutory Citation';
      case AnomalyCategory.unusualJurisdiction: return 'Unusual Foreign Jurisdiction';
    }
  }

  String get icon {
    switch (this) {
      case AnomalyCategory.dateInconsistency: return '📅';
      case AnomalyCategory.partyMismatch: return '👥';
      case AnomalyCategory.amountDiscrepancy: return '💵';
      case AnomalyCategory.missingStandardClause: return '🛡️';
      case AnomalyCategory.abnormalFormattingOrFont: return '📝';
      case AnomalyCategory.missingSignaturesOrStamps: return '🖋️';
      case AnomalyCategory.invalidLegalReference: return '⚖️';
      case AnomalyCategory.unusualJurisdiction: return '🌐';
    }
  }
}

enum AnomalySeverity {
  highSuspicion,
  moderateSuspicion,
  advisory,
}

extension AnomalySeverityExt on AnomalySeverity {
  String get displayName {
    switch (this) {
      case AnomalySeverity.highSuspicion: return 'High Suspicion';
      case AnomalySeverity.moderateSuspicion: return 'Moderate Suspicion';
      case AnomalySeverity.advisory: return 'Advisory Note';
    }
  }

  String get emoji {
    switch (this) {
      case AnomalySeverity.highSuspicion: return '🚨';
      case AnomalySeverity.moderateSuspicion: return '⚠️';
      case AnomalySeverity.advisory: return 'ℹ️';
    }
  }
}

/// Represents structural, chronological, or formatting inconsistencies in legal documents.
class DocumentAnomaly {
  final String id;
  final AnomalyCategory category;
  final AnomalySeverity severity;
  final String title;
  final String explanation;
  final String evidence;
  final String verificationTip;
  final int? pageIndex;

  const DocumentAnomaly({
    required this.id,
    required this.category,
    required this.severity,
    required this.title,
    required this.explanation,
    required this.evidence,
    required this.verificationTip,
    this.pageIndex,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category.name,
    'severity': severity.name,
    'title': title,
    'explanation': explanation,
    'evidence': evidence,
    'verificationTip': verificationTip,
    'pageIndex': pageIndex,
  };
}
