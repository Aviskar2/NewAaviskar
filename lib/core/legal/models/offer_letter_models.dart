/// Models for Offer Letter Extraction and Comparison under Indian Employment Law.

enum OfferChoice {
  offerA, // Previous / Current
  offerB, // New Offer
  neutral,
}

enum OfferWinner {
  offerA, // Previous is safer/better
  offerB, // New is more beneficial
  conditional, // New is financially better but has predatory clauses needing negotiation
}

extension OfferWinnerExt on OfferWinner {
  String get displayName {
    switch (this) {
      case OfferWinner.offerB:
        return 'New Offer is More Beneficial';
      case OfferWinner.offerA:
        return 'Previous Offer is More Favorable';
      case OfferWinner.conditional:
        return 'New Offer Conditionally Better (Negotiation Advised)';
    }
  }

  String get shortBadge {
    switch (this) {
      case OfferWinner.offerB:
        return 'NEW OFFER RECOMMENDED';
      case OfferWinner.offerA:
        return 'PREVIOUS OFFER SAFER';
      case OfferWinner.conditional:
        return 'PROCEED WITH NEGOTIATION';
    }
  }
}

/// Extracted attributes from an employment offer letter.
class OfferLetterDetails {
  final String companyName;
  final String jobTitle;
  final double? ctcTotal; // In LPA (e.g. 18.5)
  final String ctcDisplay;
  final String fixedSalaryDisplay;
  final String variableBonusDisplay;
  final String? joiningBonus;
  final String? esops;
  final String? retirals;
  final int noticePeriodDays;
  final String noticePeriodDisplay;
  final int? probationMonths;
  final int bondPeriodMonths;
  final double? bondPenalty;
  final String bondDisplay;
  final int nonCompetePeriodMonths;
  final String nonCompeteDisplay;
  final String workMode;
  final int? annualLeaves;
  final String? healthInsuranceCover;
  final List<String> redFlags;
  final List<String> positiveHighlights;
  final String rawText;

  const OfferLetterDetails({
    required this.companyName,
    required this.jobTitle,
    this.ctcTotal,
    required this.ctcDisplay,
    required this.fixedSalaryDisplay,
    required this.variableBonusDisplay,
    this.joiningBonus,
    this.esops,
    this.retirals,
    this.noticePeriodDays = 30,
    required this.noticePeriodDisplay,
    this.probationMonths,
    this.bondPeriodMonths = 0,
    this.bondPenalty,
    required this.bondDisplay,
    this.nonCompetePeriodMonths = 0,
    required this.nonCompeteDisplay,
    required this.workMode,
    this.annualLeaves,
    this.healthInsuranceCover,
    this.redFlags = const [],
    this.positiveHighlights = const [],
    required this.rawText,
  });

  bool get hasBond => bondPeriodMonths > 0 || (bondPenalty != null && bondPenalty! > 0);
  bool get hasNonCompete => nonCompetePeriodMonths > 0;
  bool get hasLongNotice => noticePeriodDays >= 60;
}

/// Head-to-head metric item for side-by-side comparison.
class MetricComparison {
  final String category;
  final String metricTitle;
  final String valueA; // Previous Offer
  final String valueB; // New Offer
  final OfferChoice favorable;
  final String significance; // 'Critical', 'Important', 'Informational'
  final String explanation;

  const MetricComparison({
    required this.category,
    required this.metricTitle,
    required this.valueA,
    required this.valueB,
    required this.favorable,
    required this.significance,
    required this.explanation,
  });
}

/// Comprehensive comparison analysis between two employment offers.
class OfferComparisonResult {
  final OfferLetterDetails offerA; // Previous / Current
  final OfferLetterDetails offerB; // New
  final OfferWinner winner;
  final String winnerTitle;
  final String verdictSummary;
  final double scoreA; // 0..100
  final double scoreB; // 0..100
  final double financialScoreA;
  final double financialScoreB;
  final double legalFreedomScoreA;
  final double legalFreedomScoreB;
  final double workLifeScoreA;
  final double workLifeScoreB;
  final double benefitsScoreA;
  final double benefitsScoreB;
  final List<MetricComparison> comparisons;
  final List<String> keyAdvantagesNew;
  final List<String> keyRisksNew;
  final List<String> negotiationActionItems;
  final String legalAdvisory;
  final bool analyzedWithAi;
  final String? aiModelUsed;
  final DateTime analyzedAt;

  const OfferComparisonResult({
    required this.offerA,
    required this.offerB,
    required this.winner,
    required this.winnerTitle,
    required this.verdictSummary,
    required this.scoreA,
    required this.scoreB,
    required this.financialScoreA,
    required this.financialScoreB,
    required this.legalFreedomScoreA,
    required this.legalFreedomScoreB,
    required this.workLifeScoreA,
    required this.workLifeScoreB,
    required this.benefitsScoreA,
    required this.benefitsScoreB,
    required this.comparisons,
    required this.keyAdvantagesNew,
    required this.keyRisksNew,
    required this.negotiationActionItems,
    required this.legalAdvisory,
    this.analyzedWithAi = false,
    this.aiModelUsed,
    required this.analyzedAt,
  });

  /// The point difference between New (B) and Previous (A)
  double get scoreDelta => scoreB - scoreA;
}
