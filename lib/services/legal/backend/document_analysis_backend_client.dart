import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/legal/models/document_analysis_status.dart';
import '../../../core/legal/models/legal_finding.dart';
import '../ai/ai_provider.dart';
import '../pipeline/clause_segmentation_service.dart';
import '../pipeline/controlled_legal_database_service.dart';

/// Client service that delegates document analysis to the secure backend API (Section 33 & 34).
///
/// Flutter App -> Backend API (/api/analyze-document) -> AI Provider -> Return Structured Analysis
/// Ensures that no raw AI secret keys are ever compiled into the mobile app binary.
class DocumentAnalysisBackendClient implements AIProvider {
  final String backendBaseUrl;
  final Duration timeout;
  final ControlledLegalDatabaseService _legalDb = ControlledLegalDatabaseService();

  DocumentAnalysisBackendClient({
    this.backendBaseUrl = 'http://10.0.2.2:3001', // Android emulator localhost / local backend
    this.timeout = const Duration(seconds: 25),
  });

  @override
  String get providerId => 'backend_proxy';

  @override
  String get modelName => 'ScanSure Secure Backend Engine';

  @override
  Future<StructuredBackendAnalysisResult> analyzeDocument({
    required String documentText,
    required String documentType,
    required List<SegmentedClause> clauses,
    required String language,
    required String country,
    Map<String, dynamic>? metadata,
  }) async {
    final stopwatch = Stopwatch()..start();
    final analysisId = 'an_${DateTime.now().millisecondsSinceEpoch}';

    final uri = Uri.parse('$backendBaseUrl/api/analyze-document');

    final requestBody = {
      'analysisId': analysisId,
      'documentText': documentText,
      'documentType': documentType,
      'language': language,
      'country': country,
      'clauses': clauses.map((c) => c.toJson()).toList(),
      'metadata': ?metadata,
    };

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(timeout);

      stopwatch.stop();

      // Section 55: Debug logging
      debugPrint('[BackendClient] Analysis ID: $analysisId, Status: ${response.statusCode}, Time: ${stopwatch.elapsedMilliseconds}ms');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          return _parseAndValidateBackendResponse(decoded, analysisId);
        } else {
          return _buildFailureResult(
            analysisId: analysisId,
            documentType: documentType,
            status: DocumentAnalysisStatus.analysisUnavailable,
            errorMessage: 'Malformed JSON response from backend.',
          );
        }
      } else if (response.statusCode == 429) {
        return _buildFailureResult(
          analysisId: analysisId,
          documentType: documentType,
          status: DocumentAnalysisStatus.analysisUnavailable,
          errorMessage: 'Backend rate limit reached. Please retry in a few moments.',
        );
      } else {
        return _buildFailureResult(
          analysisId: analysisId,
          documentType: documentType,
          status: DocumentAnalysisStatus.analysisUnavailable,
          errorMessage: 'Backend returned error status ${response.statusCode}.',
        );
      }
    } on SocketException catch (e) {
      stopwatch.stop();
      debugPrint('[BackendClient] Backend server unreachable at $backendBaseUrl: $e');
      return _buildFailureResult(
        analysisId: analysisId,
        documentType: documentType,
        status: DocumentAnalysisStatus.analysisUnavailable,
        errorMessage: 'Backend service offline or unreachable.',
      );
    } on TimeoutException {
      stopwatch.stop();
      debugPrint('[BackendClient] Backend analysis timed out after ${timeout.inSeconds}s.');
      return _buildFailureResult(
        analysisId: analysisId,
        documentType: documentType,
        status: DocumentAnalysisStatus.analysisUnavailable,
        errorMessage: 'Analysis timed out. Please retry.',
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('[BackendClient] Unexpected error calling backend: $e');
      return _buildFailureResult(
        analysisId: analysisId,
        documentType: documentType,
        status: DocumentAnalysisStatus.analysisUnavailable,
        errorMessage: 'Backend error: $e',
      );
    }
  }

  /// Validates the JSON schema against Section 38 requirements.
  StructuredBackendAnalysisResult _parseAndValidateBackendResponse(
    Map<String, dynamic> data,
    String defaultId,
  ) {
    final analysisId = data['analysisId']?.toString() ?? defaultId;
    final docType = data['documentType']?.toString() ?? 'other';

    final overallRisk = data['overallRisk'] as Map<String, dynamic>? ?? {};
    final levelStr = overallRisk['level']?.toString().toLowerCase() ?? 'medium';
    final score = (overallRisk['score'] as num?)?.toDouble() ?? 0.0;
    final confStr = overallRisk['confidence']?.toString().toLowerCase() ?? 'medium';

    DocumentAnalysisConfidence confidence = DocumentAnalysisConfidence.medium;
    if (confStr == 'high') {
      confidence = DocumentAnalysisConfidence.high;
    } else if (confStr == 'low') {
      confidence = DocumentAnalysisConfidence.low;
    } else if (confStr.contains('insufficient')) {
      confidence = DocumentAnalysisConfidence.insufficientEvidence;
    }

    final summary = data['summary']?.toString() ??
        'Analysis completed for $docType under active Indian laws.';
    final execSummary = data['executiveSummary']?.toString() ?? summary;

    final findings = <LegalFinding>[];
    if (data['findings'] is List) {
      for (final item in data['findings']) {
        if (item is Map<String, dynamic>) {
          final f = LegalFinding.fromJson(item);
          // Verify statutory references against controlled Indian database (Section 45)
          final verifiedBasis = <StatutoryCitation>[];
          for (final citation in f.statutoryBasis) {
            verifiedBasis.add(_legalDb.verifyOrFlag(
              rawActName: citation.actName,
              rawSection: citation.section,
              providedTitle: citation.title,
              relevanceExplanation: citation.description,
            ));
          }

          findings.add(LegalFinding(
            id: f.id,
            clauseId: f.clauseId,
            clauseType: f.clauseType,
            severity: f.severity,
            title: f.title,
            simpleExplanation: f.simpleExplanation,
            legalExplanation: f.legalExplanation,
            rawExcerpt: f.rawExcerpt,
            pageIndex: f.pageIndex,
            startOffset: f.startOffset,
            endOffset: f.endOffset,
            scoreContribution: f.scoreContribution,
            category: f.category,
            evidence: f.evidence,
            boundingBox: f.boundingBox,
            statutoryBasis: verifiedBasis.isNotEmpty ? verifiedBasis : f.statutoryBasis,
            recommendedAction: f.recommendedAction,
            confidence: f.confidence,
          ));
        }
      }
    }

    final checks = DocumentConsistencyChecks.fromJson(
        data['checks'] as Map<String, dynamic>?);

    final modelUsed = data['model']?.toString() ?? modelName;

    return StructuredBackendAnalysisResult(
      analysisId: analysisId,
      documentType: docType,
      overallSeverity: levelStr,
      riskScore: score,
      confidence: confidence,
      status: findings.isEmpty
          ? DocumentAnalysisStatus.noMaterialRisk
          : DocumentAnalysisStatus.completed,
      summary: summary,
      executiveLegalSummary: execSummary,
      findings: findings,
      checks: checks,
      modelUsed: modelUsed,
      analyzedAt: DateTime.now(),
    );
  }

  StructuredBackendAnalysisResult _buildFailureResult({
    required String analysisId,
    required String documentType,
    required DocumentAnalysisStatus status,
    required String errorMessage,
  }) {
    return StructuredBackendAnalysisResult(
      analysisId: analysisId,
      documentType: documentType,
      overallSeverity: 'safe',
      riskScore: 0.0,
      confidence: DocumentAnalysisConfidence.insufficientEvidence,
      status: status,
      summary: errorMessage,
      executiveLegalSummary: errorMessage,
      findings: [],
      modelUsed: modelName,
      analyzedAt: DateTime.now(),
      errorMessage: errorMessage,
    );
  }
}
