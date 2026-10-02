import 'dart:ui';
import 'document_highlight.dart';
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

  final String? clauseId; // e.g. clause_001
  final int? startOffset;
  final int? endOffset;
  final int scoreContribution;
  final String? category;
  final String? evidence;
  final DocumentHighlight? highlight;

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
    this.clauseId,
    this.startOffset,
    this.endOffset,
    this.scoreContribution = 0,
    this.category,
    this.evidence,
    this.highlight,
  });

  LegalFinding copyWith({
    String? id,
    LegalClauseType? clauseType,
    LegalRiskSeverity? severity,
    String? title,
    String? simpleExplanation,
    String? legalExplanation,
    String? rawExcerpt,
    int? pageIndex,
    OcrBoundingBox? boundingBox,
    List<StatutoryCitation>? statutoryBasis,
    String? recommendedAction,
    double? confidence,
    String? clauseId,
    int? startOffset,
    int? endOffset,
    int? scoreContribution,
    String? category,
    String? evidence,
    DocumentHighlight? highlight,
  }) {
    return LegalFinding(
      id: id ?? this.id,
      clauseType: clauseType ?? this.clauseType,
      severity: severity ?? this.severity,
      title: title ?? this.title,
      simpleExplanation: simpleExplanation ?? this.simpleExplanation,
      legalExplanation: legalExplanation ?? this.legalExplanation,
      rawExcerpt: rawExcerpt ?? this.rawExcerpt,
      pageIndex: pageIndex ?? this.pageIndex,
      boundingBox: boundingBox ?? this.boundingBox,
      statutoryBasis: statutoryBasis ?? this.statutoryBasis,
      recommendedAction: recommendedAction ?? this.recommendedAction,
      confidence: confidence ?? this.confidence,
      clauseId: clauseId ?? this.clauseId,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      scoreContribution: scoreContribution ?? this.scoreContribution,
      category: category ?? this.category,
      evidence: evidence ?? this.evidence,
      highlight: highlight ?? this.highlight,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'clauseId': clauseId,
    'clauseType': clauseType.name,
    'severity': severity.name,
    'title': title,
    'simpleExplanation': simpleExplanation,
    'legalExplanation': legalExplanation,
    'rawExcerpt': rawExcerpt,
    'pageIndex': pageIndex,
    'startOffset': startOffset,
    'endOffset': endOffset,
    'scoreContribution': scoreContribution,
    'category': category,
    'evidence': evidence ?? rawExcerpt,
    'boundingBox': boundingBox?.toJson(),
    'highlight': highlight?.toJson(),
    'statutoryBasis': statutoryBasis.map((s) => s.toJson()).toList(),
    'recommendedAction': recommendedAction,
    'confidence': confidence,
  };

  factory LegalFinding.fromJson(Map<String, dynamic> json) {
    LegalClauseType clauseType = LegalClauseType.generalObligation;
    final typeStr = json['clauseType']?.toString() ?? json['clause_type']?.toString();
    if (typeStr != null) {
      for (final t in LegalClauseType.values) {
        if (t.name.toLowerCase() == typeStr.toLowerCase()) {
          clauseType = t;
          break;
        }
      }
    }

    LegalRiskSeverity severity = LegalRiskSeverity.medium;
    final sevStr = json['severity']?.toString().toLowerCase();
    if (sevStr == 'high' || sevStr == 'critical') {
      severity = LegalRiskSeverity.high;
    } else if (sevStr == 'low') {
      severity = LegalRiskSeverity.low;
    } else if (sevStr == 'safe') {
      severity = LegalRiskSeverity.safe;
    }

    final citations = <StatutoryCitation>[];
    final basisList = json['statutoryBasis'] ?? json['statutory_references'] ?? json['legalReferences'];
    if (basisList is List) {
      for (final item in basisList) {
        if (item is Map<String, dynamic>) {
          citations.add(StatutoryCitation.fromJson(item));
        } else if (item is Map) {
          citations.add(StatutoryCitation.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    final excerpt = json['rawExcerpt']?.toString() ??
        json['raw_excerpt']?.toString() ??
        json['excerpt']?.toString() ??
        '';

    return LegalFinding(
      id: json['id']?.toString() ?? 'finding_auto',
      clauseId: json['clauseId']?.toString() ?? json['clause_id']?.toString(),
      clauseType: clauseType,
      severity: severity,
      title: json['title']?.toString() ?? 'Potential Risk Detected',
      simpleExplanation: json['simpleExplanation']?.toString() ??
          json['simple_explanation']?.toString() ??
          json['explanation']?.toString() ??
          '',
      legalExplanation: json['legalExplanation']?.toString() ??
          json['legal_explanation']?.toString() ??
          '',
      rawExcerpt: excerpt,
      evidence: json['evidence']?.toString() ?? excerpt,
      pageIndex: (json['pageIndex'] as num?)?.toInt() ?? (json['page_index'] as num?)?.toInt() ?? 0,
      startOffset: (json['startOffset'] as num?)?.toInt() ?? (json['start_offset'] as num?)?.toInt(),
      endOffset: (json['endOffset'] as num?)?.toInt() ?? (json['end_offset'] as num?)?.toInt(),
      scoreContribution: (json['scoreContribution'] as num?)?.toInt() ??
          (json['score_contribution'] as num?)?.toInt() ??
          0,
      category: json['category']?.toString(),
      boundingBox: json['boundingBox'] != null
          ? OcrBoundingBox.fromJson(Map<String, dynamic>.from(json['boundingBox'] as Map))
          : null,
      statutoryBasis: citations,
      recommendedAction: json['recommendedAction']?.toString() ??
          json['recommended_action']?.toString() ??
          'Review this term before signing.',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.85,
      highlight: json['highlight'] != null
          ? DocumentHighlight.fromJson(Map<String, dynamic>.from(json['highlight'] as Map))
          : null,
    );
  }
}
