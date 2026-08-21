/// Classification of clauses analyzed in legal documents.
enum LegalClauseType {
  penaltyAndDamages,
  nonCompeteRestraint,
  unilateralTermination,
  unlimitedIndemnity,
  arbitrationAndJurisdiction,
  hiddenFeesAndCostShifting,
  automaticRenewal,
  confidentialityOverreach,
  waiverOfRights,
  unilateralVariation,
  securityDepositForfeiture,
  intellectualPropertyAssignment,
  missingStandardProtection,
  upfrontFeeScam,
  predatoryInterestRate,
  restraintOfLegalRecourse,
  generalObligation,
}

extension LegalClauseTypeExt on LegalClauseType {
  String get displayName {
    switch (this) {
      case LegalClauseType.penaltyAndDamages:
        return 'Disproportionate Penalty / Liquidated Damages';
      case LegalClauseType.nonCompeteRestraint:
        return 'Post-Termination Restraint / Non-Compete (Sec 27)';
      case LegalClauseType.unilateralTermination:
        return 'One-Sided / Immediate Termination';
      case LegalClauseType.unlimitedIndemnity:
        return 'Expansive / Unlimited Indemnification';
      case LegalClauseType.arbitrationAndJurisdiction:
        return 'Exclusive Jurisdiction / Onerous Arbitration';
      case LegalClauseType.hiddenFeesAndCostShifting:
        return 'Hidden Charges / Unilateral Fee Escalation';
      case LegalClauseType.automaticRenewal:
        return 'Auto-Renewal / Lock-in Period';
      case LegalClauseType.confidentialityOverreach:
        return 'Overbroad Confidentiality / NDA Scope';
      case LegalClauseType.waiverOfRights:
        return 'Waiver of Statutory Claims & Remedies';
      case LegalClauseType.unilateralVariation:
        return 'Unilateral Modification of Terms';
      case LegalClauseType.securityDepositForfeiture:
        return 'Arbitrary Deposit Deductions / Forfeiture';
      case LegalClauseType.intellectualPropertyAssignment:
        return 'Broad Pre-existing IP Assignment';
      case LegalClauseType.missingStandardProtection:
        return 'Missing Standard Legal Protection';
      case LegalClauseType.upfrontFeeScam:
        return '🚨 Upfront Fee / Deposit Scam Trap';
      case LegalClauseType.predatoryInterestRate:
        return '⚠️ Predatory / Usurious Interest Rate Trap';
      case LegalClauseType.restraintOfLegalRecourse:
        return '⚖️ Void Restraint of Legal Recourse (Sec 28)';
      case LegalClauseType.generalObligation:
        return 'General Contractual Obligation';
    }
  }

  String get categoryIcon {
    switch (this) {
      case LegalClauseType.penaltyAndDamages: return '💸';
      case LegalClauseType.nonCompeteRestraint: return '🚫';
      case LegalClauseType.unilateralTermination: return '🚪';
      case LegalClauseType.unlimitedIndemnity: return '🛡️';
      case LegalClauseType.arbitrationAndJurisdiction: return '⚖️';
      case LegalClauseType.hiddenFeesAndCostShifting: return '🔍';
      case LegalClauseType.automaticRenewal: return '🔄';
      case LegalClauseType.confidentialityOverreach: return '🤫';
      case LegalClauseType.waiverOfRights: return '⚠️';
      case LegalClauseType.unilateralVariation: return '📝';
      case LegalClauseType.securityDepositForfeiture: return '💰';
      case LegalClauseType.intellectualPropertyAssignment: return '💡';
      case LegalClauseType.missingStandardProtection: return '🛡️';
      case LegalClauseType.upfrontFeeScam: return '🚨';
      case LegalClauseType.predatoryInterestRate: return '📈';
      case LegalClauseType.restraintOfLegalRecourse: return '⚖️';
      case LegalClauseType.generalObligation: return '📄';
    }
  }
}
