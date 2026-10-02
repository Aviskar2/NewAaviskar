import 'dart:math' as math;
import '../../../core/legal/models/document_analysis_status.dart';
import '../../../core/legal/models/document_anomaly.dart';
import '../../../core/legal/models/legal_analysis_result.dart';
import '../../../core/legal/models/legal_clause.dart';
import '../../../core/legal/models/legal_document_type.dart';
import '../../../core/legal/models/legal_finding.dart';
import '../../../core/legal/models/ocr_document.dart';

/// Detailed result of evidence-based risk evaluation.
class CalculatedRiskEvaluation {
  final double overallScore; // 0..100
  final LegalRiskSeverity severity;
  final RiskBreakdown breakdown;
  final DocumentAnalysisConfidence confidence;
  final DocumentAnalysisStatus status;
  final List<LegalFinding> acceptedFindings;
  final List<LegalFinding> rejectedFindings;
  final String statusExplanation;

  const CalculatedRiskEvaluation({
    required this.overallScore,
    required this.severity,
    required this.breakdown,
    required this.confidence,
    required this.status,
    required this.acceptedFindings,
    required this.rejectedFindings,
    required this.statusExplanation,
  });
}

/// Step 8 & 9 & Sections 39, 40, 41, 42 of Document Analysis Pipeline.
///
/// Computes an evidence-based risk score (0-100) strictly from validated findings,
/// eliminating all hardcoded ~90% scores and fixed heuristics.
///
/// Scoring Framework:
/// - Low severity finding: +5 to +15
/// - Medium severity finding: +15 to +30
/// - High severity finding: +25 to +40
/// - Critical/Scam finding: +35 to +50
///
/// Modifiers:
/// - Finding confidence weighting
/// - Duplicate finding suppression
/// - Evidence length and relevance validation
/// - Harmless / benign context detection (Test 10)
/// - Diminishing marginal returns aggregation capped at 100
class DocumentRiskScoringEngine {
  /// Evaluates risk score and confidence from findings and document properties.
  CalculatedRiskEvaluation evaluate({
    required List<LegalFinding> rawFindings,
    required List<DocumentAnomaly> rawAnomalies,
    required OcrDocument doc,
    double ocrQualityScore = 0.90,
    LegalDocumentType docType = LegalDocumentType.otherOrUnknown,
  }) {
    // 1. Evidence-First Validation (Section 42):
    // Reject any finding that lacks a valid excerpt or explanation
    final acceptedFindings = <LegalFinding>[];
    final rejectedFindings = <LegalFinding>[];

    for (final f in rawFindings) {
      if (f.rawExcerpt.trim().isEmpty || f.simpleExplanation.trim().isEmpty) {
        rejectedFindings.add(f);
        continue;
      }

      // Check for harmless / negated context (Section 54 Test 10)
      if (_isHarmlessContext(f)) {
        rejectedFindings.add(f);
        continue;
      }

      acceptedFindings.add(f);
    }

    // 2. Duplicate finding suppression (Section 39)
    final deduplicatedFindings = _deduplicateFindings(acceptedFindings);

    // 3. Handle zero findings / "Nothing Detected" properly (Section 41)
    if (deduplicatedFindings.isEmpty && rawAnomalies.isEmpty) {
      if (ocrQualityScore < 0.50 || doc.isLowConfidence) {
        return CalculatedRiskEvaluation(
          overallScore: 0.0,
          severity: LegalRiskSeverity.safe,
          breakdown: const RiskBreakdown(
            legalRisk: 0.0,
            financialRisk: 0.0,
            terminationRisk: 0.0,
            documentAnomalyRisk: 0.0,
          ),
          confidence: DocumentAnalysisConfidence.insufficientEvidence,
          status: DocumentAnalysisStatus.poorOcrQuality,
          acceptedFindings: [],
          rejectedFindings: rejectedFindings,
          statusExplanation:
              'Analysis incomplete. The document text quality was insufficient for reliable analysis.',
        );
      }

      if (doc.rawText.trim().length < 60) {
        return CalculatedRiskEvaluation(
          overallScore: 0.0,
          severity: LegalRiskSeverity.safe,
          breakdown: const RiskBreakdown(
            legalRisk: 0.0,
            financialRisk: 0.0,
            terminationRisk: 0.0,
            documentAnomalyRisk: 0.0,
          ),
          confidence: DocumentAnalysisConfidence.insufficientEvidence,
          status: DocumentAnalysisStatus.insufficientEvidence,
          acceptedFindings: [],
          rejectedFindings: rejectedFindings,
          statusExplanation:
              'Document could not be analyzed adequately. Insufficient text content provided.',
        );
      }

      return CalculatedRiskEvaluation(
        overallScore: 5.0,
        severity: LegalRiskSeverity.safe,
        breakdown: const RiskBreakdown(
          legalRisk: 0.0,
          financialRisk: 0.0,
          terminationRisk: 0.0,
          documentAnomalyRisk: 0.0,
        ),
        confidence: ocrQualityScore >= 0.80
            ? DocumentAnalysisConfidence.high
            : DocumentAnalysisConfidence.medium,
        status: DocumentAnalysisStatus.noMaterialRisk,
        acceptedFindings: [],
        rejectedFindings: rejectedFindings,
        statusExplanation: 'No significant risk indicators detected in this document.',
      );
    }

    // 4. Calculate individual score contributions (Section 39)
    double legalRiskAccum = 0.0;
    double financialRiskAccum = 0.0;
    double terminationRiskAccum = 0.0;
    double totalRawContribution = 0.0;

    for (final f in deduplicatedFindings) {
      double baseContribution;
      if (f.scoreContribution > 0) {
        baseContribution = f.scoreContribution.toDouble();
      } else {
        switch (f.severity) {
          case LegalRiskSeverity.safe:
            baseContribution = 0.0;
            break;
          case LegalRiskSeverity.low:
            baseContribution = 10.0; // +5 to +15
            break;
          case LegalRiskSeverity.medium:
            baseContribution = 22.0; // +15 to +30
            break;
          case LegalRiskSeverity.high:
            // Critical upfront fee scams get top high contribution
            if (f.clauseType == LegalClauseType.upfrontFeeScam) {
              baseContribution = 42.0; // +35 to +50
            } else {
              baseContribution = 32.0; // +25 to +40
            }
            break;
        }
      }

      // Confidence adjustment
      final confFactor = f.confidence.clamp(0.40, 1.0);
      double adjusted = baseContribution * confFactor;

      // Evidence quality adjustment: longer, precise excerpts receive full weight
      if (f.rawExcerpt.length < 20) {
        adjusted *= 0.75;
      } else if (f.rawExcerpt.length >= 60) {
        adjusted *= 1.05;
      }

      totalRawContribution += adjusted;

      // Assign to risk breakdown categories
      switch (f.clauseType) {
        case LegalClauseType.upfrontFeeScam:
        case LegalClauseType.predatoryInterestRate:
        case LegalClauseType.penaltyAndDamages:
        case LegalClauseType.securityDepositForfeiture:
        case LegalClauseType.hiddenFeesAndCostShifting:
          financialRiskAccum += adjusted;
          break;

        case LegalClauseType.unilateralTermination:
        case LegalClauseType.unlimitedIndemnity:
        case LegalClauseType.automaticRenewal:
          terminationRiskAccum += adjusted;
          break;

        default:
          legalRiskAccum += adjusted;
          break;
      }
    }

    // 5. Add anomaly contributions
    double anomalyRiskAccum = 0.0;
    for (final a in rawAnomalies) {
      switch (a.severity) {
        case AnomalySeverity.highSuspicion:
          anomalyRiskAccum += 15.0;
          totalRawContribution += 15.0;
          break;
        case AnomalySeverity.moderateSuspicion:
          anomalyRiskAccum += 8.0;
          totalRawContribution += 8.0;
          break;
        case AnomalySeverity.advisory:
          anomalyRiskAccum += 3.0;
          totalRawContribution += 3.0;
          break;
      }
    }

    // 6. Sub-linear asymptotic aggregation capped strictly at 0-100
    // Uses smooth curve: score = 100 * (1 - e^(-raw / 68.0))
    // Ensures 1 high issue gives ~35, 2 high issues give ~60, 3+ issues reach 75-88
    final curveScore = 100.0 * (1.0 - math.exp(-totalRawContribution / 68.0));
    final finalScore = curveScore.clamp(0.0, 100.0).roundToDouble();

    // 7. Clamp breakdown category values to 0-100
    final clampedLegal = (100.0 * (1.0 - math.exp(-legalRiskAccum / 50.0))).clamp(0.0, 100.0).roundToDouble();
    final clampedFinancial = (100.0 * (1.0 - math.exp(-financialRiskAccum / 50.0))).clamp(0.0, 100.0).roundToDouble();
    final clampedTermination = (100.0 * (1.0 - math.exp(-terminationRiskAccum / 50.0))).clamp(0.0, 100.0).roundToDouble();
    final clampedAnomaly = (100.0 * (1.0 - math.exp(-anomalyRiskAccum / 40.0))).clamp(0.0, 100.0).roundToDouble();

    // 8. Overall severity based on calculated evidence score
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

    // 9. Separate confidence determination (Section 35 Step 9 & Section 40)
    DocumentAnalysisConfidence confidence;
    if (ocrQualityScore < 0.60 || doc.isLowConfidence) {
      confidence = DocumentAnalysisConfidence.low;
    } else if (docType == LegalDocumentType.otherOrUnknown && deduplicatedFindings.isEmpty) {
      confidence = DocumentAnalysisConfidence.low;
    } else if (deduplicatedFindings.isNotEmpty &&
        deduplicatedFindings.every((f) => f.confidence >= 0.88) &&
        ocrQualityScore >= 0.85) {
      confidence = DocumentAnalysisConfidence.high;
    } else {
      confidence = DocumentAnalysisConfidence.medium;
    }

    String explanation;
    if (severity == LegalRiskSeverity.high) {
      explanation = '${deduplicatedFindings.length} high-risk indicators detected requiring thorough legal review.';
    } else if (severity == LegalRiskSeverity.medium) {
      explanation = 'Moderate risk indicators detected. Review flagged clauses before signing.';
    } else {
      explanation = 'Document has low risk profile with standard contractual provisions.';
    }

    return CalculatedRiskEvaluation(
      overallScore: finalScore,
      severity: severity,
      breakdown: RiskBreakdown(
        legalRisk: clampedLegal,
        financialRisk: clampedFinancial,
        terminationRisk: clampedTermination,
        documentAnomalyRisk: clampedAnomaly,
      ),
      confidence: confidence,
      status: DocumentAnalysisStatus.completed,
      acceptedFindings: deduplicatedFindings,
      rejectedFindings: rejectedFindings,
      statusExplanation: explanation,
    );
  }

