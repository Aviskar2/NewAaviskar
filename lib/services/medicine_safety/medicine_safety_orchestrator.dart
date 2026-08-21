import '../../models/medicine_safety_model.dart';
import '../product_safety/expiry_extractor_service.dart';
import 'drug_license_service.dart';
import 'drug_schedule_service.dart';
import 'jan_aushadhi_service.dart';

/// Master orchestrator for the Indian Medicine & Pharma Safety verification engine.
class MedicineSafetyOrchestrator {
  final DrugLicenseService _licenseService = DrugLicenseService();
  final DrugScheduleService _scheduleService = DrugScheduleService();
  final JanAushadhiService _janAushadhiService = JanAushadhiService();
  final ExpiryExtractorService _expiryService = ExpiryExtractorService();

  /// Runs full deterministic safety verification on scanned medicine packaging.
  Future<MedicineSafetyReport> analyze(
    String rawText, {
    String? imagePath,
    DateTime? referenceDate,
  }) async {
    final now = referenceDate ?? DateTime.now();

    // 1. Extract active generic ingredients
    final activeIngredients = _janAushadhiService.extractActiveIngredients(rawText);

    // 2. Classify Drug Schedule & Statutory Warning
    final scheduleResult = _scheduleService.classify(rawText, activeIngredients);
    final DrugSchedule schedule = scheduleResult['schedule'] as DrugSchedule;
    final String scheduleWarning = scheduleResult['warning'] as String;
    final bool isBannedFdc = scheduleResult['isBanned'] as bool;
    final String? bannedDetails = scheduleResult['bannedDetails'] as String?;

    // 3. Verify Drug Manufacturing License (Mfg Lic No)
    final licenseVerification = _licenseService.extractAndVerify(rawText);

    // 4. Batch & Expiry Analysis
    final batchNumber = _extractBatchNumber(rawText);
    final expiryData = _expiryService.extract(rawText, referenceDate: now);

    final bool isExpired = expiryData.expiryDate != null && expiryData.expiryDate!.isBefore(now);
    final bool isExpiringSoon = expiryData.daysRemaining != null &&
        expiryData.daysRemaining! >= 0 &&
        expiryData.daysRemaining! <= 60;

    final batchExpiry = MedicineBatchExpiry(
      batchNumber: batchNumber,
      manufacturingDate: expiryData.manufacturingDate,
      expiryDate: expiryData.expiryDate,
      daysRemaining: expiryData.daysRemaining,
      isExpired: isExpired,
      isExpiringSoon: isExpiringSoon,
      rawTextExcerpt: expiryData.rawTextExcerpt,
    );

    // 5. Jan Aushadhi Generic Comparison & Price Savings
    final genericComparison = _janAushadhiService.findGenericAlternative(rawText, activeIngredients);

    // 6. Extract Storage Instructions
    final storage = _extractStorageInstructions(rawText);

    // 7. Compile Granular Findings
    final findings = <MedicineFinding>[];

    // Banned Drug Alert
    if (isBannedFdc) {
      findings.add(MedicineFinding(
        id: 'banned_fdc',
        title: 'BANNED DRUG COMBINATION (CDSCO)',
        explanation: bannedDetails ?? 'This Fixed Dose Combination has been banned by the Ministry of Health under Section 26A of the Drugs and Cosmetics Act due to safety risks.',
        recommendation: 'DO NOT CONSUME. Return to pharmacy and consult a doctor for an approved single-molecule alternative.',
        category: 'BANNED',
        severity: MedicineSafetyVerdict.bannedFdc,
        statutoryReference: 'Drugs and Cosmetics Act, 1940 (Sec 26A)',
      ));
    }

    // Expiry Warnings
    if (isExpired) {
      findings.add(MedicineFinding(
        id: 'med_expired',
        title: 'MEDICINE IS EXPIRED — HIGH RISK',
        explanation: 'This medicine expired ${expiryData.daysRemaining?.abs() ?? 0} days ago (${expiryData.rawTextExcerpt}). Expired drugs lose chemical potency and may form toxic degradation products.',
        recommendation: 'Do not consume. Discard safely according to biomedical disposal guidelines.',
        category: 'EXPIRY',
        severity: MedicineSafetyVerdict.highRisk,
        statutoryReference: 'Drugs and Cosmetics Rules, 1945 (Rule 65)',
      ));
    } else if (isExpiringSoon) {
      findings.add(MedicineFinding(
        id: 'med_expiring_soon',
        title: 'Expiring Soon (${expiryData.daysRemaining} Days Left)',
        explanation: 'Medicine is near the end of its therapeutic shelf-life (${expiryData.rawTextExcerpt}).',
        recommendation: 'Ensure you finish the prescribed course before the expiry date.',
        category: 'EXPIRY',
        severity: MedicineSafetyVerdict.caution,
      ));
    }

    // Schedule Warning
    if (schedule == DrugSchedule.scheduleH1) {
      findings.add(MedicineFinding(
        id: 'sched_h1',
        title: 'Schedule H1 Warning (Red Border Box)',
        explanation: scheduleWarning,
        recommendation: 'Only take under registered medical prescription. Complete the full antibiotic/prescribed course.',
        category: 'SCHEDULE',
        severity: MedicineSafetyVerdict.caution,
        statutoryReference: 'Drugs & Cosmetics Rules 1945 (Notification GSR 588(E))',
      ));
    } else if (schedule == DrugSchedule.scheduleX) {
      findings.add(MedicineFinding(
        id: 'sched_x',
        title: 'Schedule X (NRx Narcotic / Psychotropic)',
        explanation: scheduleWarning,
        recommendation: 'Strict medical control required. Store in secure locked location.',
        category: 'SCHEDULE',
        severity: MedicineSafetyVerdict.caution,
        statutoryReference: 'NDPS Act, 1985 & Drugs and Cosmetics Rules',
      ));
    } else if (schedule == DrugSchedule.scheduleH) {
      findings.add(MedicineFinding(
        id: 'sched_h',
        title: 'Schedule H (Prescription Drug)',
        explanation: scheduleWarning,
        recommendation: 'To be dispensed only with a valid doctor\'s prescription.',
        category: 'SCHEDULE',
        severity: MedicineSafetyVerdict.safe,
        statutoryReference: 'Drugs and Cosmetics Rules, 1945 (Schedule H)',
      ));
    }

    // Manufacturing License Finding
    if (licenseVerification != null) {
      findings.add(MedicineFinding(
        id: 'mfg_lic',
        title: 'Drug Manufacturing License Verified',
        explanation: licenseVerification.statusMessage,
        category: 'LICENSE',
        severity: MedicineSafetyVerdict.safe,
        statutoryReference: 'Drugs and Cosmetics Rules, 1945 (${licenseVerification.formType})',
      ));
    } else {
      findings.add(const MedicineFinding(
        id: 'mfg_lic_missing',
        title: 'Mfg License Number Not Detected',
        explanation: 'No explicit Mfg. Lic. No. found on the visible packaging text. Indian law mandates all manufactured medicines display a valid state license.',
        recommendation: 'Check the side or end flap of the medicine carton or foil strip.',
        category: 'LICENSE',
        severity: MedicineSafetyVerdict.caution,
      ));
    }

    // Jan Aushadhi Generic Savings Finding
    if (genericComparison != null) {
      findings.add(MedicineFinding(
        id: 'jan_aushadhi_savings',
        title: 'PMBJP Generic Alternative Available (${genericComparison.savingsPercentage.toInt()}% Cheaper)',
        explanation: 'Branded MRP: ₹${genericComparison.estimatedBrandedMrp.toStringAsFixed(0)} vs Pradhan Mantri Jan Aushadhi (PMBJP): ₹${genericComparison.janAushadhiPrice.toStringAsFixed(0)}. Save ₹${genericComparison.amountSaved.toStringAsFixed(0)} per pack with the exact same active salt: ${genericComparison.genericSalt}.',
        recommendation: 'Ask your doctor or chemist for the Jan Aushadhi generic equivalent (${genericComparison.pmbjpCode}).',
        category: 'GENERIC',
        severity: MedicineSafetyVerdict.safe,
        statutoryReference: 'Pradhan Mantri Bhartiya Janaushadhi Pariyojana (PMBJP)',
      ));
    }

    // 8. Overall Safety Verdict & Score Calculation
    MedicineSafetyVerdict overallVerdict = MedicineSafetyVerdict.safe;
    double score = 100.0;

    if (isBannedFdc) {
      overallVerdict = MedicineSafetyVerdict.bannedFdc;
      score = 0.0;
    } else if (isExpired) {
      overallVerdict = MedicineSafetyVerdict.highRisk;
      score = 25.0;
    } else if (schedule == DrugSchedule.scheduleH1 || schedule == DrugSchedule.scheduleX) {
      overallVerdict = MedicineSafetyVerdict.caution;
      score = 80.0;
    } else if (schedule == DrugSchedule.scheduleH) {
      overallVerdict = MedicineSafetyVerdict.safe;
      score = 95.0;
    }

    return MedicineSafetyReport(
      rawOcrText: rawText,
      imagePath: imagePath,
      brandName: genericComparison?.brandName,
      activeIngredients: activeIngredients,
      schedule: schedule,
      scheduleWarningText: scheduleWarning,
      licenseVerification: licenseVerification,
      batchExpiry: batchExpiry,
      genericComparison: genericComparison,
      isBannedFdc: isBannedFdc,
      bannedFdcDetails: bannedDetails,
      findings: findings,
      overallVerdict: overallVerdict,
      safetyScore: score,
      analyzedAt: DateTime.now(),
      storageInstructions: storage,
    );
  }

