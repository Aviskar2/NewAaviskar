import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scan_sure/core/legal/models/document_analysis_status.dart';
import 'package:scan_sure/core/legal/models/document_anomaly.dart';
import 'package:scan_sure/core/legal/models/legal_clause.dart';
import 'package:scan_sure/core/legal/models/legal_document_type.dart';
import 'package:scan_sure/core/legal/models/legal_finding.dart';
import 'package:scan_sure/services/legal/legal_orchestrator.dart';
import 'package:scan_sure/services/legal/pipeline/document_chunker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LegalOrchestrator orchestrator;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    orchestrator = LegalOrchestrator();
  });

  group('Section 54: Complete 10-Scenario Document Risk Analysis Test Suite', () {
    // -------------------------------------------------------------------------
    // Scenario 1: Normal Loan Agreement
    // -------------------------------------------------------------------------
    test('Scenario 1: Normal loan agreement returns low/medium risk with valid loan terms', () async {
      const normalLoanText = '''
LOAN AGREEMENT
This Loan Agreement is made on 12th October 2024 between Apex Capital Ltd ("Lender") and Rajesh Sharma ("Borrower").
1. PRINCIPAL LOAN AMOUNT: The Lender agrees to advance a loan of Rs. 2,00,000 to the Borrower by direct bank transfer upon document verification.
2. INTEREST RATE: Interest shall accrue at 10.5% per annum calculated on reducing balance.
3. REPAYMENT SCHEDULE: The Borrower shall repay the loan in 24 equated monthly installments (EMI) of Rs. 9,280 starting from 10th November 2024.
4. PREPAYMENT: The Borrower may prepay the principal amount at any time subject to nominal standard processing charges.
5. GOVERNING LAW: This Agreement shall be governed by the laws of India and courts of New Delhi shall have exclusive jurisdiction.
IN WITNESS WHEREOF the parties have executed this Agreement.
Signed: Lender Representative
Signed: Borrower
''';

      final doc = orchestrator.createDocumentFromText(normalLoanText, confidence: 0.95);
      final result = await orchestrator.analyze(doc, enableAiEnhancement: false);

      expect(result.documentType, LegalDocumentType.loanAgreement);
      expect(result.overallRiskScore, lessThanOrEqualTo(50.0));
      expect(result.findings.any((f) => f.clauseType == LegalClauseType.upfrontFeeScam), isFalse);
      expect(result.overallSeverity, isNot(LegalRiskSeverity.high));
      expect(result.analysisId.startsWith('an_'), isTrue);
    });

    // -------------------------------------------------------------------------
    // Scenario 2: Loan Agreement with Suspicious Upfront Payment
    // -------------------------------------------------------------------------
    test('Scenario 2: Loan agreement with suspicious upfront payment flags payment risk', () async {
      const suspiciousLoanText = '''
FAST CASH PERSONAL LOAN SANCTION LETTER
Lender: QuickCredit Fast Money Pvt Ltd
Borrower: Suman Verma
1. SANCTION AMOUNT: Personal loan of Rs. 5,00,000 is approved.
2. MANDATORY UPFRONT REGISTRATION FEE: To release the loan disbursement, Borrower must deposit a mandatory upfront registration fee of Rs 35000 via IMPS before loan disbursement. The funds will not be disbursed without this registration fee.
3. DISBURSEMENT: Disbursal within 2 hours of payment receipt.
4. INTEREST: 12% per annum.
IN WITNESS WHEREOF:
Signed: Authorized Signatory
''';

      final doc = orchestrator.createDocumentFromText(suspiciousLoanText, confidence: 0.94);
      final result = await orchestrator.analyze(doc, enableAiEnhancement: false);

      expect(result.documentType, LegalDocumentType.loanAgreement);
      expect(result.findings.any((f) => f.clauseType == LegalClauseType.upfrontFeeScam), isTrue);
      final upfrontFinding = result.findings.firstWhere((f) => f.clauseType == LegalClauseType.upfrontFeeScam);
      expect(upfrontFinding.severity, LegalRiskSeverity.high);
      expect(upfrontFinding.clauseId?.startsWith('clause_'), isTrue);
      expect(upfrontFinding.rawExcerpt.isNotEmpty, isTrue);
      expect(upfrontFinding.statutoryBasis.any((s) => s.actName.contains('Bharatiya Nyaya Sanhita')), isTrue);
      expect(result.overallRiskScore, greaterThanOrEqualTo(45.0));
    });

    // -------------------------------------------------------------------------
    // Scenario 3: Employment Scam Document
    // -------------------------------------------------------------------------
    test('Scenario 3: Employment scam document flags upfront recruitment fee and restraint', () async {
      const employmentScamText = '''
GLOBAL INFOTECH TALENT - OFFER OF EMPLOYMENT
Date: 15 January 2025
Candidate: Amit Kumar
Position: Remote Systems Specialist
1. REMUNERATION: Monthly CTC of Rs. 95,000.
2. MANDATORY ONBOARDING SECURITY DEPOSIT: To confirm acceptance of this position, the candidate must pay a mandatory registration fee of Rs 25000 before interview and joining for training materials.
3. NON-COMPETE RESTRAINT: The employee agrees that for a period of 5 years following termination, employee shall not work for any technology company in the world.
IN WITNESS WHEREOF:
Signed: HR Manager
''';

      final doc = orchestrator.createDocumentFromText(employmentScamText, confidence: 0.95);
      final result = await orchestrator.analyze(doc, enableAiEnhancement: false);

      expect(result.documentType, LegalDocumentType.employmentContract);
      expect(result.findings.any((f) => f.clauseType == LegalClauseType.upfrontFeeScam), isTrue);
      expect(result.findings.any((f) => f.clauseType == LegalClauseType.nonCompeteRestraint), isTrue);
      expect(result.overallRiskScore, greaterThanOrEqualTo(60.0));
      expect(result.overallSeverity, LegalRiskSeverity.high);
    });

    // -------------------------------------------------------------------------
    // Scenario 4: Rental Agreement
    // -------------------------------------------------------------------------
    test('Scenario 4: Rental agreement yields relevant tenancy analysis', () async {
      const rentalText = '''
RESIDENTIAL LEASE AND TENANCY AGREEMENT
This Tenancy Agreement is made on 1st November 2024 between Ramesh Patel ("Landlord") and Sunita Rao ("Tenant").
1. PREMISES: Flat No. 402, Sunshine Residency, Indiranagar, Bengaluru.
2. TERM: Fixed term of 11 months commencing from 1st November 2024.
3. MONTHLY RENT: Tenant shall pay a monthly rent of Rs. 28,000 on or before the 5th day of every calendar month.
4. SECURITY DEPOSIT: Tenant has deposited Rs. 56,000 as refundable interest-free security deposit.
5. TERMINATION: Either party may terminate this tenancy by serving one month prior written notice.
IN WITNESS WHEREOF the parties have set their hands:
Signed: Landlord
Signed: Tenant
Witness 1: Rajesh
Witness 2: Mohan
''';

      final doc = orchestrator.createDocumentFromText(rentalText, confidence: 0.96);
      final result = await orchestrator.analyze(doc, enableAiEnhancement: false);

      expect(result.documentType, LegalDocumentType.rentalAgreement);
      expect(result.findings.any((f) => f.clauseType == LegalClauseType.upfrontFeeScam), isFalse);
      expect(result.overallRiskScore, lessThan(40.0));
      expect(result.executiveLegalSummary.contains('Model Tenancy Act') || result.executiveLegalSummary.contains('Transfer of Property'), isTrue);
    });

    // -------------------------------------------------------------------------
    // Scenario 5: Completely Normal Agreement
    // -------------------------------------------------------------------------
    test('Scenario 5: Completely normal agreement returns no significant risk indicators', () async {
      const normalNdaText = '''
MUTUAL NON-DISCLOSURE AGREEMENT
This Mutual Non-Disclosure Agreement is entered into by and between Alpha Solutions Ltd and Beta Services Ltd.
1. PURPOSE: The parties wish to explore a mutually beneficial business collaboration.
2. CONFIDENTIALITY: Each party agrees to treat proprietary technical data of the other party with the same degree of care it uses for its own confidential information, for a period of two years.
3. EXCLUSIONS: Information already publicly known through no breach shall not be considered confidential.
4. DISPUTE RESOLUTION: Any dispute shall be resolved through amicable mediation and Indian arbitration in New Delhi.
IN WITNESS WHEREOF the authorized officers have signed:
Signed: Alpha Solutions Ltd
Signed: Beta Services Ltd
Witness 1: Signature
Witness 2: Signature
''';

      final doc = orchestrator.createDocumentFromText(normalNdaText, confidence: 0.98);
      final result = await orchestrator.analyze(doc, enableAiEnhancement: false);

      expect(result.findings.isEmpty, isTrue);
      expect(result.overallSeverity, LegalRiskSeverity.safe);
      expect(result.status, DocumentAnalysisStatus.noMaterialRisk);
      expect(result.overallRiskScore, lessThanOrEqualTo(10.0));
    });

    // -------------------------------------------------------------------------
    // Scenario 6: Contradictory Document
    // -------------------------------------------------------------------------
    test('Scenario 6: Contradictory document triggers structural inconsistency warning', () async {
      const contradictoryText = '''
SUPPLY AND PROCUREMENT CONTRACT
Date of Execution: 15th December 2025
Delivery Date: 10th January 2024
1. PRICE: The Buyer shall pay a total consideration of Rupees Fifty Thousand only (Rs. 5,00,000) upon signing.
2. DELIVERY: The Seller agrees that delivery date is 10th January 2024.
IN WITNESS WHEREOF:
Signed: Buyer
Signed: Seller
''';

      final doc = orchestrator.createDocumentFromText(contradictoryText, confidence: 0.90);
      final result = await orchestrator.analyze(doc, enableAiEnhancement: false);

      expect(result.anomalies.isNotEmpty, isTrue);
      final hasDateInconsistency = result.anomalies.any((a) => a.category == AnomalyCategory.dateInconsistency);
      final hasAmountMismatch = result.anomalies.any((a) => a.category == AnomalyCategory.amountDiscrepancy);
      expect(hasDateInconsistency || hasAmountMismatch, isTrue);
      expect(
        result.consistencyChecks.dateConsistency == 'warning' || result.consistencyChecks.structure == 'warning',
        isTrue,
      );
    });

    // -------------------------------------------------------------------------
    // Scenario 7: Poor OCR Document
    // -------------------------------------------------------------------------
    test('Scenario 7: Poor OCR document returns low-confidence / text-quality warning without fake 90%', () async {
      const corruptedOcrText = 'â–¡â–¡ @#%^ &amp; ?? â–’â–’ !! %%% unreadable 123...';

      final doc = orchestrator.createDocumentFromText(corruptedOcrText, confidence: 0.20);
      final result = await orchestrator.analyze(doc, enableAiEnhancement: false);

      expect(result.status, DocumentAnalysisStatus.poorOcrQuality);
      expect(result.confidenceLevel, DocumentAnalysisConfidence.insufficientEvidence);
      // Must NOT return fake 90%
      expect(result.overallRiskScore, 0.0);
      expect(result.plainSummary.contains('text quality was insufficient'), isTrue);
    });

    // -------------------------------------------------------------------------
    // Scenario 8: Random Unrelated Text
    // -------------------------------------------------------------------------
    test('Scenario 8: Random unrelated text returns low-confidence / unsupported result without fraud flags', () async {
      const randomText = '''
The quick brown fox jumps gracefully over the lazy dog resting near the riverbank on a warm sunny afternoon.
A gentle breeze whispered through the tall green pine trees, while birds chirped melodious tunes high above the canopy.
Local weather reports predict occasional showers tomorrow with moderate temperatures throughout the region.
''';

      final doc = orchestrator.createDocumentFromText(randomText, confidence: 0.90);
      final result = await orchestrator.analyze(doc, enableAiEnhancement: false);

      expect(result.findings.isEmpty, isTrue);
      expect(result.overallRiskScore, lessThanOrEqualTo(10.0));
      expect(result.overallSeverity, LegalRiskSeverity.safe);
      expect(result.documentType, LegalDocumentType.otherOrUnknown);
    });

    // -------------------------------------------------------------------------
    // Scenario 9: Very Long Document (Chunking)
    // -------------------------------------------------------------------------
    test('Scenario 9: Very long document is segmented into stable clause IDs and chunked', () async {
      final buffer = StringBuffer();
      buffer.writeln('COMMERCIAL MASTER SERVICES AGREEMENT');
      buffer.writeln('This Master Services Agreement is executed on 1st January 2025.');
      for (int i = 1; i <= 35; i++) {
        buffer.writeln('Clause $i. Standard operational term number $i specifying routine procedural obligations between party A and party B.');
        buffer.writeln('The parties agree to communicate notices in writing for section $i.');
      }
      buffer.writeln('IN WITNESS WHEREOF the parties sign:');
      buffer.writeln('Signed: Party A');
      buffer.writeln('Signed: Party B');

      final doc = orchestrator.createDocumentFromText(buffer.toString(), confidence: 0.95);

      // Verify chunker logic
      final clauses = orchestrator.segmentationService.segmentDocument(doc.rawText, doc: doc);
      expect(clauses.length, greaterThan(25));
      expect(clauses.first.id, 'clause_001');

      const chunker = DocumentChunker(maxClausesPerChunk: 10, overlapClauses: 2);
      final chunks = chunker.createChunks(clauses);
      expect(chunks.length, greaterThan(1));

      final result = await orchestrator.analyze(doc, enableAiEnhancement: false);
      expect(result.findings.length, lessThan(10));
      expect(result.analysisId.isNotEmpty, isTrue);
    });

    // -------------------------------------------------------------------------
    // Scenario 10: Suspicious Keyword in Harmless Context
    // -------------------------------------------------------------------------
    test('Scenario 10: Suspicious keyword in harmless / negated context is NOT flagged as fraud', () async {
      const harmlessContextText = '''
STANDARD EMPLOYMENT CONTRACT
Employer: Horizon Software Technologies Ltd
Employee: Priya Menon
1. POSITION: Senior Software Engineer
2. NO UPFRONT FEES POLICY: Horizon Software Technologies does not charge any registration fee, security deposit, processing fee, or upfront payment of any kind from job applicants or employees. All onboarding materials and equipment are provided free of cost.
3. REMUNERATION: Annual fixed compensation of Rs. 18,00,000 payable monthly.
4. TERMINATION: Either party may terminate employment by giving 30 days written notice or salary in lieu thereof.
IN WITNESS WHEREOF:
Signed: HR Director
Signed: Priya Menon
Witness 1: Signature
Witness 2: Signature
''';

      final doc = orchestrator.createDocumentFromText(harmlessContextText, confidence: 0.97);
      final result = await orchestrator.analyze(doc, enableAiEnhancement: false);

      // Crucial requirement: "does not charge any registration fee" must NOT trigger upfront fee scam!
      expect(result.findings.any((f) => f.clauseType == LegalClauseType.upfrontFeeScam), isFalse);
      expect(result.overallSeverity, isNot(LegalRiskSeverity.high));
      expect(result.overallRiskScore, lessThanOrEqualTo(25.0));
    });
  });
}
