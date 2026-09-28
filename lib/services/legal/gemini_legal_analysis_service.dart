import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../config/api_config.dart';
import '../../core/legal/constants/indian_acts_database.dart';
import '../../core/legal/models/document_anomaly.dart';
import '../../core/legal/models/legal_clause.dart';
import '../../core/legal/models/legal_document_type.dart';
import '../../core/legal/models/legal_finding.dart';
import 'local_legal_llm_service.dart';

/// Dedicated Google Gemini AI Service for deep Indian Legal Document Analysis.
///
/// Supports:
/// - Text-only document analysis (extracted from PDF, DOCX, or OCR)
/// - Multimodal image + text analysis (camera captures, scanned photos)
/// - Full Indian law reference with official India Code source URLs
/// - Statutory citation matching against BNS 2023, DPDP 2023, RERA 2016, etc.
class GeminiLegalAnalysisService {
  static const List<String> _candidateModels = [
    'gemini-3.5-flash',
    'gemini-3.8-flash',
    'gemini-3.5-flash-lite',
    'gemini-2.5-flash-lite',
    'gemini-flash-latest',
  ];

  /// Core system prompt for Indian legal document analysis with official law references.
  static String _buildSystemPrompt(LegalDocumentType docType) => '''
You are an expert Indian Legal Document, Contract, and Fraud Auditor AI. You specialize in analyzing documents under currently active and enforceable Indian Laws.

APPLICABLE INDIAN LAWS (Active & In Force):
1. Bharatiya Nyaya Sanhita, 2023 (BNS) — In force from 1 July 2024, replaces IPC
   - Section 318: Cheating & dishonestly inducing delivery of property (replaces IPC 420)
   - Section 316: Criminal breach of trust
   - Section 336/338: Forgery of valuable security or agreement
   - Section 308: Extortion & coercive penalty demands
   Reference: https://www.indiacode.nic.in/handle/123456789/21808

2. Bharatiya Sakshya Adhiniyam, 2023 (BSA) — Replaces Indian Evidence Act
   - Section 61 & 63: Electronic agreements & digital signature admissibility
   Reference: https://www.indiacode.nic.in/handle/123456789/21810

3. Digital Personal Data Protection Act, 2023 (DPDP Act)
   - Section 6 & 8: Consent requirements, data fiduciary obligations, penalties up to ₹250 Cr
   Reference: https://www.indiacode.nic.in/handle/123456789/20563

4. Indian Contract Act, 1872
   - Section 23: Agreements opposed to public policy are void
   - Section 27: Restraint of trade void (post-employment non-compete unenforceable)
   - Section 28: Restraint of legal proceedings void
   - Section 73: Compensation for consequential breach
   - Section 74: Only reasonable compensation, not punitive penalties (Fateh Chand v. Balkishan Das)
   Reference: https://www.indiacode.nic.in/handle/123456789/2187

5. Consumer Protection Act, 2019
   - Section 2(46): Unfair contract terms declared unenforceable
   - Section 2(47): Unfair trade practices & deceptive charges prohibited
   Reference: https://www.indiacode.nic.in/handle/123456789/15256

6. Model Tenancy Act, 2021
   - Section 11: Security deposit ceiling (max 2 months for residential)
   - Section 20 & 21: Prohibition on severing essential services & eviction safeguards
   - Section 22: 24-hour prior notice before landlord entry
   Reference: https://mohua.gov.in/upload/uploadfiles/files/Model_Tenancy_Act_English.pdf

7. Real Estate (Regulation and Development) Act, 2016 (RERA)
   - Section 13: No advance exceeding 10% without registered agreement
   - Section 18: Full refund with interest or monthly compensation for delays
   Reference: https://www.indiacode.nic.in/handle/123456789/2158

8. Arbitration and Conciliation Act, 1996
   - Section 12(5) & Seventh Schedule: Unilateral sole arbitrator appointment illegal
   Reference: https://www.indiacode.nic.in/handle/123456789/1978

9. MSMED Act, 2006
   - Section 15 & 16: Mandatory 45-day payment, 3x RBI compound interest for delayed payments
   Reference: https://www.indiacode.nic.in/handle/123456789/2013

10. Registration Act, 1908 & Transfer of Property Act, 1882
    - Section 17(1)(d): Mandatory registration for leases >11 months
    - Section 106: 15-day statutory notice for month-to-month leases
    Reference: https://www.indiacode.nic.in/handle/123456789/2179

11. Competition Act, 2002
    - Section 3 & 4: Anti-competitive exclusive supply & tie-in agreements prohibited
    Reference: https://www.indiacode.nic.in/handle/123456789/2010

12. Usurious Loans Act, 1918
    - Courts can re-open transactions with excessive interest rates
    Reference: https://www.indiacode.nic.in/handle/123456789/2369

Document Type Being Analyzed: ${docType.displayName}

YOUR TASKS:
1. EXTRACT & READ the full document text (if image is provided, perform OCR and extract all text).
2. IDENTIFY all dangerous, unfair, void, unconscionable, or scam clauses.
3. For EACH finding, provide:
   - The exact clause type
   - Severity (high/medium/low)
   - The exact quoted text from the document (raw_excerpt)
   - A simple layman's explanation
   - A formal legal explanation citing specific Indian Act sections
   - The recommended action for the user
   - The specific Indian law reference with official source URL
4. DETECT structural anomalies (date mismatches, party discrepancies, missing witnesses, unsigned sections).
5. Provide dual summaries (plain language + executive legal).

CRITICAL SAFETY RULES:
- Never claim a document is definitively "fraudulent" or "illegal" without qualification.
- Use phrases like "Potentially unenforceable under Indian Law", "High-risk clause", "Structural discrepancy detected".
- Always cite the specific Act name, Section number, and official India Code URL for every finding.
- If the document is an image, extract ALL text first and then analyze.

RESPOND STRICTLY WITH VALID RAW JSON (no markdown fences, no explanatory text):
{
  "extracted_text": "Full text extracted from the document/image (if image was provided, otherwise echo back the input text)",
  "plain_summary": "2-3 sentences in simple layman's language explaining what this document is and what major risks exist",
  "executive_legal_summary": "2-3 sentences in formal legal terminology for a lawyer",
  "ai_findings": [
    {
      "clause_type": "upfrontFeeScam|nonCompeteRestraint|penaltyAndDamages|unilateralTermination|unlimitedIndemnity|unilateralVariation|securityDepositForfeiture|hiddenFeesAndCostShifting|arbitrationAndJurisdiction|restraintOfLegalRecourse|waiverOfRights|predatoryInterestRate|confidentialityOverreach|automaticRenewal|generalObligation",
      "severity": "high|medium|low",
      "title": "Clear, descriptive title of the finding",
      "simple_explanation": "Why this is dangerous in simple language",
      "legal_explanation": "Formal legal analysis citing specific Indian Act & Section",
      "raw_excerpt": "Exact quoted text from the document that triggered this finding",
      "recommended_action": "What the user should do",
      "statutory_references": [
        {
          "act_name": "Full name of the Indian Act with year",
          "section": "Section number(s)",
          "title": "Brief title of the provision",
          "description": "How this provision applies to the finding",
          "official_source_url": "https://www.indiacode.nic.in/... or official government URL",
          "is_enforceable": true
        }
      ]
    }
  ],
  "ai_anomalies": [
    {
      "category": "dateInconsistency|partyMismatch|amountDiscrepancy|missingStandardClause|unusualJurisdiction|missingWitness|stampPaperIssue",
      "severity": "highSuspicion|moderateSuspicion|advisory",
      "title": "Clear title",
      "explanation": "What was detected",
      "evidence": "Specific evidence from the document",
      "verification_tip": "How the user can verify this"
    }
  ]
}
''';

