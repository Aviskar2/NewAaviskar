import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../config/openrouter_models.dart';
import '../models/analysis_result.dart';
import '../models/bill_model.dart';
import 'gemini_fraud_service.dart';

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
  final GeminiFraudService _geminiService = GeminiFraudService();

  /// Live free models are discovered at runtime (vision-capable first when
  /// analyzing a bill image); see [OpenRouterModelDirectory].

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

    // 1. Prioritize Google Gemini AI for High-Precision Multimodal Fraud Detection
    if (ApiConfig.geminiActive) {
      try {
        final geminiResult = await _geminiService.analyzeBillForFraud(
          initialBill: initialBill,
          rawOcrText: rawOcrText,
          imagePath: imagePath,
        );
        if (geminiResult != null) {
          debugPrint('Gemini AI Fraud Detection completed with ${geminiResult.modelUsed}');
          return LlmBillResult(
            bill: geminiResult.enhancedBill ?? initialBill,
            aiFindings: geminiResult.findings,
          );
        }
      } catch (e) {
        debugPrint('Gemini AI Fraud Detection error: $e. Falling back to secondary models...');
      }
    }

    if (!ApiConfig.aiActive) {
      debugPrint('Skipping secondary LLM enhancement: OpenRouter API key not configured.');
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

    // Tight budget — deterministic fallback is fast, don't block the user.
    final budget = base64Image != null ? 12 : 10;
    try {
      return await _tryModels(initialBill, rawOcrText, base64Image)
          .timeout(Duration(seconds: budget), onTimeout: () {
        debugPrint(
            'LLM enhancement timed out (${budget}s limit). Proceeding with deterministic results.');
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
    // Text-only bills skip vision-only models entirely — those pools are
    // separate and often congested while text models respond fine.
    final candidates = base64Image != null
        ? OpenRouterModelDirectory.visionCandidates()
        : OpenRouterModelDirectory.textCandidates();
    int attempt = 0;
    for (final model in await candidates) {
      if (attempt > 0) {
        // Exponential backoff to avoid OpenRouter 429 rate limit spikes
        final backoffMs = (400 * (1 << (attempt - 1))).clamp(400, 1500);
        await Future.delayed(Duration(milliseconds: backoffMs));
      }
      attempt++;
      try {
        final result = await _callOpenRouter(model, rawOcrText, base64Image, initialBill)
            .timeout(const Duration(seconds: 5));
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
You are an expert Indian Bill, Invoice, Receipt & Handwritten Slip Auditor specializing in Indian GST law.

CRITICAL INSTRUCTIONS:

1. FINANCIAL SUMMARY & ARITHMETIC (EXTREME ACCURACY):
   - "taxable_amount": Base amount before GST taxes. If prices are tax-inclusive (MRP), compute taxable base = (Gross - Discount) / (1 + total GST rate/100).
   - "grand_total": The EXACT final net payable invoice amount that the customer pays.
   - "discount_total": Any trade discount, coupon, or savings deducted.
   - CROSS-VERIFY MATH: grand_total MUST EQUAL taxable_amount + cgst_amount + sgst_amount + igst_amount + cess_amount + charges - discount ± round_off. If your numbers don't add up, recalculate until they do.
   - CRITICAL: When reading GST amounts from the bill, use EXACTLY what is printed. Do NOT round or alter numbers. If bill says CGST 2.5% = 11.75, report exactly 2.5% and 11.75.

2. ACCURATE GST BREAKDOWN (INDIAN GST LAW):
   - Standard GST slabs in India: 0%, 0.25%, 0.5%, 1%, 1.5%, 3%, 5%, 6%, 9%, 12%, 14%, 18%, 28%
   - "cgst_rate" / "cgst_amount": Central GST. Rate MUST be one of the standard slabs above.
   - "sgst_rate" / "sgst_amount": State GST. For intra-state: SGST rate = CGST rate, SGST amount = CGST amount.
   - "igst_rate" / "igst_amount": Integrated GST (inter-state only). IGST rate = CGST + SGST combined.
   - "cess_amount": Compensation cess if applicable (usually on luxury/sin goods).
   - NEVER report a GST rate like 2.58%, 6.12%, 18.03% etc. Rates MUST be standard slab values.
   - If the bill shows CGST@2.5% and SGST@2.5%, the total GST is 5%.
   - If the bill shows IGST@5%, the total GST is 5% (inter-state).

3. HANDWRITTEN BILLS & RECEIPTS:
   - Carefully decipher handwriting (in English, Hindi, Hinglish, or regional terms).
   - Accurately read handwritten item names, quantities, unit prices, and line amounts.
   - Check if the manual handwritten addition done by the shopkeeper is mathematically correct.

4. ITEMS & PRODUCTS:
   - Clean up garbled OCR / handwriting to clear product names.
   - Extract exact quantity, unit price, and line total for each item.

5. BILL TYPE & LEGAL COMPLIANCE (INDIAN CONSUMER LAW):
   - Detect correct bill_type.
   - SERVICE CHARGE: Under CCPA guidelines (2022), restaurants/hotels CANNOT impose mandatory service charge. It must be optional. If found, flag as "verify" severity with explanation.
   - GST ON SERVICE CHARGE: If GST is charged on service charge amount, flag as suspicious.
   - WRONG GST RATE: If any item has a GST rate that doesn't match standard Indian slabs, flag it.
   - OVERCHARGING: If printed total > calculated total by more than ₹2, flag as overcharge.

6. ADVANCED FRAUD DETECTION:
   - Vendor legitimacy: GSTIN state code vs address region.
   - Item category mismatch: Items not matching bill type.
   - Hidden charges: Subtle fees in small print.
   - Handwriting consistency: Same pen/hand throughout.
   - Duplicate invoice check.

Respond strictly with ONLY valid raw JSON (no markdown, no explanation):
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
  "ai_summary": "Simple summary of what was found"
}
''';

    final uri = Uri.parse('${ApiConfig.openRouterBaseUrl}/chat/completions');

    final sanitizedPrompt = systemPrompt.replaceAll('\u00A0', ' ');
    final sanitizedOcr = rawOcrText.replaceAll('\u00A0', ' ');

    // Build message content supporting both vision and text
    dynamic userMessageContent;
    if (base64Image != null && base64Image.isNotEmpty) {
      userMessageContent = [
        {
          'type': 'text',
          'text': 'Analyze this Indian bill (it may be printed or a handwritten slip/parchi). Decipher all handwriting and text, calculate financial totals, GST breakdown, and item details with high accuracy.\n\nRaw OCR text (if any):\n$sanitizedOcr',
        },
        {
          'type': 'image_url',
          'image_url': {
            'url': 'data:image/jpeg;base64,$base64Image',
          },
        },
      ];
    } else {
      userMessageContent = 'Here is the raw OCR text of the bill:\n\n$sanitizedOcr';
    }

    final jsonPayload = jsonEncode({
      'model': model,
      'temperature': 0.1,
      'messages': [
        {'role': 'system', 'content': sanitizedPrompt},
        {'role': 'user', 'content': userMessageContent},
      ],
    }).replaceAll('\u00A0', ' ');

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer ${ApiConfig.effectiveApiKey}',
        'HTTP-Referer': ApiConfig.appSiteUrl,
        'X-Title': ApiConfig.appName,
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: utf8.encode(jsonPayload),
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      debugPrint('OpenRouter response code ${response.statusCode}: ${response.body}');
      // Gated or retired models will never succeed — skip them next time.
      if (response.statusCode == 403 || response.statusCode == 404) {
        OpenRouterModelDirectory.blockModel(model);
      } else if (response.statusCode == 429) {
        // Shared free pool congested — back off briefly, try healthy models.
        OpenRouterModelDirectory.coolDown(model);
      }
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

    // Taxes — snap rates to standard Indian GST slabs
    final rawCgstRate = _toDouble(json['cgst_rate']);
    final rawSgstRate = _toDouble(json['sgst_rate']);
    final rawIgstRate = _toDouble(json['igst_rate']);

    final taxes = BillTaxSection(
      subtotal: _toDouble(json['taxable_amount']) ?? baseBill.taxes.subtotal,
      cgstAmount: _toDouble(json['cgst_amount']) ?? baseBill.taxes.cgstAmount,
      sgstAmount: _toDouble(json['sgst_amount']) ?? baseBill.taxes.sgstAmount,
      igstAmount: _toDouble(json['igst_amount']) ?? baseBill.taxes.igstAmount,
      cessAmount: _toDouble(json['cess_amount']) ?? baseBill.taxes.cessAmount,
      cgstRate: rawCgstRate != null ? _snapGstRate(rawCgstRate) : baseBill.taxes.cgstRate,
      sgstRate: rawSgstRate != null ? _snapGstRate(rawSgstRate) : baseBill.taxes.sgstRate,
      igstRate: rawIgstRate != null ? _snapGstRate(rawIgstRate) : baseBill.taxes.igstRate,
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

  /// Snap a GST rate to the nearest standard Indian GST slab.
  /// Returns the standard slab if within 0.6%, otherwise returns original.
  static double _snapGstRate(double rate) {
    const slabs = [0.0, 0.25, 0.5, 1.0, 1.5, 3.0, 5.0, 6.0, 9.0, 12.0, 14.0, 18.0, 28.0];
    double best = rate;
    double bestDist = 999;
    for (final slab in slabs) {
      final dist = (rate - slab).abs();
      if (dist < bestDist) {
        bestDist = dist;
        best = slab;
      }
    }
    return bestDist <= 0.6 ? best : rate;
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '').trim());
    return null;
  }
}
