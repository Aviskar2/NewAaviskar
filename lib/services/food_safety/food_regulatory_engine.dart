import '../../core/food_safety/models/food_safety_models.dart';

/// Authentic Indian FSSAI Food Regulatory Rules Engine.
/// Implements:
/// - Food Safety and Standards (Food Products Standards and Food Additives) Regulations, 2011 & Amendments
/// - Food Safety and Standards (Labelling and Display) Regulations, 2020
/// - Food Safety and Standards (Prohibition and Restrictions on Sales) Regulations
class FoodRegulatoryEngine {
  static final FoodRegulatoryEngine instance = FoodRegulatoryEngine._();
  FoodRegulatoryEngine._();
  factory FoodRegulatoryEngine() => instance;

  /// Knowledge base of INS additives and their FSSAI regulatory status.
  static const Map<String, FoodAdditive> _insDatabase = {
    // ─── Prohibited Additives ───────────────────────────────────────────────
    'INS 924A': FoodAdditive(
      name: 'Potassium Bromate',
      insNumber: 'INS 924a',
      type: 'Flour Treatment Agent / Bleaching Agent',
      status: 'Prohibited for this use',
      explanation:
          'Potassium Bromate (INS 924a) was de-notified and prohibited from use in all food products in India by FSSAI in 2016 due to public health directives.',
      regulatorySource:
          'FSSAI Notification No. Stds/SP(Water & Beverages)/Notification(1)/FSSAI-2016',
      condition: 'Prohibited across all packaged food and bakery categories.',
      maxLevel: '0 ppm (Not permitted)',
      effectiveDate: '20-Jun-2016',
      lastVerified: '2024 FSSAI Compendium',
      officialSourceUrl: 'https://www.fssai.gov.in/upload/notifications/2016/06/576b92f768b5aOrder_Potassium_Bromate_20_06_2016.pdf',
      isNonCompliance: true,
      requiresVerification: false,
    ),
    'INS 928': FoodAdditive(
      name: 'Benzoyl Peroxide',
      insNumber: 'INS 928',
      type: 'Bleaching Agent',
      status: 'Prohibited for this use',
      explanation:
          'Benzoyl Peroxide is prohibited in standard refined flours (Maida) and bakery flours unless specifically exempted under regulated milling licenses.',
      regulatorySource:
          'FSS (Food Products Standards and Food Additives) Regulations, 2011, Reg 2.4.2',
      condition: 'Restricted to licensed industrial milling only, prohibited in direct consumer mixes.',
      maxLevel: '40 ppm max where licensed; prohibited in retail breads',
      effectiveDate: '05-Aug-2011',
      lastVerified: '2024 FSSAI Compendium',
      officialSourceUrl: 'https://www.fssai.gov.in',
      isNonCompliance: true,
      requiresVerification: false,
    ),

    // ─── Category / Condition Dependent Additives ───────────────────────────
    'INS 211': FoodAdditive(
      name: 'Sodium Benzoate',
      insNumber: 'INS 211',
      type: 'Preservative',
      status: 'Category/condition dependent',
      explanation:
          'Whether this additive is permitted depends on the food category and applicable conditions/limits. Permitted up to 600-750 ppm in beverages and sauces, but prohibited in milk, plain flours, and infant nutrition.',
      regulatorySource:
          'FSS (Food Products Standards and Food Additives) Regulations, 2011, Appendix A, Table 1',
      condition: 'Permitted in carbonated fruit beverages, crushes, pickles; prohibited in dairy & infant foods.',
      maxLevel: '750 ppm (Class II Preservative)',
      effectiveDate: '05-Aug-2011',
      lastVerified: '2024 FSSAI Compendium',
      officialSourceUrl: 'https://www.fssai.gov.in',
      isNonCompliance: false,
      requiresVerification: true,
    ),
    'INS 202': FoodAdditive(
      name: 'Potassium Sorbate',
      insNumber: 'INS 202',
      type: 'Preservative',
      status: 'Category/condition dependent',
      explanation:
          'Permitted Class II preservative in bakery products, cheeses, and fruit spreads within statutory upper limits. Prohibited in pure spice powders and infant food.',
      regulatorySource:
          'FSS (Food Products Standards and Food Additives) Regulations, 2011, Appendix A, Table 2',
      condition: 'Permitted in bakery products (1000 ppm max), cheese (500 ppm max).',
      maxLevel: '1000 ppm',
      effectiveDate: '05-Aug-2011',
      lastVerified: '2024 FSSAI Compendium',
      officialSourceUrl: 'https://www.fssai.gov.in',
      isNonCompliance: false,
      requiresVerification: true,
    ),
    'INS 621': FoodAdditive(
      name: 'Monosodium Glutamate (MSG)',
      insNumber: 'INS 621',
      type: 'Flavour Enhancer',
      status: 'Category/condition dependent',
      explanation:
          'Permitted in noodles, seasonings, and savory snacks under Good Manufacturing Practice (GMP). Mandatory statutory warning required: "Not recommended for infants below 12 months".',
      regulatorySource:
          'FSS (Food Products Standards and Food Additives) Regulations, 2011, Reg 3.1.11 & Labelling Regulations 2020',
      condition: 'Requires mandatory advisory label; prohibited in infant and baby formulations.',
      maxLevel: 'Good Manufacturing Practice (GMP)',
      effectiveDate: '05-Aug-2011',
      lastVerified: '2024 FSSAI Compendium',
      officialSourceUrl: 'https://www.fssai.gov.in',
      isNonCompliance: false,
      requiresVerification: true,
    ),
    'INS 102': FoodAdditive(
      name: 'Tartrazine',
      insNumber: 'INS 102',
      type: 'Synthetic Food Colour',
      status: 'Category/condition dependent',
      explanation:
          'Permitted synthetic food colour for specific items (confectionery, non-alcoholic beverages) capped at 100 mg/kg. Mandatory label declaration: "CONTAINS PERMITTED SYNTHETIC FOOD COLOUR(S)".',
      regulatorySource:
          'FSS (Labelling and Display) Regulations, 2020 & FSS Additives Regs 2011 Reg 3.1.2',
      condition: 'Permitted up to 100 mg/kg in selected categories with mandatory front/back declaration.',
      maxLevel: '100 mg/kg (or 200 mg/kg in canned foods)',
      effectiveDate: '05-Aug-2011',
      lastVerified: '2024 FSSAI Compendium',
      officialSourceUrl: 'https://www.fssai.gov.in',
      isNonCompliance: false,
      requiresVerification: true,
    ),
    'INS 110': FoodAdditive(
      name: 'Sunset Yellow FCF',
      insNumber: 'INS 110',
      type: 'Synthetic Food Colour',
      status: 'Category/condition dependent',
      explanation:
          'Permitted synthetic color subject to strict maximum usage limits (100 ppm) and mandatory statutory label disclosure.',
      regulatorySource:
          'FSS (Labelling and Display) Regulations, 2020, Reg 5(2)',
      condition: 'Permitted in biscuits, confectionery, and ready-to-serve beverages.',
      maxLevel: '100 mg/kg',
      effectiveDate: '05-Aug-2011',
      lastVerified: '2024 FSSAI Compendium',
      officialSourceUrl: 'https://www.fssai.gov.in',
      isNonCompliance: false,
      requiresVerification: true,
    ),
    'INS 951': FoodAdditive(
      name: 'Aspartame',
      insNumber: 'INS 951',
      type: 'Non-Caloric Artificial Sweetener',
      status: 'Category/condition dependent',
      explanation:
          'Permitted non-caloric sweetener. Statutory warning required on label: "Contains Artificial Sweetener. Not recommended for children. Contains Phenylalanine".',
      regulatorySource:
          'FSS (Labelling and Display) Regulations, 2020, Schedule II',
      condition: 'Prohibited in infant food; requires mandatory phenylketonuric advisory statement.',
      maxLevel: '700 ppm in beverages; 1000 ppm in confectionery',
      effectiveDate: '05-Aug-2011',
      lastVerified: '2024 FSSAI Compendium',
      officialSourceUrl: 'https://www.fssai.gov.in',
      isNonCompliance: false,
      requiresVerification: true,
    ),
    'INS 950': FoodAdditive(
      name: 'Acesulfame Potassium',
      insNumber: 'INS 950',
      type: 'Non-Caloric Artificial Sweetener',
      status: 'Category/condition dependent',
      explanation:
          'Permitted artificial sweetener requiring statutory front/back declaration and quantity declaration on the label.',
      regulatorySource:
          'FSS (Labelling and Display) Regulations, 2020, Schedule II',
      condition: 'Requires statutory label declaration.',
      maxLevel: '600 ppm in carbonated water; 1000 ppm in confectionery',
      effectiveDate: '05-Aug-2011',
      lastVerified: '2024 FSSAI Compendium',
      officialSourceUrl: 'https://www.fssai.gov.in',
      isNonCompliance: false,
      requiresVerification: true,
    ),

    // ─── Permitted Standard Additives (GMP) ─────────────────────────────────
    'INS 330': FoodAdditive(
      name: 'Citric Acid',
      insNumber: 'INS 330',
      type: 'Acidity Regulator / Antioxidant Synergist',
      status: 'Permitted',
      explanation:
          'Widely permitted food acidulent and antioxidant synergist under Good Manufacturing Practice (GMP) across nearly all food categories.',
      regulatorySource:
          'FSS (Food Products Standards and Food Additives) Regulations, 2011, Table 10',
      condition: 'Permitted under Good Manufacturing Practice (GMP).',
      maxLevel: 'GMP',
      effectiveDate: '05-Aug-2011',
      lastVerified: '2024 FSSAI Compendium',
      officialSourceUrl: 'https://www.fssai.gov.in',
      isNonCompliance: false,
      requiresVerification: false,
    ),
    'INS 322': FoodAdditive(
      name: 'Lecithin (Soy / Egg)',
      insNumber: 'INS 322',
      type: 'Emulsifier',
      status: 'Permitted',
      explanation:
          'Natural emulsifier permitted under Good Manufacturing Practice (GMP) in chocolate, confectionery, baked goods, and spreads.',
      regulatorySource:
          'FSS (Food Products Standards and Food Additives) Regulations, 2011, Appendix A',
      condition: 'Permitted under GMP. If derived from soy or egg, source must be declared in allergen statement.',
      maxLevel: 'GMP',
      effectiveDate: '05-Aug-2011',
      lastVerified: '2024 FSSAI Compendium',
      officialSourceUrl: 'https://www.fssai.gov.in',
      isNonCompliance: false,
      requiresVerification: false,
    ),
    'INS 500': FoodAdditive(
      name: 'Sodium Carbonates (Baking Soda)',
      insNumber: 'INS 500',
      type: 'Acidity Regulator / Raising Agent',
      status: 'Permitted',
      explanation:
          'Standard food-grade leavening agent and acidity regulator permitted under GMP across food categories.',
      regulatorySource:
          'FSS (Food Products Standards and Food Additives) Regulations, 2011, Table 10',
      condition: 'Permitted under GMP in bakery, confectionery, and processed foods.',
      maxLevel: 'GMP',
      effectiveDate: '05-Aug-2011',
      lastVerified: '2024 FSSAI Compendium',
      officialSourceUrl: 'https://www.fssai.gov.in',
      isNonCompliance: false,
      requiresVerification: false,
    ),
    'INS 440': FoodAdditive(
      name: 'Pectin',
      insNumber: 'INS 440',
      type: 'Gelling Agent / Thickener',
      status: 'Permitted',
      explanation:
          'Naturally derived plant gelling agent permitted under GMP in jams, jellies, dairy, and confectionery.',
      regulatorySource:
          'FSS (Food Products Standards and Food Additives) Regulations, 2011, Table 10',
      condition: 'Permitted under GMP.',
      maxLevel: 'GMP',
      effectiveDate: '05-Aug-2011',
      lastVerified: '2024 FSSAI Compendium',
      officialSourceUrl: 'https://www.fssai.gov.in',
      isNonCompliance: false,
      requiresVerification: false,
    ),
    'INS 300': FoodAdditive(
      name: 'Ascorbic Acid (Vitamin C)',
      insNumber: 'INS 300',
      type: 'Antioxidant',
      status: 'Permitted',
      explanation:
          'Food-grade antioxidant permitted under GMP to retard oxidative rancidity in processed foods and beverages.',
      regulatorySource:
          'FSS (Food Products Standards and Food Additives) Regulations, 2011, Table 9',
      condition: 'Permitted under GMP.',
      maxLevel: 'GMP (up to 200 ppm in flour)',
      effectiveDate: '05-Aug-2011',
      lastVerified: '2024 FSSAI Compendium',
      officialSourceUrl: 'https://www.fssai.gov.in',
      isNonCompliance: false,
      requiresVerification: false,
    ),
    'INS 150D': FoodAdditive(
      name: 'Caramel IV (Sulphite Ammonia Caramel)',
      insNumber: 'INS 150d',
      type: 'Natural / Nature-Identical Colour',
      status: 'Permitted',
      explanation:
          'Permitted food colour for carbonated beverages, confectionery, and sauces subject to FSSAI identity standards.',
      regulatorySource:
          'FSS (Food Products Standards and Food Additives) Regulations, 2011, Reg 3.1.2',
      condition: 'Permitted within category GMP / maximum limit norms.',
      maxLevel: 'GMP / category limits',
      effectiveDate: '05-Aug-2011',
      lastVerified: '2024 FSSAI Compendium',
      officialSourceUrl: 'https://www.fssai.gov.in',
      isNonCompliance: false,
      requiresVerification: false,
    ),
  };

