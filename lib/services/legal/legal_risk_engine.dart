import '../../core/legal/models/document_anomaly.dart';
import '../../core/legal/models/legal_analysis_result.dart';
import '../../core/legal/models/legal_clause.dart';
import '../../core/legal/models/legal_finding.dart';
import '../../core/legal/models/ocr_document.dart';

class RiskEvaluation {
  final double overallScore; // 0..100
  final LegalRiskSeverity severity;
  final RiskBreakdown breakdown;

  const RiskEvaluation({
    required this.overallScore,
    required this.severity,
    required this.breakdown,
  });
}

class LegalRiskEngine {
  /// Calculates explainable, highly accurate multi-factor risk scores based on
  /// detected clauses, statutory invalidations, scams, and structural anomalies.
  RiskEvaluation evaluate(
    List<LegalFinding> findings,
    List<DocumentAnomaly> anomalies,
    OcrDocument doc,
  ) {
    if (findings.isEmpty && anomalies.isEmpty) {
      return const RiskEvaluation(
        overallScore: 5.0,
        severity: LegalRiskSeverity.safe,
        breakdown: RiskBreakdown(
          legalRisk: 0.0,
          financialRisk: 0.0,
          terminationRisk: 0.0,
          documentAnomalyRisk: 0.0,
        ),
      );
    }

    double legalRiskAccum = 0.0;
    double financialRiskAccum = 0.0;
    double terminationRiskAccum = 0.0;
    double anomalyRiskAccum = 0.0;

    for (final f in findings) {
      switch (f.clauseType) {
        // High severity statutory violations & void restraints
        case LegalClauseType.nonCompeteRestraint:
        case LegalClauseType.restraintOfLegalRecourse:
        case LegalClauseType.waiverOfRights:
          legalRiskAccum += 34.0;
          break;

        case LegalClauseType.arbitrationAndJurisdiction:
        case LegalClauseType.unilateralVariation:
        case LegalClauseType.confidentialityOverreach:
          legalRiskAccum += 18.0;
          break;

        // Scams, predatory rates, excessive liquidated damages
        case LegalClauseType.upfrontFeeScam:
          financialRiskAccum += 45.0; // Severe scam indicator
          break;

        case LegalClauseType.predatoryInterestRate:
        case LegalClauseType.penaltyAndDamages:
          financialRiskAccum += 28.0;
          break;

        case LegalClauseType.securityDepositForfeiture:
        case LegalClauseType.hiddenFeesAndCostShifting:
          financialRiskAccum += 22.0;
          break;

        // Termination & unilateral risk
        case LegalClauseType.unilateralTermination:
          terminationRiskAccum += 26.0;
          break;

        case LegalClauseType.unlimitedIndemnity:
          terminationRiskAccum += 30.0;
          break;

        case LegalClauseType.automaticRenewal:
          terminationRiskAccum += 16.0;
          break;

        default:
          legalRiskAccum += 10.0;
          break;
      }
    }

    for (final a in anomalies) {
      if (a.severity == AnomalySeverity.highSuspicion) {
        anomalyRiskAccum += 28.0;
      } else if (a.severity == AnomalySeverity.moderateSuspicion) {
        anomalyRiskAccum += 14.0;
      } else {
        anomalyRiskAccum += 6.0;
      }
    }

    if (doc.isLowConfidence) {
      anomalyRiskAccum += 12.0;
    }

    // Clamp category risks
    final clampedLegal = legalRiskAccum.clamp(0.0, 100.0);
    final clampedFinancial = financialRiskAccum.clamp(0.0, 100.0);
    final clampedTermination = terminationRiskAccum.clamp(0.0, 100.0);
    final clampedAnomaly = anomalyRiskAccum.clamp(0.0, 100.0);

    // Calculate dynamic weighted raw score
    // Financial (scams/penalties): 35%, Legal (void restraints): 30%, Termination: 20%, Anomaly: 15%
    double weightedScore = (clampedFinancial * 0.35) +
        (clampedLegal * 0.30) +
        (clampedTermination * 0.20) +
        (clampedAnomaly * 0.15);

    // Cumulative clause impact: each additional finding adds compound risk
    final highCount = findings.where((f) => f.severity == LegalRiskSeverity.high).length;
    final mediumCount = findings.where((f) => f.severity == LegalRiskSeverity.medium).length;
    final hasScam = findings.any((f) => f.clauseType == LegalClauseType.upfrontFeeScam);

    double compositeScore;
    if (hasScam) {
      // Direct high scam score (88 - 98%)
      compositeScore = 88.0 + (highCount * 3.0) + (anomalies.length * 2.0);
    } else if (highCount >= 3) {
      compositeScore = 78.0 + (highCount * 4.0) + (mediumCount * 2.0);
    } else if (highCount >= 1) {
      compositeScore = 52.0 + (highCount * 10.0) + (weightedScore * 0.25) + (mediumCount * 4.0);
    } else if (mediumCount > 0) {
      compositeScore = 24.0 + (mediumCount * 8.0) + (weightedScore * 0.2);
    } else {
      compositeScore = weightedScore;
    }

    final finalScore = compositeScore.clamp(0.0, 100.0).roundToDouble();

    LegalRiskSeverity severity;
    if (finalScore >= 60.0) {
      severity = LegalRiskSeverity.high;
    } else if (finalScore >= 30.0) {
      severity = LegalRiskSeverity.medium;
    } else if (finalScore > 10.0) {
      severity = LegalRiskSeverity.low;
    } else {
      severity = LegalRiskSeverity.safe;
    }

    return RiskEvaluation(
      overallScore: finalScore,
      severity: severity,
      breakdown: RiskBreakdown(
        legalRisk: clampedLegal,
        financialRisk: clampedFinancial,
        terminationRisk: clampedTermination,
        documentAnomalyRisk: clampedAnomaly,
      ),
    );
  }
}
