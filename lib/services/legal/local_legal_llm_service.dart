import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../core/legal/models/document_anomaly.dart';
import '../../core/legal/models/legal_clause.dart';
import '../../core/legal/models/legal_document_type.dart';
import '../../core/legal/models/legal_finding.dart';

class AiLegalEnhancement {
  final String plainLanguageSummary;
  final String executiveLegalSummary;
  final List<LegalFinding> aiDiscoveredFindings;
  final List<DocumentAnomaly> aiDiscoveredAnomalies;
  final String modelUsed;

  const AiLegalEnhancement({
    required this.plainLanguageSummary,
    required this.executiveLegalSummary,
    this.aiDiscoveredFindings = const [],
    this.aiDiscoveredAnomalies = const [],
    required this.modelUsed,
  });
}

class LocalLegalLlmService {
  final String ollamaHost;
  final String ollamaModel;

  LocalLegalLlmService({
    this.ollamaHost = 'http://10.0.2.2:11434', // default emulator localhost
    this.ollamaModel = 'llama3.2',
  });

  /// Enhances legal analysis using Local Ollama or OpenRouter Cloud AI with fast timeout & fallback.
  Future<AiLegalEnhancement?> analyze(
    String rawText,
    LegalDocumentType docType, {
    bool preferLocalOllama = false,
  }) async {
    if (rawText.trim().length < 15) return null;

    // 1. Try Local Ollama if requested
    if (preferLocalOllama) {
      try {
        final ollamaResult = await _callOllama(rawText, docType)
            .timeout(const Duration(seconds: 5));
        if (ollamaResult != null) return ollamaResult;
      } catch (e) {
        debugPrint('Ollama local LLM unavailable: $e. Falling back...');
      }
    }

    // 2. Try OpenRouter Cloud AI using active key
    if (ApiConfig.openRouterApiKey.isNotEmpty &&
        !ApiConfig.openRouterApiKey.contains('<YOUR_')) {
      final candidates = [
        'google/gemini-2.0-flash-exp:free',
        'google/gemini-2.0-flash:free',
        'meta-llama/llama-3.3-70b-instruct:free',
      ];
      try {
        return await _tryCandidates(candidates, rawText, docType)
            .timeout(const Duration(seconds: 6), onTimeout: () {
          debugPrint('Legal LLM enhancement timed out (6s). Proceeding with deterministic rules.');
          return null;
        });
      } catch (e) {
        debugPrint('Legal LLM enhancement error: $e');
      }
    }

    return null;
  }

  Future<AiLegalEnhancement?> _tryCandidates(
    List<String> candidates,
    String rawText,
    LegalDocumentType docType,
  ) async {
    for (final model in candidates) {
      try {
        final result = await _callOpenRouter(model, rawText, docType)
            .timeout(const Duration(seconds: 4));
        if (result != null) return result;
      } catch (e) {
        debugPrint('OpenRouter model $model failed or timed out: $e');
      }
    }
    return null;
  }

