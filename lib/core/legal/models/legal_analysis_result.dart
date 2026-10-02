import 'document_analysis_status.dart';
import 'document_anomaly.dart';
import 'legal_document_type.dart';
import 'legal_finding.dart';
import 'ocr_document.dart';

class RiskBreakdown {
  final double legalRisk; // 0..100
  final double financialRisk; // 0..100
  final double terminationRisk; // 0..100
  final double documentAnomalyRisk; // 0..100

  const RiskBreakdown({
    required this.legalRisk,
    required this.financialRisk,
    required this.terminationRisk,
    required this.documentAnomalyRisk,
  });

  Map<String, dynamic> toJson() => {
    'legalRisk': legalRisk,
    'financialRisk': financialRisk,
    'terminationRisk': terminationRisk,
    'documentAnomalyRisk': documentAnomalyRisk,
  };

  factory RiskBreakdown.fromJson(Map<String, dynamic> json) => RiskBreakdown(
    legalRisk: (json['legalRisk'] as num?)?.toDouble() ?? 0.0,
    financialRisk: (json['financialRisk'] as num?)?.toDouble() ?? 0.0,
    terminationRisk: (json['terminationRisk'] as num?)?.toDouble() ?? 0.0,
    documentAnomalyRisk: (json['documentAnomalyRisk'] as num?)?.toDouble() ?? 0.0,
  );
}

class LegalAnalysisResult {
  final OcrDocument document;
  final LegalDocumentType documentType;
  final double documentTypeConfidence;
  final double overallRiskScore; // 0..100
  final LegalRiskSeverity overallSeverity;
  final RiskBreakdown riskBreakdown;
  final List<LegalFinding> findings;
  final List<DocumentAnomaly> anomalies;
  final String plainSummary;
  final String executiveLegalSummary;
  final DateTime analyzedAt;
  final String? aiModelUsed;
  final bool isAiEnhanced;

  // New pipeline & transparency metadata (Sections 38, 40, 41, 48, 49)
  final String analysisId;
  final String documentHash;
  final DocumentAnalysisConfidence confidenceLevel;
  final DocumentAnalysisStatus status;
  final DocumentConsistencyChecks consistencyChecks;
  final String analysisMethod;
  final String? statusMessage;

  const LegalAnalysisResult({
    required this.document,
    required this.documentType,
    required this.documentTypeConfidence,
    required this.overallRiskScore,
    required this.overallSeverity,
    required this.riskBreakdown,
    required this.findings,
    required this.anomalies,
    required this.plainSummary,
    required this.executiveLegalSummary,
    required this.analyzedAt,
    this.aiModelUsed,
    this.isAiEnhanced = false,
    this.analysisId = 'an_default',
    this.documentHash = '',
    this.confidenceLevel = DocumentAnalysisConfidence.medium,
    this.status = DocumentAnalysisStatus.completed,
    this.consistencyChecks = const DocumentConsistencyChecks(),
    this.analysisMethod = 'AI-assisted document analysis',
    this.statusMessage,
  });

  List<LegalFinding> get highRiskFindings =>
      findings.where((f) => f.severity == LegalRiskSeverity.high).toList();

  List<LegalFinding> get mediumRiskFindings =>
      findings.where((f) => f.severity == LegalRiskSeverity.medium).toList();

  List<LegalFinding> get lowRiskFindings =>
      findings.where((f) => f.severity == LegalRiskSeverity.low).toList();

  List<LegalFinding> get safeFindings =>
      findings.where((f) => f.severity == LegalRiskSeverity.safe).toList();

  List<DocumentAnomaly> get highSuspicionAnomalies =>
      anomalies.where((a) => a.severity == AnomalySeverity.highSuspicion).toList();

  /// Total count of critical issues
  int get criticalIssueCount =>
      highRiskFindings.length + highSuspicionAnomalies.length;
}
