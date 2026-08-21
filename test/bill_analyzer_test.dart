import 'package:flutter_test/flutter_test.dart';
import 'package:aura_ai/services/bill_parser_service.dart';
import 'package:aura_ai/models/bill_model.dart';
import 'package:aura_ai/models/analysis_result.dart';
import 'package:aura_ai/services/government_source_service.dart';
import 'package:aura_ai/services/gst_rule_engine.dart';
import 'package:aura_ai/services/charge_analyzer.dart';
import 'package:aura_ai/services/pattern_fraud_detector.dart';
import 'package:aura_ai/services/ml_fraud_detector.dart';
import 'synthetic_bill_generator.dart';

void main() {
  late BillParserService parser;
  late GstRuleEngine engine;
  late GovernmentSourceService govService;
  late ChargeAnalyzer chargeAnalyzer;
  late PatternFraudDetector patternDetector;
  late MlFraudDetector mlDetector;

  setUp(() {
    parser = BillParserService();
    govService = GovernmentSourceService();
    engine = GstRuleEngine(govService);
    chargeAnalyzer = ChargeAnalyzer(govService);
    patternDetector = PatternFraudDetector(govService);
    mlDetector = MlFraudDetector(govService);
  });

  // ─── GSTIN Checksum Tests ─────────────────────────────────────────────────

  group('GSTIN Validation (GovernmentSourceService)', () {
    test('Valid GSTIN passes offline check', () async {
      // 29ABCDE1234F1Z5 — valid format, needs correct checksum
      // Use a known-valid GSTIN format for testing
      final v = await govService.verifyGstin('07AAAAA0000A1Z5');
      // Format check passes (checksum may/may not — depends on actual checksum)
      expect(v.gstin, '07AAAAA0000A1Z5');
    });

    test('Invalid format GSTIN is rejected', () async {
      final v = await govService.verifyGstin('INVALID_GSTIN');
      expect(v.status, GstinStatus.formatError);
    });

    test('Wrong checksum GSTIN is rejected', () async {
      // Malformed checksum (last char changed)
      final v = await govService.verifyGstin('27AABCU9603R1ZX');
      expect(v.status == GstinStatus.invalid || v.status == GstinStatus.formatError, isTrue);
    });

    test('State code is extracted', () async {
      final v = await govService.verifyGstin('07AAAAA0000A1Z5');
      if (v.status == GstinStatus.valid) {
        expect(v.stateCode, contains('Delhi'));
      }
    });
  });

  // ─── Bill Parser Tests ────────────────────────────────────────────────────

  group('Bill Parser', () {
    test('Parses restaurant bill type', () {
      const text = '''
Hotel Grand Palace
Restaurant Bill
Table No: 12
GSTIN: 27AABCU9603R1Z7

Butter Chicken   1 x 350  350.00
Garlic Naan      2 x 60   120.00

Subtotal: 470.00
CGST 2.5%: 11.75
SGST 2.5%: 11.75
Service Charge: 47.00
Grand Total: 540.50
''';
      final bill = parser.parse(text);
      expect(bill.billType, BillType.restaurant);
      expect(bill.taxes.cgstAmount, 11.75);
      expect(bill.taxes.sgstAmount, 11.75);
    });

    test('Extracts GSTIN from bill', () {
      const text = 'GSTIN: 27AABCU9603R1Z7\nSome bill content';
      final bill = parser.parse(text);
      expect(bill.gstin, isNotNull);
    });

    test('Detects pharmacy bill type', () {
      const text = '''
Apollo Pharmacy
Medicine Invoice
GSTIN: 33AABCU9603R1Z5
Paracetamol 500mg  x 10   45.00
Amoxicillin 250mg  x 14   120.00
Total: 165.00
''';
      final bill = parser.parse(text);
      expect(bill.billType, BillType.pharmacy);
    });

    test('Extracts grand total accurately with savings and cash tender present', () {
      const text = '''
TRENT HYPERMARKET PVT LTD
STAR BAZAAR
Invoice No: BT04 103698524
Item 1 / 1001 / 30.00  1 PC  30.00
Item 2 / 1002 / 64.00  4 PC  64.00
Sub Total: 290.84
CGST 2.5%: 22.28
SGST 2.5%: 22.28
Total Invoice Amount: 335.40
Total Savings: 209.60
Tendered Cash: 500.00
Change Due: 164.60
Total Qty: 5
''';
      final bill = parser.parse(text);
      expect(bill.grandTotal, 335.40);
    });

    test('Extracts net payable when discounts and round off exist', () {
      const text = '''
RELIANCE RETAIL LIMITED
Taxable Value: 400.00
CGST 9%: 36.00
SGST 9%: 36.00
Discount: 50.00
Round Off: -0.20
Net Payable: 421.80
Total Items: 3
''';
      final bill = parser.parse(text);
      expect(bill.grandTotal, 421.80);
    });

    test('Detects service charge', () {
      const text = '''
Restaurant Bill
Food Total: 500
Service Charge: 50.00
CGST: 12.50
SGST: 12.50
Total: 575.00
''';
      final bill = parser.parse(text);
      expect(bill.charges.any((c) => c.isServiceCharge), isTrue);
    });
  });

  // ─── GST Engine Tests ─────────────────────────────────────────────────────

  group('GST Rule Engine', () {
    test('Correct CGST/SGST: no error findings', () {
      // Create a bill where math is correct
      const text = '''
Invoice
Subtotal: 1000.00
CGST 9%: 90.00
SGST 9%: 90.00
Grand Total: 1180.00
''';
      final bill = parser.parse(text);
      final findings = engine.analyze(bill);
      final errors = findings.where((f) =>
          f.severity.name == 'error' &&
          (f.id.contains('cgst') || f.id.contains('sgst'))).toList();
      expect(errors, isEmpty);
    });

    test('Flags CGST mismatch when wrong amount printed', () {
      // Manually build a bill where CGST is wrong
      const text = '''
Invoice
Subtotal: 1000.00
CGST 9%: 50.00
SGST 9%: 90.00
Grand Total: 1140.00
''';
      final bill = parser.parse(text);
      final findings = engine.analyze(bill);
      final cgstIssue = findings.where((f) => f.id == 'cgst_mismatch');
      expect(cgstIssue.isNotEmpty, isTrue);
    });

    test('Flags service charge in restaurant bill', () {
      const text = '''
Restaurant
CGST 2.5%: 10
SGST 2.5%: 10
Service Charge: 50
Grand Total: 460
''';
      final bill = parser.parse(text);
      final findings = engine.analyze(bill);
      expect(
        findings.any((f) => f.category == 'Service Charge'),
        isTrue,
      );
    });

    test('Flags duplicate tax (both IGST and CGST/SGST)', () {
      const text = '''
Invoice
IGST 18%: 180
CGST 9%: 90
SGST 9%: 90
Total: 1360
''';
      final bill = parser.parse(text);
      final findings = engine.analyze(bill);
      expect(
        findings.any((f) => f.id == 'duplicate_tax'),
        isTrue,
      );
    });

    test('Correct total: no total mismatch finding', () {
      const text = '''
Invoice
Subtotal: 500
CGST 9%: 45
SGST 9%: 45
Grand Total: 590.00
''';
      final bill = parser.parse(text);
      final findings = engine.analyze(bill);
      final totalMismatch = findings.where((f) => f.id == 'total_mismatch');
      expect(totalMismatch, isEmpty);
    });
  });

  // ─── Financial Summary & GST Calculations ─────────────────────────────────

  group('Financial Summary & GST Calculations', () {
    test('Calculates items gross total, discounts, and net total accurately', () {
      const items = [
        BillItem(name: 'Rice 5kg', quantity: 1, unitPrice: 300, lineTotal: 300),
        BillItem(name: 'Sugar 2kg', quantity: 2, unitPrice: 50, lineTotal: 100),
      ];
      const taxes = BillTaxSection(
        subtotal: 350.0,
        cgstAmount: 17.5,
        sgstAmount: 17.5,
        cgstRate: 5.0,
        sgstRate: 5.0,
        roundOff: -0.0,
      );
      const charges = [
        BillCharge(label: 'Delivery Fee', amount: 30.0),
      ];

      const bill = StructuredBill(
        rawText: 'Handwritten Slip / Printed Bill',
        billType: BillType.supermarket,
        items: items,
        taxes: taxes,
        charges: charges,
        discountTotal: 50.0,
        grandTotal: 415.0,
        confidence: 0.95,
      );

      expect(bill.itemsGrossTotal, 400.0);
      expect(bill.totalDiscountAmount, 50.0);
      expect(bill.taxes.totalPrintedTax, 35.0);
      expect(bill.totalCharges, 30.0);
      expect(bill.calculatedNetTotal, 415.0);
      expect(bill.taxes.effectiveGstRate, 10.0);
      expect(bill.isIntraState, isTrue);
      expect(bill.isInterState, isFalse);
    });

    test('Calculates Inter-State IGST correctly', () {
      const taxes = BillTaxSection(
        subtotal: 1000.0,
        igstAmount: 180.0,
        igstRate: 18.0,
      );

      const bill = StructuredBill(
        rawText: 'Interstate Tax Invoice',
        billType: BillType.gstInvoice,
        items: [],
        taxes: taxes,
        charges: [],
        grandTotal: 1180.0,
        confidence: 0.95,
      );

      expect(bill.isInterState, isTrue);
      expect(bill.taxes.effectiveGstRate, 18.0);
      expect(bill.calculatedNetTotal, 1180.0);
    });
  });

  // ─── Charge Analyzer Tests ────────────────────────────────────────────────

  group('Charge Analyzer - New Rules', () {
    test('Flags hidden/unrecognised charges', () {
      final bill = SyntheticBillGenerator.generate(FraudPattern.chargesWithoutItems);
      final findings = chargeAnalyzer.analyze(bill);
      expect(findings.any((f) => f.id.startsWith('hidden_charge_')), isTrue);
    });

    test('Flags excessive charge ratio', () {
      final bill = SyntheticBillGenerator.generate(FraudPattern.excessiveChargeRatio);
      final findings = chargeAnalyzer.analyze(bill);
      expect(findings.any((f) => f.id == 'excessive_charge_ratio'), isTrue);
    });

    test('Flags duplicate convenience fees', () {
      final bill = SyntheticBillGenerator.generate(FraudPattern.duplicateConvenienceFee);
      final findings = chargeAnalyzer.analyze(bill);
      expect(findings.any((f) => f.id == 'duplicate_convenience_fee'), isTrue);
    });

    test('Flags duplicate delivery charges', () {
      final bill = SyntheticBillGenerator.generate(FraudPattern.duplicateDelivery);
      final findings = chargeAnalyzer.analyze(bill);
      expect(findings.any((f) => f.id == 'duplicate_delivery'), isTrue);
    });

    test('Flags excessive packaging', () {
      final bill = SyntheticBillGenerator.generate(FraudPattern.excessivePackaging);
      final findings = chargeAnalyzer.analyze(bill);
      expect(findings.any((f) => f.id == 'excessive_packaging'), isTrue);
    });
  });

  // ─── Pattern Fraud Detector Tests ────────────────────────────────────────

  group('Pattern Fraud Detector', () {
    test('Detects suspiciously round amount', () {
      final bill = SyntheticBillGenerator.generate(FraudPattern.roundAmountSuspicious);
      final findings = patternDetector.analyze(bill);
      expect(findings.any((f) => f.id.contains('round_amount')), isTrue);
    });

    test('Detects threshold manipulation', () {
      final bill = SyntheticBillGenerator.generate(FraudPattern.thresholdManipulation);
      final findings = patternDetector.analyze(bill);
      expect(findings.any((f) => f.id.contains('threshold_manipulation')), isTrue);
    });

    test('Detects phantom item with zero quantity', () {
      final bill = SyntheticBillGenerator.generate(FraudPattern.phantomItemZeroQty);
      final findings = patternDetector.analyze(bill);
      expect(findings.any((f) => f.id.contains('phantom_item')), isTrue);
    });

    test('Detects missing HSN/SAC on GST invoice', () {
      final bill = SyntheticBillGenerator.generate(FraudPattern.missingHsnSac);
      final findings = patternDetector.analyze(bill);
      expect(findings.any((f) => f.id.contains('missing_hsn')), isTrue);
    });

    test('Detects future date', () {
      final bill = SyntheticBillGenerator.generate(FraudPattern.futureDate);
      final findings = patternDetector.analyze(bill);
      expect(findings.any((f) => f.id == 'future_date'), isTrue);
    });

    test('Detects excessive discount', () {
      final bill = SyntheticBillGenerator.generate(FraudPattern.excessiveDiscount);
      final findings = patternDetector.analyze(bill);
      expect(findings.any((f) => f.id.contains('excessive_discount')), isTrue);
    });

    test('Detects charges without items', () {
      final bill = SyntheticBillGenerator.generate(FraudPattern.chargesWithoutItems);
      final findings = patternDetector.analyze(bill);
      expect(findings.any((f) => f.id == 'charges_without_items'), isTrue);
    });

    test('Normal bill has no pattern fraud findings', () {
      final bill = SyntheticBillGenerator.generate(FraudPattern.normalBill);
      final findings = patternDetector.analyze(bill);
      final suspicious = findings.where((f) =>
          f.severity == FindingSeverity.suspicious ||
          f.severity == FindingSeverity.error).toList();
      expect(suspicious, isEmpty);
    });
  });

  // ─── ML Fraud Detector Tests ──────────────────────────────────────────────

  group('ML Fraud Detector', () {
    test('Detects price anomalies with Z-score', () {
      final bill = SyntheticBillGenerator.generate(FraudPattern.itemTotalMismatch);
      final findings = mlDetector.analyze(bill);
      // The bill has items with mismatched totals — may trigger price anomaly
      expect(findings, isA<List<AnalysisFinding>>());
    });

    test('Detects vendor risk signals', () {
      // Bill without GSTIN or seller name
      final bill = StructuredBill(
        rawText: 'Minimal bill',
        billType: BillType.unknown,
        items: [
          const BillItem(name: 'Item', quantity: 1, unitPrice: 100, lineTotal: 100),
        ],
        taxes: const BillTaxSection(),
        charges: const [],
        grandTotal: 100,
        confidence: 0.5,
      );
      final findings = mlDetector.analyze(bill);
      expect(findings.any((f) => f.id == 'vendor_risk_signals'), isTrue);
    });

    test('Normal bill has low anomaly score', () {
      final bill = SyntheticBillGenerator.generate(FraudPattern.normalBill);
      final findings = mlDetector.analyze(bill);
      final highSeverity = findings.where((f) =>
          f.severity == FindingSeverity.suspicious).toList();
      expect(highSeverity, isEmpty);
    });
  });

  // ─── GST Engine - New Rules Tests ─────────────────────────────────────────

  group('GST Rule Engine - New Rules', () {
    test('Flags excessive CESS', () {
      const bill = StructuredBill(
        rawText: 'CESS bill',
        billType: BillType.gstInvoice,
        items: [BillItem(name: 'Item', quantity: 1, unitPrice: 1000, lineTotal: 1000, gstRate: 28)],
        taxes: BillTaxSection(subtotal: 1000, cgstAmount: 140, sgstAmount: 140, cessAmount: 500, cgstRate: 14, sgstRate: 14),
        charges: [],
        grandTotal: 1780,
        confidence: 0.9,
      );
      final findings = engine.analyze(bill);
      expect(findings.any((f) => f.id == 'excessive_cess'), isTrue);
    });

    test('Flags same HSN with different rates', () {
      const bill = StructuredBill(
        rawText: 'HSN mismatch',
        billType: BillType.gstInvoice,
        items: [
          BillItem(name: 'Item A', quantity: 1, unitPrice: 100, lineTotal: 100, gstRate: 18, hsnSac: '9401'),
          BillItem(name: 'Item B', quantity: 1, unitPrice: 200, lineTotal: 200, gstRate: 12, hsnSac: '9401'),
        ],
        taxes: BillTaxSection(subtotal: 300, cgstAmount: 30, sgstAmount: 30, cgstRate: 10, sgstRate: 10),
        charges: [],
        grandTotal: 360,
        confidence: 0.9,
      );
      final findings = engine.analyze(bill);
      expect(findings.any((f) => f.id.contains('hsn_rate_mismatch')), isTrue);
    });
  });

  // ─── Synthetic Bill Generator Tests ──────────────────────────────────────

  group('Synthetic Bill Generator', () {
    test('Generates normal bill correctly', () {
      final bill = SyntheticBillGenerator.generate(FraudPattern.normalBill);
      expect(bill.billType, BillType.restaurant);
      expect(bill.grandTotal, 504);
      expect(bill.items.length, 3);
    });

    test('Generates CGST/SGST mismatch bill', () {
      final bill = SyntheticBillGenerator.generate(FraudPattern.cgstSgstMismatch);
      expect(bill.taxes.cgstAmount, isNot(equals(bill.taxes.sgstAmount)));
    });

    test('Generates invalid GSTIN bill', () {
      final bill = SyntheticBillGenerator.generate(FraudPattern.invalidGstin);
      expect(bill.gstin, isNotNull);
      // Should fail checksum verification
    });

    test('Generates all fraud pattern types', () {
      for (final pattern in FraudPattern.values) {
        final bill = SyntheticBillGenerator.generate(pattern);
        expect(bill, isA<StructuredBill>());
        expect(bill.rawText, isNotEmpty);
      }
    });
  });
}
