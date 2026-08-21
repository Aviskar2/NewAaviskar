import '../models/bill_model.dart';
import '../models/analysis_result.dart';
import 'bill_parser_service.dart';
import 'gst_rule_engine.dart';
import 'government_source_service.dart';
import 'charge_analyzer.dart';
import 'llm_bill_service.dart';
import 'pattern_fraud_detector.dart';
import 'ml_fraud_detector.dart';
import 'bill_history_analyzer.dart';

class BillAnalysisOrchestrator {
  final BillParserService _parser = BillParserService();
  final LlmBillService _llmService = LlmBillService();
  final GovernmentSourceService _govService = GovernmentSourceService();
  late final GstRuleEngine _gstEngine;
  late final ChargeAnalyzer _chargeAnalyzer;
  late final PatternFraudDetector _patternDetector;
  late final MlFraudDetector _mlDetector;
  late final BillHistoryAnalyzer _historyAnalyzer;

  BillAnalysisOrchestrator() {
    _gstEngine = GstRuleEngine(_govService);
    _chargeAnalyzer = ChargeAnalyzer(_govService);
    _patternDetector = PatternFraudDetector(_govService);
    _mlDetector = MlFraudDetector(_govService);
    _historyAnalyzer = BillHistoryAnalyzer(_govService);
  }

  /// Full analysis pipeline from raw OCR text or direct image.
  Future<BillAnalysisResult> analyze(
    String rawText, {
    String? imagePath,
    BillType? forcedBillType,
    Map<String, dynamic>? qrData,
  }) async {
    // 1. Parse OCR text deterministically
    final initialBill = _parser.parse(rawText, forcedType: forcedBillType);

    // 2. Enhance with AI (OpenRouter Vision/LLM for handwritten bills, products, taxes & totals)
    final llmResult = await _llmService.enhance(
      initialBill,
      rawText,
      imagePath: imagePath,
    );
    final bill = llmResult.bill;

    final billWithQr = qrData != null
        ? StructuredBill(
            rawText: bill.rawText,
            billType: bill.billType,
            sellerName: bill.sellerName,
            gstin: bill.gstin,
            sellerAddress: bill.sellerAddress,
            customerName: bill.customerName,
            customerGstin: bill.customerGstin,
            invoiceNumber: bill.invoiceNumber,
            invoiceDate: bill.invoiceDate,
            items: bill.items,
            taxes: bill.taxes,
            charges: bill.charges,
            grandTotal: bill.grandTotal,
            discountTotal: bill.discountTotal,
            qrData: qrData,
            confidence: bill.confidence,
            isAiEnhanced: bill.isAiEnhanced,
            aiNotes: bill.aiNotes,
            aiModelUsed: bill.aiModelUsed,
          )
        : bill;

    // 3. GST rule engine (deterministic)
    final gstFindings = _gstEngine.analyze(billWithQr);

    // 4. Charge analyzer
    final chargeFindings = _chargeAnalyzer.analyze(billWithQr);

    // 5. Pattern fraud detector (new)
    final patternFindings = _patternDetector.analyze(billWithQr);

    // 6. ML anomaly detector (new)
    final mlFindings = _mlDetector.analyze(billWithQr);

    // 7. History analyzer (new)
    final historyFindings = _historyAnalyzer.analyze(billWithQr);

    // 8. GSTIN verification
    GstinVerification? gstinVerification;
    if (billWithQr.gstin != null) {
      gstinVerification = await _govService.verifyGstin(
        billWithQr.gstin!,
        sellerName: billWithQr.sellerName,
      );
      gstFindings.add(_gstinFinding(gstinVerification));
    }

    // 9. Item-level results
    final itemResults = _buildItemResults(billWithQr);

    // 10. Record bill for future history analysis
    await _historyAnalyzer.recordBill(billWithQr);

    // 11. All findings merged (including AI-detected fraud flags)
    final allFindings = [
      ...gstFindings,
      ...chargeFindings,
      ...patternFindings,
      ...mlFindings,
      ...historyFindings,
      ...llmResult.aiFindings,
    ];

    // 12. Overall result
    final overallResult = _determineOverall(allFindings);

    // 8. Robust Discrepancy & Financial Computation
    final netBase = billWithQr.taxes.subtotal ??
        (billWithQr.computedSubtotal > 0
            ? billWithQr.computedSubtotal
            : (billWithQr.itemsGrossTotal > 0
                ? (billWithQr.itemsGrossTotal - billWithQr.totalDiscountAmount)
                : null));

    double? computedTotal;
    double? discrepancy;
    double? excess;

    if (netBase != null && netBase > 0) {
      computedTotal = netBase +
          billWithQr.taxes.totalPrintedTax +
          billWithQr.totalCharges +
          (billWithQr.taxes.roundOff ?? 0.0);
    } else if (billWithQr.itemsGrossTotal > 0) {
      computedTotal = billWithQr.itemsGrossTotal -
          billWithQr.totalDiscountAmount +
          billWithQr.taxes.totalPrintedTax +
          billWithQr.totalCharges +
          (billWithQr.taxes.roundOff ?? 0.0);
    } else if (billWithQr.grandTotal != null) {
      computedTotal = billWithQr.grandTotal;
    }

    if (computedTotal != null) {
      computedTotal = double.parse(computedTotal.toStringAsFixed(2));
    }

    if (billWithQr.grandTotal != null && computedTotal != null) {
      discrepancy = (billWithQr.grandTotal! - computedTotal).abs();
      discrepancy = double.parse(discrepancy.toStringAsFixed(2));
      // Flag excess only if printed total exceeds computed total by > ₹2.00 (accounts for minor rounding)
      if (billWithQr.grandTotal! > computedTotal + 2.0) {
        excess = double.parse((billWithQr.grandTotal! - computedTotal).toStringAsFixed(2));
      }
    }

    return BillAnalysisResult(
      bill: billWithQr,
      overallResult: overallResult,
      printedTotal: billWithQr.grandTotal,
      computedTotal: computedTotal,
      totalDiscrepancy: discrepancy,
      potentialExcess: excess,
      findings: allFindings,
      itemResults: itemResults,
      gstinVerification: gstinVerification,
      sources: _govService.allSources,
      analyzedAt: DateTime.now(),
      isOnlineVerified: gstinVerification?.isLiveVerified ?? false,
    );
  }

