import '../models/legal_clause.dart';
import '../models/legal_finding.dart';

class IndianActsDatabase {
  /// Comprehensive offline dictionary of Indian statutory provisions mapped to clause types.
  static final List<StatutoryCitation> statutoryProvisions = [
    // ─── Indian Contract Act, 1872 ──────────────────────────────────────────
    const StatutoryCitation(
      actName: 'Indian Contract Act, 1872',
      section: 'Section 27',
      title: 'Agreement in Restraint of Trade Void',
      description:
          'Every agreement by which any one is restrained from exercising a lawful profession, trade or business of any kind, is to that extent void. Post-employment non-compete restrictions are generally unenforceable under Indian Law (Percept D\'Mark v. Zaheer Khan, Supreme Court).',
      officialSourceUrl: 'https://www.indiacode.nic.in/handle/123456789/2187',
      isEnforceableInIndia: true,
    ),
    const StatutoryCitation(
      actName: 'Indian Contract Act, 1872',
      section: 'Section 28',
      title: 'Agreements in Restraint of Legal Proceedings Void',
      description:
          'Every agreement which restricts a party absolutely from enforcing rights by usual legal proceedings in ordinary tribunals, or which limits the time to enforce rights, is void.',
      officialSourceUrl: 'https://www.indiacode.nic.in/handle/123456789/2187',
      isEnforceableInIndia: true,
    ),
    const StatutoryCitation(
      actName: 'Indian Contract Act, 1872',
      section: 'Section 74',
      title: 'Compensation for Breach where Penalty Stipulated',
      description:
          'When a contract is breached with a stipulated penalty, the party complaining of the breach is entitled to receive reasonable compensation not exceeding the penalty amount. Courts will not enforce exorbitant or punitive damages beyond actual proven loss (Fateh Chand v. Balkishan Das).',
      officialSourceUrl: 'https://www.indiacode.nic.in/handle/123456789/2187',
      isEnforceableInIndia: true,
    ),
    const StatutoryCitation(
      actName: 'Indian Contract Act, 1872',
      section: 'Section 23',
      title: 'What Considerations and Objects are Lawful',
      description:
          'The consideration or object of an agreement is unlawful if it is forbidden by law, defeats the provisions of any law, or is fraudulent, or the Court regards it as immoral or opposed to public policy.',
      officialSourceUrl: 'https://www.indiacode.nic.in/handle/123456789/2187',
      isEnforceableInIndia: true,
    ),

    // ─── Consumer Protection Act, 2019 ───────────────────────────────────────
    const StatutoryCitation(
      actName: 'Consumer Protection Act, 2019',
      section: 'Section 2(46)',
      title: 'Unfair Contract Terms',
      description:
          'A contract between a manufacturer or service provider and a consumer having terms which cause significant change in the rights of the consumer, including demanding excessive security deposits, imposing disproportionate penalties, or terminating contract unilaterally without reasonable cause.',
      officialSourceUrl: 'https://www.indiacode.nic.in/handle/123456789/15256',
      isEnforceableInIndia: true,
    ),
    const StatutoryCitation(
      actName: 'Consumer Protection Act, 2019',
      section: 'Section 2(47)',
      title: 'Unfair Trade Practices',
      description:
          'Prohibits deceptive trade practices, including hidden charges, misleading pricing descriptions, and arbitrary forfeiture of consideration paid by consumers.',
      officialSourceUrl: 'https://www.indiacode.nic.in/handle/123456789/15256',
      isEnforceableInIndia: true,
    ),

    // ─── Model Tenancy Act / Rent Control ───────────────────────────────────
    const StatutoryCitation(
      actName: 'Model Tenancy Act, 2021',
      section: 'Section 11 & Section 21',
      title: 'Security Deposit Ceiling and Eviction Protections',
      description:
          'Security deposit for residential premises shall not exceed two months\' rent. Landlords cannot arbitrarily increase rent during the tenancy period or evict tenants without written notice through the Rent Court.',
      officialSourceUrl: 'https://mohua.gov.in/upload/uploadfiles/files/Model_Tenancy_Act_English.pdf',
      isEnforceableInIndia: true,
    ),

    // ─── Real Estate (Regulation and Development) Act, 2016 (RERA) ───────────
    const StatutoryCitation(
      actName: 'Real Estate (Regulation and Development) Act, 2016',
      section: 'Section 13 & Section 18',
      title: 'Standard Agreement for Sale & Compensation for Delay',
      description:
          'Promoters cannot accept more than 10% of the apartment cost without entering into a registered agreement for sale. If promoter fails to hand over possession by the agreed date, buyer has absolute right to refund with interest.',
      officialSourceUrl: 'https://www.indiacode.nic.in/handle/123456789/2158',
      isEnforceableInIndia: true,
    ),

    // ─── Information Technology Act, 2000 ────────────────────────────────────
    const StatutoryCitation(
      actName: 'Information Technology Act, 2000',
      section: 'Section 43A & Section 72A',
      title: 'Protection of Sensitive Personal Data',
      description:
          'Bodies corporate possessing sensitive personal data must maintain reasonable security practices. Unauthorized disclosure of confidential data in breach of contract attracts civil and criminal penalties.',
      officialSourceUrl: 'https://www.indiacode.nic.in/handle/123456789/1999',
      isEnforceableInIndia: true,
    ),

    // ─── Specific Relief Act, 1963 ──────────────────────────────────────────
    const StatutoryCitation(
      actName: 'Specific Relief Act, 1963',
      section: 'Section 14(c) & Section 41(e)',
      title: 'Contracts not Specifically Enforceable',
      description:
          'A contract which is in its nature determinable (can be ended by notice) cannot be specifically enforced by demanding perpetual performance, nor can an injunction be granted to prevent the breach of a contract whose performance cannot be compelled.',
      officialSourceUrl: 'https://www.indiacode.nic.in/handle/123456789/2180',
      isEnforceableInIndia: true,
    ),
  ];

