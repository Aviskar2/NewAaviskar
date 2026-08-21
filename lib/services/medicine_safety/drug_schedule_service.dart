import '../../models/medicine_safety_model.dart';

/// Classifies Drug Schedules and identifies statutory warning banners
/// under the Drugs and Cosmetics Rules, 1945 & CDSCO notifications.
class DrugScheduleService {
  /// Known Schedule H1 active molecules (Notification GSR 588(E) - August 30, 2013)
  static const List<String> _scheduleH1Drugs = [
    'ALPRAZOLAM', 'BALOFLOXACIN', 'BUPRENORPHINE', 'CAPREOMYCIN',
    'CEFDITOREN', 'CEFEPIME', 'CEFOPERAZONE', 'CEFOTAXIME', 'CEFPIROME',
    'CEFPODOXIME', 'CEFTAZIDIME', 'CEFTRIAXONE', 'CHLORDIAZEPOXIDE',
    'CLOBAZAM', 'CLONAZEPAM', 'CLORAZEPATE', 'CYCLOSERINE', 'DIAZEPAM',
    'DORIPENEM', 'ERTAPENEM', 'ETHIONAMIDE', 'FAROPENEM', 'FLURAZEPAM',
    'GATIFLOXACIN', 'GEMIFLOXACIN', 'IMIPENEM', 'ISONIAZID', 'LEVOFLOXACIN',
    'MEROPENEM', 'MIDAZOLAM', 'MOXIFLOXACIN', 'NITRAZEPAM', 'PAROMOMYCIN',
    'PRAZEPAM', 'RIFABUTIN', 'RIFAMPICIN', 'RIFAPENTINE', 'SPARFLOXACIN',
    'TRAMADOL', 'ZOLPIDEM', 'AZITHROMYCIN',
  ];

  /// Known Schedule X Drugs (Narcotic and Psychotropic substances)
  static const List<String> _scheduleXDrugs = [
    'AMOBARBITAL', 'AMPHETAMINE', 'BARBITAL', 'CYCLOBARBITAL',
    'DEXAMPHETAMINE', 'GLUTETHIMIDE', 'MEPROBAMATE', 'METHYLPHENIDATE',
    'PENTOBARBITAL', 'PHENMETRAZINE', 'SECOBARBITAL', 'KETAMINE',
  ];

  /// Known Schedule G Drugs (Medical supervision caution)
  static const List<String> _scheduleGDrugs = [
    'METFORMIN', 'GLIBENCLAMIDE', 'GLIMEPIRIDE', 'GLIPIZIDE', 'INSULIN',
    'ANTIHISTAMINIC', 'CARBUTAMIDE', 'CHLORPROPAMIDE', 'DIMETHINDENE',
    'PHENFORMIN', 'TOLBUTAMIDE',
  ];

  /// Known Banned Fixed Dose Combinations (FDCs) by CDSCO / Ministry of Health
  static const List<Map<String, dynamic>> _bannedFdcList = [
    {
      'name': 'Nimesulide + Paracetamol dispersible tablet',
      'keywords': ['NIMESULIDE', 'PARACETAMOL'],
      'reason': 'Banned for children below 12 years due to hepatotoxicity risk (Notification S.O. 560(E)).',
    },
    {
      'name': 'Aceclofenac + Paracetamol + Rabeprazole',
      'keywords': ['ACECLOFENAC', 'RABEPRAZOLE'],
      'reason': 'Prohibited FDC: Lacks therapeutic justification under Drugs & Cosmetics Act (Sec 26A).',
    },
    {
      'name': 'Amoxicillin + Bromhexine',
      'keywords': ['AMOXICILLIN', 'BROMHEXINE'],
      'reason': 'Banned FDC: Incompatible therapeutic rationalization.',
    },
    {
      'name': 'Ofloxacin + Ornidazole suspension for pediatric use',
      'keywords': ['OFLOXACIN', 'ORNIDAZOLE'],
      'reason': 'Banned for pediatric diarrhea due to antimicrobial resistance risk.',
    },
  ];

  /// Classifies medicine schedule and statutory warnings from text.
  Map<String, dynamic> classify(String rawText, List<String> activeIngredients) {
    final clean = rawText.toUpperCase();
    final combined = '$clean ${activeIngredients.join(" ").toUpperCase()}';

    // 1. Check for CDSCO Banned FDCs
    for (final fdc in _bannedFdcList) {
      final keywords = fdc['keywords'] as List<String>;
      final allMatched = keywords.every((kw) => combined.contains(kw));
      if (allMatched && (combined.contains('COMBINATION') || combined.contains('+') || activeIngredients.length >= 2)) {
        return {
          'schedule': DrugSchedule.scheduleH,
          'isBanned': true,
          'bannedDetails': '${fdc['name']}: ${fdc['reason']}',
          'warning': '⛔ BANNED DRUG / PROHIBITED FDC: This combination has been prohibited for manufacture and sale under Section 26A of the Drugs and Cosmetics Act.',
        };
      }
    }

    // 2. Schedule H1 Check (Explicit text or active molecule)
    final hasH1Text = clean.contains('SCHEDULE H1') || clean.contains('SCH. H1') || clean.contains('SCHEDULE-H1');
    final hasH1Molecule = _scheduleH1Drugs.any((drug) => combined.contains(drug));

    if (hasH1Text || hasH1Molecule) {
      return {
        'schedule': DrugSchedule.scheduleH1,
        'isBanned': false,
        'warning': '🚨 SCHEDULE H1 PRESCRIPTION DRUG: Warning — Dangerous to take without medical advice. '
            'Not to be sold by retail without the prescription of a Registered Medical Practitioner. '
            'Pharmacy must maintain separate dispensing register.',
      };
    }

    // 3. Schedule X Check
    final hasXText = clean.contains('SCHEDULE X') || clean.contains('NRX');
    final hasXMolecule = _scheduleXDrugs.any((drug) => combined.contains(drug));

    if (hasXText || hasXMolecule) {
      return {
        'schedule': DrugSchedule.scheduleX,
        'isBanned': false,
        'warning': '🔴 SCHEDULE X (NRx): Habit-forming psychotropic / narcotic preparation. '
            'Requires duplicate medical prescription and strict controlled dispensing.',
      };
    }

    // 4. Schedule G Check
    final hasGText = clean.contains('SCHEDULE G');
    final hasGMolecule = _scheduleGDrugs.any((drug) => combined.contains(drug));

    if (hasGText || hasGMolecule) {
      return {
        'schedule': DrugSchedule.scheduleG,
        'isBanned': false,
        'warning': '⚠️ SCHEDULE G: Caution — It is dangerous to take this preparation except under medical supervision.',
      };
    }

    // 5. Schedule H Check
    final hasHText = clean.contains('SCHEDULE H') || clean.contains('RX ONLY') || clean.contains('PRESCRIPTION ONLY') || clean.startsWith('RX');
    if (hasHText) {
      return {
        'schedule': DrugSchedule.scheduleH,
        'isBanned': false,
        'warning': '⚠️ SCHEDULE H PRESCRIPTION DRUG: Warning — To be sold by retail on the prescription of a Registered Medical Practitioner only.',
      };
    }

    // 6. Over-the-counter check (e.g. simple Paracetamol, Antacids, Throat lozenges)
    return {
      'schedule': DrugSchedule.otc,
      'isBanned': false,
      'warning': '✅ Over-The-Counter (OTC): Safe for general consumer purchase. Follow dosage on pack.',
    };
  }
}
