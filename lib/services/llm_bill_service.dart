import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/analysis_result.dart';
import '../models/bill_model.dart';

/// Result from AI enhancement containing enhanced bill and any AI-detected fraud/scam findings.
class LlmBillResult {
  final StructuredBill bill;
  final List<AnalysisFinding> aiFindings;

  const LlmBillResult({
    required this.bill,
    required this.aiFindings,
  });
}

class LlmBillService {
  /// Active and reliable candidate vision & text models on OpenRouter (fast free models first)
  static const List<String> _candidateModels = [
    'google/gemini-2.0-flash-exp:free',
    'google/gemini-2.0-flash:free',
    'qwen/qwen-2.5-vl-72b-instruct:free',
    'meta-llama/llama-3.2-11b-vision-instruct:free',
    'meta-llama/llama-3.3-70b-instruct:free',
    'mistralai/mistral-7b-instruct:free',
    'deepseek/deepseek-chat:free',
  ];

  /// Enhances deterministic bill parsing using LLM/Vision with fast fallback.
  /// Supports printed invoices as well as handwritten bills/slips/kirana parchi.
  Future<LlmBillResult> enhance(
    StructuredBill initialBill,
    String rawOcrText, {
    String? imagePath,
  }) async {
    final bool hasImage = imagePath != null && File(imagePath).existsSync();
    if (!hasImage && rawOcrText.trim().length < 5) {
      debugPrint('Skipping LLM enhancement: No image and OCR text is too short.');
      return LlmBillResult(bill: initialBill, aiFindings: []);
    }

    if (ApiConfig.openRouterApiKey.isEmpty ||
        ApiConfig.openRouterApiKey.contains('<YOUR_')) {
      debugPrint('Skipping LLM enhancement: OpenRouter API key not configured.');
      return LlmBillResult(bill: initialBill, aiFindings: []);
    }

    String? base64Image;
    if (hasImage) {
      try {
        final bytes = await File(imagePath).readAsBytes();
        base64Image = base64Encode(bytes);
      } catch (e) {
        debugPrint('Could not read image for vision analysis: $e');
      }
    }

    try {
      return await _tryModels(initialBill, rawOcrText, base64Image)
          .timeout(const Duration(seconds: 10), onTimeout: () {
        debugPrint('LLM enhancement timed out (10s limit). Proceeding with deterministic results.');
        return LlmBillResult(bill: initialBill, aiFindings: []);
      });
    } catch (e) {
      debugPrint('LLM enhancement error: $e. Using deterministic results.');
      return LlmBillResult(bill: initialBill, aiFindings: []);
    }
  }

  Future<LlmBillResult> _tryModels(
    StructuredBill initialBill,
    String rawOcrText,
    String? base64Image,
  ) async {
    for (final model in _candidateModels) {
      try {
        final result = await _callOpenRouter(model, rawOcrText, base64Image, initialBill)
            .timeout(const Duration(seconds: 6));
        if (result != null) {
          return result;
        }
      } catch (e) {
        debugPrint('Model $model failed or timed out: $e. Trying next...');
      }
    }

    // Fallback to initial bill if all AI calls fail
    return LlmBillResult(bill: initialBill, aiFindings: []);
  }

