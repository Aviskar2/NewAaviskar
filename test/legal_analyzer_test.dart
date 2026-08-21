import 'package:flutter_test/flutter_test.dart';
import 'package:aura_ai/core/legal/models/legal_clause.dart';
import 'package:aura_ai/core/legal/models/legal_document_type.dart';
import 'package:aura_ai/core/legal/models/legal_finding.dart';
import 'package:aura_ai/services/legal/clause_extraction_service.dart';
import 'package:aura_ai/services/legal/document_anomaly_service.dart';
import 'package:aura_ai/services/legal/indian_law_rag_service.dart';
import 'package:aura_ai/services/legal/legal_document_classifier.dart';
import 'package:aura_ai/services/legal/legal_orchestrator.dart';
import 'package:aura_ai/services/legal/legal_risk_engine.dart';

void main() {
  late LegalDocumentClassifier classifier;
  late ClauseExtractionService clauseService;
  late DocumentAnomalyService anomalyService;
  late IndianLawRagService ragService;
  late LegalRiskEngine riskEngine;
  late LegalOrchestrator orchestrator;

  setUp(() {
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
  });
}
