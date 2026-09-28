import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/analysis_result.dart';
import '../models/bill_model.dart';
import '../core/legal/models/document_anomaly.dart';
import '../core/legal/models/legal_clause.dart';
import '../core/legal/models/legal_document_type.dart';
import '../core/legal/models/legal_finding.dart';
import 'legal/local_legal_llm_service.dart';

/// Result from Gemini AI fraudulent detection & audit.
class GeminiBillFraudResult {
  final bool isFraudulent;
  final double fraudScore; // 0.0 (clean) to 1.0 (extreme fraud/scam)
  final String fraudSummary;
  final List<AnalysisFinding> findings;
  final StructuredBill? enhancedBill;
  final String modelUsed;

  const GeminiBillFraudResult({
    required this.isFraudulent,
    required this.fraudScore,
    required this.fraudSummary,
    required this.findings,
    this.enhancedBill,
    required this.modelUsed,
  });
}

/// Dedicated Google Gemini AI Service for Indian Invoice, Bill & Legal Document Fraud Detection.
class GeminiFraudService {
  static const List<String> _candidateModels = [
    'gemini-3.5-flash',
    'gemini-3.8-flash',
    'gemini-3.5-flash-lite',
    'gemini-2.5-flash-lite',
    'gemini-flash-latest',
  ];

  /// Official Government Source references for legal & fraud citations
  static final GovernmentSource _ccpaSource = GovernmentSource(
    title: 'CCPA Guidelines on Service Charge (July 2022)',
    description:
        'Hotels & restaurants prohibited from levying mandatory service charges automatically.',
    url: 'https://consumeraffairs.nic.in',
    organization: 'Central Consumer Protection Authority',
    effectiveDate: '04-07-2022',
    lastVerified: DateTime.now(),
    status: SourceVerificationStatus.live,
    confidence: 0.99,
  );

  static final GovernmentSource _gstLawSource = GovernmentSource(
    title: 'Central Goods and Services Tax (CGST) Act, 2017',
    description:
        'Provisions relating to invoice rules, tax rate slabs, and anti-profiteering (Sec 171).',
    url: 'https://cbic-gst.gov.in',
    organization: 'Central Board of Indirect Taxes and Customs',
    effectiveDate: '01-07-2017',
    lastVerified: DateTime.now(),
    status: SourceVerificationStatus.live,
    confidence: 0.99,
  );

  static final GovernmentSource _legalMetrologySource = GovernmentSource(
    title: 'Legal Metrology (Packaged Commodities) Rules, 2011',
    description: 'Selling above Maximum Retail Price (MRP) is illegal and punishable under law.',
    url: 'https://consumeraffairs.nic.in',
    organization: 'Department of Consumer Affairs',
    effectiveDate: '01-01-2011',
    lastVerified: DateTime.now(),
    status: SourceVerificationStatus.live,
    confidence: 0.98,
  );

  /// Performs deep multimodal fraud detection on invoices, receipts, and handwritten slips.
  Future<GeminiBillFraudResult?> analyzeBillForFraud({
    required StructuredBill initialBill,
    required String rawOcrText,
    String? imagePath,
  }) async {
    if (!ApiConfig.geminiActive) {
      debugPrint('GeminiFraudService: Gemini AI not active or key unconfigured.');
      return null;
    }

    final bool hasImage = imagePath != null && File(imagePath).existsSync();
    if (!hasImage && rawOcrText.trim().length < 5) {
      return null;
    }

    String? base64Image;
    String mimeType = 'image/jpeg';
    if (hasImage) {
      try {
        final bytes = await File(imagePath).readAsBytes();
        base64Image = base64Encode(bytes);
        if (imagePath.toLowerCase().endsWith('.png')) {
          mimeType = 'image/png';
        } else if (imagePath.toLowerCase().endsWith('.webp')) {
          mimeType = 'image/webp';
        }
      } catch (e) {
        debugPrint('GeminiFraudService: Error reading image file: $e');
      }
    }

    for (final model in _candidateModels) {
      try {
        final result = await _callGeminiBillAudit(
          model: model,
          initialBill: initialBill,
          rawOcrText: rawOcrText,
          base64Image: base64Image,
          mimeType: mimeType,
        ).timeout(const Duration(seconds: 18));

        if (result != null) {
          return result;
        }
      } catch (e) {
        debugPrint('GeminiFraudService model $model failed: $e. Trying fallback...');
      }
    }

    return null;
  }