  /// Analyzes a legal document using Gemini AI.
  ///
  /// Supports text-only or multimodal (image+text) analysis.
  /// [rawText] — The extracted text from the document (can be empty if image is provided)
  /// [docType] — The classified document type
  /// [imagePaths] — Optional list of image file paths for multimodal analysis
  Future<AiLegalEnhancement?> analyzeDocument({
    required String rawText,
    required LegalDocumentType docType,
    List<String>? imagePaths,
  }) async {
    if (!ApiConfig.geminiActive) {
      debugPrint('GeminiLegalAnalysisService: Gemini AI not active or key unconfigured.');
      return null;
    }

    // Must have either text or images
    final hasText = rawText.trim().length >= 10;
    final hasImages = imagePaths != null && imagePaths.isNotEmpty;
    if (!hasText && !hasImages) {
      debugPrint('GeminiLegalAnalysisService: No text or images provided.');
      return null;
    }

    // Encode images to base64
    final imageDataList = <_ImageData>[];
    if (hasImages) {
      for (final path in imagePaths) {
        try {
          final file = File(path);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final base64 = base64Encode(bytes);
            String mimeType = 'image/jpeg';
            final lower = path.toLowerCase();
            if (lower.endsWith('.png')) {
              mimeType = 'image/png';
            } else if (lower.endsWith('.webp')) {
              mimeType = 'image/webp';
            } else if (lower.endsWith('.heic') || lower.endsWith('.heif')) {
              mimeType = 'image/heic';
            }
            imageDataList.add(_ImageData(base64: base64, mimeType: mimeType));
          }
        } catch (e) {
          debugPrint('GeminiLegalAnalysisService: Error reading image $path: $e');
        }
      }
    }

