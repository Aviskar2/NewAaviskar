import 'package:flutter/painting.dart' show Rect;
import '../../core/food_safety/models/food_safety_models.dart';
import '../../models/scan_result_model.dart';
import '../product_safety/fssai_validator_service.dart';
import 'food_regulatory_engine.dart';

/// Intelligent Food Label OCR Parser.
/// Parses raw OCR blocks into structured Ingredients, Nutrition, Allergens,
/// and FSSAI statutory declarations.
class FoodLabelParser {
  final FoodRegulatoryEngine _engine = FoodRegulatoryEngine();
  final FssaiValidatorService _fssaiValidator = FssaiValidatorService();

  /// Parse multi-line OCR text or blocks into structured label components.
  ParsedFoodLabel parse({
    required String rawText,
    List<OcrBlock> blocks = const [],
    List<String> imagePaths = const [],
  }) {
    final cleanText = rawText.trim();

    // 1. Check for error conditions
    if (cleanText.isEmpty || cleanText.length < 15) {
      return ParsedFoodLabel.error(FoodSafetyErrorType.blurryImage);
    }

    if (_isNonFoodText(cleanText)) {
      return ParsedFoodLabel.error(FoodSafetyErrorType.unsupportedLabel);
    }

    // 2. Extract Ingredients section
    final ingredientItems = _extractIngredients(cleanText, blocks);
    final additives = _extractAdditives(ingredientItems);

    // 3. Extract Nutrition panel
    final nutrition = _extractNutrition(cleanText);

    // 4. Extract Allergens
    final allergens = _extractAllergens(cleanText);

    // 5. Extract FSSAI License
    final fssai = _fssaiValidator.validateFromText(cleanText);

    // 6. Detect Product Name and Food Category
    final detectedCategory = _detectCategory(cleanText);
    final productName = _detectProductName(cleanText);

    return ParsedFoodLabel(
      rawText: cleanText,
      blocks: blocks,
      imagePaths: imagePaths,
      productName: productName,
      detectedCategory: detectedCategory,
      ingredients: ingredientItems,
      additives: additives,
      allergens: allergens,
      nutritionSummary: nutrition,
      fssaiLicence: fssai,
      hasIngredientsPanel: ingredientItems.isNotEmpty,
      hasNutritionPanel: !nutrition.isEmpty,
      hasFssaiLicence: fssai != null && fssai.isValid,
      isImageClear: cleanText.length > 30,
    );
  }

  /// Detects whether text is completely non-food (e.g., invoices, electronics, court orders).
  bool _isNonFoodText(String text) {
    final upper = text.toUpperCase();
    final nonFoodKeywords = [
      'TAX INVOICE', 'GSTIN', 'BILL OF LADING', 'RESISTOR', 'VOLTAGE',
      'CIRCUIT BREAKER', 'CPU ARCHITECTURE', 'PETITIONER', 'HON\'BLE COURT',
      'SECTION 138 NI ACT', 'WARRANTY VOID IF REMOVED',
    ];
    for (final kw in nonFoodKeywords) {
      if (upper.contains(kw)) return true;
    }

    // Must contain at least one food packaging indicator if reasonably long
    if (upper.length > 80) {
      final foodIndicators = [
        'INGREDIENT', 'NUTRITION', 'ENERGY', 'SUGAR', 'FAT', 'SERVING',
        'FSSAI', 'NET WT', 'NET WEIGHT', 'BEST BEFORE', 'EXPIRY', 'MFG',
        'FLAVOUR', 'CONTAINS', 'SALT', 'SODIUM', 'CARBOHYDRATE', 'ALLERGEN',
        'EDIBLE', 'VEG', 'NON-VEG', 'PACKED BY', 'MANUFACTURED',
      ];
      final matches = foodIndicators.where((k) => upper.contains(k)).length;
      if (matches == 0) return true;
    }

    return false;
  }

