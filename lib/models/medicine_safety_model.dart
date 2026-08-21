import 'package:flutter/material.dart';

/// Drug Schedule under Drugs and Cosmetics Rules, 1945.
enum DrugSchedule {
  scheduleH1, // Red border box: 3rd/4th gen antibiotics, anti-TB, psychotropics
  scheduleH,  // Rx: Prescription drugs
  scheduleX,  // NRx: Habit-forming, psychotropic, narcotic
  scheduleG,  // Medical supervision caution (e.g. Metformin, Insulin, Antihistamines)
  otc,        // Over-the-counter (general sales)
  unknown;

  String get displayName {
    switch (this) {
      case DrugSchedule.scheduleH1:
        return 'Schedule H1 (High-Alert Prescription)';
      case DrugSchedule.scheduleH:
        return 'Schedule H (Prescription Drug)';
      case DrugSchedule.scheduleX:
        return 'Schedule X (Narcotic / Psychotropic)';
      case DrugSchedule.scheduleG:
        return 'Schedule G (Medical Supervision Required)';
      case DrugSchedule.otc:
        return 'Over-the-Counter (OTC General Sale)';
      case DrugSchedule.unknown:
        return 'General / Unclassified Medicine';
    }
  }

  String get badgeSymbol {
    switch (this) {
      case DrugSchedule.scheduleH1:
        return 'Rx (Sched H1)';
      case DrugSchedule.scheduleH:
        return 'Rx';
      case DrugSchedule.scheduleX:
        return 'NRx';
      case DrugSchedule.scheduleG:
        return 'Caution (G)';
      case DrugSchedule.otc:
        return 'OTC';
      case DrugSchedule.unknown:
        return 'Med';
    }
  }

  Color get color {
    switch (this) {
      case DrugSchedule.scheduleH1:
        return const Color(0xFFDC2626); // Red
      case DrugSchedule.scheduleX:
        return const Color(0xFF991B1B); // Dark Crimson
      case DrugSchedule.scheduleH:
        return const Color(0xFFD97706); // Amber
      case DrugSchedule.scheduleG:
        return const Color(0xFF2563EB); // Blue
      case DrugSchedule.otc:
        return const Color(0xFF16A34A); // Green
      case DrugSchedule.unknown:
        return const Color(0xFF4B5563);
    }
  }
}

/// Overall safety status for medicine.
enum MedicineSafetyVerdict {
  safe,
  caution,
  highRisk,
  bannedFdc;

  String get displayName {
    switch (this) {
      case MedicineSafetyVerdict.safe:
        return 'Genuine & Safe';
      case MedicineSafetyVerdict.caution:
        return 'Prescription Required / Precautions';
      case MedicineSafetyVerdict.highRisk:
        return 'High Risk / Expired / Unsafe';
      case MedicineSafetyVerdict.bannedFdc:
        return 'Banned Drug / Prohibited FDC';
    }
  }

  String get emoji {
    switch (this) {
      case MedicineSafetyVerdict.safe:
        return '✅';
      case MedicineSafetyVerdict.caution:
        return '⚠️';
      case MedicineSafetyVerdict.highRisk:
        return '🚨';
      case MedicineSafetyVerdict.bannedFdc:
        return '⛔';
    }
  }

  Color get color {
    switch (this) {
      case MedicineSafetyVerdict.safe:
        return const Color(0xFF16A34A);
      case MedicineSafetyVerdict.caution:
        return const Color(0xFFD97706);
      case MedicineSafetyVerdict.highRisk:
      case MedicineSafetyVerdict.bannedFdc:
        return const Color(0xFFDC2626);
    }
  }
}

/// Individual medicine safety audit finding.
class MedicineFinding {
  final String id;
  final String title;
  final String explanation;
  final String? recommendation;
  final String category; // 'LICENSE', 'SCHEDULE', 'GENERIC', 'EXPIRY', 'BANNED', 'STORAGE'
  final MedicineSafetyVerdict severity;
  final String? statutoryReference;

  const MedicineFinding({
    required this.id,
    required this.title,
    required this.explanation,
    this.recommendation,
    required this.category,
    required this.severity,
    this.statutoryReference,
  });
}

/// Verification of Drug Manufacturing License (Mfg Lic No / M.L. No.).
class DrugLicenseVerification {
  final String rawLicenseNumber;
  final bool isValid;
  final String? formType; // e.g. Form 25 (Non-biologicals), Form 28 (Biologicals)
  final String? stateCode;
  final String? stateAuthority; // e.g. "Food & Drugs Control Administration (FDCA), Gujarat"
  final String statusMessage;

  const DrugLicenseVerification({
    required this.rawLicenseNumber,
    required this.isValid,
    this.formType,
    this.stateCode,
    this.stateAuthority,
    required this.statusMessage,
  });
}

/// Jan Aushadhi (PMBJP) Generic Alternative & Price Savings Model.
class JanAushadhiGenericComparison {
  final String brandName;
  final String genericSalt;
  final String strength;
  final double estimatedBrandedMrp;
  final double janAushadhiPrice;
  final double savingsPercentage;
  final double amountSaved;
  final String pmbjpCode;

  const JanAushadhiGenericComparison({
    required this.brandName,
    required this.genericSalt,
    required this.strength,
    required this.estimatedBrandedMrp,
    required this.janAushadhiPrice,
    required this.savingsPercentage,
    required this.amountSaved,
    required this.pmbjpCode,
  });
}

/// Batch and Expiry Information for Medicine.
class MedicineBatchExpiry {
  final String? batchNumber;
  final DateTime? manufacturingDate;
  final DateTime? expiryDate;
  final int? daysRemaining;
  final bool isExpired;
  final bool isExpiringSoon; // within 60 days
  final String rawTextExcerpt;

  const MedicineBatchExpiry({
    this.batchNumber,
    this.manufacturingDate,
    this.expiryDate,
    this.daysRemaining,
    this.isExpired = false,
    this.isExpiringSoon = false,
    required this.rawTextExcerpt,
  });
}

/// Master Unified Medicine & Pharma Safety Report.
class MedicineSafetyReport {
  final String rawOcrText;
  final String? imagePath;
  final String? brandName;
  final List<String> activeIngredients;
  final DrugSchedule schedule;
  final String scheduleWarningText;
  final DrugLicenseVerification? licenseVerification;
  final MedicineBatchExpiry batchExpiry;
  final JanAushadhiGenericComparison? genericComparison;
  final bool isBannedFdc;
  final String? bannedFdcDetails;
  final List<MedicineFinding> findings;
  final MedicineSafetyVerdict overallVerdict;
  final double safetyScore; // 0 to 100
  final DateTime analyzedAt;
  final String? storageInstructions;

  const MedicineSafetyReport({
    required this.rawOcrText,
    this.imagePath,
    this.brandName,
    this.activeIngredients = const [],
    required this.schedule,
    required this.scheduleWarningText,
    this.licenseVerification,
    required this.batchExpiry,
    this.genericComparison,
    this.isBannedFdc = false,
    this.bannedFdcDetails,
    required this.findings,
    required this.overallVerdict,
    required this.safetyScore,
    required this.analyzedAt,
    this.storageInstructions,
  });
}
