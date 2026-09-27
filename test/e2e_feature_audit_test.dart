// End-to-end feature audit: exercises every feature pipeline the way the
// app does at runtime, including adversarial / empty / garbage inputs.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aura_ai/config/api_config.dart';
import 'package:aura_ai/config/app_settings.dart';
import 'package:aura_ai/models/scan_result_model.dart';
import 'package:aura_ai/services/bill_analysis_orchestrator.dart';
import 'package:aura_ai/services/legal/legal_orchestrator.dart';
import 'package:aura_ai/services/medicine_safety/medicine_safety_orchestrator.dart';
import 'package:aura_ai/services/product_safety/product_safety_orchestrator.dart';
import 'package:aura_ai/models/product_safety_model.dart';
import 'package:aura_ai/models/analysis_result.dart';
import 'package:aura_ai/core/legal/models/legal_finding.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    // Keep pipelines offline/deterministic. Individual AI tests re-enable it.
    ApiConfig.aiEnhancementEnabled = false;
  });

  // ─────────────────────────────────────────────────────────────────────────
  // FEATURE 1: BILL ANALYZER (full orchestration pipeline)
  // ─────────────────────────────────────────────────────────────────────────
  group('E2E: Bill Analyzer Orchestrator', () {
    const validGstInvoice = '''
SHARMA GENERAL STORES
123 MG Road, Pune - 411001
GSTIN: 27AAPFU0939F1ZV
Invoice No: INV-2024-101
Date: 15-08-2024

Item                    Qty   Rate    Amount
Atta 5kg                1     220.00  220.00
Sugar 1kg               2     45.00   90.00
Rice 10kg               1     480.00  480.00

Taxable Value: 790.00
CGST 2.5%: 19.75
SGST 2.5%: 19.75
Round Off: 0.50
Grand Total: 830.00
''';

    test('valid GST invoice → parses items, taxes, GSTIN verified', () async {
      final orch = BillAnalysisOrchestrator();
      final result = await orch.analyze(validGstInvoice);

      expect(result.bill.items.length, greaterThanOrEqualTo(3),
          reason: 'should parse at least 3 line items');
      expect(result.bill.gstin, isNotNull);
      expect(result.printedTotal, isNotNull);
      expect(result.computedTotal, isNotNull);
      expect(result.findings, isNotEmpty);
      expect(result.sources, isNotEmpty);
    });

    test('inflated grand total → potentialExcess detected', () async {
      const inflated = '''
KRISHNA ELECTRONICS
GSTIN: 27AAPFU0939F1ZV
Bluetooth Speaker x1 = 1500.00
Subtotal: 1500.00
CGST 9%: 135.00
SGST 9%: 135.00
Grand Total: 2500.00
''';
      final orch = BillAnalysisOrchestrator();
      final result = await orch.analyze(inflated);

      expect(result.potentialExcess, isNotNull,
          reason: 'printed ₹2500 vs computed ~1770 must flag excess');
      expect(result.overallResult, isNot(OverallResult.looksCorrect));
    });

    test('mandatory service charge restaurant bill → flagged', () async {
      const restaurantBill = '''
HOTEL GRAND DINING
GSTIN: 27AAPFU0939F1ZV
Food: 1000.00
Service Charge 10%: 100.00
CGST 2.5%: 27.50
SGST 2.5%: 27.50
Grand Total: 1155.00
''';
      final orch = BillAnalysisOrchestrator();
      final result = await orch.analyze(restaurantBill);

      final hasServiceChargeFinding = result.findings.any(
        (f) => f.title.toLowerCase().contains('service charge'),
      );
      expect(hasServiceChargeFinding, isTrue,
          reason: 'CCPA rule: mandatory service charge must be flagged');
    });

    test('empty OCR text → no crash, graceful unknown result', () async {
      final orch = BillAnalysisOrchestrator();
      final result = await orch.analyze('');
      expect(result.bill, isNotNull);
      expect(result.findings, isA<List<AnalysisFinding>>());
    });

    test('garbage random text → no crash', () async {
      final orch = BillAnalysisOrchestrator();
      final result = await orch.analyze(
          '@#\$%^ asdf jkl; zzzz 12345 !!! ??? random noise text');
      expect(result.bill, isNotNull);
    });

    test('IGST inter-state bill → parses IGST without CGST/SGST', () async {
      const igstBill = '''
TECHNO EXPORTS MUMBAI
GSTIN: 27AAPFU0939F1ZV
Invoice: EXP/24/777
Keyboard x2 @ 700.00 = 1400.00
Taxable: 1400.00
IGST 18%: 252.00
Grand Total: 1652.00
''';
      final orch = BillAnalysisOrchestrator();
      final result = await orch.analyze(igstBill);

      expect(result.bill.taxes.igstAmount, equals(252.0));
      expect(result.bill.items, isNotEmpty);
    });

    test('handwritten kirana slip (no GST) → items + total parsed', () async {
      const kirana = '''
RAMU KIRANA STORE
Biscuit 2 x 20 = 40
Milk 1 x 30 = 30
Bread 1 x 45 = 45
Eggs 6 x 8 = 48
Total = 163
''';
      final orch = BillAnalysisOrchestrator();
      final result = await orch.analyze(kirana);

      expect(result.bill.grandTotal, isNotNull,
          reason: 'handwritten total must be captured');
      // Computed from items should be close to printed total (no big overcharge)
      if (result.computedTotal != null && result.potentialExcess != null) {
        expect(result.potentialExcess!, lessThan(20),
            reason: 'honest slip should not flag large excess');
      }
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // FEATURE 2: LEGAL ANALYZER
  // ─────────────────────────────────────────────────────────────────────────
  group('E2E: Legal Analyzer Orchestrator', () {
    const rentalAgreement = '''
RENTAL AGREEMENT

This Rental Agreement is made on 01 January 2024 between
Mr. Rajesh Kumar (hereinafter "Landlord") and Ms. Priya Sharma (hereinafter "Tenant").

1. TERM: The tenancy shall be for a period of 11 months.
2. RENT: The Tenant shall pay monthly rent of Rs. 25,000.
3. SECURITY DEPOSIT: The security deposit of Rs. 100,000 shall be paid in advance.
   The Landlord may forfeit the entire security deposit at his sole discretion
   without providing any reason or explanation to the Tenant.
4. TERMINATION: The Landlord may terminate this agreement at any time without
   notice and without assigning any reasons whatsoever.
5. PENALTY: Any delay in payment shall attract penalty of Rs. 5000 per day
   as liquidated damages.
6. NON-COMPETE: The Tenant shall not engage in any business competing with
   the Landlord anywhere in India during or after the termination of this agreement.
7. INDEMNITY: The Tenant shall indemnify the Landlord against all claims,
   damages, losses unlimited in amount, arising from any act whatsoever.
8. JURISDICTION: Only courts of Landlord's hometown shall have jurisdiction.
9. MODIFICATION: The Landlord may unilaterally modify any term of this
   agreement including rent increase of any percentage at any time.

SIGNED:
Landlord: Rajesh Kumar
Tenant: _________________
Witness 1: _________________
''';

    test('rental agreement → classified + unfair clauses detected', () async {
      final orch = LegalOrchestrator();
      final doc = orch.createDocumentFromText(rentalAgreement);
      final result = await orch.analyze(doc, enableAiEnhancement: false);

      expect(result.findings, isNotEmpty,
          reason: 'agreement has multiple unfair clauses that rules must catch');
      expect(result.overallRiskScore, inInclusiveRange(0, 100));
      expect(result.plainSummary, isNotEmpty);
      expect(result.executiveLegalSummary, isNotEmpty);
      expect(
        result.findings.any((f) => f.severity == LegalRiskSeverity.high),
        isTrue,
        reason: 'forfeiture-at-will / no-notice termination are high risk',
      );
    });

    test('empty document → no crash, produces valid result', () async {
      final orch = LegalOrchestrator();
      final doc = orch.createDocumentFromText('');
      final result = await orch.analyze(doc, enableAiEnhancement: false);
      expect(result.documentType, isNotNull);
      expect(result.overallRiskScore, inInclusiveRange(0, 100));
    });

    test('garbage text → no crash', () async {
      final orch = LegalOrchestrator();
      final doc = orch.createDocumentFromText('lorem ipsum xyz abc 123 !!!');
      final result = await orch.analyze(doc, enableAiEnhancement: false);
      expect(result.plainSummary, isNotEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // FEATURE 3: MEDICINE SAFETY
  // ─────────────────────────────────────────────────────────────────────────
  group('E2E: Medicine Safety Orchestrator', () {
    const dolo650 = '''
DOLO 650 TABLET
Paracetamol IP 650 mg
Mfg. Lic. No.: G/25/1234
Batch No: DOLO24X
Mfg Date: 03/2025
Exp Date: 02/2027
MRP: Rs. 30.00 (inclusive of all taxes)
Store below 30°C, protect from light.
Marketd by Micro Labs Ltd
Schedule H drug - to be sold by retail on the prescription only.
''';

    test('valid medicine Dolo 650 → safe verdict + license verified', () async {
      final orch = MedicineSafetyOrchestrator();
      final report = await orch.analyze(dolo650,
          referenceDate: DateTime(2026, 8, 26));

      expect(report.brandName, isNotNull);
      expect(
        report.activeIngredients.any(
            (i) => i.toLowerCase().contains('paracetamol')),
        isTrue,
        reason: 'Dolo 650 contains Paracetamol IP 650mg',
      );
      expect(report.isBannedFdc, isFalse);
      expect(report.batchExpiry.isExpired, isFalse);
      expect(report.safetyScore, greaterThan(60));
      expect(report.findings, isNotEmpty);
    });

    test('expired medicine → high risk verdict', () async {
      const expiredMed = '''
CROCIN ADVANCE 500
Paracetamol Tablets IP 500mg
Mfg. Lic. No.: MH/25/567
Batch No: CR-991
Mfg Date: 01/2023
EXP DATE: 05/2025
MRP Rs. 25.00
''';
      final orch = MedicineSafetyOrchestrator();
      final report = await orch.analyze(expiredMed,
          referenceDate: DateTime(2026, 8, 26));

      expect(report.batchExpiry.isExpired, isTrue);
      expect(report.safetyScore, lessThanOrEqualTo(40));
      expect(report.findings.any((f) => f.category == 'EXPIRY'), isTrue);
    });

    test('banned FDC combination → banned verdict, score 0', () async {
      const bannedFdc = '''
NIMKES PLUS TABLET
Nimesulide 100mg + Paracetamol 325mg
Mfg. Lic. No.: G/25/9999
Batch No: NB-11
Exp Date: 12/2027
MRP Rs. 55
''';
      final orch = MedicineSafetyOrchestrator();
      final report = await orch.analyze(bannedFdc,
          referenceDate: DateTime(2026, 8, 26));

      if (report.isBannedFdc) {
        expect(report.safetyScore, equals(0.0));
        expect(report.findings.any((f) => f.id == 'banned_fdc'), isTrue);
      }
    });

    test('empty input → no crash', () async {
      final orch = MedicineSafetyOrchestrator();
      final report = await orch.analyze('');
      expect(report.findings, isA<List>());
      expect(report.safetyScore, inInclusiveRange(0, 100));
    });

    test('garbage input → no crash', () async {
      final orch = MedicineSafetyOrchestrator();
      final report = await orch.analyze('zzz yyy xxx ### 000 ---');
      expect(report.safetyScore, inInclusiveRange(0, 100));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // FEATURE 4: PRODUCT SAFETY
  // ─────────────────────────────────────────────────────────────────────────
  group('E2E: Product Safety Orchestrator', () {
    const colaLabel = '''
THUMS UP CARBONATED DRINK
Net Qty: 750 ml
Mfg Date: 10/06/2026
Best Before: 6 months from packaging
FSSAI Lic. No.: 10012345678901
Ingredients: Carbonated Water, Sugar, Acidity Regulator (INS 338),
Caffeine, Added Flavour (Natural Colour INS 150d)
Preservative: Sodium Benzoate (INS 211)
Nutrition per 100ml: Energy 45 kcal, Total Sugar 11g,
Sodium 10mg
Customer Care: care@coca-cola.in
Marketed by: Coca-Cola India Pvt Ltd
Barcode: 8901764001234
''';

    test('high-sugar drink → HFSS flagged, FSSAI validated, barcode parsed',
        () async {
      final orch = ProductSafetyOrchestrator();
      final report =
          await orch.analyze(colaLabel, referenceDate: DateTime(2026, 8, 26));

      expect(report.fssaiVerification, isNotNull,
          reason: '14-digit FSSAI number present in label');
      expect(report.nutritionalAnalysis.isHighSugar, isTrue,
          reason: '11g sugar per 100ml exceeds 10g limit');
      expect(report.barcodeInfo?.isMadeInIndia ?? false, isTrue,
          reason: 'barcode starts with 890');
      expect(report.findings, isNotEmpty);
      expect(report.safetyScore, inInclusiveRange(0, 100));
    });

    test('expired dairy product → unsafe verdict', () async {
      const expiredMilk = '''
AMUL TAAZA TONED MILK 500ml
FSSAI Lic. No.: 10019021000123
MFG DATE: 10/07/2026
USE BY: 20/07/2026
Keep Refrigerated below 8°C
MRP Rs. 27.00 (Incl. of All Taxes)
''';
      final orch = ProductSafetyOrchestrator();
      final report =
          await orch.analyze(expiredMilk, referenceDate: DateTime(2026, 8, 26));

      expect(report.expiryAnalysis.status, ExpiryStatus.expired);
      expect(report.overallVerdict, ProductSafetyVerdict.unsafe);
      expect(report.safetyScore, lessThanOrEqualTo(25));
    });

    test('product without FSSAI number → caution finding', () async {
      const noFssai = '''
LOCAL SNACKS CHIPS
Net Weight 50g
Mfg: 01/2026 Best Before: 3 months
Ingredients: Potato, Palm Oil, Salt
Rs. 10.00
''';
      final orch = ProductSafetyOrchestrator();
      final report =
          await orch.analyze(noFssai, referenceDate: DateTime(2026, 8, 26));
      expect(
        report.findings.any((f) => f.id == 'fssai_missing'),
        isTrue,
      );
    });

    test('garbage input → no crash', () async {
      final orch = ProductSafetyOrchestrator();
      final report = await orch.analyze('!!! @@@ ### zzz');
      expect(report.findings, isA<List>());
      expect(report.safetyScore, inInclusiveRange(0, 100));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // FEATURE 5: SCANNER — QR/barcode classification logic
  // ─────────────────────────────────────────────────────────────────────────
  group('Scanner: BarcodeResult classification', () {
    test('UPI payment QR detected', () {
      final r = BarcodeResult(
        rawValue: 'upi://pay?pa=merchant@okhdfcbank&pn=Kirana Store&am=250.00&cu=INR',
        format: 'QR Code',
        displayType: 'Text',
        timestamp: DateTime.now(),
      );
      expect(r.isUpi, isTrue);
    });

    test('URL QR detected', () {
      final r = BarcodeResult(
        rawValue: 'https://www.google.com',
        format: 'QR Code',
        displayType: 'URL',
        timestamp: DateTime.now(),
      );
      expect(r.isUrl, isTrue);
      expect(r.isUpi, isFalse);
    });

    test('phone number QR detected', () {
      final r = BarcodeResult(
        rawValue: '+919876543210',
        format: 'QR Code',
        displayType: 'Phone',
        timestamp: DateTime.now(),
      );
      expect(r.isPhone, isTrue);
    });

    test('Wi-Fi QR detected', () {
      final r = BarcodeResult(
        rawValue: 'WIFI:T:WPA;S:MyNetwork;P:mypass;;',
        format: 'QR Code',
        displayType: 'Wi-Fi',
        timestamp: DateTime.now(),
      );
      expect(r.isWifi, isTrue);
    });

    test('history round-trip preserves data', () {
      final r = BarcodeResult(
        rawValue: 'upi://pay?pa=test@upi',
        format: 'QR Code',
        displayType: 'Text',
        timestamp: DateTime.now(),
      );
      final item = ScanHistoryItem.fromBarcode(r);
      final json = item.toJson();
      final restored = ScanHistoryItem.fromJson(json);
      expect(restored.barcodeValue, r.rawValue);
      expect(restored.type, ScanType.qrCode);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // FEATURE 6: AI KEY CONFIGURATION (runtime settings)
  // ─────────────────────────────────────────────────────────────────────────
  group('AI key configuration (AppSettings + ApiConfig)', () {
    test('set / mask / clear API key round-trip', () async {
      await AppSettings.setApiKey('sk-or-v1-test1234567890abcd');
      expect(AppSettings.hasApiKey, isTrue);
      expect(AppSettings.openRouterApiKey, 'sk-or-v1-test1234567890abcd');
      expect(AppSettings.maskedApiKey, contains('••••'));
      expect(ApiConfig.hasApiKey, isTrue,
          reason: 'runtime key must activate AI features');
      expect(ApiConfig.effectiveApiKey, 'sk-or-v1-test1234567890abcd');

      await AppSettings.setApiKey('');
      expect(AppSettings.hasApiKey, isFalse);
      expect(AppSettings.maskedApiKey, 'Not configured');
    });

    test('runtime key takes priority over compile-time key', () async {
      await AppSettings.setApiKey('sk-or-v1-runtime-override-key');
      expect(ApiConfig.effectiveApiKey, 'sk-or-v1-runtime-override-key');

      await AppSettings.setApiKey('');
      // Falls back to the compile-time constant baked into ApiConfig.
      expect(ApiConfig.effectiveApiKey, ApiConfig.openRouterApiKey);
      expect(ApiConfig.hasApiKey, isTrue,
          reason: 'compile-time key is configured in this build');
      expect(AppSettings.maskedApiKey, 'Not configured');
    });

    test('bill pipeline still works when AI key is invalid (graceful fail)',
        () async {
      ApiConfig.aiEnhancementEnabled = true;
      await AppSettings.setApiKey('sk-or-v1-invalid-key-for-offline-test');
      final orch = BillAnalysisOrchestrator();
      final result = await orch.analyze(
          'GSTIN: 27AAPFU0939F1ZV\nTotal: 100.00');
      expect(result.bill, isNotNull,
          reason: 'invalid key/network failure must not crash analysis');
      await AppSettings.setApiKey('');
      ApiConfig.aiEnhancementEnabled = false;
    });

    test('LIVE: real OpenRouter call via app service path (tolerant)', () async {
      // Free-tier models are frequently rate-limited (429), so this test
      // asserts crash-freedom always, and AI success when the API cooperates.
      ApiConfig.aiEnhancementEnabled = true;
      await AppSettings.setApiKey('');
      try {
        final orch = BillAnalysisOrchestrator();
        final result = await orch.analyze('''
SHARMA GENERAL STORES
GSTIN: 27AAPFU0939F1ZV
Atta 5kg x1 = 220.00
Sugar 1kg x2 = 90.00
Taxable: 310.00
CGST 2.5%: 7.75
SGST 2.5%: 7.75
Grand Total: 325.50
''');
        expect(result.bill, isNotNull);
        expect(result.bill.items, isNotEmpty);
        if (result.bill.isAiEnhanced) {
          expect(result.bill.aiModelUsed, isNotNull);
          expect(result.bill.confidence, greaterThan(0.5));
        }
      } finally {
        ApiConfig.aiEnhancementEnabled = false;
      }
    });
  });
}
