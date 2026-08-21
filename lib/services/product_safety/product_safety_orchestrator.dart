import '../../models/product_safety_model.dart';
import 'barcode_gs1_service.dart';
import 'expiry_extractor_service.dart';
import 'fssai_validator_service.dart';
import 'nutritional_audit_service.dart';

/// Master orchestrator for the Product & Food Safety verification engine.
class ProductSafetyOrchestrator {
  final BarcodeGs1Service _barcodeService = BarcodeGs1Service();
  final ExpiryExtractorService _expiryService = ExpiryExtractorService();
  final FssaiValidatorService _fssaiService = FssaiValidatorService();
  final NutritionalAuditService _nutritionalService = NutritionalAuditService();

  /// Runs full deterministic analysis on OCR text and optional barcode.
  Future<ProductSafetyReport> analyze(
    String rawText, {
    String? rawBarcode,
    String? imagePath,
    DateTime? referenceDate,
  }) async {
    // 1. Barcode analysis
    BarcodeProductInfo? barcodeInfo;
    final barcodeToUse = rawBarcode ?? _barcodeService.extractBarcodeFromText(rawText);
    if (barcodeToUse != null) {
      barcodeInfo = _barcodeService.parseBarcode(barcodeToUse);
    }

    // 2. FSSAI verification
    final fssaiVerification = _fssaiService.validateFromText(rawText);

    // 3. Expiry and shelf life extraction
    final expiryAnalysis = _expiryService.extract(rawText, referenceDate: referenceDate);

    // 4. Nutritional HFSS evaluation
    final nutritionalAnalysis = _nutritionalService.auditNutrition(rawText);

    // 5. Food standards, additives & allergens
    final ingredientAnalysis = _nutritionalService.auditIngredients(rawText);

    // 6. Generate granular findings
    final findings = <ProductSafetyFinding>[];

    // FSSAI Findings
    if (fssaiVerification != null) {
      if (fssaiVerification.isValid) {
        findings.add(ProductSafetyFinding(
          id: 'fssai_valid',
          title: 'FSSAI License Verified',
          explanation: fssaiVerification.statusMessage,
          category: 'FSSAI',
          severity: ProductSafetyVerdict.safe,
          statutoryReference: 'Food Safety and Standards Act, 2006 (Sec 31)',
        ));
      } else {
        findings.add(ProductSafetyFinding(
          id: 'fssai_invalid',
          title: 'Suspicious / Invalid FSSAI License Number',
          explanation: fssaiVerification.statusMessage,
          recommendation: 'Check FSSAI FoSCoS portal (https://foscos.fssai.gov.in) before consuming.',
          category: 'FSSAI',
          severity: ProductSafetyVerdict.unsafe,
          statutoryReference: 'FSS (Licensing and Registration) Regs 2011',
        ));
      }
    } else {
      findings.add(const ProductSafetyFinding(
        id: 'fssai_missing',
        title: 'FSSAI License Not Detected',
        explanation: 'No 14-digit FSSAI number found on packaging text. Under Indian law, all pre-packaged foods must display an active FSSAI logo and license number.',
        recommendation: 'Verify if the FSSAI logo is on another face of the packaging.',
        category: 'FSSAI',
        severity: ProductSafetyVerdict.caution,
        statutoryReference: 'FSS (Packaging and Labelling) Regulations, 2020',
      ));
    }

    // Expiry Findings
    if (expiryAnalysis.status == ExpiryStatus.expired) {
      findings.add(ProductSafetyFinding(
        id: 'expiry_expired',
        title: 'Product Is Past Expiry Date',
        explanation: 'The product expired ${expiryAnalysis.daysRemaining?.abs() ?? 0} days ago (${expiryAnalysis.rawTextExcerpt}). Selling or consuming expired food violates the Consumer Protection Act.',
        recommendation: 'Do not consume. Request a refund or replacement from the merchant under CPA 2019.',
        category: 'EXPIRY',
        severity: ProductSafetyVerdict.unsafe,
        statutoryReference: 'Consumer Protection Act, 2019 & FSS Act 2006',
      ));
    } else if (expiryAnalysis.status == ExpiryStatus.expiringSoon) {
      findings.add(ProductSafetyFinding(
        id: 'expiry_soon',
        title: 'Product Expiring Soon (${expiryAnalysis.daysRemaining} Days Left)',
        explanation: 'Product is near the end of its shelf life (${expiryAnalysis.rawTextExcerpt}).',
        recommendation: 'Consume before expiry and store according to manufacturer instructions.',
        category: 'EXPIRY',
        severity: ProductSafetyVerdict.caution,
      ));
    } else if (expiryAnalysis.status == ExpiryStatus.fresh) {
      findings.add(ProductSafetyFinding(
        id: 'expiry_fresh',
        title: 'Fresh / Valid Shelf Life (${expiryAnalysis.daysRemaining} Days Remaining)',
        explanation: expiryAnalysis.rawTextExcerpt,
        category: 'EXPIRY',
        severity: ProductSafetyVerdict.safe,
      ));
    }

    // Nutritional HFSS Findings
    if (nutritionalAnalysis.isHighSugar) {
      findings.add(ProductSafetyFinding(
        id: 'hfss_sugar',
        title: 'High Sugar Content Alert',
        explanation: 'Total/Added sugars exceed recommended daily intake limits (>10g/100g).',
        recommendation: 'Moderate consumption, especially for children and diabetic individuals.',
        category: 'NUTRITION',
        severity: ProductSafetyVerdict.caution,
        statutoryReference: 'FSSAI Dietary Guidelines & ICMR Nutrition Limits',
      ));
    }
    if (nutritionalAnalysis.isHighSodium) {
      findings.add(ProductSafetyFinding(
        id: 'hfss_sodium',
        title: 'High Sodium / Salt Alert',
        explanation: 'Sodium content exceeds 400mg per 100g, contributing to high daily salt intake.',
        recommendation: 'Limit portion sizes to maintain healthy blood pressure levels.',
        category: 'NUTRITION',
        severity: ProductSafetyVerdict.caution,
      ));
    }
    if (nutritionalAnalysis.hasExcessTransFat) {
      findings.add(const ProductSafetyFinding(
        id: 'trans_fat_alert',
        title: 'Excess Industrial Trans Fat Detected',
        explanation: 'Trans fat content is higher than 0.2g per serve, exceeding FSSAI national reduction targets.',
        recommendation: 'Avoid regular consumption to protect cardiovascular health.',
        category: 'NUTRITION',
        severity: ProductSafetyVerdict.unsafe,
        statutoryReference: 'FSS (Food Products Standards and Food Additives) Tenth Amendment 2020',
      ));
    }

    // Additive Findings
    for (int i = 0; i < ingredientAnalysis.detectedAdditives.length; i++) {
      final additive = ingredientAnalysis.detectedAdditives[i];
      findings.add(ProductSafetyFinding(
        id: 'additive_$i',
        title: 'Food Additive / Preservative Detected',
        explanation: additive,
        category: 'ADDITIVE',
        severity: ProductSafetyVerdict.caution,
      ));
    }

    // Allergen Findings
    if (ingredientAnalysis.detectedAllergens.isNotEmpty) {
      findings.add(ProductSafetyFinding(
        id: 'allergens_alert',
        title: 'Declared Allergens Present',
        explanation: 'Contains: ${ingredientAnalysis.detectedAllergens.join(", ")}.',
        recommendation: 'Check if any family members have food allergies to these ingredients.',
        category: 'ALLERGEN',
        severity: ProductSafetyVerdict.caution,
        statutoryReference: 'FSSAI Mandatory Allergen Labelling Rules',
      ));
    }

    // Country of Origin / Made in India
    if (barcodeInfo != null && barcodeInfo.isMadeInIndia) {
      findings.add(ProductSafetyFinding(
        id: 'origin_india',
        title: 'Made in India (GS1 Prefix 890)',
        explanation: 'Barcode indicates manufacturing registered in India by ${barcodeInfo.brandName ?? "Indian Manufacturer"}.',
        category: 'METROLOGY',
        severity: ProductSafetyVerdict.safe,
        statutoryReference: 'Legal Metrology (Packaged Commodities) Rules, 2011',
      ));
    }

    // 7. Calculate Overall Verdict and Score
    final hasUnsafe = findings.any((f) => f.severity == ProductSafetyVerdict.unsafe);
    final hasCaution = findings.any((f) => f.severity == ProductSafetyVerdict.caution);

    ProductSafetyVerdict overallVerdict = ProductSafetyVerdict.safe;
    double safetyScore = 100.0;

    if (hasUnsafe) {
      overallVerdict = ProductSafetyVerdict.unsafe;
      safetyScore = 40.0;
    } else if (hasCaution) {
      overallVerdict = ProductSafetyVerdict.caution;
      safetyScore = 75.0;
    }

    if (expiryAnalysis.status == ExpiryStatus.expired) {
      safetyScore = 20.0;
      overallVerdict = ProductSafetyVerdict.unsafe;
    }

    return ProductSafetyReport(
      rawOcrText: rawText,
      imagePath: imagePath,
      barcodeInfo: barcodeInfo,
      fssaiVerification: fssaiVerification,
      expiryAnalysis: expiryAnalysis,
      nutritionalAnalysis: nutritionalAnalysis,
      ingredientAnalysis: ingredientAnalysis,
      findings: findings,
      overallVerdict: overallVerdict,
      safetyScore: safetyScore,
      analyzedAt: DateTime.now(),
      aiSummary: 'Product audited under FSS Act 2006, Legal Metrology Rules, and ICMR nutritional benchmarks.',
    );
  }
}