  /// Deduplicates findings that target the exact same clause and category.
  List<LegalFinding> _deduplicateFindings(List<LegalFinding> findings) {
    final seen = <String, LegalFinding>{};

    for (final f in findings) {
      final key = '${f.clauseId ?? f.rawExcerpt.trim().toLowerCase()}_${f.clauseType.name}';
      if (!seen.containsKey(key)) {
        seen[key] = f;
      } else {
        // Keep the one with higher severity or confidence
        final existing = seen[key]!;
        if (f.severity.index < existing.severity.index || f.confidence > existing.confidence) {
          seen[key] = f;
        }
      }
    }

    return seen.values.toList();
  }

  /// Detects whether an excerpt mentions a suspicious keyword in a purely benign,
  /// protective, or negated context (Section 54 Test 10).
  bool _isHarmlessContext(LegalFinding finding) {
    final text = finding.rawExcerpt.toLowerCase();

    // Negations: "no registration fee", "will not charge any fee", "never ask for deposit"
    final benignPatterns = [
      'will not charge any registration fee',
      'no registration fee is required',
      'no upfront fee',
      'does not require any payment',
      'no security deposit shall be demanded',
      'shall never demand any upfront',
      'free of any charge or fee',
      'company does not charge any fee',
      'strictly prohibits charging candidates',
      'no fee of any kind is payable',
      'does not charge any registration fee',
      'does not charge',
      'will not charge',
      'no registration fee',
      'no fee shall be charged',
      'without any registration fee',
      'does not charge any',
    ];

    for (final pattern in benignPatterns) {
      if (text.contains(pattern)) {
        return true;
      }
    }

    return false;
  }
}