  String? _extractBatchNumber(String text) {
    final clean = text.toUpperCase();
    final batchPatterns = [
      RegExp(r'(?:B\.?\s*NO\.?|BATCH\s*NO\.?|BATCH\s*NUMBER|LOT\s*NO\.?)[:\s\-]+([A-Z0-9\-]{3,15})'),
      RegExp(r'\bB\.NO\.[:\s]*([A-Z0-9\-]+)\b'),
    ];

    for (final pattern in batchPatterns) {
      final match = pattern.firstMatch(clean);
      if (match != null) {
        return match.group(1)?.trim();
      }
    }
    return null;
  }

  String? _extractStorageInstructions(String text) {
    final clean = text.toUpperCase();
    if (clean.contains('STORE BELOW 25') || clean.contains('STORE BELOW 30')) {
      return 'Store in a dry place below 30°C. Protect from direct sunlight & moisture.';
    }
    if (clean.contains('REFRIGERAT') || clean.contains('2°C TO 8°C') || clean.contains('2-8°C')) {
      return 'Store in a refrigerator (2°C to 8°C). Do not freeze.';
    }
    if (clean.contains('PROTECT FROM LIGHT')) {
      return 'Store in the original container to protect from light & moisture.';
    }
    return 'Store in a cool, dry place away from children.';
  }
}