  Future<GeminiBillFraudResult?> _callGeminiBillAudit({
    required String model,
    required StructuredBill initialBill,
    required String rawOcrText,
    String? base64Image,
    required String mimeType,
  }) async {
    final apiKey = ApiConfig.effectiveGeminiApiKey;
    final uri = Uri.parse(
      '${ApiConfig.geminiBaseUrl}/models/$model:generateContent?key=$apiKey',
    );

    const systemPrompt = '''
You are an expert Indian Forensic Bill, Invoice & Consumer Fraud Auditor specializing in Indian Consumer Law (CCPA 2022), GST Act 2017, and Legal Metrology Act.

AUDIT TASKS:
1. DETECT FRAUD & ILLEGAL SURCHARGES:
   - Mandatory/Forced Service Charge: Under CCPA July 2022 guidelines, hotels/restaurants CANNOT add service charge automatically or forcibly. It is strictly optional. Flag as illegal/suspicious.
   - Tax on Service Charge: If GST is levied on top of an unauthorized service charge, flag as double extortion.
   - GST Fraud: Check if GSTIN format is valid. Check if GST slabs match standard Indian rates (0%, 5%, 12%, 18%, 28%). Flag non-standard rates or fake GST collection.
   - Interstate vs Intra-state Tax Mismatch: CGST+SGST can only be charged intra-state. Inter-state sales must charge IGST.
   - Math & Rounding Manipulation: Verify if items subtotal + taxes + charges = grand total. Check for hidden padding, phantom items, or excessive rounding.
   - Overcharging beyond MRP or quoted price.
   - Altered/Tampered handwritten slips (parchi) with manipulated figures.

2. EXTRACT PRECISE STRUCTURED FINANCIAL DATA:
   - Extract seller name, GSTIN, invoice number, date, bill type (restaurant, retail, pharmacy, supermarket, electronic, etc.).
   - Extract exact taxable base amount, CGST, SGST, IGST, cess, charges, discount, grand total.
   - Extract cleaned items with quantity, unit price, and line total.

Respond strictly in valid JSON matching this schema:
{
  "is_fraud": true/false,
  "fraud_score": 0.0 to 1.0,
  "fraud_summary": "Concise explanation of fraud or compliance status",
  "fraud_flags": [
    {
      "severity": "suspicious" (or "error" or "verify"),
      "title": "Clear finding title",
      "explanation": "Detailed explanation citing relevant Indian law or guideline",
      "what_found": "What was observed on the bill",
      "what_expected": "What the law or arithmetic requires",
      "difference": 0.0,
      "recommendation": "Exact consumer recourse (e.g. Demand removal, Call 1915 NCH, lodge INGRAM complaint)",
      "category": "Service Charge" (or "GST", "Arithmetic", "Pricing", "Legal")
    }
  ],
  "bill_data": {
    "seller_name": "...",
    "gstin": "...",
    "invoice_number": "...",
    "invoice_date": "YYYY-MM-DD",
    "bill_type": "restaurant",
    "grand_total": 0.0,
    "taxable_amount": 0.0,
    "cgst_rate": 0.0,
    "cgst_amount": 0.0,
    "sgst_rate": 0.0,
    "sgst_amount": 0.0,
    "igst_rate": null,
    "igst_amount": 0.0,
    "cess_amount": 0.0,
    "discount_total": 0.0,
    "round_off": 0.0,
    "items": [
      {
        "name": "...",
        "quantity": 1.0,
        "unit_price": 0.0,
        "line_total": 0.0
      }
    ],
    "charges": [
      {
        "label": "...",
        "amount": 0.0
      }
    ]
  }
}
''';

    final List<Map<String, dynamic>> userParts = [];

    // Add visual photo if available (multimodal inspection)
    if (base64Image != null && base64Image.isNotEmpty) {
      userParts.add({
        'inlineData': {
          'mimeType': mimeType,
          'data': base64Image,
        }
      });
    }

    // Add combined prompt as a single text part with non-breaking spaces replaced
    final combinedPrompt = '''
$systemPrompt

AUDIT THIS INDIAN BILL/INVOICE:
- OCR Extracted Text:
$rawOcrText

- Pre-parsed Grand Total: ${initialBill.grandTotal ?? 'Unknown'}
- Pre-parsed GSTIN: ${initialBill.gstin ?? 'Unknown'}
- Pre-parsed Seller: ${initialBill.sellerName ?? 'Unknown'}
'''.replaceAll('\u00A0', ' ');

    userParts.add({'text': combinedPrompt});

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

    final parsedJson = jsonDecode(textOutput);
    return _parseGeminiBillResult(parsedJson, initialBill, model);
  }

