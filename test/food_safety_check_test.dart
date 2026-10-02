import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_sure/core/food_safety/models/food_safety_models.dart';
import 'package:scan_sure/screens/food_safety/food_safety_home_screen.dart';
import 'package:scan_sure/screens/food_safety/food_safety_result_screen.dart';
import 'package:scan_sure/screens/food_safety/food_analysis_loading_screen.dart';
import 'package:scan_sure/screens/food_safety/sheets/ingredient_detail_sheet.dart';
import 'package:scan_sure/screens/food_safety/sheets/food_regulatory_details_sheet.dart';
import 'package:scan_sure/screens/food_safety/widgets/food_safety_error_view.dart';
import 'package:scan_sure/screens/food_safety/widgets/highlighted_food_label_view.dart';
import 'package:scan_sure/screens/food_safety/widgets/nutrition_summary_card.dart';
import 'package:scan_sure/services/food_safety/food_label_parser.dart';
import 'package:scan_sure/services/food_safety/food_regulatory_engine.dart';
import 'package:scan_sure/services/food_safety/food_safety_orchestrator.dart';
import 'package:scan_sure/screens/scanner/universal_product_entry_screen.dart';
import 'package:scan_sure/services/ocr_service.dart';
import 'package:scan_sure/services/scan_history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Food Regulatory Engine Tests', () {
    final engine = FoodRegulatoryEngine();

    test('Identifies prohibited additive Potassium Bromate (INS 924a)', () {
      final additive = engine.lookupAdditive('INS 924a');
      expect(additive, isNotNull);
      expect(additive!.name, contains('Potassium Bromate'));
      expect(additive.isNonCompliance, isTrue);
      expect(additive.status, equals('Prohibited for this use'));
      expect(additive.regulatorySource, contains('FSSAI'));
    });

    test('Identifies category dependent additive Sodium Benzoate (INS 211)', () {
      final additive = engine.lookupAdditive('Sodium Benzoate (INS 211)');
      expect(additive, isNotNull);
      expect(additive!.insNumber, equals('INS 211'));
      expect(additive.status, equals('Category/condition dependent'));
      expect(additive.requiresVerification, isTrue);
      expect(additive.isNonCompliance, isFalse);
    });

    test('Identifies permitted GMP additive Citric Acid (INS 330)', () {
      final additive = engine.lookupAdditive('Citric Acid');
      expect(additive, isNotNull);
      expect(additive!.status, equals('Permitted'));
      expect(additive.requiresVerification, isFalse);
      expect(additive.isNonCompliance, isFalse);
    });

    test('Evaluates prohibited additive to potentialNonCompliance status without arbitrary scores', () {
      final prohibited = engine.lookupAdditive('INS 924a')!;
      final eval = engine.evaluate(
        detectedAdditives: [prohibited],
        ingredients: [
          IngredientItem(
            name: prohibited.name,
            rawText: 'INS 924a',
            status: IngredientStatus.potentialNonCompliance,
            why: prohibited.explanation,
            source: prohibited.regulatorySource,
          ),
        ],
        hasIngredientsPanel: true,
        hasNutritionPanel: true,
        hasFssaiLicence: true,
        detectedCategory: 'Bakery',
        isImageClear: true,
      );

      expect(eval.status, equals(FoodVerificationStatus.potentialNonCompliance));
      expect(eval.primaryFinding, isNotNull);
      expect(eval.primaryFinding!.finding, contains('Potassium Bromate'));
      expect(eval.primaryFinding!.ruleStatus, equals('Prohibited for this use'));
    });

    test('Evaluates category-dependent additive to reviewRecommended status', () {
      final additive = engine.lookupAdditive('INS 211')!;
      final eval = engine.evaluate(
        detectedAdditives: [additive],
        ingredients: [
          IngredientItem(
            name: additive.name,
            rawText: 'Preservative (INS 211)',
            status: IngredientStatus.requiresVerification,
            why: additive.explanation,
            source: additive.regulatorySource,
          ),
        ],
        hasIngredientsPanel: true,
        hasNutritionPanel: true,
        hasFssaiLicence: true,
        detectedCategory: 'Fruit Beverage',
        isImageClear: true,
      );

      expect(eval.status, equals(FoodVerificationStatus.reviewRecommended));
      expect(eval.primaryFinding, isNotNull);
      expect(eval.primaryFinding!.ruleStatus, equals('Category/condition dependent'));
    });

    test('Evaluates missing crucial label panels to cannotFullyVerify without violation', () {
      final eval = engine.evaluate(
        detectedAdditives: [],
        ingredients: [],
        hasIngredientsPanel: false, // missing
        hasNutritionPanel: false, // missing
        hasFssaiLicence: false,
        detectedCategory: 'Packaged Food',
        isImageClear: true,
      );

      expect(eval.status, equals(FoodVerificationStatus.cannotFullyVerify));
      expect(eval.missingInformation, isNotEmpty);
      expect(eval.primaryFinding, isNull); // Never converts missing info into a violation
    });

    test('Evaluates compliant label to noIssue status', () {
      final gmpAdditive = engine.lookupAdditive('INS 330')!;
      final eval = engine.evaluate(
        detectedAdditives: [gmpAdditive],
        ingredients: [
          IngredientItem(
            name: 'Citric Acid',
            rawText: 'INS 330',
            status: IngredientStatus.permitted,
            why: gmpAdditive.explanation,
            source: gmpAdditive.regulatorySource,
          ),
        ],
        hasIngredientsPanel: true,
        hasNutritionPanel: true,
        hasFssaiLicence: true,
        detectedCategory: 'Fruit Drink',
        isImageClear: true,
      );

      expect(eval.status, equals(FoodVerificationStatus.noIssue));
      expect(eval.primaryFinding, isNull);
    });
  });

  group('Food Label Parser Tests', () {
    final parser = FoodLabelParser();

    test('Extracts ingredients, allergens, nutrition facts, and FSSAI license', () {
      const sampleOcr = '''
      MANGO TASTE DRINK
      INGREDIENTS: Water, Mango Pulp, Sugar, Acidity Regulator (INS 330), Preservative (INS 211), Synthetic Colour (INS 110).
      ALLERGEN ADVICE: Contains Wheat Gluten and Milk Solids.
      NUTRITION INFORMATION per 100ml:
      Energy: 56 kcal
      Total Fat: 0.0g
      Saturated Fat: 0.0g
      Trans Fat: 0.0g
      Total Sugar: 13.8g
      Added Sugar: 11.2g
      Sodium: 42 mg
      Protein: 0.2g
      FSSAI Lic. No. 10012011000168
      Batch: M-2024
      ''';

      final parsed = parser.parse(rawText: sampleOcr);
      expect(parsed.hasError, isFalse);
      expect(parsed.hasIngredientsPanel, isTrue);
      expect(parsed.ingredients.length, greaterThanOrEqualTo(4));
      expect(parsed.additives.length, greaterThanOrEqualTo(2));
      expect(parsed.allergens, contains('Cereals containing Gluten (Wheat/Barley)'));
      expect(parsed.allergens, contains('Milk & Milk Solids'));
      expect(parsed.nutritionSummary.energyKcal, equals(56.0));
      expect(parsed.nutritionSummary.totalSugarGrams, equals(13.8));
      expect(parsed.nutritionSummary.sodiumMg, equals(42.0));
      expect(parsed.hasFssaiLicence, isTrue);
    });

    test('Rejects non-food text with unsupportedLabel error', () {
      const invoiceText = '''
      TAX INVOICE
      GSTIN: 27AAAAA0000A1Z5
      ITEM: RESISTOR 10K OHM
      VOLTAGE: 220V
      CIRCUIT BREAKER
      TOTAL AMOUNT: Rs. 1500
      ''';

      final parsed = parser.parse(rawText: invoiceText);
      expect(parsed.hasError, isTrue);
      expect(parsed.errorType, equals(FoodSafetyErrorType.unsupportedLabel));
    });

    test('Rejects blurry/empty text with blurryImage error', () {
      final parsed = parser.parse(rawText: 'blur');
      expect(parsed.hasError, isTrue);
      expect(parsed.errorType, equals(FoodSafetyErrorType.blurryImage));
    });
  });

  group('Food Safety UI Screens & Widgets Tests', () {
    testWidgets('Screen 1: FoodSafetyHomeScreen renders faithfully', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FoodSafetyHomeScreen(),
        ),
      );

      // Verify Title & Subtitle
      expect(find.text('Food Safety Check'), findsWidgets);
      expect(
        find.text('Scan a food label to check ingredients, nutrition and visible labelling requirements.'),
        findsOneWidget,
      );

      // Verify Scanning Frame Helper Text
      expect(find.text('Capture the Ingredients panel'), findsOneWidget);

      // Verify Buttons
      expect(find.text('Scan Label'), findsOneWidget);
      expect(find.text('Upload Photo'), findsOneWidget);

      // Verify Small helper
      expect(
        find.text('For best results, capture the full Ingredients and Nutrition panels.'),
        findsOneWidget,
      );

      // Verify "What we check" expandable section
      expect(find.text('What we check'), findsOneWidget);
      expect(find.text('Ingredients & additives'), findsNothing);

      // Scroll to "What we check" before tapping
      await tester.ensureVisible(find.text('What we check'));
      await tester.tap(find.text('What we check'));
      await tester.pumpAndSettle();

      expect(find.text('Ingredients & additives'), findsOneWidget);
      expect(find.text('Allergen declarations'), findsOneWidget);
      expect(find.text('Nutrition information'), findsOneWidget);
      expect(find.text('Visible labelling details'), findsOneWidget);
      expect(find.text('FSSAI licence information where visible'), findsOneWidget);
    });

    testWidgets('Screen 4: FoodAnalysisLoadingScreen displays real sequential steps', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FoodAnalysisLoadingScreen(currentStep: FoodAnalysisStep.matchingIngredients),
        ),
      );

      expect(find.text('Checking Label'), findsOneWidget);
      expect(find.text('Reading text'), findsOneWidget);
      expect(find.text('Identifying ingredients'), findsOneWidget);
      expect(find.text('Detecting additives'), findsOneWidget);
      expect(find.text('Checking food category'), findsOneWidget);
      expect(find.text('Checking applicable rules'), findsOneWidget);
      expect(find.text('Preparing result'), findsOneWidget);
    });

    testWidgets('Screen 5: Result Screen renders No label-based issue found', (tester) async {
      final sample = FoodSafetyOrchestrator.createSampleResult(FoodVerificationStatus.noIssue);

      await tester.pumpWidget(
        MaterialApp(
          home: FoodSafetyResultScreen(result: sample),
        ),
      );

      // Status header
      expect(find.text('No label-based issue found'), findsOneWidget);
      expect(
        find.text('No applicable issue was identified from the information visible on the scanned label.'),
        findsOneWidget,
      );

      // Summary list
      expect(find.text('Ingredients'), findsOneWidget);
      expect(find.text('Additives'), findsOneWidget);
      expect(find.text('Allergens'), findsOneWidget);
      expect(find.text('Label information'), findsOneWidget);
      expect(find.text('✓ Reviewed'), findsNWidgets(4));

      // Action & Disclaimer
      expect(find.text('View details'), findsOneWidget);
      expect(
        find.text('This check reviews information printed on the label. It does not replace laboratory testing.'),
        findsOneWidget,
      );
    });

    testWidgets('Screen 6: Result Screen renders Review recommended with primary finding', (tester) async {
      final sample = FoodSafetyOrchestrator.createSampleResult(FoodVerificationStatus.reviewRecommended);

      await tester.pumpWidget(
        MaterialApp(
          home: FoodSafetyResultScreen(result: sample),
        ),
      );

      expect(find.text('Review recommended'), findsOneWidget);
      expect(find.text('1 item requires further regulatory verification.'), findsOneWidget);
      expect(find.text('Sodium Benzoate (INS 211)'), findsOneWidget);
      expect(find.text('Category/condition dependent'), findsWidgets);
      expect(find.text('View rule'), findsOneWidget);
    });

    testWidgets('Screen 7: Result Screen renders Potential non-compliance identified', (tester) async {
      final sample = FoodSafetyOrchestrator.createSampleResult(FoodVerificationStatus.potentialNonCompliance);

      await tester.pumpWidget(
        MaterialApp(
          home: FoodSafetyResultScreen(result: sample),
        ),
      );

      expect(find.text('Potential non-compliance identified'), findsOneWidget);
      expect(find.textContaining('Potassium Bromate'), findsWidgets);
      expect(find.text('Prohibited for this use'), findsOneWidget);
      expect(find.text('View regulatory source'), findsOneWidget);
    });

    testWidgets('Screen 8: Result Screen renders Cannot fully verify with missing information', (tester) async {
      final sample = FoodSafetyOrchestrator.createSampleResult(FoodVerificationStatus.cannotFullyVerify);

      await tester.pumpWidget(
        MaterialApp(
          home: FoodSafetyResultScreen(result: sample),
        ),
      );

      expect(find.text('Cannot fully verify'), findsOneWidget);
      expect(
        find.text('Some checks require information that is not available on the scanned label.'),
        findsOneWidget,
      );
      expect(find.text('Missing information:'), findsOneWidget);
      expect(find.text('View details'), findsOneWidget);
    });

    testWidgets('Screen 9: IngredientDetailSheet renders clearly with FSSAI citation', (tester) async {
      const ingredient = IngredientItem(
        name: 'Sodium Benzoate',
        rawText: 'INS 211',
        insNumber: 'INS 211',
        type: 'Preservative',
        status: IngredientStatus.requiresVerification,
        why: 'Whether this additive is permitted depends on the food category and applicable conditions/limits.',
        source: 'FSS (Food Products Standards and Food Additives) Regulations, 2011, Appendix A, Table 1',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IngredientDetailSheet(ingredient: ingredient),
          ),
        ),
      );

      expect(find.text('Sodium Benzoate'), findsOneWidget);
      expect(find.text('INS 211'), findsOneWidget);
      expect(find.text('Category Dependent'), findsOneWidget);
      expect(find.text('Preservative'), findsOneWidget);
      expect(find.textContaining('Whether this additive is permitted depends'), findsOneWidget);
      expect(find.text('View full rule'), findsOneWidget);
    });

    testWidgets('Screen 10: HighlightedFoodLabelView renders legend and ingredient chips', (tester) async {
      final sample = FoodSafetyOrchestrator.createSampleResult(FoodVerificationStatus.reviewRecommended);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HighlightedFoodLabelView(result: sample),
          ),
        ),
      );

      expect(find.text('LABEL HIGHLIGHT LEGEND'), findsOneWidget);
      expect(find.text('Permitted additive'), findsOneWidget);
      expect(find.text('Requires verification'), findsOneWidget);
      expect(find.text('SCANNED LABEL TEXT'), findsOneWidget);
      expect(find.text('Sodium Benzoate'), findsOneWidget);
    });

    testWidgets('Screen 11: NutritionSummaryCard shows values objectively without health score', (tester) async {
      const nutrition = NutritionSummary(
        energyKcal: 450,
        totalSugarGrams: 22,
        totalFatGrams: 18,
        saturatedFatGrams: 4.5,
        transFatGrams: 0.1,
        sodiumMg: 320,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NutritionSummaryCard(nutrition: nutrition),
          ),
        ),
      );

      expect(find.text('Nutrition Information'), findsOneWidget);
      expect(find.text('Energy'), findsOneWidget);
      expect(find.text('450 kcal'), findsOneWidget);
      expect(find.text('Total sugar'), findsOneWidget);
      expect(find.text('22.0 g'), findsOneWidget);
      expect(find.text('Total fat'), findsOneWidget);
      expect(find.text('18.0 g'), findsOneWidget);
      expect(find.text('Sodium'), findsOneWidget);
      expect(find.text('320 mg'), findsOneWidget);
      // Ensure NO arbitrary health score or unhealthy labels are displayed
      expect(find.textContaining('Unhealthy'), findsNothing);
      expect(find.textContaining('Toxic'), findsNothing);
      expect(find.textContaining('% Safe'), findsNothing);
    });

    testWidgets('Screen 12: FoodRegulatoryDetailsSheet displays statutory FSSAI citations', (tester) async {
      final sample = FoodSafetyOrchestrator.createSampleResult(FoodVerificationStatus.reviewRecommended);

      await tester.pumpWidget(
        MaterialApp(
          home: FoodRegulatoryDetailsSheet(result: sample),
        ),
      );

      expect(find.text('Regulatory Details'), findsOneWidget);
      expect(find.text('Statutory Framework: FSSAI (India)'), findsOneWidget);
      expect(find.text('Sodium Benzoate (INS 211)'), findsWidgets);
      expect(find.text('Official source'), findsOneWidget);
    });

    testWidgets('Screen 13: FoodSafetyErrorView displays all 8 error states correctly', (tester) async {
      for (final err in FoodSafetyErrorType.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: FoodSafetyErrorView(
              errorType: err,
              onTryAgain: () {},
              onUploadAnother: () {},
            ),
          ),
        );

        expect(find.text(err.title), findsOneWidget);
        expect(find.text('Try Again'), findsOneWidget);
        if (err.allowUploadAnother) {
          expect(find.text('Upload Another Photo'), findsOneWidget);
        }
      }
    });

    testWidgets('Navigation: Tapping Food & Beverages chip in UniversalProductEntryScreen opens FoodSafetyHomeScreen', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final historyService = ScanHistoryService();
      await historyService.load();
      final ocrService = OcrService();

      await tester.pumpWidget(
        MaterialApp(
          home: UniversalProductEntryScreen(
            ocrService: ocrService,
            historyService: historyService,
          ),
        ),
      );

      // Verify category chip is present
      final foodChipFinder = find.text('🥗 Food & Beverages');
      expect(foodChipFinder, findsOneWidget);

      // Tap category chip
      await tester.tap(foodChipFinder);
      await tester.pumpAndSettle();

      // Verify FoodSafetyHomeScreen is opened
      expect(find.text('Food Safety Check'), findsWidgets);
      expect(find.text('Capture the Ingredients panel'), findsOneWidget);
      expect(find.text('Scan Label'), findsOneWidget);
    });
  });
}