  Future<AiLegalEnhancement?> _callOpenRouter(
    String model,
    String rawText,
    LegalDocumentType docType,
  ) async {
    final systemPrompt = '''
You are an expert Indian Legal Document & Contract Risk Auditor.
Analyze the provided document under applicable Indian Laws (Indian Contract Act 1872, Consumer Protection Act 2019, Model Tenancy Act, RERA 2016, IT Act 2000, Specific Relief Act).

Document Type: ${docType.displayName}

TASKS:
1. Provide a dual-summary:
   - "plain_summary": 2-3 sentences in simple layman's language explaining what this document is and what major risks the user should watch out for.
   - "executive_legal_summary": 2-3 sentences in formal legal terminology for a lawyer.
2. Identify any dangerous, unfair, or unconscionable clauses.
3. Identify any structural or authenticity anomalies (date mismatches, party discrepancies, missing witness sections).

CRITICAL SAFETY RULE:
Never claim a document is definitely "fraudulent" or "illegal". Use phrases like "Potentially unenforceable under Indian Law", "High-risk clause", or "Structural discrepancy detected".

Respond strictly with ONLY valid raw JSON in this schema (no markdown fences, no explanatory text):
{
  "plain_summary": "...",
  "executive_legal_summary": "...",
  "ai_findings": [
    {
      "clause_type": "nonCompeteRestraint", // or penaltyAndDamages, unilateralTermination, unlimitedIndemnity, unilateralVariation, securityDepositForfeiture
      "severity": "high", // or "medium", "low"
      "title": "...",
      "simple_explanation": "...",
      "legal_explanation": "...",
      "raw_excerpt": "...",
      "recommended_action": "..."
    }
  ],
  "ai_anomalies": [
    {
      "category": "dateInconsistency", // or partyMismatch, amountDiscrepancy, missingStandardClause, unusualJurisdiction
      "severity": "moderateSuspicion", // or highSuspicion, advisory
      "title": "...",
      "explanation": "...",
      "evidence": "...",
      "verification_tip": "..."
    }
  ]
}
''';

    final uri = Uri.parse('${ApiConfig.openRouterBaseUrl}/chat/completions');
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer ${ApiConfig.openRouterApiKey}',
        'HTTP-Referer': ApiConfig.appSiteUrl,
        'X-Title': ApiConfig.appName,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'temperature': 0.1,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': 'Here is the scanned legal document text:\n\n$rawText'},
        ],
      }),
    ).timeout(const Duration(seconds: 4));

    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(response.body);
    final content = decoded['choices']?[0]?['message']?['content']?.toString();
    if (content == null || content.isEmpty) return null;

    final jsonStr = _extractJson(content);
    if (jsonStr == null) return null;

    final data = jsonDecode(jsonStr);
    return _parseAiResponse(data, model);
  }

  Future<AiLegalEnhancement?> _callOllama(
    String rawText,
    LegalDocumentType docType,
  ) async {
    final uri = Uri.parse('$ollamaHost/api/generate');
    final prompt = 'Analyze this Indian legal document (${docType.displayName}) and return JSON with plain_summary, executive_legal_summary:\n$rawText';

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': ollamaModel,
        'prompt': prompt,
        'stream': false,
        'format': 'json',
      }),
    ).timeout(const Duration(seconds: 4));

    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body);
    final responseText = decoded['response']?.toString();
    if (responseText == null) return null;

    final jsonStr = _extractJson(responseText);
    if (jsonStr == null) return null;

    final data = jsonDecode(jsonStr);
    return _parseAiResponse(data, 'ollama:$ollamaModel');
  }

  String? _extractJson(String text) {
    String cleaned = text.replaceAll(RegExp(r'<think>[\s\S]*?<\/think>', caseSensitive: false), '').trim();
    if (cleaned.startsWith('```json')) cleaned = cleaned.substring(7);
    if (cleaned.startsWith('```')) cleaned = cleaned.substring(3);
    if (cleaned.endsWith('```')) cleaned = cleaned.substring(0, cleaned.length - 3);
    cleaned = cleaned.trim();

    final startIdx = cleaned.indexOf('{');
    final endIdx = cleaned.lastIndexOf('}');
    if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
      return cleaned.substring(startIdx, endIdx + 1);
    }
    return null;
  }

  AiLegalEnhancement _parseAiResponse(Map<String, dynamic> data, String modelUsed) {
    final plainSummary = data['plain_summary']?.toString() ??
        'This document contains standard terms along with several clauses that require careful review before execution.';
    final legalSummary = data['executive_legal_summary']?.toString() ??
        'The instrument has been audited against Indian statutory benchmarks with specific attention to enforceability and one-sided covenants.';

    final findings = <LegalFinding>[];
    if (data['ai_findings'] is List) {
      for (int i = 0; i < (data['ai_findings'] as List).length; i++) {
        final f = data['ai_findings'][i];
        if (f is Map) {
          final sevStr = f['severity']?.toString().toLowerCase();
          LegalRiskSeverity sev = LegalRiskSeverity.medium;
          if (sevStr == 'high') sev = LegalRiskSeverity.high;
          if (sevStr == 'low') sev = LegalRiskSeverity.low;

          findings.add(LegalFinding(
            id: 'ai_finding_$i',
            clauseType: LegalClauseType.generalObligation,
            severity: sev,
            title: f['title']?.toString() ?? 'AI Identified Legal Finding',
            simpleExplanation: f['simple_explanation']?.toString() ?? '',
            legalExplanation: f['legal_explanation']?.toString() ?? '',
            rawExcerpt: f['raw_excerpt']?.toString() ?? '',
            pageIndex: 0,
            recommendedAction: f['recommended_action']?.toString() ?? 'Review with legal counsel.',
            confidence: 0.88,
          ));
        }
      }
    }

    final anomalies = <DocumentAnomaly>[];
    if (data['ai_anomalies'] is List) {
      for (int i = 0; i < (data['ai_anomalies'] as List).length; i++) {
        final a = data['ai_anomalies'][i];
        if (a is Map) {
          anomalies.add(DocumentAnomaly(
            id: 'ai_anomaly_$i',
            category: AnomalyCategory.missingStandardClause,
            severity: AnomalySeverity.moderateSuspicion,
            title: a['title']?.toString() ?? 'Potential Inconsistency',
            explanation: a['explanation']?.toString() ?? '',
            evidence: a['evidence']?.toString() ?? '',
            verificationTip: a['verification_tip']?.toString() ?? 'Verify original execution copy.',
          ));
        }
      }
    }

    return AiLegalEnhancement(
      plainLanguageSummary: plainSummary,
      executiveLegalSummary: legalSummary,
      aiDiscoveredFindings: findings,
      aiDiscoveredAnomalies: anomalies,
      modelUsed: modelUsed,
    );
  }
}
