import 'package:flutter/material.dart';

/// Overall safety risk classification for a scanned product.
enum ProductSafetyVerdict {
  safe,
  caution,
  unsafe,
  unknown;

  String get displayName {
    switch (this) {
      case ProductSafetyVerdict.safe:
        return 'Safe & Compliant';
      case ProductSafetyVerdict.caution:
        return 'Caution / High Limits';
      case ProductSafetyVerdict.unsafe:
        return 'High Risk / Unsafe';
      case ProductSafetyVerdict.unknown:
        return 'Needs Verification';
    }
  }

  String get emoji {
    switch (this) {
      case ProductSafetyVerdict.safe:
        return '✅';
      case ProductSafetyVerdict.caution:
        return '⚠️';
      case ProductSafetyVerdict.unsafe:
        return '🚨';
      case ProductSafetyVerdict.unknown:
        return '🔍';
    }
  }

  Color get color {
    switch (this) {
      case ProductSafetyVerdict.safe:
        return const Color(0xFF16A34A);
      case ProductSafetyVerdict.caution:
        return const Color(0xFFD97706);
      case ProductSafetyVerdict.unsafe:
        return const Color(0xFFDC2626);
      case ProductSafetyVerdict.unknown:
        return const Color(0xFF2563EB);
    }
  }
}

/// Status of product expiry / shelf-life.
enum ExpiryStatus {
  fresh,
  expiringSoon,
  expired,
  unknown;

  String get displayName {
    switch (this) {
      case ExpiryStatus.fresh:
        return 'Fresh / Valid Shelf Life';
      case ExpiryStatus.expiringSoon:
        return 'Expiring Soon (Within 30 Days)';
      case ExpiryStatus.expired:
        return 'EXPIRED — Do Not Consume';
      case ExpiryStatus.unknown:
        return 'Expiry Date Unclear';
    }
  }

  String get emoji {
    switch (this) {
      case ExpiryStatus.fresh:
        return '🟢';
      case ExpiryStatus.expiringSoon:
        return '🟡';
      case ExpiryStatus.expired:
        return '🔴';
      case ExpiryStatus.unknown:
        return '⚪';
    }
  }
}

/// FSSAI License classification.
enum FssaiLicenseType {
  centralLicense,
  stateLicense,
  basicRegistration,
  invalid;

  String get displayName {
    switch (this) {
      case FssaiLicenseType.centralLicense:
        return 'Central FSSAI License (Large / Importer)';
      case FssaiLicenseType.stateLicense:
        return 'State FSSAI License (Medium Food Business)';
      case FssaiLicenseType.basicRegistration:
        return 'Basic FSSAI Registration (Petty Food Business)';
      case FssaiLicenseType.invalid:
        return 'Invalid FSSAI License';
    }
  }
}

/// Individual safety / statutory audit finding.
class ProductSafetyFinding {
  final String id;
  final String title;
  final String explanation;
  final String? recommendation;
  final String category; // 'FSSAI', 'EXPIRY', 'NUTRITION', 'ADDITIVE', 'ALLERGEN', 'METROLOGY'
  final ProductSafetyVerdict severity;
  final String? statutoryReference; // e.g. "FSS (Packaging & Labelling) Regs 2020"

  const ProductSafetyFinding({
    required this.id,
    required this.title,
    required this.explanation,
    this.recommendation,
    required this.category,
    required this.severity,
    this.statutoryReference,
  });
}

/// Structural verification of a 14-digit FSSAI number.
class FssaiVerification {
  final String rawLicenseNumber;
  final bool isValid;
  final FssaiLicenseType licenseType;
  final String? stateCode;
  final String? stateName;
  final String? registrationYear;
  final String? enrollingAuthority;
  final String? manufacturerSerialNumber;
  final String statusMessage;

  const FssaiVerification({
    required this.rawLicenseNumber,
    required this.isValid,
    required this.licenseType,
    this.stateCode,
    this.stateName,
    this.registrationYear,
    this.enrollingAuthority,
    this.manufacturerSerialNumber,
    required this.statusMessage,
  });
}