    // Try each candidate model
    for (final model in _candidateModels) {
      try {
        final result = await _callGemini(
          model: model,
          rawText: rawText,
          docType: docType,
          images: imageDataList,
        ).timeout(const Duration(seconds: 25));

        if (result != null) {
          return result;
        }
      } catch (e) {
        debugPrint('GeminiLegalAnalysisService model $model failed: $e');
      }
    }

    return null;
  }

  Future<AiLegalEnhancement?> _callGemini({
    required String model,
    required String rawText,
    required LegalDocumentType docType,
    required List<_ImageData> images,
  }) async {
    final apiKey = ApiConfig.effectiveGeminiApiKey;
    final uri = Uri.parse(
      '${ApiConfig.geminiBaseUrl}/models/$model:generateContent?key=$apiKey',
    );

    final systemPrompt = _buildSystemPrompt(docType);

    // Build content parts
    final List<Map<String, dynamic>> userParts = [];

    // Add images first (multimodal)
    for (final img in images) {
      userParts.add({
        'inlineData': {
          'mimeType': img.mimeType,
          'data': img.base64,
        }
      });
    }

    // Build the text prompt
    final StringBuffer promptBuffer = StringBuffer();
    promptBuffer.writeln(systemPrompt);
    promptBuffer.writeln();

    if (images.isNotEmpty) {
      promptBuffer.writeln('ANALYZE THE ATTACHED DOCUMENT IMAGE(S).');
      promptBuffer.writeln('First extract ALL text from the image(s), then analyze for legal risks.');
      promptBuffer.writeln();
    }

    if (rawText.trim().isNotEmpty) {
      promptBuffer.writeln('DOCUMENT TEXT (OCR/Extracted):');
      promptBuffer.writeln(rawText);
    } else if (images.isNotEmpty) {
      promptBuffer.writeln('No pre-extracted text available. Extract text from the image(s) and analyze.');
    }

    userParts.add({
      'text': promptBuffer.toString().replaceAll('\u00A0', ' '),
    });

    final requestBody = {
      'contents': [
        {
          'role': 'user',
          'parts': userParts,
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 0.1,
      }
    };

    final data = await _postToGemini(uri, requestBody);
    if (data == null) return null;

    final textOutput =
        data['candidates']?[0]?['content']?['parts']?[0]?['text']?.toString();
    if (textOutput == null || textOutput.trim().isEmpty) return null;

    try {
      final parsedJson = jsonDecode(textOutput);
      return _parseResponse(parsedJson, model);
    } catch (e) {
      // Try extracting JSON from response if it has markdown fences
      final extracted = _extractJson(textOutput);
      if (extracted != null) {
        try {
          final parsedJson = jsonDecode(extracted);
          return _parseResponse(parsedJson, model);
        } catch (_) {}
      }
      debugPrint('GeminiLegalAnalysisService: JSON parse error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _postToGemini(
    Uri uri,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri).timeout(timeout);
      request.headers.contentType =
          ContentType('application', 'json', charset: 'utf-8');

      final jsonStr = jsonEncode(body).replaceAll('\u00A0', ' ');
      final utf8Bytes = utf8.encode(jsonStr);
      request.contentLength = utf8Bytes.length;
      request.add(utf8Bytes);

      final response = await request.close().timeout(timeout);
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        return jsonDecode(responseBody) as Map<String, dynamic>;
      } else {
        debugPrint('Gemini API status ${response.statusCode}: $responseBody');
        return null;
      }
    } catch (e) {
      debugPrint('Gemini HTTP request error: $e');
      return null;
    } finally {
      client.close();
    }
  }

  String? _extractJson(String text) {
    String cleaned = text
        .replaceAll(RegExp(r'<think>[\s\S]*?<\/think>', caseSensitive: false), '')
        .trim();
    if (cleaned.startsWith('```json')) cleaned = cleaned.substring(7);
    if (cleaned.startsWith('```')) cleaned = cleaned.substring(3);
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    cleaned = cleaned.trim();

    final startIdx = cleaned.indexOf('{');
    final endIdx = cleaned.lastIndexOf('}');
    if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
      return cleaned.substring(startIdx, endIdx + 1);
    }
    return null;
  }

  AiLegalEnhancement _parseResponse(Map<String, dynamic> data, String model) {
    final plainSummary = data['plain_summary']?.toString() ??
        'This document has been analyzed for legal risks under Indian law.';
    final execSummary = data['executive_legal_summary']?.toString() ?? plainSummary;
    // extractedText can be used for OCR fallback when images were provided
    // final extractedText = data['extracted_text']?.toString() ?? '';

    final findings = <LegalFinding>[];
    final anomalies = <DocumentAnomaly>[];

    // Parse findings
    if (data['ai_findings'] is List) {
      for (int i = 0; i < (data['ai_findings'] as List).length; i++) {
        final f = data['ai_findings'][i];
        if (f is Map) {
          final sevStr = f['severity']?.toString().toLowerCase() ?? 'medium';
          LegalRiskSeverity severity = LegalRiskSeverity.medium;
          if (sevStr == 'high') severity = LegalRiskSeverity.high;
          if (sevStr == 'low') severity = LegalRiskSeverity.low;

          // Parse clause type
          final clauseTypeStr = f['clause_type']?.toString() ?? 'generalObligation';
          final clauseType = _parseClauseType(clauseTypeStr);

          // Parse statutory references from AI response
          final statutoryRefs = <StatutoryCitation>[];
          if (f['statutory_references'] is List) {
            for (final ref in f['statutory_references']) {
              if (ref is Map) {
                statutoryRefs.add(StatutoryCitation(
                  actName: ref['act_name']?.toString() ?? 'Indian Statute',
                  section: ref['section']?.toString() ?? '',
                  title: ref['title']?.toString() ?? '',
                  description: ref['description']?.toString() ?? '',
                  officialSourceUrl: ref['official_source_url']?.toString(),
                  isEnforceableInIndia: ref['is_enforceable'] != false,
                ));
              }
            }
          }

          // If AI didn't return statutory refs, match from our database
          if (statutoryRefs.isEmpty) {
            statutoryRefs.addAll(
              IndianActsDatabase.getProvisionsForClause(clauseType),
            );
          }

          findings.add(LegalFinding(
            id: 'gemini_legal_$i',
            clauseType: clauseType,
            severity: severity,
            title: f['title']?.toString() ?? 'AI Identified Legal Finding',
            simpleExplanation: f['simple_explanation']?.toString() ?? '',
            legalExplanation: f['legal_explanation']?.toString() ?? '',
            rawExcerpt: f['raw_excerpt']?.toString() ?? '',
            pageIndex: 0,
            statutoryBasis: statutoryRefs,
            recommendedAction: f['recommended_action']?.toString() ??
                'Review with a qualified legal professional.',
            confidence: 0.94,
          ));
        }
      }
    }

    // Parse anomalies
    if (data['ai_anomalies'] is List) {
      for (int i = 0; i < (data['ai_anomalies'] as List).length; i++) {
        final a = data['ai_anomalies'][i];
        if (a is Map) {
          final catStr = a['category']?.toString() ?? 'missingStandardClause';
          final sevStr = a['severity']?.toString() ?? 'moderateSuspicion';

          anomalies.add(DocumentAnomaly(
            id: 'gemini_anomaly_$i',
            category: _parseAnomalyCategory(catStr),
            severity: _parseAnomalySeverity(sevStr),
            title: a['title']?.toString() ?? 'Structural Discrepancy',
            explanation: a['explanation']?.toString() ?? '',
            evidence: a['evidence']?.toString() ?? '',
            verificationTip: a['verification_tip']?.toString() ??
                'Verify with the original execution copy.',
          ));
        }
      }
    }

    return AiLegalEnhancement(
      plainLanguageSummary: plainSummary,
      executiveLegalSummary: execSummary,
      aiDiscoveredFindings: findings,
      aiDiscoveredAnomalies: anomalies,
      modelUsed: 'Google Gemini ($model)',
    );
  }

  LegalClauseType _parseClauseType(String typeStr) {
    switch (typeStr.toLowerCase()) {
      case 'upfrontfeescam':
        return LegalClauseType.upfrontFeeScam;
      case 'noncompeterestraint':
        return LegalClauseType.nonCompeteRestraint;
      case 'penaltyanddamages':
        return LegalClauseType.penaltyAndDamages;
      case 'unilateraltermination':
        return LegalClauseType.unilateralTermination;
      case 'unlimitedindemnity':
        return LegalClauseType.unlimitedIndemnity;
      case 'unilateralvariation':
        return LegalClauseType.unilateralVariation;
      case 'securitydepositforfeiture':
        return LegalClauseType.securityDepositForfeiture;
      case 'hiddenfeesandcostshifting':
        return LegalClauseType.hiddenFeesAndCostShifting;
      case 'arbitrationandjurisdiction':
        return LegalClauseType.arbitrationAndJurisdiction;
      case 'restraintoflegalrecourse':
        return LegalClauseType.restraintOfLegalRecourse;
      case 'waiverofrights':
        return LegalClauseType.waiverOfRights;
      case 'predatoryinterestrate':
        return LegalClauseType.predatoryInterestRate;
      case 'confidentialityoverreach':
        return LegalClauseType.confidentialityOverreach;
      case 'automaticrenewal':
        return LegalClauseType.automaticRenewal;
      case 'intellectualpropertyassignment':
        return LegalClauseType.intellectualPropertyAssignment;
      case 'missingstandardprotection':
        return LegalClauseType.missingStandardProtection;
      default:
        return LegalClauseType.generalObligation;
    }
  }

  AnomalyCategory _parseAnomalyCategory(String catStr) {
    switch (catStr.toLowerCase()) {
      case 'dateinconsistency':
        return AnomalyCategory.dateInconsistency;
      case 'partymismatch':
        return AnomalyCategory.partyMismatch;
      case 'amountdiscrepancy':
        return AnomalyCategory.amountDiscrepancy;
      case 'missingstandardclause':
        return AnomalyCategory.missingStandardClause;
      case 'unusualjurisdiction':
        return AnomalyCategory.unusualJurisdiction;
      default:
        return AnomalyCategory.missingStandardClause;
    }
  }

  AnomalySeverity _parseAnomalySeverity(String sevStr) {
    switch (sevStr.toLowerCase()) {
      case 'highsuspicion':
        return AnomalySeverity.highSuspicion;
      case 'moderatesuspicion':
        return AnomalySeverity.moderateSuspicion;
      case 'advisory':
        return AnomalySeverity.advisory;
      default:
        return AnomalySeverity.moderateSuspicion;
    }
  }
}

class _ImageData {
  final String base64;
  final String mimeType;

  const _ImageData({required this.base64, required this.mimeType});
}
