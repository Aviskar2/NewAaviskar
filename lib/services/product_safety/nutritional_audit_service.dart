import '../../models/product_safety_model.dart';

/// Service to audit Nutrition facts, HFSS thresholds, INS additives & allergens.
class NutritionalAuditService {
  /// Known harmful or monitored INS Additives in India (FSSAI Compendium of Food Additives)
  static const Map<String, String> _insDatabase = {
    '621': 'Monosodium Glutamate (MSG / Ajinomoto) — Flavour Enhancer (Avoid in infant food)',
    '627': 'Disodium Guanylate — Flavour Enhancer',
    '631': 'Disodium Inosinate — Flavour Enhancer',
    '635': 'Disodium 5-ribonucleotides — Flavour Enhancer',
    '102': 'Tartrazine (Yellow 5) — Synthetic Azo Dye (Potential allergen/hyperactivity)',
    '110': 'Sunset Yellow FCF (Yellow 6) — Synthetic Food Color',
    '122': 'Carmoisine (Azorubine) — Synthetic Red Color',
    '124': 'Ponceau 4R — Synthetic Red Color',
    '127': 'Erythrosine — Synthetic Red Color (Restricted in multiple jurisdictions)',
    '129': 'Allura Red AC — Synthetic Food Color',
    '133': 'Brilliant Blue FCF — Synthetic Blue Color',
    '150D': 'Caramel IV (Sulphite Ammonia Caramel) — Coloring Agent',
    '211': 'Sodium Benzoate — Chemical Preservative (Avoid with Vitamin C / Ascorbic Acid)',
    '220': 'Sulphur Dioxide — Preservative & Antioxidant (Potent Allergen for asthmatics)',
    '223': 'Sodium Metabisulphite — Chemical Preservative',
    '249': 'Potassium Nitrite — Curing Agent / Preservative in processed meats',
    '250': 'Sodium Nitrite — Preservative (Nitrosamine risk at high heat)',
    '319': 'TBHQ (Tertiary Butylhydroquinone) — Synthetic Antioxidant preservative',
    '320': 'BHA (Butylated Hydroxyanisole) — Synthetic Antioxidant',
    '321': 'BHT (Butylated Hydroxytoluene) — Synthetic Antioxidant',
    '950': 'Acesulfame Potassium (Ace-K) — Intense Artificial Sweetener',
    '951': 'Aspartame — Artificial Sweetener (Not recommended for Phenylketonurics)',
    '954': 'Saccharin — Artificial Sweetener',
    '955': 'Sucralose — Non-nutritive Artificial Sweetener',
    '960': 'Steviol Glycosides (Stevia) — Natural High-intensity Sweetener',
  };

  /// Common allergens monitored under FSSAI regulations
  static const List<String> _allergenKeywords = [
    'GLUTEN', 'WHEAT', 'MILK', 'DAIRY', 'LACTOSE', 'PEANUT', 'PEANUTS',
    'TREE NUTS', 'ALMOND', 'CASHEW', 'WALNUT', 'SOY', 'SOYA', 'SOYBEAN',
    'EGG', 'EGGS', 'FISH', 'CRUSTACEAN', 'SHELLFISH', 'SESAME', 'SULPHITE',
  ];

  /// Audits OCR text for nutritional facts and HFSS thresholds.
  NutritionalAnalysis auditNutrition(String rawText) {
    final clean = rawText.toUpperCase();

    final energy = _extractNumeric(clean, [r'ENERGY[:\s]+(\d+(?:\.\d+)?)\s*(?:KCAL|CAL)?', r'CALORIES[:\s]+(\d+(?:\.\d+)?)']);
    final totalFat = _extractNumeric(clean, [r'TOTAL FAT[:\s]+(\d+(?:\.\d+)?)\s*G?', r'FAT[:\s]+(\d+(?:\.\d+)?)\s*G']);
    final satFat = _extractNumeric(clean, [r'SATURATED FAT[:\s]+(\d+(?:\.\d+)?)\s*G?', r'SAT FAT[:\s]+(\d+(?:\.\d+)?)\s*G']);
    final transFat = _extractNumeric(clean, [r'TRANS FAT[:\s]+(\d+(?:\.\d+)?)\s*G?']);
    final carbs = _extractNumeric(clean, [r'CARBOHYDRATE[S]?[:\s]+(\d+(?:\.\d+)?)\s*G?', r'TOTAL CARBS[:\s]+(\d+(?:\.\d+)?)\s*G']);
    final totalSugar = _extractNumeric(clean, [r'TOTAL SUGAR[S]?[:\s]+(\d+(?:\.\d+)?)\s*G?', r'SUGAR[S]?[:\s]+(\d+(?:\.\d+)?)\s*G']);
    final addedSugar = _extractNumeric(clean, [r'ADDED SUGAR[S]?[:\s]+(\d+(?:\.\d+)?)\s*G?']);
    final sodium = _extractNumeric(clean, [r'SODIUM[:\s]+(\d+(?:\.\d+)?)\s*(?:MG|G)?', r'SALT[:\s]+(\d+(?:\.\d+)?)\s*G?']);
    final protein = _extractNumeric(clean, [r'PROTEIN[:\s]+(\d+(?:\.\d+)?)\s*G?']);

    // FSSAI / ICMR HFSS Thresholds (per 100g)
    final isHighSugar = (totalSugar != null && totalSugar > 10.0) || (addedSugar != null && addedSugar > 6.0);
    final isHighSodium = (sodium != null && sodium > 400.0); // 400mg per 100g
    final isHighSatFat = (satFat != null && satFat > 5.0);
    final hasExcessTransFat = (transFat != null && transFat > 0.2); // FSSAI cap < 0.2g / 2%

    final warnings = <String>[];
    if (isHighSugar) {
      warnings.add('High Sugar Content (>10g/100g) — May increase diabetes and obesity risk.');
    }
    if (isHighSodium) {
      warnings.add('High Sodium (>400mg/100g) — May contribute to high blood pressure / hypertension.');
    }
    if (isHighSatFat) {
      warnings.add('High Saturated Fat (>5g/100g) — High intake can increase LDL cholesterol.');
    }
    if (hasExcessTransFat) {
      warnings.add('Contains Trans Fat (>0.2g) — FSSAI mandates eliminating industrial trans fats.');
    }

    return NutritionalAnalysis(
      energyKcal: energy,
      totalFatGrams: totalFat,
      saturatedFatGrams: satFat,
      transFatGrams: transFat,
      totalCarbsGrams: carbs,
      totalSugarGrams: totalSugar,
      addedSugarGrams: addedSugar,
      sodiumMg: sodium,
      proteinGrams: protein,
      isHighSugar: isHighSugar,
      isHighSodium: isHighSodium,
      isHighSaturatedFat: isHighSatFat,
      hasExcessTransFat: hasExcessTransFat,
      nutritionalWarnings: warnings,
    );
  }