/// Automated Expiry and Shelf-Life Analysis.
class ExpiryAnalysis {
  final DateTime? manufacturingDate;
  final DateTime? expiryDate;
  final String? bestBeforePhrase;
  final int? daysRemaining;
  final ExpiryStatus status;
  final String rawTextExcerpt;
  final double shelfLifeConsumedPercentage;

  const ExpiryAnalysis({
    this.manufacturingDate,
    this.expiryDate,
    this.bestBeforePhrase,
    this.daysRemaining,
    required this.status,
    required this.rawTextExcerpt,
    this.shelfLifeConsumedPercentage = 0.0,
  });
}

/// Nutritional values and High Fat, Sugar, Salt (HFSS) warnings.
class NutritionalAnalysis {
  final double? energyKcal;
  final double? totalFatGrams;
  final double? saturatedFatGrams;
  final double? transFatGrams;
  final double? totalCarbsGrams;
  final double? totalSugarGrams;
  final double? addedSugarGrams;
  final double? sodiumMg;
  final double? proteinGrams;
  final double? servingSizeGrams;

  // HFSS Traffic Light Flags (FSSAI / ICMR guidelines per 100g)
  final bool isHighSugar;
  final bool isHighSodium;
  final bool isHighSaturatedFat;
  final bool hasExcessTransFat; // Trans fat > 0.2g / exceeds 2% cap

  final List<String> nutritionalWarnings;

  const NutritionalAnalysis({
    this.energyKcal,
    this.totalFatGrams,
    this.saturatedFatGrams,
    this.transFatGrams,
    this.totalCarbsGrams,
    this.totalSugarGrams,
    this.addedSugarGrams,
    this.sodiumMg,
    this.proteinGrams,
    this.servingSizeGrams,
    this.isHighSugar = false,
    this.isHighSodium = false,
    this.isHighSaturatedFat = false,
    this.hasExcessTransFat = false,
    this.nutritionalWarnings = const [],
  });
}

/// Food Standards, Additives, and Allergen Information.
class IngredientStandardsAnalysis {
  final bool isVegetarian;
  final bool isNonVegetarian;
  final bool isVegan;
  final List<String> detectedAdditives; // e.g. "INS 621 (MSG)", "INS 102 (Tartrazine)"
  final List<String> detectedAllergens; // e.g. "Gluten", "Peanuts", "Soy"
  final List<String> healthConcerns; // e.g. "Contains Palm Oil", "Artificial Sweetener"

  const IngredientStandardsAnalysis({
    this.isVegetarian = false,
    this.isNonVegetarian = false,
    this.isVegan = false,
    this.detectedAdditives = const [],
    this.detectedAllergens = const [],
    this.healthConcerns = const [],
  });
}

/// GS1 / Barcode Information.
class BarcodeProductInfo {
  final String barcode;
  final String format; // EAN-13, UPC-A, QR
  final bool isMadeInIndia; // Prefix 890
  final String countryOfOrigin;
  final String? brandName;
  final String? productName;
  final String? category;

  const BarcodeProductInfo({
    required this.barcode,
    required this.format,
    required this.isMadeInIndia,
    required this.countryOfOrigin,
    this.brandName,
    this.productName,
    this.category,
  });
}

/// Master unified Product & Food Safety Report.
class ProductSafetyReport {
  final String rawOcrText;
  final String? imagePath;
  final BarcodeProductInfo? barcodeInfo;
  final FssaiVerification? fssaiVerification;
  final ExpiryAnalysis expiryAnalysis;
  final NutritionalAnalysis nutritionalAnalysis;
  final IngredientStandardsAnalysis ingredientAnalysis;
  final List<ProductSafetyFinding> findings;
  final ProductSafetyVerdict overallVerdict;
  final double safetyScore; // 0 to 100
  final DateTime analyzedAt;
  final String? aiSummary;
  final bool isAiEnhanced;

  const ProductSafetyReport({
    required this.rawOcrText,
    this.imagePath,
    this.barcodeInfo,
    this.fssaiVerification,
    required this.expiryAnalysis,
    required this.nutritionalAnalysis,
    required this.ingredientAnalysis,
    required this.findings,
    required this.overallVerdict,
    required this.safetyScore,
    required this.analyzedAt,
    this.aiSummary,
    this.isAiEnhanced = false,
  });
}
