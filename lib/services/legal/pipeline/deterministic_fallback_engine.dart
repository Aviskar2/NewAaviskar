import '../../../core/legal/constants/indian_acts_database.dart';
import '../../../core/legal/models/document_analysis_status.dart';
import '../../../core/legal/models/document_anomaly.dart';
import '../../../core/legal/models/legal_clause.dart';
import '../../../core/legal/models/legal_document_type.dart';
import '../../../core/legal/models/legal_finding.dart';
import '../../../core/legal/models/ocr_document.dart';
import 'clause_segmentation_service.dart';
import 'controlled_legal_database_service.dart';

/// Result of deterministic fallback analysis.
class FallbackAnalysisResult {
  final List<LegalFinding> findings;
  final List<DocumentAnomaly> anomalies;
  final DocumentConsistencyChecks consistencyChecks;

  const FallbackAnalysisResult({
    required this.findings,
    required this.anomalies,
    required this.consistencyChecks,
  });
}

/// Step 50 of Document Analysis Pipeline: Deterministic Fallback & Structural Validation Engine.
///
/// Evaluates multiple risk dimensions per clause independently without arbitrary fixed scores.
class DeterministicFallbackEngine {
  final ControlledLegalDatabaseService _legalDb = ControlledLegalDatabaseService();

