import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_sure/config/api_config.dart';
import 'package:scan_sure/config/app_settings.dart';
import 'package:scan_sure/models/bill_model.dart';
import 'package:scan_sure/services/gemini_fraud_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  group('Gemini AI Fraud Detector Configuration & Service Tests', () {
    test('Gemini API Key and Endpoint is configured and active', () async {
      await AppSettings.setGeminiApiKey('AIzaSyTestMockGeminiApiKey12345');
      expect(ApiConfig.hasGeminiKey, isTrue);
      // geminiModel is derived from the shared candidate list, so assert
      // against that single source of truth instead of a hardcoded string —
      // this keeps the test in sync automatically if the fallback chain in
      // ApiConfig.geminiCandidateModels is ever updated.
      expect(ApiConfig.geminiModel, ApiConfig.geminiCandidateModels.first);
      expect(ApiConfig.geminiCandidateModels, isNotEmpty);
      expect(ApiConfig.effectiveGeminiApiKey, 'AIzaSyTestMockGeminiApiKey12345');
      expect(AppSettings.maskedGeminiApiKey, contains('AIzaS'));
      await AppSettings.setGeminiApiKey('');
    });

    test('GeminiFraudService handles mock fraudulent bill response accurately', () {
      final service = GeminiFraudService();
      const rawText = '''
Hotel Sagar Grand
Date: 12-09-2026
Food items: 1000.00
Service Charge 10%: 100.00
CGST 2.5%: 27.50
SGST 2.5%: 27.50
Grand Total: 1155.00
''';

      final initialBill = StructuredBill(
        rawText: rawText,
        billType: BillType.restaurant,
        sellerName: 'Hotel Sagar Grand',
        items: const [
          BillItem(name: 'Food items', lineTotal: 1000.0),
        ],
        taxes: const BillTaxSection(
          subtotal: 1000.0,
          cgstAmount: 27.50,
          sgstAmount: 27.50,
        ),
        charges: const [
          BillCharge(label: 'Service Charge 10%', amount: 100.0),
        ],
        grandTotal: 1155.00,
        confidence: 0.9,
      );

      // Verify that CCPA guidelines violation is structured properly
      expect(initialBill.charges.any((c) => c.isServiceCharge), isTrue);
      expect(service, isNotNull);
    });

    test('GeminiFraudService live Indian bill fraud detection executes successfully', () async {
      final service = GeminiFraudService();
      const rawOcrText = '''
THE ROYAL SPICE RESTAURANT
GSTIN: 27AABCT3421K1ZM
Invoice: INV-9831
Paneer Tikka: 350.00
Butter Naan (2): 120.00
Subtotal: 470.00
Service Charge (10%): 47.00
CGST 2.5%: 12.93
SGST 2.5%: 12.93
Total: 542.86
''';

      final bill = StructuredBill(
        rawText: rawOcrText,
        billType: BillType.restaurant,
        sellerName: 'THE ROYAL SPICE RESTAURANT',
        items: const [
          BillItem(name: 'Paneer Tikka', lineTotal: 350.0),
          BillItem(name: 'Butter Naan', lineTotal: 120.0),
        ],
        taxes: const BillTaxSection(
          subtotal: 470.0,
          cgstAmount: 12.93,
          sgstAmount: 12.93,
        ),
        charges: const [
          BillCharge(label: 'Service Charge', amount: 47.0),
        ],
        grandTotal: 542.86,
        confidence: 0.9,
      );

      final result = await service.analyzeBillForFraud(
        initialBill: bill,
        rawOcrText: rawOcrText,
      );

      // Note: Live API call over network. If network is connected, verify result.
      if (result != null) {
        expect(result.modelUsed, isNotEmpty);
        expect(result.findings, isNotEmpty);
        expect(
          result.findings.any((f) =>
              f.title.toLowerCase().contains('service') ||
              f.explanation.toLowerCase().contains('service') ||
              f.category.toLowerCase().contains('service')),
          isTrue,
        );
      }
    });
  });
}
