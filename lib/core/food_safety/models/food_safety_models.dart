import 'package:flutter/painting.dart' show Rect;
import '../../../models/product_safety_model.dart' show FssaiVerification;
import '../../../models/scan_result_model.dart' show OcrBlock;

/// Regulatory verification status for a scanned food product label.
/// Per ScanSure principles: strictly label-based regulatory screening, NOT a health score.
enum FoodVerificationStatus {
  noIssue,
  reviewRecommended,
  potentialNonCompliance,
  cannotFullyVerify;

  String get title {
    switch (this) {
      case FoodVerificationStatus.noIssue:
        return 'No label-based issue found';
      case FoodVerificationStatus.reviewRecommended:
        return 'Review recommended';
      case FoodVerificationStatus.potentialNonCompliance:
        return 'Potential non-compliance identified';
      case FoodVerificationStatus.cannotFullyVerify:
        return 'Cannot fully verify';
    }
  }

  String get subtitle {
    switch (this) {
      case FoodVerificationStatus.noIssue:
        return 'No applicable issue was identified from the information visible on the scanned label.';
      case FoodVerificationStatus.reviewRecommended:
        return '1 item requires further regulatory verification.';
      case FoodVerificationStatus.potentialNonCompliance:
        return 'One or more items do not conform to applicable FSSAI regulatory standards.';
      case FoodVerificationStatus.cannotFullyVerify:
        return 'Some checks require information that is not available on the scanned label.';
    }
  }

  String get iconSymbol {
    switch (this) {
      case FoodVerificationStatus.noIssue:
        return '✓';
      case FoodVerificationStatus.reviewRecommended:
        return '⚠';
      case FoodVerificationStatus.potentialNonCompliance:
        return '✕';
      case FoodVerificationStatus.cannotFullyVerify:
        return 'ⓘ';
    }
  }
}

/// Semantic highlighting status of an individual ingredient/substance.
enum IngredientStatus {
  normal,
  permitted,
  requiresVerification,
  potentialNonCompliance,
  unknown;

  String get displayName {
    switch (this) {
      case IngredientStatus.normal:
        return 'Standard Ingredient';
      case IngredientStatus.permitted:
        return 'Permitted Additive';
      case IngredientStatus.requiresVerification:
        return 'Category Dependent';
      case IngredientStatus.potentialNonCompliance:
        return 'Prohibited for this use';
      case IngredientStatus.unknown:
        return 'Unclassified';
    }
  }
}

/// Steps for multi-panel food label capture.
enum FoodSafetyScanStep {
  ingredients,
  nutrition,
  otherDetails;

  String get displayName {
    switch (this) {
      case FoodSafetyScanStep.ingredients:
        return 'Ingredients';
      case FoodSafetyScanStep.nutrition:
        return 'Nutrition';
      case FoodSafetyScanStep.otherDetails:
        return 'Other details';
    }
  }
}

/// Real backend analysis states shown sequentially on the analyzing screen.
enum FoodAnalysisStep {
  readingLabel,
  identifyingIngredients,
  matchingIngredients,
  checkingCategory,
  checkingRegulations,
  preparingResult;

  String get displayName {
    switch (this) {
      case FoodAnalysisStep.readingLabel:
        return 'Reading text';
      case FoodAnalysisStep.identifyingIngredients:
        return 'Identifying ingredients';
      case FoodAnalysisStep.matchingIngredients:
        return 'Detecting additives';
      case FoodAnalysisStep.checkingCategory:
        return 'Checking food category';
      case FoodAnalysisStep.checkingRegulations:
        return 'Checking applicable rules';
      case FoodAnalysisStep.preparingResult:
        return 'Preparing result';
    }
  }
}

/// An individual food additive identified on the label.
class FoodAdditive {
  final String name;
  final String insNumber; // e.g. "INS 211"
  final String type; // e.g. "Preservative", "Acidity Regulator", "Synthetic Colour"
  final String status; // "Permitted", "Category dependent", "Prohibited for this use"
  final String detectedIn; // "Ingredients"
  final String explanation;
  final String regulatorySource; // e.g. "FSSAI Food Safety and Standards Regulations, 2011"
  final String? condition;
  final String? maxLevel;
  final String effectiveDate;
  final String lastVerified;
  final String officialSourceUrl;
  final bool isNonCompliance;
  final bool requiresVerification;

  const FoodAdditive({
    required this.name,
    required this.insNumber,
    required this.type,
    required this.status,
    this.detectedIn = 'Ingredients',
    required this.explanation,
    required this.regulatorySource,
    this.condition,
    this.maxLevel,
    this.effectiveDate = '05-Aug-2011',
    this.lastVerified = '2024 FSSAI Compendium',
    this.officialSourceUrl = 'https://www.fssai.gov.in',
    this.isNonCompliance = false,
    this.requiresVerification = false,
  });
}

/// An ingredient mapped directly to the document/label text.
class IngredientItem {
  final String name;
  final String rawText;
  final String? insNumber;
  final String type;
  final IngredientStatus status;
  final String why;
  final String source;
  final Rect? boundingBox;
  final int? lineNumber;

  const IngredientItem({
    required this.name,
    required this.rawText,
    this.insNumber,
    this.type = 'Ingredient',
    this.status = IngredientStatus.normal,
    required this.why,
    required this.source,
    this.boundingBox,
    this.lineNumber,
  });
}

