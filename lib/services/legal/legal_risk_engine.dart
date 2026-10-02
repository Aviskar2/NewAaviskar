import '../../core/legal/models/document_analysis_status.dart';
import '../../core/legal/models/document_anomaly.dart';
import '../../core/legal/models/legal_analysis_result.dart';
import '../../core/legal/models/legal_document_type.dart';
import '../../core/legal/models/legal_finding.dart';
import '../../core/legal/models/ocr_document.dart';
import 'pipeline/document_risk_scoring_engine.dart';

class RiskEvaluation {
  final double overallScore; // 0..100
  final LegalRiskSeverity severity;
  final RiskBreakdown breakdown;
  final DocumentAnalysisConfidence confidence;
  final DocumentAnalysisStatus status;
  final String statusExplanation;

  const RiskEvaluation({
    required this.overallScore,
    required this.severity,
    required this.breakdown,
    this.confidence = DocumentAnalysisConfidence.medium,
    this.status = DocumentAnalysisStatus.completed,
    this.statusExplanation = '',
  });
}

/// Rebuilt LegalRiskEngine (Section 32, 39, 40).
///
/// Completely eliminates all hard-coded 90% shortcuts and arbitrary jumps.
/// Evaluates dynamic, evidence-calibrated risk contributions based on validated findings.
class LegalRiskEngine {
  final DocumentRiskScoringEngine _scoringEngine = DocumentRiskScoringEngine();

  /// Calculates explainable, multi-factor risk scores based on detected evidence.
  RiskEvaluation evaluate(
    List<LegalFinding> findings,
    List<DocumentAnomaly> anomalies,
    OcrDocument doc, {
    double ocrQualityScore = 0.90,
    LegalDocumentType docType = LegalDocumentType.otherOrUnknown,
  }) {
    final result = _scoringEngine.evaluate(
      rawFindings: findings,
      rawAnomalies: anomalies,
      doc: doc,
      ocrQualityScore: ocrQualityScore,
      docType: docType,
    );

    return RiskEvaluation(
      overallScore: result.overallScore,
      severity: result.severity,
      breakdown: result.breakdown,
      confidence: result.confidence,
      status: result.status,
      statusExplanation: result.statusExplanation,
    );
  }
}
