import '../../../core/legal/models/document_analysis_status.dart';
import '../../../core/legal/models/document_anomaly.dart';
import '../../../core/legal/models/legal_finding.dart';
import '../pipeline/clause_segmentation_service.dart';

/// Structured response returned by an AI provider or backend analysis service (Section 38).
class StructuredBackendAnalysisResult {
  final String analysisId;
  final String documentType;
  final String overallSeverity; // high, medium, low, safe
  final double riskScore;       // 0..100
  final DocumentAnalysisConfidence confidence;
  final DocumentAnalysisStatus status;
  final String summary;
  final String executiveLegalSummary;
  final List<LegalFinding> findings;
  final List<DocumentAnomaly> anomalies;
  final DocumentConsistencyChecks checks;
  final String modelUsed;
  final DateTime analyzedAt;
  final String? errorMessage;

  const StructuredBackendAnalysisResult({
    required this.analysisId,
    required this.documentType,
    required this.overallSeverity,
    required this.riskScore,
    required this.confidence,
    required this.status,
    required this.summary,
    required this.executiveLegalSummary,
    required this.findings,
    this.anomalies = const [],
    this.checks = const DocumentConsistencyChecks(),
    required this.modelUsed,
    required this.analyzedAt,
    this.errorMessage,
  });

  bool get isSuccessful => status.isSuccessful && errorMessage == null;
}

/// Abstract AI Provider interface (Section 33).
/// Allows switching between Gemini, OpenAI, Claude, or custom providers
/// without changing the core fraud/risk detection pipeline.
abstract class AIProvider {
  String get providerId;
  String get modelName;

  Future<StructuredBackendAnalysisResult> analyzeDocument({
    required String documentText,
    required String documentType,
    required List<SegmentedClause> clauses,
    required String language,
    required String country,
    Map<String, dynamic>? metadata,
  });
}
