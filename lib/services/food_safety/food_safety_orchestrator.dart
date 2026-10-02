import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/food_safety/models/food_safety_models.dart';
import '../../models/scan_result_model.dart';
import '../ocr_service.dart';
import 'food_label_parser.dart';
import 'food_regulatory_engine.dart';

/// Orchestrates Food Safety Label Screening: OCR -> Parse -> Regulatory Audit.
class FoodSafetyOrchestrator {
  static final FoodSafetyOrchestrator instance = FoodSafetyOrchestrator._();
  FoodSafetyOrchestrator._();
  factory FoodSafetyOrchestrator() => instance;

  final OcrService _ocrService = OcrService();
  final FoodLabelParser _parser = FoodLabelParser();
  final FoodRegulatoryEngine _engine = FoodRegulatoryEngine();

  /// Runs full label analysis while reporting real sequential progress to [onProgress].
  Future<FoodLabelScanResult> analyzeLabel({
    required List<String> imagePaths,
    String? forcedText,
    void Function(FoodAnalysisStep step)? onProgress,
  }) async {
    // Stage 1: Reading label
    onProgress?.call(FoodAnalysisStep.readingLabel);
    await Future.delayed(const Duration(milliseconds: 350));

    String fullText = '';
    List<OcrBlock> blocks = [];

    if (forcedText != null && forcedText.isNotEmpty) {
      fullText = forcedText;
    } else if (imagePaths.isNotEmpty) {
      try {
        final ocr = await _ocrService.recognizeFromPath(imagePaths.first);
        fullText = ocr.fullText;
        blocks = ocr.blocks;

        // If there are multiple photos (e.g. nutrition panel photo), combine text
        if (imagePaths.length > 1) {
          for (final path in imagePaths.skip(1)) {
            try {
              final nextOcr = await _ocrService.recognizeFromPath(path);
              fullText += '\n\n${nextOcr.fullText}';
              blocks.addAll(nextOcr.blocks);
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('OCR recognition error: $e');
        throw FoodSafetyErrorType.ocrFailure;
      }
    } else {
      throw FoodSafetyErrorType.blurryImage;
    }

    if (fullText.trim().isEmpty) {
      throw FoodSafetyErrorType.ocrFailure;
    }

    // Stage 2: Identifying ingredients
    onProgress?.call(FoodAnalysisStep.identifyingIngredients);
    await Future.delayed(const Duration(milliseconds: 300));

    final parsed = _parser.parse(
      rawText: fullText,
      blocks: blocks,
      imagePaths: imagePaths,
    );

    if (parsed.hasError) {
      throw parsed.errorType!;
    }

    if (!parsed.hasIngredientsPanel) {
      throw FoodSafetyErrorType.noIngredientsDetected;
    }

    // Stage 3: Detecting additives
    onProgress?.call(FoodAnalysisStep.matchingIngredients);
    await Future.delayed(const Duration(milliseconds: 300));

    // Stage 4: Checking food category
    onProgress?.call(FoodAnalysisStep.checkingCategory);
    await Future.delayed(const Duration(milliseconds: 250));

    // Stage 5: Checking applicable rules
    onProgress?.call(FoodAnalysisStep.checkingRegulations);
    await Future.delayed(const Duration(milliseconds: 350));

    final eval = _engine.evaluate(
      detectedAdditives: parsed.additives,
      ingredients: parsed.ingredients,
      hasIngredientsPanel: parsed.hasIngredientsPanel,
      hasNutritionPanel: parsed.hasNutritionPanel,
      hasFssaiLicence: parsed.hasFssaiLicence,
      detectedCategory: parsed.detectedCategory,
      isImageClear: parsed.isImageClear,
    );

    // Stage 6: Preparing result
    onProgress?.call(FoodAnalysisStep.preparingResult);
    await Future.delayed(const Duration(milliseconds: 200));

    return FoodLabelScanResult(
      status: eval.status,
      productName: parsed.productName,
      detectedCategory: parsed.detectedCategory,
      primaryFinding: eval.primaryFinding,
      otherObservations: eval.otherObservations,
      ingredients: parsed.ingredients,
      additives: parsed.additives,
      allergens: parsed.allergens,
      missingInformation: eval.missingInformation,
      nutritionSummary: parsed.nutritionSummary,
      fssaiLicence: parsed.fssaiLicence,
      scannedImages: imagePaths,
      rawOcrText: fullText,
      ocrBlocks: blocks,
      analyzedAt: DateTime.now(),
    );
  }

  /// Preset sample scenarios for testing and demonstration of all 4 regulatory states.
  static FoodLabelScanResult createSampleResult(FoodVerificationStatus status) {
    switch (status) {
      case FoodVerificationStatus.noIssue:
        return FoodLabelScanResult(
          status: FoodVerificationStatus.noIssue,
          productName: 'Organic Whole Wheat Crispbread',
          detectedCategory: 'Bakery & Biscuits',
          primaryFinding: null,
          otherObservations: const [],
          ingredients: const [
            IngredientItem(
              name: 'Whole Wheat Flour',
              rawText: 'Whole Wheat Flour (84%)',
              type: 'Primary Ingredient',
              status: IngredientStatus.normal,
              why: 'Standard agricultural cereal ingredient.',
              source: 'FSS (Food Products Standards) Regulations, 2011',
            ),
            IngredientItem(
              name: 'Cold Pressed Sunflower Oil',
              rawText: 'Cold Pressed Sunflower Oil',
              type: 'Edible Vegetable Oil',
              status: IngredientStatus.normal,
              why: 'Permitted edible vegetable oil.',
              source: 'FSS (Food Products Standards) Regulations, 2011',
            ),
            IngredientItem(
              name: 'Iodised Salt',
              rawText: 'Iodised Salt',
              type: 'Seasoning',
              status: IngredientStatus.normal,
              why: 'Conforms to mandatory iodisation standards under FSSAI.',
              source: 'FSS (Food Products Standards) Regulations, 2011',
            ),
            IngredientItem(
              name: 'Sodium Bicarbonate',
              rawText: 'Raising Agent (INS 500(ii))',
              insNumber: 'INS 500',
              type: 'Raising Agent',
              status: IngredientStatus.permitted,
              why: 'Standard permitted raising agent under Good Manufacturing Practice (GMP).',
              source: 'FSS (Food Products Standards and Food Additives) Regulations, 2011, Table 10',
            ),
            IngredientItem(
              name: 'Citric Acid',
              rawText: 'Acidity Regulator (INS 330)',
              insNumber: 'INS 330',
              type: 'Acidity Regulator',
              status: IngredientStatus.permitted,
              why: 'Permitted acidity regulator under GMP.',
              source: 'FSS (Food Products Standards and Food Additives) Regulations, 2011, Table 10',
            ),
          ],
          additives: const [
            FoodAdditive(
              name: 'Sodium Carbonates',
              insNumber: 'INS 500',
              type: 'Raising Agent',
              status: 'Permitted',
              explanation: 'Permitted under GMP in bakery and biscuit categories.',
              regulatorySource: 'FSS (Food Products Standards and Food Additives) Regulations, 2011',
            ),
            FoodAdditive(
              name: 'Citric Acid',
              insNumber: 'INS 330',
              type: 'Acidity Regulator',
              status: 'Permitted',
              explanation: 'Permitted food acidulent under GMP.',
              regulatorySource: 'FSS (Food Products Standards and Food Additives) Regulations, 2011',
            ),
          ],
          allergens: const ['Cereals containing Gluten (Wheat)'],
          nutritionSummary: const NutritionSummary(
            energyKcal: 412,
            totalSugarGrams: 3.2,
            addedSugarGrams: 0.0,
            totalFatGrams: 8.5,
            saturatedFatGrams: 1.1,
            transFatGrams: 0.0,
            sodiumMg: 380,
            proteinGrams: 11.4,
            servingSize: '30g',
          ),
          rawOcrText: 'INGREDIENTS: Whole Wheat Flour (84%), Cold Pressed Sunflower Oil, Iodised Salt, Raising Agent (INS 500(ii)), Acidity Regulator (INS 330).\nALLERGEN ADVICE: Contains Gluten (Wheat).\nNUTRITION: Energy 412 kcal, Total Fat 8.5g, Saturated Fat 1.1g, Trans Fat 0g, Total Sugar 3.2g, Sodium 380mg, Protein 11.4g per 100g.\nFSSAI Lic. No. 10012011000168.',
          analyzedAt: DateTime.now(),
        );

      case FoodVerificationStatus.reviewRecommended:
        return FoodLabelScanResult(
          status: FoodVerificationStatus.reviewRecommended,
          productName: 'Mango Splash Fruit Beverage',
          detectedCategory: 'Fruit Beverage / Drink',
          primaryFinding: const RegulatoryFinding(
            findingId: 'FSSAI-REVIEW-INS211',
            finding: 'Sodium Benzoate (INS 211)',
            ruleStatus: 'Category/condition dependent',
            foodCategory: 'Fruit Beverage / Drink',
            condition: 'Permitted in carbonated and ready-to-serve fruit beverages up to 600 ppm; prohibited in milk and infant foods.',
            maxLevel: '600 ppm',
            source: 'FSS (Food Products Standards and Food Additives) Regulations, 2011, Appendix A, Table 1',
            effectiveDate: '05-Aug-2011',
            lastVerified: '2024 FSSAI Compendium',
            officialSourceUrl: 'https://www.fssai.gov.in',
            isPrimaryFinding: true,
            why: 'Whether this additive is permitted depends on the food category and applicable conditions/limits.',
          ),
          otherObservations: const [
            RegulatoryFinding(
              findingId: 'FSSAI-REVIEW-INS110',
              finding: 'Sunset Yellow FCF (INS 110)',
              ruleStatus: 'Category/condition dependent',
              foodCategory: 'Fruit Beverage / Drink',
              condition: 'Requires mandatory statutory label statement: "CONTAINS PERMITTED SYNTHETIC FOOD COLOUR(S)".',
              maxLevel: '100 mg/kg',
              source: 'FSS (Labelling and Display) Regulations, 2020, Reg 5(2)',
              why: 'Synthetic colour permitted within 100 ppm; requires statutory front disclosure.',
            ),
          ],
          ingredients: const [
            IngredientItem(
              name: 'Water',
              rawText: 'Water',
              status: IngredientStatus.normal,
              why: 'Standard base liquid.',
              source: 'FSSAI Standards',
            ),
            IngredientItem(
              name: 'Mango Pulp',
              rawText: 'Mango Pulp (15%)',
              status: IngredientStatus.normal,
              why: 'Standard fruit component.',
              source: 'FSSAI Standards',
            ),
            IngredientItem(
              name: 'Sugar',
              rawText: 'Sugar',
              status: IngredientStatus.normal,
              why: 'Permitted sweetener.',
              source: 'FSSAI Standards',
            ),
            IngredientItem(
              name: 'Sodium Benzoate',
              rawText: 'Preservative (INS 211)',
              insNumber: 'INS 211',
              type: 'Preservative',
              status: IngredientStatus.requiresVerification,
              why: 'Whether this additive is permitted depends on the food category and applicable conditions/limits.',
              source: 'FSS (Food Products Standards and Food Additives) Regulations, 2011, Appendix A, Table 1',
            ),
            IngredientItem(
              name: 'Sunset Yellow FCF',
              rawText: 'Colour (INS 110)',
              insNumber: 'INS 110',
              type: 'Synthetic Food Colour',
              status: IngredientStatus.requiresVerification,
              why: 'Permitted synthetic colour subject to 100 ppm upper limit and mandatory label declaration.',
              source: 'FSS (Labelling and Display) Regulations, 2020, Reg 5(2)',
            ),
          ],
          additives: const [
            FoodAdditive(
              name: 'Sodium Benzoate',
              insNumber: 'INS 211',
              type: 'Preservative',
              status: 'Category/condition dependent',
              explanation: 'Whether this additive is permitted depends on the food category and applicable conditions/limits.',
              regulatorySource: 'FSS (Food Products Standards and Food Additives) Regulations, 2011, Appendix A, Table 1',
              condition: 'Permitted in fruit drinks up to 600 ppm.',
              maxLevel: '600 ppm',
              requiresVerification: true,
            ),
          ],
          allergens: const [],
          nutritionSummary: const NutritionSummary(
            energyKcal: 56,
            totalSugarGrams: 13.8,
            addedSugarGrams: 11.2,
            totalFatGrams: 0.0,
            saturatedFatGrams: 0.0,
            transFatGrams: 0.0,
            sodiumMg: 42,
            proteinGrams: 0.2,
            servingSize: '200ml',
          ),
          rawOcrText: 'INGREDIENTS: Water, Mango Pulp (15%), Sugar, Acidity Regulator (INS 330), Preservative (INS 211), Synthetic Colour (INS 110).\nNUTRITION: Energy 56 kcal, Total Sugar 13.8g, Added Sugar 11.2g, Total Fat 0g, Sodium 42mg per 100ml.\nFSSAI Lic. No. 12723055000123.',
          analyzedAt: DateTime.now(),
        );

      case FoodVerificationStatus.potentialNonCompliance:
        return FoodLabelScanResult(
          status: FoodVerificationStatus.potentialNonCompliance,
          productName: 'Commercial White Sandwich Bread',
          detectedCategory: 'Bakery & Biscuits',
          primaryFinding: const RegulatoryFinding(
            findingId: 'FSSAI-NONCOMP-924A',
            finding: 'Potassium Bromate (INS 924a)',
            ruleStatus: 'Prohibited for this use',
            foodCategory: 'Bakery & Biscuits',
            condition: 'Completely prohibited in all food products in India since 2016 notification.',
            maxLevel: '0 ppm (Prohibited)',
            source: 'FSSAI Order No. Stds/SP(Water & Beverages)/Notification(1)/FSSAI-2016',
            effectiveDate: '20-Jun-2016',
            lastVerified: '2024 FSSAI Compendium',
            officialSourceUrl: 'https://www.fssai.gov.in',
            isPrimaryFinding: true,
            why: 'Potassium Bromate (INS 924a) was de-notified and prohibited from use in food products by FSSAI in 2016.',
          ),
          otherObservations: const [],
          ingredients: const [
            IngredientItem(
              name: 'Refined Wheat Flour (Maida)',
              rawText: 'Refined Wheat Flour (Maida)',
              status: IngredientStatus.normal,
              why: 'Standard flour ingredient.',
              source: 'FSSAI Standards',
            ),
            IngredientItem(
              name: 'Yeast',
              rawText: 'Yeast',
              status: IngredientStatus.normal,
              why: 'Standard leavening agent.',
              source: 'FSSAI Standards',
            ),
            IngredientItem(
              name: 'Potassium Bromate',
              rawText: 'Flour Improver (INS 924a)',
              insNumber: 'INS 924a',
              type: 'Flour Treatment Agent',
              status: IngredientStatus.potentialNonCompliance,
              why: 'Potassium Bromate (INS 924a) was de-notified and prohibited from use in food products by FSSAI in 2016.',
              source: 'FSSAI Order No. Stds/SP(Water & Beverages)/Notification(1)/FSSAI-2016',
            ),
          ],
          additives: const [
            FoodAdditive(
              name: 'Potassium Bromate',
              insNumber: 'INS 924a',
              type: 'Flour Treatment Agent',
              status: 'Prohibited for this use',
              explanation: 'Potassium Bromate (INS 924a) was de-notified and prohibited from use in food products by FSSAI in 2016.',
              regulatorySource: 'FSSAI Order No. Stds/SP(Water & Beverages)/Notification(1)/FSSAI-2016',
              isNonCompliance: true,
            ),
          ],
          allergens: const ['Cereals containing Gluten (Wheat)'],
          nutritionSummary: const NutritionSummary(
            energyKcal: 260,
            totalSugarGrams: 4.5,
            totalFatGrams: 2.1,
            saturatedFatGrams: 0.6,
            transFatGrams: 0.0,
            sodiumMg: 490,
            proteinGrams: 8.2,
            servingSize: '50g (2 slices)',
          ),
          rawOcrText: 'INGREDIENTS: Refined Wheat Flour (Maida), Water, Sugar, Yeast, Salt, Flour Improver (INS 924a).\nFSSAI Lic. No. 11518018000456.',
          analyzedAt: DateTime.now(),
        );

      case FoodVerificationStatus.cannotFullyVerify:
        return FoodLabelScanResult(
          status: FoodVerificationStatus.cannotFullyVerify,
          productName: 'Unidentified Packaged Snack',
          detectedCategory: 'Packaged Food',
          primaryFinding: null,
          otherObservations: const [],
          ingredients: const [],
          additives: const [],
          allergens: const [],
          missingInformation: const [
            'Quantity/concentration not visible',
            'Product category unclear',
            'Label image unclear or truncated',
          ],
          nutritionSummary: const NutritionSummary(),
          rawOcrText: 'CRUNCHY DELIGHT\nNET WT: [CUT OFF]\nBATCH: 2024-X\n[Remainder of label illegible or missing]',
          analyzedAt: DateTime.now(),
        );
    }
  }
}