  /// Finds relevant Indian legislative provisions for a given clause type.
  static List<StatutoryCitation> getProvisionsForClause(LegalClauseType type) {
    switch (type) {
      case LegalClauseType.nonCompeteRestraint:
        return statutoryProvisions.where((p) => p.section.contains('27')).toList();
      case LegalClauseType.penaltyAndDamages:
      case LegalClauseType.securityDepositForfeiture:
        return statutoryProvisions.where((p) => p.section.contains('74') || p.section.contains('2(46)') || p.actName.contains('Tenancy')).toList();
      case LegalClauseType.unilateralTermination:
      case LegalClauseType.unilateralVariation:
        return statutoryProvisions.where((p) => p.section.contains('2(46)') || p.actName.contains('Specific Relief')).toList();
      case LegalClauseType.arbitrationAndJurisdiction:
      case LegalClauseType.waiverOfRights:
        return statutoryProvisions.where((p) => p.section.contains('28') || p.section.contains('23')).toList();
      case LegalClauseType.hiddenFeesAndCostShifting:
        return statutoryProvisions.where((p) => p.section.contains('2(47)') || p.actName.contains('RERA')).toList();
      case LegalClauseType.confidentialityOverreach:
        return statutoryProvisions.where((p) => p.actName.contains('Information Technology') || p.section.contains('27')).toList();
      case LegalClauseType.upfrontFeeScam:
        return statutoryProvisions.where((p) => p.section.contains('23') || p.actName.contains('Consumer Protection')).toList();
      case LegalClauseType.predatoryInterestRate:
        return statutoryProvisions.where((p) => p.section.contains('74') || p.actName.contains('Consumer Protection')).toList();
      case LegalClauseType.restraintOfLegalRecourse:
        return statutoryProvisions.where((p) => p.section.contains('28')).toList();
      default:
        return statutoryProvisions.where((p) => p.actName.contains('Indian Contract Act')).toList();
    }
  }
}