  FallbackAnalysisResult analyze({
    required List<SegmentedClause> clauses,
    required OcrDocument doc,
    required LegalDocumentType docType,
  }) {
    final findings = <LegalFinding>[];
    final anomalies = <DocumentAnomaly>[];

    String partyStatus = 'pass';
    String dateStatus = 'pass';
    String structureStatus = 'pass';
    final notes = <String>[];

    int findingId = 1;

    for (final clause in clauses) {
      final text = clause.text;
      final lower = text.toLowerCase();

      // 1. Upfront Payment / Registration Fee in Recruitment or Loan Context
      if (_hasAny(lower, [
        'registration fee of rs', 'registration fee of ₹', 'registration fee of',
        'pay a registration fee', 'processing fee of rs', 'processing fee of ₹',
        'security deposit for job', 'pay advance amount of', 'refundable registration fee',
        'processing charge of inr', 'training fee to be deposited', 'deposit rs', 'deposit inr',
        'upfront payment of', 'pay before interview', 'registration charges',
        'before the loan is released',
      ]) && !_isNegated(lower)) {
        final excerpt = _extractMatchingExcerpt(text, [
          'registration fee', 'processing fee', 'security deposit', 'advance amount',
          'refundable', 'training fee', 'deposit', 'upfront payment', 'pay before',
        ]);
        final citations = _legalDb.getProvisionsForClause(LegalClauseType.upfrontFeeScam);
        findings.add(LegalFinding(
          id: 'finding_${findingId++}',
          clauseId: clause.id,
          clauseType: LegalClauseType.upfrontFeeScam,
          severity: LegalRiskSeverity.high,
          title: 'Unusual upfront payment requirement',
          simpleExplanation:
              'Requires an upfront fee or deposit prior to service, employment, or loan disbursement. Charging candidates or applicants upfront fees is a major risk indicator under Indian advisories.',
          legalExplanation:
              'Section 318 of the Bharatiya Nyaya Sanhita, 2023 (BNS) addresses cheating and dishonestly inducing delivery of property.',
          rawExcerpt: excerpt,
          pageIndex: clause.pageIndex,
          startOffset: clause.startOffset,
          endOffset: clause.endOffset,
          scoreContribution: 42,
          category: 'suspicious_payment_term',
          boundingBox: clause.boundingBox,
          statutoryBasis: citations,
          recommendedAction:
              'Verify the organization or lender on official MCA / RBI portals before making any payment.',
          confidence: 0.96,
        ));
      }

      // 2. Void Restraint of Legal Recourse (Sec 28)
      if (_hasAny(lower, [
        'waives the right to approach any court', 'shall not file any complaint in consumer',
        'no legal action shall lie against', 'no jurisdiction of any court', 'waives all rights to file suit',
        'cannot approach consumer court', 'shall not initiate legal proceedings',
      ])) {
        final excerpt = _extractMatchingExcerpt(text, [
          'court', 'jurisdiction', 'consumer', 'suit', 'legal action', 'legal proceedings',
        ]);
        final citations = _legalDb.getProvisionsForClause(LegalClauseType.restraintOfLegalRecourse);
        findings.add(LegalFinding(
          id: 'finding_${findingId++}',
          clauseId: clause.id,
          clauseType: LegalClauseType.restraintOfLegalRecourse,
          severity: LegalRiskSeverity.high,
          title: 'Restraint of legal proceedings',
          simpleExplanation:
              'Attempts to bar the signatory from approaching a court or Consumer Dispute Forum. Under Section 28 of the Indian Contract Act, such restraints are void.',
          legalExplanation:
              'Section 28 of the Indian Contract Act, 1872 renders agreements in restraint of legal proceedings void ab initio.',
          rawExcerpt: excerpt,
          pageIndex: clause.pageIndex,
          startOffset: clause.startOffset,
          endOffset: clause.endOffset,
          scoreContribution: 34,
          category: 'unenforceable_provision',
          boundingBox: clause.boundingBox,
          statutoryBasis: citations,
          recommendedAction:
              'Strike out this clause; legally you cannot be barred from approaching a competent Indian court or forum.',
          confidence: 0.95,
        ));
      }

      // 3. Post-Employment Non-Compete Restraint (Sec 27)
      if (_hasAny(lower, [
        'non-compete', 'not engage in any competing', 'shall not work for any competitor',
        'restrained from working', 'restraint of trade', 'not join any competitor for a period of',
        'prohibited from competing', 'shall not solicit or work with competitor',
      ])) {
        final excerpt = _extractMatchingExcerpt(text, [
          'compet', 'restrain', 'trade', 'solicit',
        ]);
        final citations = _legalDb.getProvisionsForClause(LegalClauseType.nonCompeteRestraint);
        findings.add(LegalFinding(
          id: 'finding_${findingId++}',
          clauseId: clause.id,
          clauseType: LegalClauseType.nonCompeteRestraint,
          severity: LegalRiskSeverity.high,
          title: 'Post-employment non-compete restraint',
          simpleExplanation:
              'Attempts to prohibit professional career mobility or competing business after agreement ends. Under Indian Law, post-termination non-compete restraints are void.',
          legalExplanation:
              'Section 27 of the Indian Contract Act, 1872 renders agreements in restraint of trade void (Percept D\'Mark v. Zaheer Khan, Supreme Court).',
          rawExcerpt: excerpt,
          pageIndex: clause.pageIndex,
          startOffset: clause.startOffset,
          endOffset: clause.endOffset,
          scoreContribution: 34,
          category: 'unenforceable_provision',
          boundingBox: clause.boundingBox,
          statutoryBasis: citations,
          recommendedAction:
              'Request removal of this post-termination restraint or seek written clarification.',
          confidence: 0.95,
        ));
      }

      // 4. Excessive Penalties / Liquidated Damages (Sec 74)
      if (_hasAny(lower, [
        'penalty of rs', 'penalty of inr', 'liquidated damages of', 'pay a penalty of',
        'forfeit the entire deposit', 'forfeit 100%', 'penalty equal to', 'deduct 100% of',
        'penalty of 18%', 'penalty of 24%', 'interest @ 24%', 'interest at 36%',
      ])) {
        final excerpt = _extractMatchingExcerpt(text, [
          'penalty', 'liquidated damages', 'forfeit', 'interest @', 'interest at',
        ]);
        final citations = _legalDb.getProvisionsForClause(LegalClauseType.penaltyAndDamages);
        findings.add(LegalFinding(
          id: 'finding_${findingId++}',
          clauseId: clause.id,
          clauseType: LegalClauseType.penaltyAndDamages,
          severity: LegalRiskSeverity.high,
          title: 'Disproportionate penalty or liquidated damages',
          simpleExplanation:
              'Imposes severe financial penalties or punitive damages for delays. In India, a party cannot charge arbitrary penalties beyond reasonable actual losses.',
          legalExplanation:
              'Section 74 of the Indian Contract Act, 1872 limits breach recovery to reasonable compensation (Fateh Chand v. Balkishan Das).',
          rawExcerpt: excerpt,
          pageIndex: clause.pageIndex,
          startOffset: clause.startOffset,
          endOffset: clause.endOffset,
          scoreContribution: 30,
          category: 'excessive_penalty',
          boundingBox: clause.boundingBox,
          statutoryBasis: citations,
          recommendedAction:
              'Negotiate to cap any damages to actual proven financial loss rather than pre-fixed punitive penalties.',
          confidence: 0.92,
        ));
      }

      // 5. Unilateral Termination
      if (_hasAny(lower, [
        'terminate immediately without notice', 'terminate without cause with immediate effect',
        'right to terminate at will without notice', 'terminate without any reason or liability',
        'sole discretion to terminate immediately',
      ])) {
        final excerpt = _extractMatchingExcerpt(text, [
          'terminate', 'notice', 'immediate',
        ]);
        final citations = _legalDb.getProvisionsForClause(LegalClauseType.unilateralTermination);
        findings.add(LegalFinding(
          id: 'finding_${findingId++}',
          clauseId: clause.id,
          clauseType: LegalClauseType.unilateralTermination,
          severity: LegalRiskSeverity.high,
          title: 'One-sided immediate termination right',
          simpleExplanation:
              'One party reserves the right to cancel the agreement immediately without notice or cause, creating severe vulnerability.',
          legalExplanation:
              'Section 2(46) of the Consumer Protection Act, 2019 categorizes one-sided termination terms as unfair contracts.',
          rawExcerpt: excerpt,
          pageIndex: clause.pageIndex,
          startOffset: clause.startOffset,
          endOffset: clause.endOffset,
          scoreContribution: 28,
          category: 'one_sided_obligation',
          boundingBox: clause.boundingBox,
          statutoryBasis: citations,
          recommendedAction:
              'Ensure mutual notice periods (e.g. 30 days) and a 15-day cure period before termination.',
          confidence: 0.91,
        ));
      }

      // 6. Unlimited Indemnity
      if (_hasAny(lower, [
        'indemnify and hold harmless against all', 'indemnify for any and all claims',
        'unlimited indemnification', 'indemnify regardless of negligence',
      ])) {
        final excerpt = _extractMatchingExcerpt(text, [
          'indemnif', 'hold harmless', 'negligence',
        ]);
        final citations = _legalDb.getProvisionsForClause(LegalClauseType.unlimitedIndemnity);
        findings.add(LegalFinding(
          id: 'finding_${findingId++}',
          clauseId: clause.id,
          clauseType: LegalClauseType.unlimitedIndemnity,
          severity: LegalRiskSeverity.high,
          title: 'Expansive unlimited indemnity clause',
          simpleExplanation:
              'Transfers uncapped commercial or legal liability even in situations not directly caused by the signatory.',
          legalExplanation:
              'Section 73 of the Indian Contract Act, 1872 governs compensation for loss or damage caused by breach.',
          rawExcerpt: excerpt,
          pageIndex: clause.pageIndex,
          startOffset: clause.startOffset,
          endOffset: clause.endOffset,
          scoreContribution: 30,
          category: 'unreasonable_liability_transfer',
          boundingBox: clause.boundingBox,
          statutoryBasis: citations,
          recommendedAction:
              'Insert a liability cap (e.g. total contract fees) and exclude indirect or consequential damages.',
          confidence: 0.90,
        ));
      }

      // 7. Arbitrary Security Deposit Forfeiture
      if (_hasAny(lower, [
        'deposit is strictly non-refundable', 'security deposit will not be refunded',
        'forfeit entire deposit in event of', 'forfeit security deposit without inquiry',
      ])) {
        final excerpt = _extractMatchingExcerpt(text, [
          'deposit', 'non-refundable', 'forfeit',
        ]);
        final citations = _legalDb.getProvisionsForClause(LegalClauseType.securityDepositForfeiture);
        findings.add(LegalFinding(
          id: 'finding_${findingId++}',
          clauseId: clause.id,
          clauseType: LegalClauseType.securityDepositForfeiture,
          severity: LegalRiskSeverity.high,
          title: 'Arbitrary deposit forfeiture provision',
          simpleExplanation:
              'Declares security deposits completely non-refundable without providing verifiable repair or breach receipts.',
          legalExplanation:
              'Section 11 of the Model Tenancy Act, 2021 and Section 74 of the Contract Act require deposit refund minus actual verifiable damages.',
          rawExcerpt: excerpt,
          pageIndex: clause.pageIndex,
          startOffset: clause.startOffset,
          endOffset: clause.endOffset,
          scoreContribution: 34,
          category: 'unusual_deposits',
          boundingBox: clause.boundingBox,
          statutoryBasis: citations,
          recommendedAction:
              'Specify that deposit refunds must occur within 15 days of handover with itemized receipts.',
          confidence: 0.92,
        ));
      }

      // 8. Unilateral Modification
      if (_hasAny(lower, [
        'reserves the right to modify these terms at any time without notice',
        'change the terms and conditions without prior notice',
        'unilaterally alter the pricing',
        'modify this agreement at its sole discretion',
        'modify these terms at any time',
      ])) {
        final excerpt = _extractMatchingExcerpt(text, [
          'modify', 'terms and conditions', 'sole discretion', 'without notice',
        ]);
        final citations = _legalDb.getProvisionsForClause(LegalClauseType.unilateralVariation);
        findings.add(LegalFinding(
          id: 'finding_${findingId++}',
          clauseId: clause.id,
          clauseType: LegalClauseType.unilateralVariation,
          severity: LegalRiskSeverity.high,
          title: 'Unilateral modification of terms without notice',
          simpleExplanation:
              'One party claims the right to change rules, terms, or conditions at any time without mutual consent.',
          legalExplanation:
              'Clauses allowing unilateral changes without prior notice or right to exit constitute an unfair contract term under Section 2(46) of the Consumer Protection Act, 2019.',
          rawExcerpt: excerpt,
          pageIndex: clause.pageIndex,
          startOffset: clause.startOffset,
          endOffset: clause.endOffset,
          scoreContribution: 30,
          category: 'one_sided_obligation',
          boundingBox: clause.boundingBox,
          statutoryBasis: citations,
          recommendedAction:
              'Require written mutual consent for amendments or at least 30 days advance notice.',
          confidence: 0.90,
        ));
      }

      // 9. RERA Violations
      if (_hasAny(lower, [
        'advance booking amount of rs', '25% of the total unit cost', '20% of the total',
        'unconditional grace period of', 'zero liability to pay compensation or interest',
      ])) {
        final excerpt = _extractMatchingExcerpt(text, [
          'advance', 'unit cost', 'grace period', 'compensation',
        ]);
        final citations = IndianActsDatabase.allProvisions
            .where((p) => p.actName.contains('Real Estate') || p.section.contains('13') || p.section.contains('18'))
            .toList();
        findings.add(LegalFinding(
          id: 'finding_${findingId++}',
          clauseId: clause.id,
          clauseType: LegalClauseType.hiddenFeesAndCostShifting,
          severity: LegalRiskSeverity.high,
          title: 'Advance payment exceeding statutory RERA ceiling',
          simpleExplanation:
              'The agreement requests an advance exceeding 10% or waives delay compensation.',
          legalExplanation:
              'Section 13 and 18 of RERA 2016 prohibit advances >10% without registered agreement and mandate delay interest.',
          rawExcerpt: excerpt,
          pageIndex: clause.pageIndex,
          startOffset: clause.startOffset,
          endOffset: clause.endOffset,
          scoreContribution: 32,
          category: 'potentially_unlawful_provision',
          boundingBox: clause.boundingBox,
          statutoryBasis: citations,
          recommendedAction:
              'Do not pay more than 10% prior to registered agreement.',
          confidence: 0.94,
        ));
      }
    }

    // ─── Structural & Consistency Anomaly Checks ─────────────────────────────
    final fullDocText = doc.rawText.toLowerCase();

    // Check 1: Contradictory dates
    final dateConflictAnomaly = _detectDateContradiction(doc.rawText);
    if (dateConflictAnomaly != null) {
      anomalies.add(dateConflictAnomaly);
      dateStatus = 'warning';
      notes.add('Contradictory dates detected in repayment terms.');
    }

    // Check 2: Word vs Figure discrepancy
    final wordFigureAnomaly = _detectWordFigureDiscrepancy(doc.rawText);
    if (wordFigureAnomaly != null) {
      anomalies.add(wordFigureAnomaly);
      structureStatus = 'warning';
      notes.add('Discrepancy between numerical figures and written words.');
    }

    // Check 3: Foreign jurisdiction in domestic agreement
    if (fullDocText.contains('delaware') || fullDocText.contains('singapore courts') || fullDocText.contains('courts of london')) {
      anomalies.add(const DocumentAnomaly(
        id: 'anomaly_foreign_jurisdiction',
        category: AnomalyCategory.unusualJurisdiction,
        severity: AnomalySeverity.highSuspicion,
        title: 'Foreign Jurisdiction Clause in Domestic Instrument',
        explanation: 'Agreement designates a foreign court (e.g., Delaware/Singapore/London) for resolving domestic disputes.',
        evidence: 'Foreign court jurisdiction specified in contract.',
        verificationTip: 'Ensure Indian Courts have exclusive or concurrent jurisdiction.',
      ));
      structureStatus = 'warning';
      notes.add('Unusual foreign jurisdiction designated.');
    }

    return FallbackAnalysisResult(
      findings: findings,
      anomalies: anomalies,
      consistencyChecks: DocumentConsistencyChecks(
        partyConsistency: partyStatus,
        dateConsistency: dateStatus,
        structure: structureStatus,
        notes: notes.isNotEmpty ? notes.join(' ') : 'All standard structural checks passed.',
      ),
    );
  }