  /// Extracts individual ingredients from the ingredients clause.
  List<IngredientItem> _extractIngredients(String text, List<OcrBlock> blocks) {
    final items = <IngredientItem>[];

    // Look for INGREDIENTS marker
    final markerRegex = RegExp(
      r'(?:INGREDIENTS|CONTENTS|INGREDIENT LIST)[:\s\-]+([\s\S]+?)(?=(?:NUTRITION|NUTRITIONAL|ALLERGEN|MFG|NET WT|BEST BEFORE|STORE IN|CONTAINS ADDED|FSSAI|\n\n|$))',
      caseSensitive: false,
    );

    final match = markerRegex.firstMatch(text);
    String rawIngredientsSection = '';
    if (match != null) {
      rawIngredientsSection = match.group(1)?.trim() ?? '';
    } else {
      // Fallback: search for blocks or lines starting with Ingredients
      for (final block in blocks) {
        if (block.text.toUpperCase().contains('INGREDIENT')) {
          rawIngredientsSection += ' ${block.text}';
        }
      }
    }

    if (rawIngredientsSection.trim().isEmpty) {
      // Search for standalone INS codes even if header was slightly missed
      final insOnlyMatches = RegExp(r'(INS\s*\d{3,4}[A-Za-z]?)', caseSensitive: false).allMatches(text);
      if (insOnlyMatches.isEmpty) {
        return items;
      }
      rawIngredientsSection = text;
    }

    // Split ingredients by commas, semicolons, or parenthetical splits
    final rawTokens = rawIngredientsSection
        .replaceAll('\n', ' ')
        .split(RegExp(r'[,;•\+]|\sand\s(?![^\(]*\))'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length > 2 && s.length < 120);

    int lineIdx = 0;
    for (final token in rawTokens) {
      lineIdx++;
      // Clean up punctuation
      final cleanedToken = token.replaceAll(RegExp(r'^[^\w]+|[^\w\)]+$'), '').trim();
      if (cleanedToken.isEmpty) continue;

      // Extract INS number if present
      final insMatch = RegExp(r'(?:INS|E)\s*\(?(\d{3,4}[A-Za-z]?)\)?', caseSensitive: false).firstMatch(cleanedToken);
      String? insNumber;
      if (insMatch != null) {
        insNumber = 'INS ${insMatch.group(1)!.toUpperCase()}';
      }

      // Check with regulatory engine
      final additive = _engine.lookupAdditive(cleanedToken);

      IngredientStatus status = IngredientStatus.normal;
      String why = 'Standard food ingredient.';
      String source = 'FSS (Labelling and Display) Regulations, 2020';
      String type = 'Ingredient';

      if (additive != null) {
        type = additive.type;
        source = additive.regulatorySource;
        if (additive.isNonCompliance) {
          status = IngredientStatus.potentialNonCompliance;
          why = additive.explanation;
        } else if (additive.requiresVerification) {
          status = IngredientStatus.requiresVerification;
          why = additive.explanation;
        } else {
          status = IngredientStatus.permitted;
          why = additive.explanation;
        }
        insNumber ??= additive.insNumber;
      } else if (insNumber != null) {
        status = IngredientStatus.unknown;
        type = 'Additive';
        why = 'Additive identified with international INS numbering.';
      }

      // Try to find matching bounding box from blocks
      Rect? box;
      for (final block in blocks) {
        if (block.text.toLowerCase().contains(cleanedToken.toLowerCase())) {
          box = block.boundingBox;
          break;
        }
      }

      items.add(IngredientItem(
        name: cleanedToken,
        rawText: token,
        insNumber: insNumber,
        type: type,
        status: status,
        why: why,
        source: source,
        boundingBox: box,
        lineNumber: lineIdx,
      ));
    }

    return items;
  }

  /// Collects unique food additives from the parsed ingredients.
  List<FoodAdditive> _extractAdditives(List<IngredientItem> ingredients) {
    final list = <FoodAdditive>[];
    final seen = <String>{};

    for (final item in ingredients) {
      final additive = _engine.lookupAdditive(item.rawText);
      if (additive != null && seen.add(additive.insNumber)) {
        list.add(additive);
      } else if (item.insNumber != null && seen.add(item.insNumber!)) {
        list.add(FoodAdditive(
          name: item.name,
          insNumber: item.insNumber!,
          type: item.type,
          status: 'Category dependent',
          explanation: 'Additive code detected on label. Verify category-specific permissions.',
          regulatorySource: 'FSS (Food Products Standards and Food Additives) Regulations, 2011',
          requiresVerification: true,
        ));
      }
    }

    return list;
  }

  /// Extracts nutrition facts per 100g or serving.
  NutritionSummary _extractNutrition(String text) {
    double? energy;
    double? totalSugar;
    double? addedSugar;
    double? totalFat;
    double? saturatedFat;
    double? transFat;
    double? sodium;
    double? protein;
    String? servingSize;

    final energyRegex = RegExp(r'(?:ENERGY|CALORIES)[\s:]*([0-9]+(?:\.[0-9]+)?)\s*(?:KCAL|CAL)?', caseSensitive: false);
    final sugarRegex = RegExp(r'(?:TOTAL\s+SUGAR|SUGARS?)[\s:]*([0-9]+(?:\.[0-9]+)?)\s*G', caseSensitive: false);
    final addedSugarRegex = RegExp(r'(?:ADDED\s+SUGARS?)[\s:]*([0-9]+(?:\.[0-9]+)?)\s*G', caseSensitive: false);
    final fatRegex = RegExp(r'(?:TOTAL\s+FAT|FAT)[\s:]*([0-9]+(?:\.[0-9]+)?)\s*G', caseSensitive: false);
    final satFatRegex = RegExp(r'(?:SATURATED\s+FAT)[\s:]*([0-9]+(?:\.[0-9]+)?)\s*G', caseSensitive: false);
    final transFatRegex = RegExp(r'(?:TRANS\s+FAT)[\s:]*([0-9]+(?:\.[0-9]+)?)\s*G', caseSensitive: false);
    final sodiumRegex = RegExp(r'(?:SODIUM|NA)[\s:]*([0-9]+(?:\.[0-9]+)?)\s*(?:MG|G)', caseSensitive: false);
    final proteinRegex = RegExp(r'(?:PROTEIN)[\s:]*([0-9]+(?:\.[0-9]+)?)\s*G', caseSensitive: false);
    final servingRegex = RegExp(r'(?:SERVING\s+SIZE|PER\s+SERVE)[\s:]*([0-9A-Za-z\s]+)', caseSensitive: false);

    final mEnergy = energyRegex.firstMatch(text);
    if (mEnergy != null) energy = double.tryParse(mEnergy.group(1)!);

    final mSugar = sugarRegex.firstMatch(text);
    if (mSugar != null) totalSugar = double.tryParse(mSugar.group(1)!);

    final mAddedSugar = addedSugarRegex.firstMatch(text);
    if (mAddedSugar != null) addedSugar = double.tryParse(mAddedSugar.group(1)!);

    final mFat = fatRegex.firstMatch(text);
    if (mFat != null) totalFat = double.tryParse(mFat.group(1)!);

    final mSatFat = satFatRegex.firstMatch(text);
    if (mSatFat != null) saturatedFat = double.tryParse(mSatFat.group(1)!);

    final mTransFat = transFatRegex.firstMatch(text);
    if (mTransFat != null) transFat = double.tryParse(mTransFat.group(1)!);

    final mSodium = sodiumRegex.firstMatch(text);
    if (mSodium != null) {
      final val = double.tryParse(mSodium.group(1)!);
      if (val != null) {
        // If reported in grams, convert to mg
        sodium = mSodium.group(0)!.toUpperCase().contains('MG') ? val : val * 1000;
      }
    }

    final mProtein = proteinRegex.firstMatch(text);
    if (mProtein != null) protein = double.tryParse(mProtein.group(1)!);

    final mServing = servingRegex.firstMatch(text);
    if (mServing != null) servingSize = mServing.group(1)?.trim();

    return NutritionSummary(
      energyKcal: energy,
      totalSugarGrams: totalSugar,
      addedSugarGrams: addedSugar,
      totalFatGrams: totalFat,
      saturatedFatGrams: saturatedFat,
      transFatGrams: transFat,
      sodiumMg: sodium,
      proteinGrams: protein,
      servingSize: servingSize,
    );
  }

  /// Extracts declared allergens from the label text.
  List<String> _extractAllergens(String text) {
    final allergens = <String>{};
    final upper = text.toUpperCase();

    // Check allergen advisory clause
    final allergenSectionRegex = RegExp(
      r'(?:ALLERGEN\s+ADVICE|ALLERGEN\s+INFORMATION|CONTAINS|MAY\s+CONTAIN)[:\s\-]+([^\.\n]+)',
      caseSensitive: false,
    );
    final match = allergenSectionRegex.firstMatch(text);
    final section = match?.group(1)?.toUpperCase() ?? upper;

    if (section.contains('GLUTEN') || section.contains('WHEAT') || section.contains('BARLEY') || section.contains('OATS')) {
      allergens.add('Cereals containing Gluten (Wheat/Barley)');
    }
    if (section.contains('MILK') || section.contains('DAIRY') || section.contains('WHEY') || section.contains('CASEIN')) {
      allergens.add('Milk & Milk Solids');
    }
    if (section.contains('SOY') || section.contains('SOYA')) {
      allergens.add('Soybeans');
    }
    if (section.contains('PEANUT') || section.contains('GROUNDNUT')) {
      allergens.add('Peanuts');
    }
    if (section.contains('TREE NUT') || section.contains('ALMOND') || section.contains('CASHEW') || section.contains('WALNUT')) {
      allergens.add('Tree Nuts');
    }
    if (section.contains('EGG')) {
      allergens.add('Eggs & Egg Products');
    }
    if (section.contains('FISH') || section.contains('CRUSTACEAN') || section.contains('PRAWN')) {
      allergens.add('Fish / Crustaceans');
    }
    if (section.contains('SULPHITE') || section.contains('SULFITE')) {
      allergens.add('Sulphites');
    }

    return allergens.toList();
  }

  /// Detects the food category from packaging signals.
  String _detectCategory(String text) {
    final upper = text.toUpperCase();
    if (upper.contains('CARBONATED') || upper.contains('BEVERAGE') || upper.contains('JUICE') || upper.contains('DRINK')) {
      return 'Fruit Beverage / Drink';
    }
    if (upper.contains('BISCUIT') || upper.contains('COOKIES') || upper.contains('CRACKER') || upper.contains('BREAD') || upper.contains('CAKE') || upper.contains('BAKERY')) {
      return 'Bakery & Biscuits';
    }
    if (upper.contains('NOODLES') || upper.contains('PASTA') || upper.contains('VERMICELLI')) {
      return 'Instant Noodles & Pasta';
    }
    if (upper.contains('CHOCOLATE') || upper.contains('CANDY') || upper.contains('CONFECTIONERY')) {
      return 'Confectionery & Sweets';
    }
    if (upper.contains('SNACK') || upper.contains('CHIPS') || upper.contains('NAMKEEN') || upper.contains('CRISPS')) {
      return 'Savory Snacks / Namkeen';
    }
    if (upper.contains('SAUCE') || upper.contains('KETCHUP') || upper.contains('DIP') || upper.contains('MAYONNAISE')) {
      return 'Sauces & Condiments';
    }
    if (upper.contains('MILK') || upper.contains('YOGURT') || upper.contains('PANEER') || upper.contains('CHEESE')) {
      return 'Dairy Products';
    }
    return 'Packaged Food';
  }

  /// Extracts probable product name from first prominent block/lines.
  String? _detectProductName(String text) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    for (final line in lines.take(5)) {
      if (line.length >= 3 && line.length <= 40) {
        final upper = line.toUpperCase();
        if (!upper.contains('INGREDIENTS') &&
            !upper.contains('NUTRITION') &&
            !upper.contains('BATCH') &&
            !upper.contains('EXPIRY') &&
            !upper.contains('FSSAI')) {
          return line;
        }
      }
    }
    return null;
  }
}