  /// Common names mapping to INS codes.
  static const Map<String, String> _nameToIns = {
    'SODIUM BENZOATE': 'INS 211',
    'POTASSIUM SORBATE': 'INS 202',
    'POTASSIUM BROMATE': 'INS 924A',
    'BENZOYL PEROXIDE': 'INS 928',
    'MONOSODIUM GLUTAMATE': 'INS 621',
    'MSG': 'INS 621',
    'TARTRAZINE': 'INS 102',
    'SUNSET YELLOW': 'INS 110',
    'ASPARTAME': 'INS 951',
    'ACESULFAME K': 'INS 950',
    'ACESULFAME POTASSIUM': 'INS 950',
    'CITRIC ACID': 'INS 330',
    'SOYA LECITHIN': 'INS 322',
    'SOY LECITHIN': 'INS 322',
    'LECITHIN': 'INS 322',
    'SODIUM BICARBONATE': 'INS 500',
    'BAKING SODA': 'INS 500',
    'PECTIN': 'INS 440',
    'ASCORBIC ACID': 'INS 300',
    'CARAMEL IV': 'INS 150D',
  };

  /// Lookup additive by INS code or name.
  FoodAdditive? lookupAdditive(String query) {
    final cleaned = query.trim().toUpperCase();

    // Check direct INS key
    if (_insDatabase.containsKey(cleaned)) {
      return _insDatabase[cleaned];
    }

    // Check INS pattern without space or with prefix e.g. "INS211" -> "INS 211", "E211" -> "INS 211"
    final insMatch = RegExp(r'(?:INS|E)\s*\(?(\d{3,4}[A-Z]?)\)?').firstMatch(cleaned);
    if (insMatch != null) {
      final code = insMatch.group(1)!;
      final key = 'INS $code';
      if (_insDatabase.containsKey(key)) {
        return _insDatabase[key];
      }
      // Try with single letter uppercase or lowercase
      for (final k in _insDatabase.keys) {
        if (k.replaceAll(' ', '') == 'INS$code') {
          return _insDatabase[k];
        }
      }
    }

    // Check common name lookup
    for (final entry in _nameToIns.entries) {
      if (cleaned.contains(entry.key)) {
        return _insDatabase[entry.value];
      }
    }

    return null;
  }

