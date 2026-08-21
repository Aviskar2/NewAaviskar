import 'package:flutter_test/flutter_test.dart';
import 'package:aura_ai/models/medicine_safety_model.dart';
import 'package:aura_ai/services/medicine_safety/drug_license_service.dart';
import 'package:aura_ai/services/medicine_safety/drug_schedule_service.dart';
import 'package:aura_ai/services/medicine_safety/jan_aushadhi_service.dart';
import 'package:aura_ai/services/medicine_safety/medicine_safety_orchestrator.dart';

void main() {
  group('Drug Manufacturing License Service', () {
    final service = DrugLicenseService();

    test('Validates Gujarat Form 25 Drug License (G/25/...)', () {
      final res = service.extractAndVerify('Mfg. Lic. No.: G/25/1458. Marketed by Micro Labs.');
      expect(res, isNotNull);
      expect(res!.isValid, isTrue);
      expect(res.rawLicenseNumber, equals('G/25/1458'));
      expect(res.stateAuthority, contains('Gujarat'));
    });

    test('Validates Himachal Pradesh Baddi/Solan Drug License (MNB/...)', () {
      final res = service.extractAndVerify('M.L. No. MNB/05/189. Baddi, Solan, H.P.');
      expect(res, isNotNull);
      expect(res!.isValid, isTrue);
      expect(res.rawLicenseNumber, equals('MNB/05/189'));
      expect(res.stateAuthority, contains('Himachal Pradesh'));
    });

    test('Validates Maharashtra Drug License (MH/...)', () {
      final res = service.extractAndVerify('Mfg Lic No: MH/102/2019');
      expect(res, isNotNull);
      expect(res!.isValid, isTrue);
      expect(res.stateAuthority, contains('Maharashtra'));
    });
  });

  group('Drug Schedule & Warning Classification Service', () {
    final service = DrugScheduleService();

    test('Classifies Schedule H1 Antibiotic (Augmentin / Azithromycin / Cefpodoxime)', () {
      final res = service.classify(
        'SCHEDULE H1 PRESCRIPTION DRUG - CAUTION. Warning: Dangerous to take without medical advice.',
        ['Amoxicillin 500 mg', 'Potassium Clavulanate 125 mg'],
      );
      expect(res['schedule'], equals(DrugSchedule.scheduleH1));
      expect(res['isBanned'], isFalse);
      expect(res['warning'], contains('SCHEDULE H1'));
    });

    test('Classifies Schedule X Narcotic / Psychotropic preparation', () {
      final res = service.classify(
        'SCHEDULE X NRx ONLY. Contains Methylphenidate HCl 10mg.',
        ['Methylphenidate 10 mg'],
      );
      expect(res['schedule'], equals(DrugSchedule.scheduleX));
      expect(res['warning'], contains('SCHEDULE X'));
    });

    test('Detects CDSCO Banned Fixed-Dose Combination (FDC)', () {
      final res = service.classify(
        'Combination of Nimesulide + Paracetamol dispersible tablet',
        ['Nimesulide', 'Paracetamol'],
      );
      expect(res['isBanned'], isTrue);
      expect(res['bannedDetails'], contains('Nimesulide'));
      expect(res['warning'], contains('BANNED DRUG'));
    });

    test('Classifies General Over-the-Counter medicine (OTC)', () {
      final res = service.classify(
        'Paracetamol Tablets IP 500mg. General sale.',
        ['Paracetamol'],
      );
      expect(res['schedule'], equals(DrugSchedule.otc));
      expect(res['isBanned'], isFalse);
    });
  });

  group('Jan Aushadhi (PMBJP) Generic Savings Service', () {
    final service = JanAushadhiService();

    test('Extracts active generic salt molecules from packaging text', () {
      const text = 'Composition: Each tablet contains Paracetamol IP 650 mg and Phenylephrine HCl 5 mg.';
      final salts = service.extractActiveIngredients(text);
      expect(salts.any((s) => s.contains('PARACETAMOL')), isTrue);
    });

    test('Matches Dolo 650 with Jan Aushadhi generic and computes ~70% price savings', () {
      const text = 'DOLO 650 TABLETS. Paracetamol 650mg.';
      final comparison = service.findGenericAlternative(text, ['PARACETAMOL 650 MG']);
      expect(comparison, isNotNull);
      expect(comparison!.brandName, equals('DOLO 650'));
      expect(comparison.estimatedBrandedMrp, equals(34.0));
      expect(comparison.janAushadhiPrice, equals(10.0));
      expect(comparison.amountSaved, equals(24.0));
      expect(comparison.savingsPercentage, greaterThan(65.0));
    });

    test('Matches Pantocid / Pan 40 with Jan Aushadhi generic and computes >80% price savings', () {
      const text = 'PAN 40 TABLETS. Pantoprazole 40mg.';
      final comparison = service.findGenericAlternative(text, ['PANTOPRAZOLE 40 MG']);
      expect(comparison, isNotNull);
      expect(comparison!.estimatedBrandedMrp, equals(165.0));
      expect(comparison.janAushadhiPrice, equals(22.0));
      expect(comparison.savingsPercentage, greaterThan(80.0));
    });
  });

  group('End-to-End Medicine Safety Orchestrator', () {
    final orchestrator = MedicineSafetyOrchestrator();
    final fixedRefDate = DateTime(2026, 6, 1);

    test('Performs complete offline safety audit on Dolo 650 with Jan Aushadhi generic savings', () async {
      const text = '''
DOLO 650 TABLETS
Each uncoated tablet contains:
Paracetamol IP 650 mg
Mfg. Lic. No.: G/25/1458
B.No.: DL9042
MFD.: 01/2026
EXP.: 12/2028
MRP Rs. 34.00
Storage: Store below 30°C in a dry place. Protect from light.
Manufactured by: Micro Labs Limited, Gujarat.
''';

      final report = await orchestrator.analyze(text, referenceDate: fixedRefDate);

      expect(report.overallVerdict, equals(MedicineSafetyVerdict.safe));
      expect(report.safetyScore, greaterThanOrEqualTo(90.0));
      expect(report.licenseVerification?.isValid, isTrue);
      expect(report.batchExpiry.isExpired, isFalse);
      expect(report.genericComparison, isNotNull);
      expect(report.genericComparison?.savingsPercentage, greaterThan(60.0));
      expect(report.findings.length, greaterThanOrEqualTo(2));
    });

    test('Audits Schedule H1 Antibiotic (Augmentin 625) with statutory red banner warnings', () async {
      const text = '''
AUGMENTIN 625 DUO TABLETS
SCHEDULE H1 PRESCRIPTION DRUG - CAUTION
Warning: It is dangerous to take this preparation except in accordance with medical advice.
Not to be sold by retail without the prescription of a Registered Medical Practitioner.
Composition:
Amoxicillin Trihydrate IP eq. to Amoxicillin 500 mg
Potassium Clavulanate Diluted IP eq. to Clavulanic Acid 125 mg
Mfg. Lic. No.: MNB/05/189
Batch No.: AG8821
MFG. DATE: 15/02/2026
EXPIRY DATE: 14/02/2028
MRP: Rs. 220.00
''';

      final report = await orchestrator.analyze(text, referenceDate: fixedRefDate);

      expect(report.schedule, equals(DrugSchedule.scheduleH1));
      expect(report.licenseVerification?.isValid, isTrue);
      expect(report.batchExpiry.isExpired, isFalse);
      expect(report.findings.any((f) => f.id == 'sched_h1'), isTrue);
      expect(report.genericComparison, isNotNull);
    });

    test('Flags expired medicine as High Risk / Prohibited consumption', () async {
      const text = '''
CETZINE 10MG TABLETS
Cetirizine Hydrochloride IP 10 mg
Mfg. Lic. No.: MH/102/2019
B.No.: CT4109
MFD: 01/01/2024
EXP: 31/12/2025
''';

      final report = await orchestrator.analyze(text, referenceDate: fixedRefDate);

      expect(report.batchExpiry.isExpired, isTrue);
      expect(report.overallVerdict, equals(MedicineSafetyVerdict.highRisk));
      expect(report.safetyScore, lessThanOrEqualTo(30.0));
      expect(report.findings.any((f) => f.id == 'med_expired'), isTrue);
    });

    test('Flags Banned Fixed-Dose Combination as Prohibited under Sec 26A', () async {
      const text = '''
NIMESULIDE AND PARACETAMOL DISPERSIBLE TABLETS
Each dispersible tablet contains:
Nimesulide BP 100 mg
Paracetamol IP 325 mg
Batch No.: NM7011
Mfg Lic No: UA/2018/442
''';

      final report = await orchestrator.analyze(text, referenceDate: fixedRefDate);

      expect(report.isBannedFdc, isTrue);
      expect(report.overallVerdict, equals(MedicineSafetyVerdict.bannedFdc));
      expect(report.safetyScore, equals(0.0));
      expect(report.findings.any((f) => f.id == 'banned_fdc'), isTrue);
    });
  });
}