/// Specific regulatory finding linked to statutory FSSAI rules.
class RegulatoryFinding {
  final String findingId;
  final String finding; // Detected ingredient / additive / label requirement
  final String ruleStatus; // "Permitted", "Restricted", "Prohibited", "Category Dependent", "Unknown"
  final String foodCategory;
  final String? condition;
  final String? maxLevel;
  final String source; // FSSAI regulation citation
  final String effectiveDate;
  final String lastVerified;
  final String officialSourceUrl;
  final bool isPrimaryFinding;
  final String why; // Short plain-English explanation

  const RegulatoryFinding({
    required this.findingId,
    required this.finding,
    required this.ruleStatus,
    required this.foodCategory,
    this.condition,
    this.maxLevel,
    required this.source,
    this.effectiveDate = '05-Aug-2011',
    this.lastVerified = '2024 FSSAI Compendium',
    this.officialSourceUrl = 'https://www.fssai.gov.in',
    this.isPrimaryFinding = false,
    required this.why,
  });
}

/// Objective nutrition values extracted directly from the visible label.
/// Per ScanSure principles: strictly informational, never labelled "unhealthy".
class NutritionSummary {
  final double? energyKcal;
  final double? totalSugarGrams;
  final double? addedSugarGrams;
  final double? totalFatGrams;
  final double? saturatedFatGrams;
  final double? transFatGrams;
  final double? sodiumMg;
  final double? proteinGrams;
  final String? servingSize;

  const NutritionSummary({
    this.energyKcal,
    this.totalSugarGrams,
    this.addedSugarGrams,
    this.totalFatGrams,
    this.saturatedFatGrams,
    this.transFatGrams,
    this.sodiumMg,
    this.proteinGrams,
    this.servingSize,
  });

  bool get isEmpty =>
      energyKcal == null &&
      totalSugarGrams == null &&
      totalFatGrams == null &&
      saturatedFatGrams == null &&
      transFatGrams == null &&
      sodiumMg == null;
}

/// Master scan result for Food Safety Check.
class FoodLabelScanResult {
  final FoodVerificationStatus status;
  final String? productName;
  final String detectedCategory;
  final RegulatoryFinding? primaryFinding;
  final List<RegulatoryFinding> otherObservations;
  final List<IngredientItem> ingredients;
  final List<FoodAdditive> additives;
  final List<String> allergens;
  final List<String> missingInformation;
  final NutritionSummary nutritionSummary;
  final FssaiVerification? fssaiLicence;
  final List<String> scannedImages;
  final String rawOcrText;
  final List<OcrBlock> ocrBlocks;
  final Map<String, String> reviewedSummary;
  final DateTime analyzedAt;

  const FoodLabelScanResult({
    required this.status,
    this.productName,
    this.detectedCategory = 'Packaged Food',
    this.primaryFinding,
    this.otherObservations = const [],
    this.ingredients = const [],
    this.additives = const [],
    this.allergens = const [],
    this.missingInformation = const [],
    required this.nutritionSummary,
    this.fssaiLicence,
    this.scannedImages = const [],
    required this.rawOcrText,
    this.ocrBlocks = const [],
    this.reviewedSummary = const {
      'Ingredients': '✓ Reviewed',
      'Additives': '✓ Reviewed',
      'Allergens': '✓ Reviewed',
      'Label information': '✓ Reviewed',
    },
    required this.analyzedAt,
  });
}

/// Explicit error states as defined in Screen 13.
enum FoodSafetyErrorType {
  blurryImage,
  noIngredientsDetected,
  unsupportedLabel,
  ocrFailure,
  networkFailure,
  regulatoryDataUnavailable,
  partialScan,
  multipleProductsDetected;

  String get title {
    switch (this) {
      case FoodSafetyErrorType.blurryImage:
        return 'Image is too blurry to read';
      case FoodSafetyErrorType.noIngredientsDetected:
        return 'Ingredients panel not detected';
      case FoodSafetyErrorType.unsupportedLabel:
        return 'Unsupported label';
      case FoodSafetyErrorType.ocrFailure:
        return "We couldn't read the label";
      case FoodSafetyErrorType.networkFailure:
        return "Couldn't complete regulatory verification";
      case FoodSafetyErrorType.regulatoryDataUnavailable:
        return 'Regulatory data is temporarily unavailable';
      case FoodSafetyErrorType.partialScan:
        return 'Some information could not be verified';
      case FoodSafetyErrorType.multipleProductsDetected:
        return 'Multiple products detected';
    }
  }

  String get description {
    switch (this) {
      case FoodSafetyErrorType.blurryImage:
        return 'Please ensure the food label is well lit, in focus, and flat before retaking the photo.';
      case FoodSafetyErrorType.noIngredientsDetected:
        return 'Scan the ingredients panel to continue. Front product branding alone does not contain required regulatory information.';
      case FoodSafetyErrorType.unsupportedLabel:
        return 'This does not appear to be a food label. Food Safety Check is designed specifically for packaged food and beverage products.';
      case FoodSafetyErrorType.ocrFailure:
        return 'Text recognition could not extract readable information. Check lighting and avoid reflections.';
      case FoodSafetyErrorType.networkFailure:
        return 'A network error prevented verification against current gazette regulations. You can retry the check.';
      case FoodSafetyErrorType.regulatoryDataUnavailable:
        return 'FSSAI regulatory index sync is temporarily offline. On-device basic checks are still available.';
      case FoodSafetyErrorType.partialScan:
        return 'Some mandatory sections like net weight, batch or ingredients were cut off or illegible.';
      case FoodSafetyErrorType.multipleProductsDetected:
        return 'Only one product should be visible in the camera frame for accurate regulatory screening.';
    }
  }

  bool get allowUploadAnother {
    return true;
  }
}
