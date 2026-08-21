import 'dart:ui';
import '../../core/legal/models/legal_analysis_result.dart';
import '../../core/legal/models/legal_document_type.dart';
import '../../core/legal/models/legal_finding.dart';
import '../../core/legal/models/ocr_document.dart';
import 'clause_extraction_service.dart';
import 'document_anomaly_service.dart';
import 'indian_law_rag_service.dart';
import 'legal_document_classifier.dart';
import 'legal_risk_engine.dart';
import 'local_legal_llm_service.dart';

class LegalOrchestrator {
  final LegalDocumentClassifier _classifier = LegalDocumentClassifier();
  final ClauseExtractionService _clauseService = ClauseExtractionService();
  final DocumentAnomalyService _anomalyService = DocumentAnomalyService();
  final IndianLawRagService _ragService = IndianLawRagService();
  final LocalLegalLlmService _llmService = LocalLegalLlmService();
  final LegalRiskEngine _riskEngine = LegalRiskEngine();

  IndianLawRagService get ragService => _ragService;

  /// Analyzes a scanned OcrDocument through the complete Indian Legal Risk pipeline.
  Future<LegalAnalysisResult> analyze(
    OcrDocument doc, {
    LegalDocumentType? forcedType,
    bool enableAiEnhancement = true,
  }) async {
    // 1. Classification
    final classification = _classifier.classify(doc.rawText);
    final docType = forcedType ?? classification.type;

    // 2. Deterministic Clause Extraction with Bounding Box mapping
    final deterministicFindings = _clauseService.extractFindings(doc);

    // 3. Document Authenticity & Anomaly checks
    final deterministicAnomalies = _anomalyService.analyzeAnomalies(doc);

    // 4. AI Enhancement (Local Ollama / OpenRouter)
    AiLegalEnhancement? aiEnhancement;
    if (enableAiEnhancement) {
      try {
        aiEnhancement = await _llmService.analyze(doc.rawText, docType);
      } catch (_) {}
    }

    // Merge Findings & Anomalies
    final allFindings = [
      ...deterministicFindings,
      if (aiEnhancement != null) ...aiEnhancement.aiDiscoveredFindings,
    ];

    final allAnomalies = [
      ...deterministicAnomalies,
      if (aiEnhancement != null) ...aiEnhancement.aiDiscoveredAnomalies,
    ];

    // 5. Evaluate Multi-Factor Risk
    final riskEval = _riskEngine.evaluate(allFindings, allAnomalies, doc);

    // 6. Summaries
    final plainSummary = aiEnhancement?.plainLanguageSummary ??
        'This ${docType.displayName} contains ${allFindings.length} detected legal clauses and ${allAnomalies.length} structural notes. Review highlighted terms before execution.';

    final legalSummary = aiEnhancement?.executiveLegalSummary ??
        'Instrument reviewed under ${docType.governingActDescription}. Assessed risk level: ${riskEval.severity.displayName} (${riskEval.overallScore.toInt()}/100).';

    return LegalAnalysisResult(
      document: doc,
      documentType: docType,
      documentTypeConfidence: classification.confidence,
      overallRiskScore: riskEval.overallScore,
      overallSeverity: riskEval.severity,
      riskBreakdown: riskEval.breakdown,
      findings: allFindings,
      anomalies: allAnomalies,
      plainSummary: plainSummary,
      executiveLegalSummary: legalSummary,
      analyzedAt: DateTime.now(),
      aiModelUsed: aiEnhancement?.modelUsed,
      isAiEnhanced: aiEnhancement != null,
    );
  }

  /// Convenience helper to create an OcrDocument from raw string and image path.
  OcrDocument createDocumentFromText(String text, {String? imagePath}) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final ocrLines = <OcrLine>[];
    final totalLines = lines.length.clamp(1, 1000);

    for (int i = 0; i < lines.length; i++) {
      final normTop = i / totalLines;
      final normHeight = 1.0 / totalLines;

      ocrLines.add(OcrLine(
        text: lines[i],
        confidence: 0.92,
        pageIndex: 0,
        boundingBox: OcrBoundingBox(
          left: 0.05,
          top: normTop,
          width: 0.90,
          height: normHeight,
        ),
      ));
    }

    final page = OcrPage(
      pageIndex: 0,
      imagePath: imagePath,
      pageSize: const Size(1080, 1920),
      lines: ocrLines,
      averageConfidence: 0.92,
    );

    return OcrDocument(
      pages: [page],
      rawText: text,
      overallConfidence: 0.92,
      scannedAt: DateTime.now(),
    );
  }
}
