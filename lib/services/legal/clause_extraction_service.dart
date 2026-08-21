import '../../core/legal/constants/indian_acts_database.dart';
import '../../core/legal/models/legal_clause.dart';
import '../../core/legal/models/legal_finding.dart';
import '../../core/legal/models/ocr_document.dart';

class ClauseExtractionService {
  /// Extracts risky, illegal, and scam clauses from an OcrDocument deterministically
  /// and calculates exact bounding box coordinates.
  List<LegalFinding> extractFindings(OcrDocument doc) {
    final findings = <LegalFinding>[];
    int findingCounter = 1;

    for (final page in doc.pages) {
      for (final line in page.lines) {
        final text = line.text;
        final lower = text.toLowerCase();

        // 1. 🚨 Upfront Fee / Scam Demands
        if (_hasAny(lower, [
          'registration fee of rs', 'processing fee of rs', 'security deposit for job',
          'pay advance amount of', 'refundable registration fee', 'processing charge of inr',
          'training fee to be deposited', 'deposit rs', 'deposit inr', 'upfront payment of',
          'pay before interview', 'registration charges',
        ])) {
          findings.add(LegalFinding(
            id: 'clause_scam_upfront_${findingCounter++}',
            clauseType: LegalClauseType.upfrontFeeScam,
            severity: LegalRiskSeverity.high,
            title: '🚨 Scam Alert: Upfront Recruitment / Processing Fee Demand',
            simpleExplanation:
                'Demanding upfront payments, "refundable" training fees, or security deposits before job employment, loan release, or verification is a severe scam indicator.',
            legalExplanation:
                'Ministry of Labour and RBI advisories prohibit charging candidates or applicants upfront recruitment/processing fees. Such practices constitute cheating and fraud under BNS Sec 318 / IPC Sec 420.',
            rawExcerpt: text,
            pageIndex: page.pageIndex,
            boundingBox: line.boundingBox,
            statutoryBasis: IndianActsDatabase.getProvisionsForClause(LegalClauseType.upfrontFeeScam),
            recommendedAction:
                'DO NOT make any upfront payment. Verify the organization on the official MCA / Government portal.',
            confidence: 0.96,
          ));
        }

        // 2. ⚖️ Void Restraint of Legal Recourse (Sec 28)
        else if (_hasAny(lower, [
          'waives the right to approach any court', 'shall not file any complaint in consumer',
          'no legal action shall lie against', 'no jurisdiction of any court', 'waives all rights to file suit',
          'cannot approach consumer court', 'shall not initiate legal proceedings',
        ])) {
          findings.add(LegalFinding(
            id: 'clause_restraint_recourse_${findingCounter++}',
            clauseType: LegalClauseType.restraintOfLegalRecourse,
            severity: LegalRiskSeverity.high,
            title: '⚖️ Void Term: Restraint of Legal Recourse (Sec 28)',
            simpleExplanation:
                'This statement attempts to prevent you from going to court or Consumer Forum if there is a dispute. This restriction is 100% void under Indian Law.',
            legalExplanation:
                'Section 28 of the Indian Contract Act, 1872 renders agreements in restraint of legal proceedings void ab initio. Any attempt to strip a consumer of their statutory right to legal remedies is invalid.',
            rawExcerpt: text,
            pageIndex: page.pageIndex,
            boundingBox: line.boundingBox,
            statutoryBasis: IndianActsDatabase.getProvisionsForClause(LegalClauseType.restraintOfLegalRecourse),
            recommendedAction:
                'Insist on striking out this clause; legally you cannot be barred from approaching a competent Indian court or forum.',
            confidence: 0.95,
          ));
        }

        // 3. Non-compete / Restraint of Trade (Sec 27)
        else if (_hasAny(lower, [
          'non-compete', 'not engage in any competing', 'shall not work for any competitor',
          'restrained from working', 'restraint of trade', 'not join any competitor for a period of',
          'prohibited from competing', 'shall not solicit or work with competitor',
        ])) {
          findings.add(LegalFinding(
            id: 'clause_non_compete_${findingCounter++}',
            clauseType: LegalClauseType.nonCompeteRestraint,
            severity: LegalRiskSeverity.high,
            title: 'Post-Employment Non-Compete Restraint (Sec 27 Void)',
            simpleExplanation:
                'This clause attempts to stop you from working for a competing business or starting your own company after leaving. Under Indian Law, post-employment non-compete clauses are generally void and unenforceable.',
            legalExplanation:
                'Section 27 of the Indian Contract Act, 1872 invalidates any agreement that restrains anyone from exercising a lawful profession, trade, or business (Percept D\'Mark v. Zaheer Khan, Supreme Court).',
            rawExcerpt: text,
            pageIndex: page.pageIndex,
            boundingBox: line.boundingBox,
            statutoryBasis: IndianActsDatabase.getProvisionsForClause(LegalClauseType.nonCompeteRestraint),
            recommendedAction:
                'Request removal of this post-termination restraint or seek written clarification that lawful career mobility is protected.',
            confidence: 0.95,
          ));
        }

        // 4. Disproportionate Penalty / Liquidated Damages (Sec 74)
        else if (_hasAny(lower, [
          'penalty of rs', 'penalty of inr', 'liquidated damages of', 'pay a penalty of',
          'forfeit the entire deposit', 'forfeit 100%', 'penalty equal to', 'deduct 100% of',
          'penalty of 18%', 'penalty of 24%', 'interest @ 24%', 'interest at 36%',
          '24% प्रति वर्ष', 'जुर्माना 10,000',
        ])) {
          findings.add(LegalFinding(
            id: 'clause_penalty_${findingCounter++}',
            clauseType: LegalClauseType.penaltyAndDamages,
            severity: LegalRiskSeverity.high,
            title: 'Disproportionate Penalty / Damages Clause',
            simpleExplanation:
                'This clause imposes a severe financial penalty or high interest rate if a dispute or delay occurs. In India, a party cannot charge arbitrary punitive penalties and can only claim reasonable actual losses.',
            legalExplanation:
                'Section 74 of the Indian Contract Act, 1872 provides that where a contract names a penalty for breach, the aggrieved party is only entitled to "reasonable compensation" (Fateh Chand v. Balkishan Das).',
            rawExcerpt: text,
            pageIndex: page.pageIndex,
            boundingBox: line.boundingBox,
            statutoryBasis: IndianActsDatabase.getProvisionsForClause(LegalClauseType.penaltyAndDamages),
            recommendedAction:
                'Negotiate to cap any damages to actual proven financial loss rather than pre-fixed excessive penalties.',
            confidence: 0.92,
          ));
        }

        // 5. 📈 Predatory / Usurious Interest Rates
        else if (_hasAny(lower, [
          'interest @ 36%', 'interest of 36%', 'interest at 36%', 'interest @ 48%',
          'penalty of 2% per day', 'penalty of 1% per day', 'interest of 24% per year',
          'penalty plus 24%',
        ])) {
          findings.add(LegalFinding(
            id: 'clause_predatory_interest_${findingCounter++}',
            clauseType: LegalClauseType.predatoryInterestRate,
            severity: LegalRiskSeverity.high,
            title: '⚠️ Predatory / High Interest Rate Penalty Trap',
            simpleExplanation:
                'This statement imposes an excessive interest rate (e.g. 24%-36%+) or compounding daily penalties that can exponentially multiply financial liabilities.',
            legalExplanation:
                'Under the Usurious Loans Act, 1918 and Section 74 of the Indian Contract Act, excessive penal interest is treated as punitive rather than compensatory, and Indian courts routinely strike down unconscionable rates.',
            rawExcerpt: text,
            pageIndex: page.pageIndex,
            boundingBox: line.boundingBox,
            statutoryBasis: IndianActsDatabase.getProvisionsForClause(LegalClauseType.predatoryInterestRate),
            recommendedAction:
                'Negotiate interest/penalty down to standard commercial rates (maximum 8-12% p.a.) and remove daily compounding multipliers.',
            confidence: 0.94,
          ));
        }

        // 6. Unilateral / Immediate Termination
        else if (_hasAny(lower, [
          'terminate immediately without notice', 'terminate without cause with immediate effect',
          'right to terminate at will without notice', 'terminate without any reason or liability',
          'sole discretion to terminate immediately', 'अधिकार सुरक्षित रखता है बिना किसी पूर्व सूचना',
          'बिना किसी पूर्व सूचना या कारण',
        ])) {
          findings.add(LegalFinding(
            id: 'clause_unilateral_term_${findingCounter++}',
            clauseType: LegalClauseType.unilateralTermination,
            severity: LegalRiskSeverity.high,
            title: 'Unilateral Immediate Termination Trap',
            simpleExplanation:
                'The other party reserves the right to cancel the agreement immediately without prior notice or cause, creating severe one-sided vulnerability.',
            legalExplanation:
                'One-sided termination terms without mutual rights or cure periods may be declared an "Unfair Contract" under Section 2(46) of the Consumer Protection Act, 2019.',
            rawExcerpt: text,
            pageIndex: page.pageIndex,
            boundingBox: line.boundingBox,
            statutoryBasis: IndianActsDatabase.getProvisionsForClause(LegalClauseType.unilateralTermination),
            recommendedAction:
                'Ensure mutual notice periods (e.g. 30 days written notice) and a 15-day cure period before any termination.',
            confidence: 0.91,
          ));
        }

        // 7. Unlimited Indemnity
        else if (_hasAny(lower, [
          'indemnify and hold harmless against all', 'indemnify for any and all claims',
          'unlimited indemnification', 'indemnify regardless of negligence', 'indemnify for all losses whatsoever',
        ])) {
          findings.add(LegalFinding(
            id: 'clause_indemnity_${findingCounter++}',
            clauseType: LegalClauseType.unlimitedIndemnity,
            severity: LegalRiskSeverity.high,
            title: 'Expansive Unlimited Indemnity Clause',
            simpleExplanation:
                'You could be forced to pay for legal fees or losses even in situations where you did not directly cause the problem.',
            legalExplanation:
                'Broad indemnity obligations without liability caps or exclusions for gross negligence transfer uncapped commercial risk to one party under Section 73 of the Indian Contract Act.',
            rawExcerpt: text,
            pageIndex: page.pageIndex,
            boundingBox: line.boundingBox,
            statutoryBasis: IndianActsDatabase.getProvisionsForClause(LegalClauseType.unlimitedIndemnity),
            recommendedAction:
                'Insert a liability cap (e.g. total fees paid in last 6 months) and exclude indirect or consequential damages.',
            confidence: 0.90,
          ));
        }

        // 8. Unilateral Modification
        else if (_hasAny(lower, [
          'reserves the right to modify these terms at any time without notice',
          'change the terms and conditions without prior notice',
          'unilaterally alter the pricing', 'modify this agreement at its sole discretion',
        ])) {
          findings.add(LegalFinding(
            id: 'clause_unilateral_var_${findingCounter++}',
            clauseType: LegalClauseType.unilateralVariation,
            severity: LegalRiskSeverity.medium,
            title: 'Unilateral Modification of Terms',
            simpleExplanation:
                'The provider claims the right to change rules, prices, or conditions at any time without your consent.',
            legalExplanation:
                'Clauses allowing unilateral changes without prior notice or right to exit constitute an unfair trade practice under Section 2(46) of the Consumer Protection Act, 2019.',
            rawExcerpt: text,
            pageIndex: page.pageIndex,
            boundingBox: line.boundingBox,
            statutoryBasis: IndianActsDatabase.getProvisionsForClause(LegalClauseType.unilateralVariation),
            recommendedAction:
                'Require written mutual consent for amendments or at least 30 days advance notice with option to exit without penalty.',
            confidence: 0.89,
          ));
        }

        // 9. Arbitrary Security Deposit Deductions
        else if (_hasAny(lower, [
          'deposit is strictly non-refundable', 'security deposit will not be refunded',
          'forfeit entire deposit in event of', 'forfeit security deposit without inquiry',
          'सुरक्षा जमा राशि है 2,50,000', 'सुरक्षा जमा राशि',
        ])) {
          findings.add(LegalFinding(
            id: 'clause_deposit_${findingCounter++}',
            clauseType: LegalClauseType.securityDepositForfeiture,
            severity: LegalRiskSeverity.high,
            title: 'Arbitrary Deposit Forfeiture / High Deposit Risk',
            simpleExplanation:
                'The agreement demands a very large security deposit or declares deposits non-refundable without proof of verifiable damage.',
            legalExplanation:
                'Under the Model Tenancy Act, 2021 (Sec 11) and Section 74 of the Contract Act, security deposits are held in trust and must be refunded upon handover minus actual verifiable repair expenses with receipts.',
            rawExcerpt: text,
            pageIndex: page.pageIndex,
            boundingBox: line.boundingBox,
            statutoryBasis: IndianActsDatabase.getProvisionsForClause(LegalClauseType.securityDepositForfeiture),
            recommendedAction:
                'Specify that deposit refunds must occur within 15 days of handover with itemized receipts for any deductions.',
            confidence: 0.92,
          ));
        }
      }
    }

    return findings;
  }

  bool _hasAny(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }
}