/// Intermediate parsed label container.
class ParsedFoodLabel {
  final String rawText;
  final List<OcrBlock> blocks;
  final List<String> imagePaths;
  final String? productName;
  final String detectedCategory;
  final List<IngredientItem> ingredients;
  final List<FoodAdditive> additives;
  final List<String> allergens;
  final NutritionSummary nutritionSummary;
  final dynamic fssaiLicence;
  final bool hasIngredientsPanel;
  final bool hasNutritionPanel;
  final bool hasFssaiLicence;
  final bool isImageClear;
  final FoodSafetyErrorType? errorType;

  ParsedFoodLabel({
    required this.rawText,
    this.blocks = const [],
    this.imagePaths = const [],
    this.productName,
    this.detectedCategory = 'Packaged Food',
    this.ingredients = const [],
    this.additives = const [],
    this.allergens = const [],
    required this.nutritionSummary,
    this.fssaiLicence,
    this.hasIngredientsPanel = true,
    this.hasNutritionPanel = true,
    this.hasFssaiLicence = false,
    this.isImageClear = true,
    this.errorType,
  });

  factory ParsedFoodLabel.error(FoodSafetyErrorType errorType) {
    return ParsedFoodLabel(
      rawText: '',
      nutritionSummary: const NutritionSummary(),
      errorType: errorType,
      hasIngredientsPanel: false,
      hasNutritionPanel: false,
      isImageClear: false,
    );
  }

  bool get hasError => errorType != null;
}