  Future<LlmBillResult?> _callOpenRouter(
    String model,
    String rawOcrText,
    String? base64Image,
    StructuredBill baseBill,
  ) async {
    final systemPrompt = '''
You are an expert Indian Bill, Invoice, Receipt & Handwritten Slip Auditor.
Your task is to analyze Indian bills — including computer-printed GST invoices, supermarket receipts, restaurant bills, petrol slips, as well as HANDWRITTEN bills/slips/kacha parchi from local kirana stores, medical shops, or restaurants.

CRITICAL INSTRUCTIONS:
1. HANDWRITTEN BILLS & RECEIPTS:
   - Carefully decipher handwriting (in English, Hindi, Hinglish, or regional terms).
   - Accurately read handwritten item names, quantities, unit prices, and line amounts.
   - For handwritten slips without explicit GST, extract item names, quantities, prices, and the handwritten sum/total.
   - Check if the manual handwritten addition done by the shopkeeper is mathematically correct or has arithmetic errors.

2. FINANCIAL SUMMARY & ARITHMETIC (EXTREME ACCURACY):
   - "taxable_amount": Base amount before GST taxes. If prices are tax-inclusive (MRP), compute taxable base = (Gross - Discount) / (1 + total GST rate/100).
   - "grand_total": The EXACT final net payable invoice amount that the customer pays.
   - "discount_total": Any trade discount, coupon, or savings deducted.
   - Cross-verify math: grand_total ≈ taxable_amount + cgst_amount + sgst_amount + igst_amount + cess_amount + charges - discount ± round_off.

3. ACCURATE GST BREAKDOWN:
   - "cgst_rate" / "cgst_amount": Central GST (e.g. 2.5%, 6%, 9%, 14%).
   - "sgst_rate" / "sgst_amount": State GST / UTGST (must equal CGST for intra-state).
   - "igst_rate" / "igst_amount": Integrated GST (for inter-state supply).
   - "cess_amount": Compensation cess if applicable.
   - In multi-slab bills (e.g. items at 5% and items at 18%), compute total CGST and total SGST accurately across all items.

4. ITEMS & PRODUCTS:
   - Clean up garbled OCR / handwriting to clear product names.
   - Extract exact quantity, unit price, and line total for each item.

5. BILL TYPE & FRAUD AUDIT:
   - Detect correct bill_type ("supermarket", "restaurant", "hotel", "pharmacy", "fuel", "electronics", "shopping", "ecommerce", "service", "gstInvoice", "unknown").
   - Flag illegal mandatory service charges, wrong GST rates, invalid GSTIN format, or overcharging math errors under Indian Consumer Law.

6. ADVANCED FRAUD DETECTION:
   - "vendor_legitimacy_check": Verify if the seller name seems consistent with the GSTIN (state code should match address region). Flag if GSTIN state code doesn't match address.
   - "item_category_mismatch": Detect if items don't match the bill type (e.g., electronics items on a restaurant bill, clothing items on a pharmacy bill).
   - "hidden_charges_analysis": Look for charges in the image that may not be captured by OCR — subtle fees, small-print surcharges, or charges buried in the layout.
   - "handwriting_consistency": For handwritten bills, check if the handwriting style is consistent throughout (same pen, same hand) or if amounts look altered.
   - "progressive_fraud": Note if the bill pattern seems to be gradually increasing amounts compared to what would be normal for this vendor type.
   - "duplicate_invoice_check": Flag if the invoice number format seems unusual or if there are signs of invoice number tampering.

Respond strictly with ONLY valid raw JSON in the following schema (no markdown fences, no explanatory text):
{
  "seller_name": "Sharma General Store",
  "seller_address": "...",
  "gstin": "27AACCT9803D1ZE",
  "invoice_number": "INV-1023",
  "invoice_date": "YYYY-MM-DD",
  "bill_type": "supermarket",
  "grand_total": 335.40,
  "taxable_amount": 290.84,
  "cgst_rate": 2.5,
  "cgst_amount": 22.28,
  "sgst_rate": 2.5,
  "sgst_amount": 22.28,
  "igst_rate": null,
  "igst_amount": 0.0,
  "cess_amount": 0.0,
  "discount_total": 0.0,
  "round_off": 0.0,
  "is_handwritten": false,
  "items": [
    {
      "name": "Atta 5kg",
      "quantity": 1.0,
      "unit": "BAG",
      "unit_price": 220.0,
      "taxable_value": 220.0,
      "line_total": 220.0,
      "gst_rate": 0.0,
      "hsn": "1101"
    }
  ],
  "charges": [
    {
      "label": "Delivery Charge",
      "amount": 0.0
    }
  ],
  "fraud_or_scam_flags": [
    {
      "severity": "suspicious",
      "title": "...",
      "explanation": "...",
      "recommendation": "...",
      "category": "GST"
    }
  ],
  "vendor_legitimacy": {
    "state_code_match": true,
    "name_consistent": true,
    "notes": "..."
  },
  "item_category_match": true,
  "hidden_charges_detected": false,
  "handwriting_consistent": true,
  "invoice_number_suspicious": false,
  "ai_summary": "Summary of audit and financial breakdown"
}
''';

    final uri = Uri.parse('${ApiConfig.openRouterBaseUrl}/chat/completions');

    // Build message content supporting both vision and text
    dynamic userMessageContent;
    if (base64Image != null && base64Image.isNotEmpty) {
      userMessageContent = [
        {
          'type': 'text',
          'text': 'Analyze this Indian bill (it may be printed or a handwritten slip/parchi). Decipher all handwriting and text, calculate financial totals, GST breakdown, and item details with high accuracy.\n\nRaw OCR text (if any):\n$rawOcrText',
        },
        {
          'type': 'image_url',
          'image_url': {
            'url': 'data:image/jpeg;base64,$base64Image',
          },
        },
      ];
    } else {
      userMessageContent = 'Here is the raw OCR text of the bill:\n\n$rawOcrText';
    }

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
          {'role': 'user', 'content': userMessageContent},
        ],
      }),
    ).timeout(const Duration(seconds: 6));

    if (response.statusCode != 200) {
      debugPrint('OpenRouter response code ${response.statusCode}: ${response.body}');
      return null;
    }

    final decoded = jsonDecode(response.body);
    final content = decoded['choices']?[0]?['message']?['content']?.toString();
    if (content == null || content.isEmpty) return null;

    final jsonString = _extractJson(content);
    if (jsonString == null) return null;

    final Map<String, dynamic> data = jsonDecode(jsonString);
    return _parseLlmResponse(data, rawOcrText, baseBill, model);
  }

  String? _extractJson(String text) {
    // Strip reasoning / think tags if present (e.g. from DeepSeek or other reasoning models)
    String cleaned = text.replaceAll(RegExp(r'<think>[\s\S]*?<\/think>', caseSensitive: false), '').trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
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

  LlmBillResult _parseLlmResponse(
    Map<String, dynamic> json,
    String rawText,
    StructuredBill baseBill,
    String modelUsed,
  ) {
    // Bill type
    BillType billType = baseBill.billType;
    final typeStr = json['bill_type']?.toString().toLowerCase();
    if (typeStr != null) {
      billType = BillType.values.firstWhere(
        (t) => t.name.toLowerCase() == typeStr,
        orElse: () => baseBill.billType,
      );
    }

    // Items
    final items = <BillItem>[];
    if (json['items'] is List) {
      for (final itemJson in json['items']) {
        if (itemJson is Map) {
          final name = itemJson['name']?.toString() ?? '';
          if (name.trim().isEmpty) continue;
          final qty = _toDouble(itemJson['quantity']) ?? 1.0;
          final unitPrice = _toDouble(itemJson['unit_price']);
          final lineTotal = _toDouble(itemJson['line_total']);
          final taxable = _toDouble(itemJson['taxable_value']) ?? lineTotal;
          final gstRate = _toDouble(itemJson['gst_rate']);

          items.add(BillItem(
            name: name,
            quantity: qty,
            unit: itemJson['unit']?.toString(),
            unitPrice: unitPrice ?? (qty > 0 && lineTotal != null ? lineTotal / qty : lineTotal),
            taxableValue: taxable,
            lineTotal: lineTotal ?? (unitPrice != null ? unitPrice * qty : null),
            gstRate: gstRate,
            hsnSac: itemJson['hsn']?.toString(),
            confidence: 0.95,
          ));
        }
      }
    }

    // Taxes
    final taxes = BillTaxSection(
      subtotal: _toDouble(json['taxable_amount']) ?? baseBill.taxes.subtotal,
      cgstAmount: _toDouble(json['cgst_amount']) ?? baseBill.taxes.cgstAmount,
      sgstAmount: _toDouble(json['sgst_amount']) ?? baseBill.taxes.sgstAmount,
      igstAmount: _toDouble(json['igst_amount']) ?? baseBill.taxes.igstAmount,
      cessAmount: _toDouble(json['cess_amount']) ?? baseBill.taxes.cessAmount,
      cgstRate: _toDouble(json['cgst_rate']) ?? baseBill.taxes.cgstRate,
      sgstRate: _toDouble(json['sgst_rate']) ?? baseBill.taxes.sgstRate,
      igstRate: _toDouble(json['igst_rate']) ?? baseBill.taxes.igstRate,
      roundOff: _toDouble(json['round_off']) ?? baseBill.taxes.roundOff,
    );

    // Charges
    final charges = <BillCharge>[];
    if (json['charges'] is List) {
      for (final c in json['charges']) {
        if (c is Map) {
          final label = c['label']?.toString() ?? '';
          final amt = _toDouble(c['amount']) ?? 0.0;
          if (label.isNotEmpty && amt > 0) {
            charges.add(BillCharge(label: label, amount: amt));
          }
        }
      }
    }

    // Invoice Date
    DateTime? invoiceDate = baseBill.invoiceDate;
    final dateStr = json['invoice_date']?.toString();
    if (dateStr != null && dateStr.isNotEmpty) {
      try {
        invoiceDate = DateTime.tryParse(dateStr) ?? baseBill.invoiceDate;
      } catch (_) {}
    }

    final finalItems = items.isNotEmpty ? items : baseBill.items;
    final finalCharges = charges.isNotEmpty ? charges : baseBill.charges;

    // Resolve grand total with cross-validation
    double? grandTotal = _toDouble(json['grand_total']);
    if (grandTotal == null || grandTotal <= 0) {
      grandTotal = baseBill.grandTotal;
    }
    // Cross-verify: If grandTotal is still missing or suspiciously small, compute from item line totals
    if ((grandTotal == null || grandTotal <= 0) && finalItems.isNotEmpty) {
      final itemsSum = finalItems.fold<double>(
        0.0,
        (sum, it) => sum + (it.lineTotal ?? ((it.unitPrice ?? 0.0) * (it.quantity ?? 1.0))),
      );
      if (itemsSum > 0) {
        final taxSum = taxes.totalPrintedTax;
        final chargesSum = finalCharges.fold<double>(0.0, (sum, c) => sum + c.amount);
        final discount = _toDouble(json['discount_total']) ?? 0.0;
        final roundOff = _toDouble(json['round_off']) ?? 0.0;
        grandTotal = itemsSum + taxSum + chargesSum - discount + roundOff;
      }
    }

    final isHandwritten = json['is_handwritten'] == true;
    String notes = json['ai_summary']?.toString() ?? '';
    if (isHandwritten && !notes.contains('Handwritten')) {
      notes = '✍️ Handwritten Bill Analyzed: $notes';
    }

    final enhancedBill = StructuredBill(
      rawText: rawText,
      billType: billType,
      sellerName: json['seller_name']?.toString() ?? baseBill.sellerName,
      sellerAddress: json['seller_address']?.toString() ?? baseBill.sellerAddress,
      gstin: json['gstin']?.toString() ?? baseBill.gstin,
      invoiceNumber: json['invoice_number']?.toString() ?? baseBill.invoiceNumber,
      invoiceDate: invoiceDate,
      items: finalItems,
      taxes: taxes,
      charges: finalCharges,
      grandTotal: grandTotal,
      discountTotal: _toDouble(json['discount_total']) ?? baseBill.discountTotal,
      qrData: baseBill.qrData,
      confidence: 0.95,
      isAiEnhanced: true,
      aiNotes: notes.isNotEmpty ? notes : null,
      aiModelUsed: modelUsed,
    );

    // Fraud / Audit findings from AI
    final aiFindings = <AnalysisFinding>[];
    if (json['fraud_or_scam_flags'] is List) {
      for (int i = 0; i < (json['fraud_or_scam_flags'] as List).length; i++) {
        final flag = json['fraud_or_scam_flags'][i];
        if (flag is Map) {
          final sevStr = flag['severity']?.toString().toLowerCase() ?? 'verify';
          FindingSeverity severity = FindingSeverity.verify;
          if (sevStr == 'suspicious') severity = FindingSeverity.suspicious;
          if (sevStr == 'error') severity = FindingSeverity.error;
          if (sevStr == 'ok') severity = FindingSeverity.ok;

          aiFindings.add(AnalysisFinding(
            id: 'ai_flag_$i',
            severity: severity,
            title: flag['title']?.toString() ?? 'AI Audit Finding',
            explanation: flag['explanation']?.toString() ?? '',
            recommendation: flag['recommendation']?.toString(),
            category: flag['category']?.toString() ?? 'AI Audit',
          ));
        }
      }
    }

    // Vendor legitimacy findings from AI
    final vendorLegitimacy = json['vendor_legitimacy'];
    if (vendorLegitimacy is Map) {
      final stateCodeMatch = vendorLegitimacy['state_code_match'];
      if (stateCodeMatch == false) {
        aiFindings.add(AnalysisFinding(
          id: 'ai_vendor_state_mismatch',
          severity: FindingSeverity.suspicious,
          title: 'GSTIN state code may not match address',
          explanation: vendorLegitimacy['notes']?.toString() ??
              'The GSTIN state code does not appear to match the vendor address region.',
          recommendation: 'Verify vendor identity — GSTIN state code mismatch is a fraud indicator.',
          category: 'Vendor',
        ));
      }
    }

    // Item-category mismatch from AI
    if (json['item_category_match'] == false) {
      aiFindings.add(AnalysisFinding(
        id: 'ai_item_category_mismatch',
        severity: FindingSeverity.suspicious,
        title: 'Items do not match bill type',
        explanation: 'The AI detected that some items on this bill do not match the expected '
            'product category for this bill type (e.g., electronics on a restaurant bill).',
        recommendation: 'Verify the bill is genuine and items are correctly categorized.',
        category: 'AI Audit',
      ));
    }

    // Hidden charges from AI
    if (json['hidden_charges_detected'] == true) {
      aiFindings.add(AnalysisFinding(
        id: 'ai_hidden_charges',
        severity: FindingSeverity.verify,
        title: 'Potential hidden charges detected by AI',
        explanation: 'The AI vision analysis detected potential charges in the bill image '
            'that may not have been captured by OCR extraction.',
        recommendation: 'Review the bill image carefully for any small-print or subtle fees.',
        category: 'AI Audit',
      ));
    }

    // Handwriting inconsistency from AI
    if (json['handwriting_consistent'] == false) {
      aiFindings.add(AnalysisFinding(
        id: 'ai_handwriting_inconsistent',
        severity: FindingSeverity.suspicious,
        title: 'Handwriting inconsistency detected',
        explanation: 'The AI detected inconsistent handwriting styles on this handwritten bill, '
            'which may indicate alteration or tampering.',
        recommendation: 'Verify the bill authenticity — inconsistent handwriting is a tampering indicator.',
        category: 'AI Audit',
      ));
    }

    // Invoice number suspicious from AI
    if (json['invoice_number_suspicious'] == true) {
      aiFindings.add(AnalysisFinding(
        id: 'ai_invoice_suspicious',
        severity: FindingSeverity.verify,
        title: 'Invoice number format seems unusual',
        explanation: 'The AI flagged the invoice number format as unusual or potentially tampered.',
        recommendation: 'Verify the invoice number with the establishment.',
        category: 'AI Audit',
      ));
    }

    return LlmBillResult(bill: enhancedBill, aiFindings: aiFindings);
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '').trim());
    return null;
  }
}
