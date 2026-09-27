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

  bool get isModernLaw {
    final lower = actName.toLowerCase();
    return lower.contains('2024') ||
        lower.contains('2023') ||
        lower.contains('2021') ||
        lower.contains('2019') ||
        lower.contains('2016') ||
        lower.contains('bharatiya') ||
        lower.contains('model tenancy') ||
        lower.contains('data protection');
  }

  String get statusBadgeText {
    final lower = actName.toLowerCase();
    if (lower.contains('bharatiya') || lower.contains('2024') || lower.contains('2023')) {
      return '⚡ Active 2024 Law in Force';
    } else if (lower.contains('model tenancy') || lower.contains('2021')) {
      return '🏛️ Modern Tenancy Standard';
    } else if (lower.contains('consumer protection') || lower.contains('2019')) {
      return '⚖️ Active Consumer Standard';
    } else if (lower.contains('rera') || lower.contains('2016')) {
      return '🏢 Active RERA Mandate';
    } else if (lower.contains('arbitration')) {
      return '⚖️ Active Arbitration Standard (2015/2019)';
    } else if (lower.contains('contract')) {
      return '📜 Substantive Law (In Force)';
    }
    return '📜 Enforceable Indian Statute';
  }

  Map<String, dynamic> toJson() => {
    'actName': actName,
    'section': section,
    'title': title,
    'description': description,
    'officialSourceUrl': officialSourceUrl,
    'isEnforceableInIndia': isEnforceableInIndia,
  };

  factory StatutoryCitation.fromJson(Map<String, dynamic> json) => StatutoryCitation(
    actName: json['actName'] as String? ?? 'Indian Statute',
    section: json['section'] as String? ?? '',
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    officialSourceUrl: json['officialSourceUrl'] as String?,
    isEnforceableInIndia: json['isEnforceableInIndia'] as bool? ?? true,
  );
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

  /// Returns the primary/latest active running statute this finding is compared against
  StatutoryCitation? get primaryStatute => statutoryBasis.isNotEmpty ? statutoryBasis.first : null;

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