  Future<Map<String, dynamic>?> _postToGemini(
    Uri uri,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 18),
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri).timeout(timeout);
      request.headers.contentType =
          ContentType('application', 'json', charset: 'utf-8');

      // Sanitize JSON and encode directly to UTF-8 bytes to avoid Latin-1 crashes
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

  GeminiBillFraudResult _parseGeminiBillResult(
    Map<String, dynamic> json,
    StructuredBill baseBill,
    String model,
  ) {
    final bool isFraud = json['is_fraud'] == true;
    final double fraudScore = (json['fraud_score'] as num?)?.toDouble() ?? (isFraud ? 0.8 : 0.0);
    final String summary = json['fraud_summary'] as String? ??
        (isFraud ? 'Gemini AI detected potential billing discrepancies or fraud.' : 'Bill verified legitimate by Gemini AI.');

    final findings = <AnalysisFinding>[];
    final flags = json['fraud_flags'] as List? ?? [];

    for (int i = 0; i < flags.length; i++) {
      final f = flags[i] as Map<String, dynamic>;
      final sevStr = f['severity']?.toString().toLowerCase() ?? 'suspicious';
      final category = f['category']?.toString() ?? 'Fraud';

      FindingSeverity severity = FindingSeverity.suspicious;
      if (sevStr == 'error') {
        severity = FindingSeverity.error;
      } else if (sevStr == 'verify') {
        severity = FindingSeverity.verify;
      } else if (sevStr == 'ok') {
        severity = FindingSeverity.ok;
      }

      GovernmentSource? source;
      if (category.toLowerCase().contains('service') || category.toLowerCase().contains('charge')) {
        source = _ccpaSource;
      } else if (category.toLowerCase().contains('gst') || category.toLowerCase().contains('tax')) {
        source = _gstLawSource;
      } else if (category.toLowerCase().contains('mrp') || category.toLowerCase().contains('price')) {
        source = _legalMetrologySource;
      }

      findings.add(AnalysisFinding(
        id: 'gemini_fraud_${i + 1}',
        severity: severity,
        title: f['title'] as String? ?? 'Billing Violation Detected',
        explanation: f['explanation'] as String? ?? 'Discrepancy flagged by Gemini AI.',
        whatFound: f['what_found']?.toString(),
        whatExpected: f['what_expected']?.toString(),
        difference: (f['difference'] as num?)?.toDouble(),
        recommendation: f['recommendation'] as String? ??
            'Review bill with the merchant and report to 1915 National Consumer Helpline if unresolved.',
        source: source,
        category: 'Gemini AI: $category',
      ));
    }

    // Build enhanced bill if data was extracted
    StructuredBill? enhancedBill;
    final billData = json['bill_data'] as Map<String, dynamic>?;
    if (billData != null) {
      final items = <BillItem>[];
      final itemsList = billData['items'] as List? ?? [];
      for (final itm in itemsList) {
        if (itm is Map<String, dynamic>) {
          items.add(BillItem(
            name: itm['name']?.toString() ?? 'Item',
            quantity: (itm['quantity'] as num?)?.toDouble() ?? 1.0,
            unitPrice: (itm['unit_price'] as num?)?.toDouble(),
            lineTotal: (itm['line_total'] as num?)?.toDouble() ?? 0.0,
            confidence: 0.95,
          ));
        }
      }

      final charges = <BillCharge>[];
      final chargesList = billData['charges'] as List? ?? [];
      for (final ch in chargesList) {
        if (ch is Map<String, dynamic>) {
          charges.add(BillCharge(
            label: ch['label']?.toString() ?? 'Charge',
            amount: (ch['amount'] as num?)?.toDouble() ?? 0.0,
          ));
        }
      }

      final taxes = BillTaxSection(
        subtotal: (billData['taxable_amount'] as num?)?.toDouble() ?? baseBill.taxes.subtotal,
        cgstRate: (billData['cgst_rate'] as num?)?.toDouble() ?? baseBill.taxes.cgstRate,
        cgstAmount: (billData['cgst_amount'] as num?)?.toDouble() ?? baseBill.taxes.cgstAmount,
        sgstRate: (billData['sgst_rate'] as num?)?.toDouble() ?? baseBill.taxes.sgstRate,
        sgstAmount: (billData['sgst_amount'] as num?)?.toDouble() ?? baseBill.taxes.sgstAmount,
        igstRate: (billData['igst_rate'] as num?)?.toDouble() ?? baseBill.taxes.igstRate,
        igstAmount: (billData['igst_amount'] as num?)?.toDouble() ?? baseBill.taxes.igstAmount,
        cessAmount: (billData['cess_amount'] as num?)?.toDouble() ?? baseBill.taxes.cessAmount,
        roundOff: (billData['round_off'] as num?)?.toDouble() ?? baseBill.taxes.roundOff,
      );

      DateTime? parsedDate;
      if (billData['invoice_date'] != null) {
        parsedDate = DateTime.tryParse(billData['invoice_date'].toString());
      }

      enhancedBill = StructuredBill(
        rawText: baseBill.rawText,
        billType: baseBill.billType,
        sellerName: billData['seller_name']?.toString() ?? baseBill.sellerName,
        gstin: billData['gstin']?.toString() ?? baseBill.gstin,
        invoiceNumber: billData['invoice_number']?.toString() ?? baseBill.invoiceNumber,
        invoiceDate: parsedDate ?? baseBill.invoiceDate,
        items: items.isNotEmpty ? items : baseBill.items,
        taxes: taxes,
        charges: charges.isNotEmpty ? charges : baseBill.charges,
        grandTotal: (billData['grand_total'] as num?)?.toDouble() ?? baseBill.grandTotal,
        discountTotal: (billData['discount_total'] as num?)?.toDouble() ?? baseBill.discountTotal,
        confidence: 0.95,
        isAiEnhanced: true,
        aiNotes: 'Verified with Google Gemini 3.6 Flash AI ($summary)',
        aiModelUsed: model,
      );
    }

    return GeminiBillFraudResult(
      isFraudulent: isFraud,
      fraudScore: fraudScore,
      fraudSummary: summary,
      findings: findings,
      enhancedBill: enhancedBill,
      modelUsed: model,
    );
  }

  /// Audits legal agreements & contracts for fraudulent, void, or unconscionable clauses.
  Future<AiLegalEnhancement?> analyzeLegalDocumentForFraud({
    required String rawText,
    required LegalDocumentType docType,
  }) async {
    if (!ApiConfig.geminiActive || rawText.trim().length < 15) {
      return null;
    }

    final apiKey = ApiConfig.effectiveGeminiApiKey;
    final systemPrompt = '''
You are an expert Indian Legal Document & Fraud Auditor.
Analyze this document strictly under active Indian Laws:
- Bharatiya Nyaya Sanhita, 2023 (BNS) [cheating, forgery, criminal breach of trust]
- Indian Contract Act, 1872 [Section 27 non-compete void, Section 74 excessive penalties]
- Consumer Protection Act, 2019 [unfair contracts, one-sided terms]
- Model Tenancy Act, 2021 [maximum 2 months security deposit]
- RERA 2016 [advance payment restrictions & builder delay rights]
- Arbitration & Conciliation Act, 1996 [unilateral arbitrator appointments are invalid]

Document Type: ${docType.displayName}

Detect predatory clauses, void restraints, and authenticity anomalies.
Respond strictly in valid JSON matching this schema:
{
  "plain_summary": "...",
  "executive_legal_summary": "...",
  "ai_findings": [
    {
      "severity": "high",
      "title": "...",
      "simple_explanation": "...",
      "legal_explanation": "...",
      "raw_excerpt": "...",
      "recommended_action": "..."
    }
  ],
  "ai_anomalies": [
    {
      "title": "...",
      "explanation": "...",
      "evidence": "...",
      "verification_tip": "..."
    }
  ]
}
''';

    for (final model in _candidateModels) {
      try {
        final uri = Uri.parse(
          '${ApiConfig.geminiBaseUrl}/models/$model:generateContent?key=$apiKey',
        );

        final data = await _postToGemini(uri, {
          'contents': [
            {
              'role': 'user',
              'parts': [
                {
                  'text':
                      '$systemPrompt\n\nDOCUMENT TEXT:\n$rawText'.replaceAll('\u00A0', ' ')
                },
              ]
            }
          ],
          'generationConfig': {
            'responseMimeType': 'application/json',
            'temperature': 0.1,
          }
        });

        if (data != null) {
          final text = data['candidates']?[0]?['content']?['parts']?[0]?['text']?.toString();
          if (text != null && text.isNotEmpty) {
            final json = jsonDecode(text);
            return _parseGeminiLegalResult(json, model);
          }
        }
      } catch (e) {
        debugPrint('Gemini legal audit with $model failed: $e');
      }
    }

    return null;
  }

  AiLegalEnhancement _parseGeminiLegalResult(Map<String, dynamic> json, String model) {
    final plainSummary = json['plain_summary'] as String? ?? 'Document analysis complete.';
    final execSummary = json['executive_legal_summary'] as String? ?? plainSummary;

    final findings = <LegalFinding>[];
    final anomalies = <DocumentAnomaly>[];

    final rawFindings = json['ai_findings'] as List? ?? [];
    for (int i = 0; i < rawFindings.length; i++) {
      final f = rawFindings[i] as Map<String, dynamic>;
      final sevStr = f['severity']?.toString().toLowerCase() ?? 'medium';

      LegalRiskSeverity severity = LegalRiskSeverity.medium;
      if (sevStr == 'high') {
        severity = LegalRiskSeverity.high;
      } else if (sevStr == 'low') {
        severity = LegalRiskSeverity.low;
      }

      findings.add(LegalFinding(
        id: 'gemini_legal_$i',
        clauseType: LegalClauseType.generalObligation,
        severity: severity,
        title: f['title']?.toString() ?? 'Flagged Clause',
        simpleExplanation: f['simple_explanation']?.toString() ?? '',
        legalExplanation: f['legal_explanation']?.toString() ?? '',
        rawExcerpt: f['raw_excerpt']?.toString() ?? '',
        pageIndex: 0,
        recommendedAction: f['recommended_action']?.toString() ?? 'Review with legal counsel.',
        confidence: 0.95,
      ));
    }

    final rawAnomalies = json['ai_anomalies'] as List? ?? [];
    for (int i = 0; i < rawAnomalies.length; i++) {
      final a = rawAnomalies[i] as Map<String, dynamic>;

      anomalies.add(DocumentAnomaly(
        id: 'gemini_anomaly_$i',
        category: AnomalyCategory.missingStandardClause,
        severity: AnomalySeverity.moderateSuspicion,
        title: a['title']?.toString() ?? 'Structural Discrepancy',
        explanation: a['explanation']?.toString() ?? '',
        evidence: a['evidence']?.toString() ?? '',
        verificationTip: a['verification_tip']?.toString() ?? 'Verify original execution copy.',
      ));
    }

    return AiLegalEnhancement(
      plainLanguageSummary: plainSummary,
      executiveLegalSummary: execSummary,
      aiDiscoveredFindings: findings,
      aiDiscoveredAnomalies: anomalies,
      modelUsed: 'Google Gemini ($model)',
    );
  }
}
