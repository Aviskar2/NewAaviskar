import 'dart:ui';
import 'legal_clause.dart';
import 'ocr_document.dart';

enum LegalRiskSeverity {
  high,
  medium,
  low,
  safe,
}

extension LegalRiskSeverityExt on LegalRiskSeverity {
  String get displayName {
    switch (this) {
      case LegalRiskSeverity.high: return 'High Risk';
      case LegalRiskSeverity.medium: return 'Medium Risk';
      case LegalRiskSeverity.low: return 'Low Risk';
      case LegalRiskSeverity.safe: return 'Standard / Safe';
    }
  }

  String get emoji {
    switch (this) {
      case LegalRiskSeverity.high: return '🔴';
      case LegalRiskSeverity.medium: return '🟠';
      case LegalRiskSeverity.low: return '🟡';
      case LegalRiskSeverity.safe: return '🟢';
    }
  }

  Color get color {
    switch (this) {
      case LegalRiskSeverity.high: return const Color(0xFFDC2626); // Red
      case LegalRiskSeverity.medium: return const Color(0xFFEA580C); // Orange
      case LegalRiskSeverity.low: return const Color(0xFFD97706); // Amber
      case LegalRiskSeverity.safe: return const Color(0xFF16A34A); // Green
    }
  }
}

/// Official Indian legislative provision reference.
class StatutoryCitation {
  final String actName;
  final String section;
  final String title;
  final String description;
  final String? officialSourceUrl;
  final bool isEnforceableInIndia;

  const StatutoryCitation({
    required this.actName,
    required this.section,
    required this.title,
    required this.description,
    this.officialSourceUrl,
    this.isEnforceableInIndia = true,
  });

  Map<String, dynamic> toJson() => {
    'actName': actName,
    'section': section,
    'title': title,
    'description': description,
    'officialSourceUrl': officialSourceUrl,
    'isEnforceableInIndia': isEnforceableInIndia,
  };
}

/// A structured finding representing a dangerous or noteworthy clause detected in the document.
class LegalFinding {
  final String id;
  final LegalClauseType clauseType;
  final LegalRiskSeverity severity;
  final String title;
  final String simpleExplanation;
  final String legalExplanation;
  final String rawExcerpt;
  final int pageIndex;
  final OcrBoundingBox? boundingBox;
  final List<StatutoryCitation> statutoryBasis;
  final String recommendedAction;
  final double confidence;

  const LegalFinding({
    required this.id,
    required this.clauseType,
    required this.severity,
    required this.title,
    required this.simpleExplanation,
    required this.legalExplanation,
    required this.rawExcerpt,
    required this.pageIndex,
    this.boundingBox,
    this.statutoryBasis = const [],
    required this.recommendedAction,
    this.confidence = 0.90,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'clauseType': clauseType.name,
    'severity': severity.name,
    'title': title,
    'simpleExplanation': simpleExplanation,
    'legalExplanation': legalExplanation,
    'rawExcerpt': rawExcerpt,
    'pageIndex': pageIndex,
    'boundingBox': boundingBox?.toJson(),
    'statutoryBasis': statutoryBasis.map((s) => s.toJson()).toList(),
    'recommendedAction': recommendedAction,
    'confidence': confidence,
  };
}
