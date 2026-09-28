import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../../config/api_config.dart';
import '../../core/legal/models/legal_analysis_result.dart';
import '../../core/legal/models/legal_document_type.dart';
import '../../core/legal/models/legal_finding.dart';
import '../../core/legal/models/ocr_document.dart';
import '../../models/scan_result_model.dart';
import 'clause_extraction_service.dart';
import 'document_anomaly_service.dart';
import 'gemini_legal_analysis_service.dart';
import 'indian_law_rag_service.dart';
import 'legal_document_classifier.dart';
import 'legal_risk_engine.dart';
import 'live_legal_update_service.dart';
import 'local_legal_llm_service.dart';

class LegalOrchestrator {
  final LegalDocumentClassifier _classifier = LegalDocumentClassifier();
  final ClauseExtractionService _clauseService = ClauseExtractionService();
  final DocumentAnomalyService _anomalyService = DocumentAnomalyService();
  final IndianLawRagService _ragService = IndianLawRagService();
  final LocalLegalLlmService _llmService = LocalLegalLlmService();
  final LegalRiskEngine _riskEngine = LegalRiskEngine();
  final LiveLegalUpdateService _liveUpdateService = LiveLegalUpdateService();
  final GeminiLegalAnalysisService _geminiLegalService = GeminiLegalAnalysisService();

  IndianLawRagService get ragService => _ragService;
  LiveLegalUpdateService get liveUpdateService => _liveUpdateService;