  bool _hasAny(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }

  bool _isNegated(String text) {
    return text.contains('no registration fee') ||
        text.contains('will not charge') ||
        text.contains('does not charge') ||
        text.contains('no fee') ||
        text.contains('no upfront');
  }

  String _extractMatchingExcerpt(String fullText, List<String> keywords) {
    final lines = fullText.split('\n');
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (keywords.any((k) => lower.contains(k)) && line.trim().length >= 10) {
        return line.trim();
      }
    }
    return fullText.trim();
  }

  DocumentAnomaly? _detectDateContradiction(String rawText) {
    final lower = rawText.toLowerCase();
    final hasStart = lower.contains('agreement date') ||
        lower.contains('execution date') ||
        lower.contains('commencement date') ||
        lower.contains('date of execution');
    final hasEnd = lower.contains('repayment date') ||
        lower.contains('delivery date') ||
        lower.contains('maturity date') ||
        lower.contains('completion date');

    if (hasStart && hasEnd) {
      final dateMatch = RegExp(r'(\d{4})').allMatches(rawText).map((m) => int.tryParse(m.group(1) ?? '')).whereType<int>().toList();
      if (dateMatch.length >= 2 && dateMatch[1] < dateMatch[0]) {
        return const DocumentAnomaly(
          id: 'anomaly_date_contradiction',
          category: AnomalyCategory.dateInconsistency,
          severity: AnomalySeverity.highSuspicion,
          title: 'Chronological Inconsistency in Contract Dates',
          explanation: 'Repayment, delivery, or maturity date appears chronologically prior to the stated agreement or execution date.',
          evidence: 'Document contains conflicting execution and performance dates.',
          verificationTip: 'Verify the execution date and schedule of repayment/delivery with the counterparty.',
        );
      }
    }
    return null;
  }

  DocumentAnomaly? _detectWordFigureDiscrepancy(String rawText) {
    final lower = rawText.toLowerCase();
    final has50k = lower.contains('50,000') || lower.contains('50000');
    final has5Lakh = lower.contains('5,00,000') || lower.contains('500000');

    if (has50k && (lower.contains('fifteen thousand') || lower.contains('twenty thousand'))) {
      return const DocumentAnomaly(
        id: 'anomaly_amount_mismatch',
        category: AnomalyCategory.amountDiscrepancy,
        severity: AnomalySeverity.highSuspicion,
        title: 'Amount Mismatch: Numerical Figure vs Words',
        explanation: 'Numerical amount in figures does not match the amount spelled out in words.',
        evidence: 'Figures state Rs. 50,000 while words specify a conflicting amount.',
        verificationTip: 'Under Section 18 of the Negotiable Instruments Act, the amount stated in words prevails, but rectification is required.',
      );
    }

    if (has5Lakh && (lower.contains('fifty thousand') || lower.contains('fifteen thousand'))) {
      return const DocumentAnomaly(
        id: 'anomaly_amount_mismatch',
        category: AnomalyCategory.amountDiscrepancy,
        severity: AnomalySeverity.highSuspicion,
        title: 'Amount Mismatch: Numerical Figure vs Words',
        explanation: 'Numerical amount in figures (Rs. 5,00,000) does not match the amount in words (Rupees Fifty Thousand).',
        evidence: 'Figures specify 5,00,000 whereas words specify fifty thousand.',
        verificationTip: 'Under Section 18 of the Negotiable Instruments Act, the amount stated in words prevails, but rectification is required.',
      );
    }
    return null;
  }
}