  /// Evaluates regulatory compliance from detected additives, ingredients, and label signals.
  /// Strictly label-based screening according to Indian food law.
  RegulatoryEvaluation evaluate({
    required List<FoodAdditive> detectedAdditives,
    required List<IngredientItem> ingredients,
    required bool hasIngredientsPanel,
    required bool hasNutritionPanel,
    required bool hasFssaiLicence,
    required String detectedCategory,
    required bool isImageClear,
  }) {
    // 1. Missing information check (Screen 8)
    final missing = <String>[];
    if (!hasIngredientsPanel) {
      missing.add('Ingredients panel not detected');
    }
    if (!hasNutritionPanel) {
      missing.add('Nutrition information panel not detected');
    }
    if (!hasFssaiLicence) {
      missing.add('FSSAI 14-digit license number not visible on scanned surface');
    }
    if (!isImageClear) {
      missing.add('Label image unclear or partially truncated');
    }
    if (detectedCategory == 'Packaged Food' || detectedCategory.isEmpty) {
      missing.add('Specific food sub-category not explicitly declared');
    }

    // 2. Check for prohibited substances (Screen 7: Potential non-compliance)
    final prohibitedAdditives = detectedAdditives.where((a) => a.isNonCompliance).toList();
    if (prohibitedAdditives.isNotEmpty) {
      final primary = prohibitedAdditives.first;
      final primaryFinding = RegulatoryFinding(
        findingId: 'FSSAI-NON-COMPLIANCE-${primary.insNumber.replaceAll(' ', '')}',
        finding: '${primary.name} (${primary.insNumber})',
        ruleStatus: 'Prohibited for this use',
        foodCategory: detectedCategory,
        condition: primary.condition,
        maxLevel: primary.maxLevel,
        source: primary.regulatorySource,
        effectiveDate: primary.effectiveDate,
        lastVerified: primary.lastVerified,
        officialSourceUrl: primary.officialSourceUrl,
        isPrimaryFinding: true,
        why: primary.explanation,
      );

      final otherObs = <RegulatoryFinding>[];
      for (final a in prohibitedAdditives.skip(1)) {
        otherObs.add(RegulatoryFinding(
          findingId: 'FSSAI-${a.insNumber}',
          finding: '${a.name} (${a.insNumber})',
          ruleStatus: 'Prohibited for this use',
          foodCategory: detectedCategory,
          condition: a.condition,
          maxLevel: a.maxLevel,
          source: a.regulatorySource,
          effectiveDate: a.effectiveDate,
          lastVerified: a.lastVerified,
          officialSourceUrl: a.officialSourceUrl,
          why: a.explanation,
        ));
      }

      return RegulatoryEvaluation(
        status: FoodVerificationStatus.potentialNonCompliance,
        primaryFinding: primaryFinding,
        otherObservations: otherObs,
        missingInformation: missing,
      );
    }

    // 3. Check for category/condition dependent substances (Screen 6: Review recommended)
    final reviewAdditives = detectedAdditives.where((a) => a.requiresVerification).toList();
    if (reviewAdditives.isNotEmpty) {
      final primary = reviewAdditives.first;
      final primaryFinding = RegulatoryFinding(
        findingId: 'FSSAI-REVIEW-${primary.insNumber.replaceAll(' ', '')}',
        finding: '${primary.name} (${primary.insNumber})',
        ruleStatus: 'Category/condition dependent',
        foodCategory: detectedCategory,
        condition: primary.condition,
        maxLevel: primary.maxLevel,
        source: primary.regulatorySource,
        effectiveDate: primary.effectiveDate,
        lastVerified: primary.lastVerified,
        officialSourceUrl: primary.officialSourceUrl,
        isPrimaryFinding: true,
        why: primary.explanation,
      );

      final otherObs = <RegulatoryFinding>[];
      for (final a in reviewAdditives.skip(1)) {
        otherObs.add(RegulatoryFinding(
          findingId: 'FSSAI-${a.insNumber}',
          finding: '${a.name} (${a.insNumber})',
          ruleStatus: 'Category/condition dependent',
          foodCategory: detectedCategory,
          condition: a.condition,
          maxLevel: a.maxLevel,
          source: a.regulatorySource,
          effectiveDate: a.effectiveDate,
          lastVerified: a.lastVerified,
          officialSourceUrl: a.officialSourceUrl,
          why: a.explanation,
        ));
      }

      return RegulatoryEvaluation(
        status: FoodVerificationStatus.reviewRecommended,
        primaryFinding: primaryFinding,
        otherObservations: otherObs,
        missingInformation: missing,
      );
    }

    // 4. Check if label cannot be fully verified due to missing crucial info (Screen 8)
    // Rule: Only show applicable missing info, never convert into a violation.
    if (missing.length >= 2 || !hasIngredientsPanel) {
      return RegulatoryEvaluation(
        status: FoodVerificationStatus.cannotFullyVerify,
        primaryFinding: null,
        otherObservations: const [],
        missingInformation: missing,
      );
    }

    // 5. No label-based issue found (Screen 5)
    return RegulatoryEvaluation(
      status: FoodVerificationStatus.noIssue,
      primaryFinding: null,
      otherObservations: const [],
      missingInformation: const [],
    );
  }
}

/// Evaluation output from the regulatory engine.
class RegulatoryEvaluation {
  final FoodVerificationStatus status;
  final RegulatoryFinding? primaryFinding;
  final List<RegulatoryFinding> otherObservations;
  final List<String> missingInformation;

  const RegulatoryEvaluation({
    required this.status,
    this.primaryFinding,
    this.otherObservations = const [],
    this.missingInformation = const [],
  });
}
