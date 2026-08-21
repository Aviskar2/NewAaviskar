import 'package:flutter_test/flutter_test.dart';
import 'package:aura_ai/models/product_safety_model.dart';
import 'package:aura_ai/services/product_safety/barcode_gs1_service.dart';
import 'package:aura_ai/services/product_safety/expiry_extractor_service.dart';
import 'package:aura_ai/services/product_safety/fssai_validator_service.dart';
import 'package:aura_ai/services/product_safety/nutritional_audit_service.dart';
import 'package:aura_ai/services/product_safety/product_safety_orchestrator.dart';

void main() {
  group('Barcode & GS1 Service', () {
    final service = BarcodeGs1Service();

    test('Identifies Made in India product with 890 GS1 prefix and brand', () {
      final info = service.parseBarcode('8901262010123');
      expect(info.isMadeInIndia, isTrue);
      expect(info.countryOfOrigin, contains('India'));
      expect(info.brandName, equals('Amul (GCMMF)'));
    });

    test('Identifies international barcode', () {
      final info = service.parseBarcode('4001234567890');
      expect(info.isMadeInIndia, isFalse);
      expect(info.countryOfOrigin, contains('Germany'));
    });

    test('Extracts 890 barcode from packaging OCR text', () {
      const text = 'Packaged by XYZ Ltd. Barcode: 8901058852140. Batch A1.';
      final extracted = service.extractBarcodeFromText(text);
      expect(extracted, equals('8901058852140'));
    });
  });

  group('FSSAI 14-Digit Validator Service', () {
    final service = FssaiValidatorService();

    test('Validates Central FSSAI License with state 00', () {
      final result = service.validateNumber('10012011000168');
      expect(result.isValid, isTrue);
      expect(result.licenseType, equals(FssaiLicenseType.centralLicense));
      expect(result.stateName, contains('Central Licensing Authority'));
      expect(result.registrationYear, equals('2012'));
    });

    test('Validates State FSSAI License with Maharashtra state code 27', () {
      final result = service.validateNumber('12723055000123');
      expect(result.isValid, isTrue);
      expect(result.licenseType, equals(FssaiLicenseType.stateLicense));
      expect(result.stateName, equals('Maharashtra'));
      expect(result.registrationYear, equals('2023'));
    });

    test('Validates Basic FSSAI Registration starting with 2', () {
      final result = service.validateNumber('22921001000456');
      expect(result.isValid, isTrue);
      expect(result.licenseType, equals(FssaiLicenseType.basicRegistration));
      expect(result.stateName, equals('Karnataka'));
    });

    test('Rejects invalid length and invalid state code', () {
      final shortRes = service.validateNumber('12345');
      expect(shortRes.isValid, isFalse);

      final invalidStateRes = service.validateNumber('19923055000123');
      expect(invalidStateRes.isValid, isFalse);
    });

    test('Extracts FSSAI license from raw OCR text', () {
      const text = 'Marketed by ABC Foods. FSSAI Lic. No. 12723055000123. Net Wt 500g';
      final res = service.validateFromText(text);
      expect(res, isNotNull);
      expect(res!.rawLicenseNumber, equals('12723055000123'));
      expect(res.stateName, equals('Maharashtra'));
    });
  });

  group('Expiry & Shelf-Life Extractor Service', () {
    final service = ExpiryExtractorService();
    final fixedRefDate = DateTime(2026, 6, 1);

    test('Detects valid fresh product with future expiry', () {
      const text = 'Mfg Dt: 10/01/2026. EXP: 10/12/2026. Batch: 902.';
      final analysis = service.extract(text, referenceDate: fixedRefDate);
      expect(analysis.manufacturingDate, equals(DateTime(2026, 1, 10)));
      expect(analysis.expiryDate, equals(DateTime(2026, 12, 10)));
      expect(analysis.status, equals(ExpiryStatus.fresh));
      expect(analysis.daysRemaining, greaterThan(0));
    });

    test('Flags expired product when expiry date is in the past', () {
      const text = 'PKD: 01/01/2026. USE BY: 04/01/2026. Keep refrigerated.';
      final analysis = service.extract(text, referenceDate: fixedRefDate);
      expect(analysis.status, equals(ExpiryStatus.expired));
      expect(analysis.daysRemaining, lessThan(0));
    });

    test('Calculates expiry from "Best Before X Months from Mfg"', () {
      const text = 'MFG: 01/02/2026. BEST BEFORE 9 MONTHS FROM MFG. Batch 44.';
      final analysis = service.extract(text, referenceDate: fixedRefDate);
      expect(analysis.manufacturingDate, equals(DateTime(2026, 2, 1)));
      expect(analysis.expiryDate, equals(DateTime(2026, 11, 1)));
      expect(analysis.status, equals(ExpiryStatus.fresh));
    });
  });

  group('Nutritional Audit & Additive Service', () {
    final service = NutritionalAuditService();

    test('Flags High Sugar and High Sodium under FSSAI HFSS limits', () {
      const text = '''
NUTRITION FACTS:
Energy: 450 kcal
Carbohydrates: 65g
Total Sugars: 24.5g
Added Sugars: 18.0g
Total Fat: 18g
Saturated Fat: 8.5g
Trans Fat: 0.3g
Sodium: 850mg
''';
      final nutrition = service.auditNutrition(text);
      expect(nutrition.isHighSugar, isTrue);
      expect(nutrition.isHighSodium, isTrue);
      expect(nutrition.isHighSaturatedFat, isTrue);
      expect(nutrition.hasExcessTransFat, isTrue);
      expect(nutrition.nutritionalWarnings.length, equals(4));
    });

    test('Detects INS additives (MSG, Tartrazine, Sodium Benzoate)', () {
      const text = 'Ingredients: Salt, Spices, Flavour Enhancer (INS 621), Colour (INS 102), Preservative (INS 211), Palm Oil.';
      final result = service.auditIngredients(text);
      expect(result.detectedAdditives.any((a) => a.contains('621')), isTrue);
      expect(result.detectedAdditives.any((a) => a.contains('102')), isTrue);
      expect(result.detectedAdditives.any((a) => a.contains('211')), isTrue);
      expect(result.healthConcerns.any((c) => c.contains('Palm Oil')), isTrue);
    });

    test('Detects Vegetarian vs Non-Vegetarian declarations', () {
      const vegText = '100% Vegetarian Green Dot Product.';
      final vegResult = service.auditIngredients(vegText);
      expect(vegResult.isVegetarian, isTrue);
      expect(vegResult.isNonVegetarian, isFalse);

      const nonVegText = 'Ingredients: Chicken extract, egg albumin, spices.';
      final nonVegResult = service.auditIngredients(nonVegText);
      expect(nonVegResult.isNonVegetarian, isTrue);
    });
  });

  group('End-to-End Product Safety Orchestrator', () {
    final orchestrator = ProductSafetyOrchestrator();
    final fixedRefDate = DateTime(2026, 6, 1);

    test('Performs complete offline safety audit on High-Sugar drink', () async {
      const sampleText = '''
REAL MANGO NECTAR BEVERAGE
Mfg Dt: 10/01/2026
EXP: 10/10/2026
Barcode: 8901491102034
FSSAI Lic No: 10012011000168
NUTRITIONAL INFORMATION (Per 100ml):
Energy: 65 kcal
Protein: 0.2g
Carbohydrate: 16.0g
Total Sugars: 15.0g
Added Sugars: 13.5g
Total Fat: 0g
Sodium: 15mg
Ingredients: Water, Mango Pulp, Sugar, INS 330, INS 440.
100% Vegetarian.
''';

      final report = await orchestrator.analyze(
        sampleText,
        rawBarcode: '8901491102034',
        referenceDate: fixedRefDate,
      );

      expect(report.barcodeInfo?.isMadeInIndia, isTrue);
      expect(report.barcodeInfo?.brandName, equals('Dabur India'));
      expect(report.fssaiVerification?.isValid, isTrue);
      expect(report.expiryAnalysis.status, equals(ExpiryStatus.fresh));
      expect(report.nutritionalAnalysis.isHighSugar, isTrue);
      expect(report.overallVerdict, equals(ProductSafetyVerdict.caution));
      expect(report.findings.length, greaterThanOrEqualTo(3));
    });

    test('Marks expired dairy product as High Risk / Unsafe', () async {
      const sampleText = '''
PASTEURIZED COW MILK
PKD: 01/01/2026
USE BY: 04/01/2026
FSSAI Lic No: 10015021000045
Contains Milk.
''';

      final report = await orchestrator.analyze(
        sampleText,
        referenceDate: fixedRefDate,
      );

      expect(report.expiryAnalysis.status, equals(ExpiryStatus.expired));
      expect(report.overallVerdict, equals(ProductSafetyVerdict.unsafe));
      expect(report.safetyScore, lessThanOrEqualTo(40.0));
      expect(report.findings.any((f) => f.id == 'expiry_expired'), isTrue);
    });
  });
}
