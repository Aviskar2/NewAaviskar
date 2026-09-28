import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scan_sure/core/legal/constants/indian_acts_database.dart';
import 'package:scan_sure/core/legal/constants/sample_legal_documents.dart';
import 'package:scan_sure/widgets/legal_analyzer/highlighted_document_paper.dart';
import 'package:scan_sure/core/legal/models/legal_clause.dart';
import 'package:scan_sure/core/legal/models/legal_document_type.dart';
import 'package:scan_sure/core/legal/models/legal_finding.dart';
import 'package:scan_sure/services/legal/clause_extraction_service.dart';
import 'package:scan_sure/services/legal/document_anomaly_service.dart';
import 'package:scan_sure/services/legal/indian_law_rag_service.dart';
import 'package:scan_sure/services/legal/legal_document_classifier.dart';
import 'package:scan_sure/services/legal/legal_orchestrator.dart';
import 'package:scan_sure/services/legal/legal_risk_engine.dart';
import 'package:scan_sure/services/legal/live_legal_update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LegalDocumentClassifier classifier;
  late ClauseExtractionService clauseService;
  late DocumentAnomalyService anomalyService;
  late IndianLawRagService ragService;
  late LegalRiskEngine riskEngine;
  late LegalOrchestrator orchestrator;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    classifier = LegalDocumentClassifier();
    clauseService = ClauseExtractionService();
    anomalyService = DocumentAnomalyService();
    ragService = IndianLawRagService();
    riskEngine = LegalRiskEngine();
    orchestrator = LegalOrchestrator();
  });

  group('Legal Document Classifier', () {
    test('Classifies Residential Rental Agreement', () {
      const text = '''
RESIDENTIAL LEASE AGREEMENT
Between Mr. Sharma (Lessor) and Ms. Verma (Lessee).
Premises: Flat 402, Sunshine Heights, Mumbai. Monthly rent of Rs. 35,000.
Security deposit of Rs. 1,00,000.
''';
      final res = classifier.classify(text);
      expect(res.type, LegalDocumentType.rentalAgreement);
      expect(res.confidence, greaterThanOrEqualTo(0.65));
    });

    test('Classifies Employment Contract', () {
      const text = '''
EMPLOYMENT AGREEMENT AND APPOINTMENT LETTER
Between Apex Technologies Pvt Ltd (Employer) and Amit Kumar (Employee).
Remuneration and CTC: 12,00,000 per annum. Probation period: 6 months.
''';
      final res = classifier.classify(text);
      expect(res.type, LegalDocumentType.employmentContract);
    });

    test('Classifies Non-Disclosure Agreement (NDA)', () {
      const text = '''
MUTUAL NON-DISCLOSURE AGREEMENT
Entered into by and between Disclosing Party and Receiving Party.
Proprietary technical and confidential information shall not be disclosed.
''';
      final res = classifier.classify(text);
      expect(res.type, LegalDocumentType.nonDisclosureAgreement);
    });
  });

  group('Clause Extraction & Statutory Matching', () {
    test('Identifies Non-Compete Restraint and attaches Section 27 citation', () {
      const text = '''
Employee Agreement:
The Employee shall not engage in any competing business or work for any competitor for 2 years post-termination.
''';
      final doc = orchestrator.createDocumentFromText(text);
      final findings = clauseService.extractFindings(doc);

      expect(findings.any((f) => f.clauseType == LegalClauseType.nonCompeteRestraint), isTrue);
      final nonCompete = findings.firstWhere((f) => f.clauseType == LegalClauseType.nonCompeteRestraint);
      expect(nonCompete.severity, LegalRiskSeverity.high);
      expect(nonCompete.statutoryBasis.any((s) => s.section.contains('27')), isTrue);
      expect(nonCompete.boundingBox, isNotNull);
    });

    test('Identifies Disproportionate Penalty and attaches Section 74 citation', () {
      const text = '''
Tenant Agreement:
In the event of delay, the tenant shall pay a penalty of Rs. 50,000 plus interest @ 24% per annum.
''';
      final doc = orchestrator.createDocumentFromText(text);
      final findings = clauseService.extractFindings(doc);

      expect(findings.any((f) => f.clauseType == LegalClauseType.penaltyAndDamages), isTrue);
      final penalty = findings.firstWhere((f) => f.clauseType == LegalClauseType.penaltyAndDamages);
      expect(penalty.statutoryBasis.any((s) => s.section.contains('74')), isTrue);
    });

    test('Identifies Unilateral Immediate Termination and Unlimited Indemnity', () {
      const text = '''
Service Contract:
Company reserves the right to terminate immediately without notice or cause.
Contractor shall indemnify and hold harmless against all claims and damages regardless of negligence.
''';
      final doc = orchestrator.createDocumentFromText(text);
      final findings = clauseService.extractFindings(doc);

      expect(findings.any((f) => f.clauseType == LegalClauseType.unilateralTermination), isTrue);
      expect(findings.any((f) => f.clauseType == LegalClauseType.unlimitedIndemnity), isTrue);
    });

    test('Retrieves statutory provisions using IndianLawRagService', () {
      final provisions = ragService.retrieveProvisions('non-compete', clauseType: LegalClauseType.nonCompeteRestraint);
      expect(provisions.isNotEmpty, isTrue);
      expect(provisions.any((p) => p.section.contains('27')), isTrue);
    });
  });

  group('Document Anomaly Detection', () {
    test('Detects numerical figure vs word discrepancy', () {
      const text = '''
Payment clause:
The borrower shall pay Rs. 50,000 (Rupees Fifteen Thousand Only) on or before 1st of every month.
''';
      final doc = orchestrator.createDocumentFromText(text);
      final anomalies = anomalyService.analyzeAnomalies(doc);

      expect(anomalies.any((a) => a.id == 'anomaly_amount_mismatch'), isTrue);
    });

    test('Detects foreign jurisdiction in domestic context', () {
      const text = '''
General Terms:
This agreement shall be governed exclusively by the Laws of Delaware and Singapore Courts.
''';
      final doc = orchestrator.createDocumentFromText(text);
      final anomalies = anomalyService.analyzeAnomalies(doc);

      expect(anomalies.any((a) => a.id == 'anomaly_foreign_jurisdiction'), isTrue);
    });
  });

  group('Legal Risk Engine & Multi-Factor Scoring', () {
    test('Calculates High Risk when critical void restraints exist', () {
      const text = '''
EMPLOYMENT AGREEMENT:
1. Employee shall not work for any competitor for a period of 2 years post-termination.
2. Employee shall pay a penalty of Rs. 5,00,000 as liquidated damages.
3. Employee shall indemnify and hold harmless against all losses regardless of negligence.
''';
      final doc = orchestrator.createDocumentFromText(text);
      final findings = clauseService.extractFindings(doc);
      final anomalies = anomalyService.analyzeAnomalies(doc);
      final risk = riskEngine.evaluate(findings, anomalies, doc);

      expect(risk.severity, LegalRiskSeverity.high);
      expect(risk.overallScore, greaterThanOrEqualTo(60.0));
      expect(risk.breakdown.legalRisk, greaterThan(0));
      expect(risk.breakdown.financialRisk, greaterThan(0));
    });

    test('Calculates Safe/Low Risk for standard balanced NDA', () {
      const text = '''
MUTUAL NON-DISCLOSURE AGREEMENT:
Both parties agree to protect proprietary data with reasonable care.
Term is 2 years. Governed by the Indian Contract Act, 1872.
''';
      final doc = orchestrator.createDocumentFromText(text);
      final findings = clauseService.extractFindings(doc);
      final anomalies = anomalyService.analyzeAnomalies(doc);
      final risk = riskEngine.evaluate(findings, anomalies, doc);

      expect(risk.severity == LegalRiskSeverity.safe || risk.severity == LegalRiskSeverity.low, isTrue);
      expect(risk.overallScore, lessThan(30.0));
    });
  });

  group('End-to-End Legal Orchestrator', () {
    test('Performs complete offline legal analysis pipeline', () async {
      const contract = '''
RESIDENTIAL RENTAL AGREEMENT
Between Rajesh (Lessor) and Suresh (Lessee).
1. Monthly rent Rs. 25,000.
2. The security deposit is strictly non-refundable and lessor shall forfeit the entire deposit in event of dispute.
3. Lessor reserves the right to modify these terms at any time without notice.
''';
      final doc = orchestrator.createDocumentFromText(contract);
      final result = await orchestrator.analyze(doc, enableAiEnhancement: false);

      expect(result.documentType, LegalDocumentType.rentalAgreement);
      expect(result.findings.isNotEmpty, isTrue);
      expect(result.overallSeverity, LegalRiskSeverity.high);
      expect(result.plainSummary.isNotEmpty, isTrue);
      expect(result.executiveLegalSummary.isNotEmpty, isTrue);
    });

    test('Registers new dynamic statutory laws and retrieves them in RAG', () {
      const newStatute = StatutoryCitation(
        actName: 'Telecommunications Act, 2023',
        section: 'Section 19',
        title: 'Protection of Telecommunication Identifiers',
        description: 'Statutory framework governing biometric verification and SIM identification.',
        officialSourceUrl: 'https://www.indiacode.nic.in/handle/123456789/21809',
        isEnforceableInIndia: true,
      );

      // Register new dynamic statute
      IndianActsDatabase.registerDynamicProvision(newStatute);

      // Verify it is part of allProvisions
      expect(IndianActsDatabase.allProvisions.any((p) => p.actName == 'Telecommunications Act, 2023'), isTrue);

      // Verify RAG retrieves it
      final retrieved = ragService.retrieveProvisions('Telecommunications');
      expect(retrieved.any((p) => p.section == 'Section 19'), isTrue);
    });

    test('Full Audit: Analyzes highRiskRentalAgreement and flags critical predatory clauses', () async {
      final doc = orchestrator.createDocumentFromText(SampleLegalDocuments.highRiskRentalAgreement);
      final result = await orchestrator.analyze(doc, enableAiEnhancement: false);

      // Verify classification
      expect(result.documentType, LegalDocumentType.rentalAgreement);

      // Verify overall high risk
      expect(result.overallSeverity, LegalRiskSeverity.high);
      expect(result.overallRiskScore, greaterThanOrEqualTo(85.0));

      // Check specific predatory clauses flagged
      final clauseTypes = result.findings.map((f) => f.clauseType).toSet();
      expect(clauseTypes.contains(LegalClauseType.securityDepositForfeiture), isTrue,
          reason: 'Should flag arbitrary 10-month deposit forfeiture');
      expect(clauseTypes.contains(LegalClauseType.unilateralTermination), isTrue,
          reason: 'Should flag unilateral termination without notice');
      expect(clauseTypes.contains(LegalClauseType.restraintOfLegalRecourse), isTrue,
          reason: 'Should flag void court restraint under Sec 28');
      expect(clauseTypes.contains(LegalClauseType.nonCompeteRestraint), isTrue,
          reason: 'Should flag void non-compete restraint under Sec 27');
      expect(clauseTypes.contains(LegalClauseType.penaltyAndDamages), isTrue,
          reason: 'Should flag disproportionate penalties');
      expect(clauseTypes.contains(LegalClauseType.unlimitedIndemnity), isTrue,
          reason: 'Should flag unlimited indemnity');

      // Verify each finding has an official Indian statutory citation
      for (final finding in result.findings) {
        expect(finding.statutoryBasis.isNotEmpty, isTrue,
            reason: 'Every finding must have at least one statutory citation');
        expect(finding.simpleExplanation.isNotEmpty, isTrue);
        expect(finding.recommendedAction.isNotEmpty, isTrue);
      }
    });

    test('Full Audit: Analyzes highRiskEmploymentBond and flags upfront fee scam & 3-yr non-compete', () async {
      final doc = orchestrator.createDocumentFromText(SampleLegalDocuments.highRiskEmploymentBond);
      final result = await orchestrator.analyze(doc, enableAiEnhancement: false);

      expect(result.overallSeverity, LegalRiskSeverity.high);
      final clauseTypes = result.findings.map((f) => f.clauseType).toSet();
      expect(clauseTypes.contains(LegalClauseType.upfrontFeeScam), isTrue,
          reason: 'Should flag upfront registration fee scam trap');
      expect(clauseTypes.contains(LegalClauseType.nonCompeteRestraint), isTrue,
          reason: 'Should flag 3-year non-compete bond');
      expect(clauseTypes.contains(LegalClauseType.restraintOfLegalRecourse), isTrue,
          reason: 'Should flag waiver of labour and consumer court recourse');
    });

    testWidgets('HighlightedDocumentPaper renders and marks flagged clauses with tap interaction', (tester) async {
      final doc = orchestrator.createDocumentFromText(SampleLegalDocuments.highRiskRentalAgreement);
      final result = await orchestrator.analyze(doc, enableAiEnhancement: false);

      LegalFinding? tappedFinding;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HighlightedDocumentPaper(
              rawText: doc.rawText,
              findings: result.findings,
              onFindingTap: (finding) {
                tappedFinding = finding;
              },
            ),
          ),
        ),
      );

      // Verify legend bar displays count of flagged clauses
      expect(find.textContaining('Flagged Clauses Highlighted in Paper'), findsOneWidget);

      // Verify risk alert labels are rendered
      expect(find.text('RISK ALERT'), findsWidgets);

      // Verify tapping a highlighted clause triggers callback
      await tester.tap(find.text('RISK ALERT').first);
      await tester.pump();

      expect(tappedFinding, isNotNull);
    });

    test('Classifies Builder-Buyer, Commercial Lease, and Vendor MSME Agreements accurately', () {
      final bbaResult = classifier.classify(SampleLegalDocuments.highRiskBuilderBuyerAgreement);
      expect(bbaResult.type, LegalDocumentType.builderBuyerAgreement);
      expect(bbaResult.type.displayName, contains('Builder-Buyer'));

      final leaseResult = classifier.classify(SampleLegalDocuments.highRiskCommercialLease);
      expect(leaseResult.type, LegalDocumentType.commercialLeaseAgreement);

      final vendorResult = classifier.classify(SampleLegalDocuments.highRiskVendorSupplyAgreement);
      expect(vendorResult.type, LegalDocumentType.vendorSupplyAgreement);
    });

    test('Full Audit: Analyzes highRiskBuilderBuyerAgreement and flags RERA Sec 13 & 18 violations', () async {
      final doc = orchestrator.createDocumentFromText(SampleLegalDocuments.highRiskBuilderBuyerAgreement);
      final result = await orchestrator.analyze(doc, enableAiEnhancement: false);

      expect(result.overallSeverity, LegalRiskSeverity.high);
      expect(result.documentType, LegalDocumentType.builderBuyerAgreement);
      final hasReraViolation = result.findings.any((f) =>
          f.statutoryBasis.any((b) => b.actName.contains('Real Estate') || b.section.contains('13') || b.section.contains('18')));
      expect(hasReraViolation, isTrue, reason: 'Must detect RERA 10% advance or delayed possession violation');
    });

    test('Live Legal Sync: syncLatestIndianLawsFromOfficialSources updates statutory database and emits LiveSyncReport', () async {
      final liveService = LiveLegalUpdateService();
      final report = await liveService.syncLatestIndianLawsFromOfficialSources(force: true);

      expect(report.isSuccess, isTrue);
      expect(report.totalProvisionsCount, greaterThanOrEqualTo(20));
      expect(report.sourceDescription, contains('Official Gazette of India'));
      expect(liveService.syncStatusNotifier.value, isNotNull);
    });
  });
}