  OverallResult _determineOverall(List<AnalysisFinding> findings) {
    if (findings.any((f) => f.severity == FindingSeverity.suspicious || f.severity == FindingSeverity.error)) {
      return OverallResult.suspiciousCharges;
    }
    if (findings.any((f) => f.severity == FindingSeverity.verify)) {
      return OverallResult.needsVerification;
    }
    return OverallResult.looksCorrect;
  }

  AnalysisFinding _gstinFinding(GstinVerification v) {
    if (v.status == GstinStatus.valid) {
      return AnalysisFinding(
        id: 'gstin_${v.gstin}',
        severity: v.isLiveVerified ? FindingSeverity.ok : FindingSeverity.verify,
        title: v.isLiveVerified ? 'GSTIN verified online' : 'GSTIN format valid (offline check)',
        explanation: v.isLiveVerified
            ? 'GSTIN ${v.gstin} was verified live from the GST portal. '
                'Registered as: ${v.legalName ?? "N/A"} (${v.registrationStatus ?? "Status unknown"})'
            : 'GSTIN ${v.gstin} passed offline format and checksum validation. '
                '${v.errorMessage ?? ""}',
        category: 'GSTIN',
        source: GovernmentSource(
          title: 'GST Portal — Taxpayer Search',
          description: 'GSTIN validation via government portal.',
          url: 'https://www.gst.gov.in/searchtaxpayer',
          organization: 'GST Portal',
          lastVerified: DateTime.now(),
          status: v.isLiveVerified
              ? SourceVerificationStatus.live
              : SourceVerificationStatus.cached,
        ),
      );
    } else if (v.status == GstinStatus.formatError) {
      return AnalysisFinding(
        id: 'gstin_format_error',
        severity: FindingSeverity.error,
        title: 'GSTIN format is invalid',
        explanation: v.errorMessage ?? 'GSTIN does not match the required format.',
        recommendation: 'Verify the GSTIN is correctly printed on the bill.',
        category: 'GSTIN',
      );
    } else if (v.status == GstinStatus.invalid) {
      return AnalysisFinding(
        id: 'gstin_checksum_fail',
        severity: FindingSeverity.suspicious,
        title: 'GSTIN checksum failed',
        explanation: 'The GSTIN did not pass the standard MOD-37 checksum. '
            'It may be incorrectly printed or fabricated.',
        recommendation: 'Verify the GSTIN on https://www.gst.gov.in/searchtaxpayer',
        category: 'GSTIN',
      );
    } else {
      return AnalysisFinding(
        id: 'gstin_verification_failed',
        severity: FindingSeverity.verify,
        title: 'GSTIN could not be verified online',
        explanation: 'Live GSTIN verification was not available. '
            'The GSTIN format is valid but could not be confirmed online.',
        recommendation: 'Verify manually at https://www.gst.gov.in/searchtaxpayer',
        category: 'GSTIN',
      );
    }
  }

  List<ItemAnalysisResult> _buildItemResults(StructuredBill bill) {
    return bill.items.map((item) {
      final expected = item.expectedTax;
      final printed = item.printedTax;
      double? diff;
      FindingSeverity status = FindingSeverity.ok;
      String? note;

      if (expected != null && printed != null) {
        diff = (printed - expected).abs();
        if (diff > 1.0) {
          status = FindingSeverity.verify;
          note = 'Tax difference of ₹${diff.toStringAsFixed(2)} detected';
        }
      } else if (expected == null && printed == null) {
        status = FindingSeverity.verify;
        note = 'Tax rate could not be verified for this item';
      }

      return ItemAnalysisResult(
        item: item,
        expectedTax: expected,
        printedTax: printed,
        taxDifference: diff,
        status: status,
        note: note,
      );
    }).toList();
  }
}