  /// Analyzes a scanned OcrDocument through the complete Indian Legal Risk pipeline.
  ///
  /// [imagePaths] — Optional list of image file paths for direct Gemini multimodal analysis.
  /// When provided, Gemini will perform visual analysis on the document images in addition
  /// to analyzing the extracted text.
  Future<LegalAnalysisResult> analyze(
    OcrDocument doc, {
    LegalDocumentType? forcedType,
    bool enableAiEnhancement = true,
    List<String>? imagePaths,
  }) async {
    // 0. Ensure dynamic laws are loaded and auto-sync in background once every 24h
    await _liveUpdateService.initialize();
    _liveUpdateService.syncIfNeeded();

    // 1. Classification
    final classification = _classifier.classify(doc.rawText);
    final docType = forcedType ?? classification.type;

    // 2. Deterministic Clause Extraction with Bounding Box mapping
    final deterministicFindings = _clauseService.extractFindings(doc);

    // 3. Document Authenticity & Anomaly checks
    final deterministicAnomalies = _anomalyService.analyzeAnomalies(doc);

    // 4. AI Enhancement — Prioritize NVIDIA NIM if configured, else Gemini -> fallback LLM
    AiLegalEnhancement? aiEnhancement;
    if (enableAiEnhancement) {
      final isNvidia =
          ApiConfig.aiActive && ApiConfig.effectiveApiKey.startsWith('nvapi-');
      if (isNvidia) {
        // 4a. Prioritize NVIDIA NIM for document analyzer
        try {
          aiEnhancement = await _llmService.analyze(doc.rawText, docType);
        } catch (e) {
          debugPrintThrottled('NVIDIA NIM document analysis error: $e');
        }

        // 4b. Fallback to Gemini if NVIDIA NIM fails
        if (aiEnhancement == null) {
          try {
            aiEnhancement = await _geminiLegalService
                .analyzeDocument(
                  rawText: doc.rawText,
                  docType: docType,
                  imagePaths: imagePaths,
                )
                .timeout(const Duration(seconds: 30));
          } catch (e) {
            debugPrintThrottled('Gemini legal analysis error: $e');
          }
        }
      } else {
        // 4a. Try Gemini AI first (supports multimodal image analysis)
        try {
          aiEnhancement = await _geminiLegalService
              .analyzeDocument(
                rawText: doc.rawText,
                docType: docType,
                imagePaths: imagePaths,
              )
              .timeout(const Duration(seconds: 30));
        } catch (e) {
          debugPrintThrottled('Gemini legal analysis error: $e');
        }

        // 4b. Fallback to existing LLM pipeline if Gemini fails
        if (aiEnhancement == null) {
          try {
            aiEnhancement = await _llmService.analyze(doc.rawText, docType);
          } catch (_) {}
        }
      }
    }

    // Ingest any newly discovered dynamic statutory citations
    if (aiEnhancement != null) {
      for (final finding in aiEnhancement.aiDiscoveredFindings) {
        for (final citation in finding.statutoryBasis) {
          await _liveUpdateService.registerAndPersistNewLaw(citation);
        }
      }
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

  /// Creates an OcrDocument from multiple OCR results (from multi-photo capture or gallery images).
  OcrDocument createDocumentFromOcrResults(List<OcrResult> results) {
    if (results.isEmpty) {
      return createDocumentFromText('');
    }

    final pages = <OcrPage>[];
    final textBuffer = StringBuffer();

    for (int pageIdx = 0; pageIdx < results.length; pageIdx++) {
      final res = results[pageIdx];
      if (textBuffer.isNotEmpty) textBuffer.writeln('\n');
      textBuffer.writeln('--- Page ${pageIdx + 1} ---');
      textBuffer.writeln(res.fullText);

      final ocrLines = <OcrLine>[];
      double maxX = 1080.0;
      double maxY = 1920.0;
      for (final block in res.blocks) {
        final r = block.boundingBox;
        if (r != null) {
          if (r.right > maxX) maxX = r.right;
          if (r.bottom > maxY) maxY = r.bottom;
        }
      }
      final pageSize = Size(maxX, maxY);

      for (int bIdx = 0; bIdx < res.blocks.length; bIdx++) {
        final block = res.blocks[bIdx];
        if (block.lineItems.isNotEmpty) {
          for (int iIdx = 0; iIdx < block.lineItems.length; iIdx++) {
            final item = block.lineItems[iIdx];
            final rect = item.boundingBox ??
                block.boundingBox ??
                Rect.fromLTWH(50, (ocrLines.length * 40.0) + 50, 900, 35);
            ocrLines.add(OcrLine(
              text: item.text,
              confidence: 0.94,
              pageIndex: pageIdx,
              boundingBox: OcrBoundingBox.fromRect(rect, pageSize: pageSize),
            ));
          }
        } else {
          for (int lIdx = 0; lIdx < block.lines.length; lIdx++) {
            final line = block.lines[lIdx];
            final rect = block.boundingBox ??
                Rect.fromLTWH(50, (ocrLines.length * 40.0) + 50, 900, 35);
            ocrLines.add(OcrLine(
              text: line,
              confidence: 0.94,
              pageIndex: pageIdx,
              boundingBox: OcrBoundingBox.fromRect(rect, pageSize: pageSize),
            ));
          }
        }
      }

      pages.add(OcrPage(
        pageIndex: pageIdx,
        imagePath: res.imagePath.isNotEmpty ? res.imagePath : null,
        pageSize: pageSize,
        lines: ocrLines,
        averageConfidence: 0.92,
      ));
    }

    return OcrDocument(
      pages: pages,
      rawText: textBuffer.toString(),
      overallConfidence: 0.92,
      scannedAt: DateTime.now(),
    );
  }

  /// Creates an OcrDocument from multiple text pages (e.g. extracted from multi-page PDF).
  OcrDocument createDocumentFromTextPages(List<String> pageTexts, {List<String?>? imagePaths}) {
    if (pageTexts.isEmpty) {
      return createDocumentFromText('');
    }

    final pages = <OcrPage>[];
    final textBuffer = StringBuffer();

    for (int pageIdx = 0; pageIdx < pageTexts.length; pageIdx++) {
      final text = pageTexts[pageIdx].trim();
      if (textBuffer.isNotEmpty) textBuffer.writeln('\n');
      textBuffer.writeln('--- Page ${pageIdx + 1} ---');
      textBuffer.writeln(text);

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
          confidence: 0.95,
          pageIndex: pageIdx,
          boundingBox: OcrBoundingBox(
            left: 0.05,
            top: normTop,
            width: 0.90,
            height: normHeight,
          ),
        ));
      }

      final imgPath = (imagePaths != null && pageIdx < imagePaths.length)
          ? imagePaths[pageIdx]
          : null;

      pages.add(OcrPage(
        pageIndex: pageIdx,
        imagePath: imgPath,
        pageSize: const Size(1080, 1920),
        lines: ocrLines,
        averageConfidence: 0.95,
      ));
    }

    return OcrDocument(
      pages: pages,
      rawText: textBuffer.toString(),
      overallConfidence: 0.95,
      scannedAt: DateTime.now(),
    );
  }
}