  /// Audits ingredients for Veg/Non-Veg, INS Additives, Palm Oil & Allergens.
  IngredientStandardsAnalysis auditIngredients(String rawText) {
    final clean = rawText.toUpperCase();

    // 1. Veg / Non-Veg detection
    final isNonVeg = clean.contains('NON-VEGETARIAN') ||
        clean.contains('NON VEG') ||
        clean.contains('CHICKEN') ||
        clean.contains('MEAT') ||
        clean.contains('FISH') ||
        clean.contains('GELATIN') ||
        clean.contains('EGG') ||
        clean.contains('PRAWN');

    final isVegan = clean.contains('100% VEGAN') || clean.contains('PLANT BASED');
    final isVeg = !isNonVeg && (clean.contains('VEGETARIAN') || clean.contains('100% VEG') || clean.contains('GREEN DOT'));

    // 2. INS Additive detection
    final detectedAdditives = <String>[];
    for (final entry in _insDatabase.entries) {
      final code = entry.key;
      final insPattern = RegExp('\\b(?:INS|E)[\\s\\-]*$code\\b', caseSensitive: false);
      if (insPattern.hasMatch(clean)) {
        detectedAdditives.add('INS $code: ${entry.value}');
      }
    }

    // Direct MSG check
    if (clean.contains('MSG') || clean.contains('AJINOMOTO') || clean.contains('MONOSODIUM GLUTAMATE')) {
      if (!detectedAdditives.any((a) => a.contains('621'))) {
        detectedAdditives.add('INS 621: Monosodium Glutamate (MSG) — Flavour Enhancer');
      }
    }

    // 3. Allergen warnings
    final detectedAllergens = <String>[];
    for (final allergen in _allergenKeywords) {
      final allergenRegex = RegExp('\\b(?:CONTAINS|ALLERGEN|MAY CONTAIN)[^.]*\\b$allergen\\b');
      if (allergenRegex.hasMatch(clean) || clean.contains('ALLERGEN: $allergen')) {
        detectedAllergens.add(allergen);
      }
    }

    // 4. Health / Quality concerns
    final concerns = <String>[];
    if (clean.contains('PALM OIL') || clean.contains('PALMOLEIN') || clean.contains('FRACTIONATED PALM')) {
      concerns.add('Contains Refined Palm Oil / Palmolein (High in Saturated Fatty Acids)');
    }
    if (clean.contains('HYDROGENATED VEGETABLE OIL') || clean.contains('VANASPATI')) {
      concerns.add('Contains Hydrogenated Vegetable Oil (Vanaspati) — Source of industrial trans fats');
    }
    if (clean.contains('ARTIFICIAL SWEETENER') || clean.contains('INTENSE SWEETENER')) {
      concerns.add('Contains Non-Caloric Artificial Sweetener');
    }
    if (clean.contains('ADDED FLAVOUR') || clean.contains('ARTIFICIAL FLAVOUR')) {
      concerns.add('Contains Synthetic / Nature Identical Artificial Flavouring Substances');
    }

    return IngredientStandardsAnalysis(
      isVegetarian: isVeg,
      isNonVegetarian: isNonVeg,
      isVegan: isVegan,
      detectedAdditives: detectedAdditives,
      detectedAllergens: detectedAllergens,
      healthConcerns: concerns,
    );
  }

  double? _extractNumeric(String text, List<String> patterns) {
    for (final p in patterns) {
      final match = RegExp(p).firstMatch(text);
      if (match != null) {
        final valStr = match.group(1);
        if (valStr != null) {
          final parsed = double.tryParse(valStr);
          if (parsed != null) return parsed;
        }
      }
    }
    return null;
  }
}
