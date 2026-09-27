import '../models/legal_clause.dart';
import '../models/legal_finding.dart';

class IndianActsDatabase {
  /// Comprehensive authoritative dictionary of Indian statutory provisions currently in active legal force.
  static final List<StatutoryCitation> statutoryProvisions = [
    // ─── Bharatiya Nyaya Sanhita, 2023 (In Force from July 1, 2024 - Replaces IPC) ───
    const StatutoryCitation(
      actName: 'Bharatiya Nyaya Sanhita, 2023 (BNS)',
      section: 'Section 318',
      title: 'Cheating and Dishonestly Inducing Delivery of Property',
      description:
          'Whoever cheats and thereby dishonestly induces the person deceived to deliver any property or make/alter any valuable security. Directly applicable to upfront fee scams, bogus property booking advances, and fraudulent registration fee traps (replaces former Section 420 IPC).',
      officialSourceUrl: 'https://www.indiacode.nic.in/handle/123456789/21808',
      isEnforceableInIndia: true,
    ),
    const StatutoryCitation(
      actName: 'Bharatiya Nyaya Sanhita, 2023 (BNS)',
      section: 'Section 316',
      title: 'Criminal Breach of Trust',
      description:
          'Punishes dishonestly misappropriating or converting to one\'s own use property entrusted to them, or dishonestly using/disposing of that property in violation of any legal contract. Applicable to arbitrary forfeiture of tenant security deposits and builder escrow fund diversions.',
      officialSourceUrl: 'https://www.indiacode.nic.in/handle/123456789/21808',
      isEnforceableInIndia: true,
    ),
    const StatutoryCitation(
      actName: 'Bharatiya Nyaya Sanhita, 2023 (BNS)',
      section: 'Section 336 & Section 338',
      title: 'Forgery of Valuable Security or Agreement',
      description:
          'Criminalizes making false documents, altered deeds, or forged signatures intended to create legal rights or cause wrongful loss in property conveyance or tenancy.',
      officialSourceUrl: 'https://www.indiacode.nic.in/handle/123456789/21808',
      isEnforceableInIndia: true,
    ),
    const StatutoryCitation(
      actName: 'Bharatiya Nyaya Sanhita, 2023 (BNS)',
      section: 'Section 308',
      title: 'Extortion and Coercive Contractual Penalty Demands',
      description:
          'Punishes intentionally putting any person in fear of any injury to that person or to any other, and thereby dishonestly inducing the person so put in fear to deliver any property or valuable security. Applies to predatory lenders and landlords enforcing coercive confiscations.',
      officialSourceUrl: 'https://www.indiacode.nic.in/handle/123456789/21808',
      isEnforceableInIndia: true,
    ),

    // ─── Digital Personal Data Protection Act, 2023 (DPDP Act) ─────────────────
    const StatutoryCitation(
      actName: 'Digital Personal Data Protection Act, 2023',
      section: 'Section 6 & Section 8',
      title: 'Consent Architecture & Data Fiduciary Obligations',
      description:
          'Data Fiduciaries must give clear notice specifying purpose and categories of personal data processed. Unilateral, indefinite, or overbroad data tracking and non-consensual sharing in contracts attracts statutory penalties up to ₹250 Crore under the DPDP Act.',
      officialSourceUrl: 'https://www.indiacode.nic.in/handle/123456789/20563',
      isEnforceableInIndia: true,
    ),

    // ─── Bharatiya Sakshya Adhiniyam, 2023 (BSA) (Replaces Indian Evidence Act) ─
    const StatutoryCitation(
      actName: 'Bharatiya Sakshya Adhiniyam, 2023 (BSA)',
      section: 'Section 61 & Section 63',
      title: 'Admissibility of Electronic Agreements & Digital Signatures',
      description:
          'Recognizes electronic agreements, digital signatures, and electronic audit trails as primary/secondary evidence in courts, provided integrity criteria and digital certification standards are maintained.',
      officialSourceUrl: 'https://www.indiacode.nic.in/handle/123456789/21810',
      isEnforceableInIndia: true,
    ),

    // ─── Model Tenancy Act, 2021 & State Tenancy Acts ──────────────────────────
    const StatutoryCitation(
      actName: 'Model Tenancy Act, 2021',
      section: 'Section 11',
      title: 'Ceiling on Security Deposit (Max 2 Months Rent)',
      description:
          'The security deposit to be paid by the tenant in advance for residential premises shall not exceed two months\' rent, and for non-residential premises shall not exceed six months\' rent. Any clause demanding 6 to 10 months advance for residential housing violates statutory guidelines.',
      officialSourceUrl: 'https://mohua.gov.in/upload/uploadfiles/files/Model_Tenancy_Act_English.pdf',
      isEnforceableInIndia: true,
    ),
    const StatutoryCitation(
      actName: 'Model Tenancy Act, 2021',
      section: 'Section 20 & Section 21',
      title: 'Prohibition on Severing Essential Services & Eviction Safeguards',
      description:
          'Landlord or property manager cannot withhold or cut essential supply (water, electricity) even during rent disputes. Eviction can only occur pursuant to an order of the Rent Court upon statutory grounds.',
      officialSourceUrl: 'https://mohua.gov.in/upload/uploadfiles/files/Model_Tenancy_Act_English.pdf',
      isEnforceableInIndia: true,
    ),
    const StatutoryCitation(
      actName: 'Model Tenancy Act, 2021',
      section: 'Section 22',
      title: 'Mandatory 24-Hour Prior Notice Before Landlord Entry',
      description:
          'Landlord or property manager cannot enter the rented premises without giving at least 24 hours prior written notice (via electronic mail or SMS/messaging) and can only enter between 7:00 AM and 8:00 PM for legitimate inspection or repair.',
      officialSourceUrl: 'https://mohua.gov.in/upload/uploadfiles/files/Model_Tenancy_Act_English.pdf',
      isEnforceableInIndia: true,
    ),

    // ─── Real Estate (Regulation and Development) Act, 2016 (RERA) ─────────────
    const StatutoryCitation(
      actName: 'Real Estate (Regulation and Development) Act, 2016',
      section: 'Section 13',
      title: 'No Deposit / Advance Exceeding 10% Without Registered Agreement',
      description:
          'A promoter/builder cannot accept a sum more than ten percent of the cost of the apartment, plot, or building as an advance payment or an application fee without first entering into a registered written agreement for sale.',
      officialSourceUrl: 'https://www.indiacode.nic.in/handle/123456789/2158',
      isEnforceableInIndia: true,
    ),
    const StatutoryCitation(
      actName: 'Real Estate (Regulation and Development) Act, 2016',
      section: 'Section 18',
      title: 'Return of Amount and Compensation for Delayed Possession',
      description:
          'If the promoter fails to complete or is unable to give possession in accordance with the terms of agreement, the allottee has an unqualified statutory right to a full refund with interest (SBI MCLR + 2%) or monthly interest for each month of delay.',
      officialSourceUrl: 'https://www.indiacode.nic.in/handle/123456789/2158',
      isEnforceableInIndia: true,
    ),

    // ─── Registration Act, 1908 & Transfer of Property Act, 1882 ───────────────
    const StatutoryCitation(
      actName: 'Registration Act, 1908',
      section: 'Section 17(1)(d) & Section 49',
      title: 'Mandatory Registration of Leases Exceeding 11 Months & Property Deeds',
      description:
          'Leases of immovable property exceeding one year or reserving a yearly rent must be registered. Under Section 49, an unregistered document requiring compulsory registration cannot affect the immovable property or be received as evidence of any transaction affecting it.',
      officialSourceUrl: 'https://www.indiacode.nic.in/handle/123456789/2179',
      isEnforceableInIndia: true,
    ),
    const StatutoryCitation(
      actName: 'Transfer of Property Act, 1882',
      section: 'Section 106 & Section 111',
      title: 'Statutory Notice Requirement & Determination of Lease',
      description:
          'Lease from month to month can only be determined by fifteen days\' notice in writing expiring with the end of a month of tenancy. Sudden unilateral lockouts without statutory notice are contrary to law.',
      officialSourceUrl: 'https://www.indiacode.nic.in/handle/123456789/2338',
      isEnforceableInIndia: true,
    ),

    // ─── Consumer Protection Act, 2019 ─────────────────────────────────────────
    const StatutoryCitation(
      actName: 'Consumer Protection Act, 2019',
      section: 'Section 2(46)',
      title: 'Unfair Contract Terms Declared Unenforceable',
      description:
          'Empowers Consumer Commissions to declare void one-sided contracts imposing unreasonable burdens, unilateral termination without reasonable cause, automatic forfeiture of deposit, or disproportionate penalties upon consumers.',
      officialSourceUrl: 'https://www.indiacode.nic.in/handle/123456789/15256',
      isEnforceableInIndia: true,
    ),
    const StatutoryCitation(
      actName: 'Consumer Protection Act, 2019',
      section: 'Section 2(47)',
      title: 'Unfair Trade Practices & Deceptive Charges',
      description:
          'Prohibits deceptive billing, unadvertised fee escalations, hidden ancillary charges, and misleading disclaimers in consumer and commercial transactions.',
      officialSourceUrl: 'https://www.indiacode.nic.in/handle/123456789/15256',
      isEnforceableInIndia: true,
    ),

    // ─── Indian Contract Act, 1872 ────────────────────────────────────────────
    const StatutoryCitation(
      actName: 'Indian Contract Act, 1872',
      section: 'Section 27',
      title: 'Agreement in Restraint of Trade Void',
      description:
          'Every agreement by which anyone is restrained from exercising a lawful profession, trade or business is to that extent void. Post-employment non-competes are unenforceable under Indian law (Supreme Court in Percept D\'Mark v. Zaheer Khan).',
      officialSourceUrl: 'https://www.indiacode.nic.in/handle/123456789/2187',
      isEnforceableInIndia: true,
    ),
    const StatutoryCitation(
      actName: 'Indian Contract Act, 1872',
      section: 'Section 28',
      title: 'Agreements in Restraint of Legal Proceedings Void',
      description:
          'Every agreement which restricts a party absolutely from enforcing legal rights in ordinary tribunals, or which shortens the statutory limitation period, is void ab initio.',
      officialSourceUrl: 'https://www.indiacode.nic.in/handle/123456789/2187',
      isEnforceableInIndia: true,
    ),
    const StatutoryCitation(
      actName: 'Indian Contract Act, 1872',
      section: 'Section 74',
      title: 'Compensation for Breach where Penalty Stipulated',
      description:
          'When a contract is breached with a stipulated penalty, the aggrieved party is entitled only to reasonable compensation not exceeding the penalty amount. Courts refuse to enforce extortionate or punitive damages beyond proven actual loss (Fateh Chand v. Balkishan Das).',
      officialSourceUrl: 'https://www.indiacode.nic.in/handle/123456789/2187',
      isEnforceableInIndia: true,
    ),
    const StatutoryCitation(
      actName: 'Indian Contract Act, 1872',
      section: 'Section 23',
      title: 'Considerations and Objects Unlawful / Against Public Policy',
      description:
          'An agreement whose consideration or object defeats any law, is fraudulent, or is regarded by the Court as unconscionable and opposed to public policy is void (Central Inland Water Transport Corp v. Brojo Nath Ganguly).',
      officialSourceUrl: 'https://www.indiacode.nic.in/handle/123456789/2187',
      isEnforceableInIndia: true,
    ),

    // ─── Arbitration and Conciliation Act, 1996 (with SC Precedents) ───────────
    const StatutoryCitation(
      actName: 'Arbitration and Conciliation Act, 1996',
      section: 'Section 12(5) & Seventh Schedule',
      title: 'Unilateral Appointment of Sole Arbitrator Illegal',
      description:
          'A party having an interest in the dispute or its affiliate cannot unilaterally nominate or appoint the sole arbitrator. The Supreme Court (Perkins Eastman Architects DPC v. HSCC) held that unilateral arbitrator appointment clauses are null and void.',
      officialSourceUrl: 'https://www.indiacode.nic.in/handle/123456789/1978',
      isEnforceableInIndia: true,
    ),
    const StatutoryCitation(
      actName: 'Arbitration and Conciliation Act, 1996',
      section: 'Section 73 & Section 74',
      title: 'Settlement Agreement Status as Court Decree',
      description:
          'A written settlement agreement reached through conciliation or mediation has the exact same legal status and effect as an arbitral award on agreed terms or a decree of a Civil Court under Order XXIII Rule 3 CPC.',
      officialSourceUrl: 'https://www.indiacode.nic.in/handle/123456789/1978',
      isEnforceableInIndia: true,
    ),

    // ─── Micro, Small and Medium Enterprises Development Act, 2006 (MSMED) ────
    const StatutoryCitation(
      actName: 'Micro, Small and Medium Enterprises Development Act, 2006',
      section: 'Section 15 & Section 16',
      title: 'Mandatory 45-Day Payment Rule & 3x RBI Compound Interest',
      description:
          'Buyers must pay MSME suppliers within agreed terms not exceeding 45 days. Any clause stretching payment beyond 45 days is void, and buyers must pay compound monthly interest at three times the RBI bank rate.',
      officialSourceUrl: 'https://www.indiacode.nic.in/handle/123456789/2013',
      isEnforceableInIndia: true,
    ),

    // ─── Commercial Courts Act, 2015 ──────────────────────────────────────────
    const StatutoryCitation(
      actName: 'Commercial Courts Act, 2015',
      section: 'Section 12A',
      title: 'Compulsory Pre-Institution Mediation in Commercial Leases & Contracts',
      description:
          'Mandatory pre-institution mediation is required before instituting commercial suits unless urgent interim relief is sought. Clauses attempting to circumvent mediation or access to commercial courts are invalid.',
      officialSourceUrl: 'https://www.indiacode.nic.in/handle/123456789/2157',
      isEnforceableInIndia: true,
    ),

    // ─── Powers of Attorney Act, 1882 ─────────────────────────────────────────
    const StatutoryCitation(
      actName: 'Powers of Attorney Act, 1882',
      section: 'Section 1A & Section 2',
      title: 'Limits on Irrevocable Power of Attorney & Sham Property Transfers',
      description:
          'General Power of Attorney cannot be used as an instrument of conveyance to transfer immovable property without a registered sale deed (Supreme Court in Suraj Lamp & Industries v. State of Haryana). Irrevocable POAs coupled with interest require strict registration.',
      officialSourceUrl: 'https://www.indiacode.nic.in/handle/123456789/2347',
      isEnforceableInIndia: true,
    ),

    // ─── Transfer of Property Act, 1882 (Mortgage Provisions) ─────────────────
    const StatutoryCitation(
      actName: 'Transfer of Property Act, 1882',
      section: 'Section 60',
      title: 'Inalienable Right of Mortgagor to Redeem Property',
      description:
          'Codifies the doctrine "Once a mortgage, always a mortgage". Any clause or condition in a loan or mortgage deed that operates as a clog on the mortgagor\'s equity of redemption is void and unenforceable.',
      officialSourceUrl: 'https://www.indiacode.nic.in/handle/123456789/2338',
      isEnforceableInIndia: true,
    ),

    // ─── Competition Act, 2002 (Franchise & Exclusive Supply) ─────────────────
    const StatutoryCitation(
      actName: 'Competition Act, 2002',
      section: 'Section 3 & Section 4',
      title: 'Prohibition of Anti-Competitive Exclusive Supply & Tie-in Agreements',
      description:
          'Prohibits agreements causing an appreciable adverse effect on competition (AAEC) in India, including tie-in arrangements, exclusive supply pacts, refusal to deal, and resale price maintenance in franchise contracts.',
      officialSourceUrl: 'https://www.indiacode.nic.in/handle/123456789/2010',
      isEnforceableInIndia: true,
    ),
  ];

  /// Dynamically discovered or synced statutory provisions (from web search, AI, or gazette updates)
  static final List<StatutoryCitation> _dynamicProvisions = [];

  /// Returns all statutory provisions (baseline authoritative acts + newly synced dynamic laws)
  static List<StatutoryCitation> get allProvisions => [
        ...statutoryProvisions,
        ..._dynamicProvisions,
      ];

  /// Register a new statutory provision or amendment dynamically.
  static void registerDynamicProvision(StatutoryCitation citation) {
    final exists = allProvisions.any((p) =>
        p.actName.toLowerCase() == citation.actName.toLowerCase() &&
        p.section.toLowerCase() == citation.section.toLowerCase());
    if (!exists) {
      _dynamicProvisions.add(citation);
    }
  }

  /// Bulk register newly discovered laws.
  static void registerBatch(List<StatutoryCitation> citations) {
    for (final c in citations) {
      registerDynamicProvision(c);
    }
  }

  /// Finds relevant Indian legislative provisions for a given clause type, prioritizing
  /// the latest and currently active running laws in force (BNS 2023, BSA 2023, DPDP 2023, MTA 2021, CPA 2019, RERA 2016).
  static List<StatutoryCitation> getProvisionsForClause(LegalClauseType type) {
    final source = allProvisions;
    List<StatutoryCitation> matches;

    switch (type) {
      case LegalClauseType.upfrontFeeScam:
        matches = source
            .where((p) =>
                p.actName.contains('Bharatiya Nyaya') ||
                p.section.contains('318') ||
                p.section.contains('336') ||
                p.section.contains('23'))
            .toList();
        break;

      case LegalClauseType.securityDepositForfeiture:
        matches = source
            .where((p) =>
                p.actName.contains('Tenancy') ||
                p.actName.contains('Bharatiya Nyaya') ||
                p.section.contains('316') ||
                p.section.contains('2(46)') ||
                p.section.contains('74'))
            .toList();
        break;

      case LegalClauseType.unilateralTermination:
      case LegalClauseType.unilateralVariation:
        matches = source
            .where((p) =>
                p.section.contains('2(46)') ||
                p.actName.contains('Tenancy') ||
                p.section.contains('106') ||
                p.actName.contains('Specific Relief'))
            .toList();
        break;

      case LegalClauseType.restraintOfLegalRecourse:
      case LegalClauseType.waiverOfRights:
        matches = source
            .where((p) =>
                p.section.contains('2(46)') ||
                p.section.contains('28') ||
                p.section.contains('23'))
            .toList();
        break;

      case LegalClauseType.predatoryInterestRate:
        matches = source
            .where((p) =>
                p.section.contains('2(46)') ||
                p.actName.contains('RERA') ||
                p.section.contains('74'))
            .toList();
        break;

      case LegalClauseType.hiddenFeesAndCostShifting:
        matches = source
            .where((p) =>
                p.section.contains('2(47)') ||
                p.actName.contains('RERA') ||
                p.section.contains('2(46)'))
            .toList();
        break;

      case LegalClauseType.confidentialityOverreach:
        matches = source
            .where((p) =>
                p.actName.contains('Data Protection') ||
                p.actName.contains('Sakshya') ||
                p.section.contains('27'))
            .toList();
        break;

      case LegalClauseType.arbitrationAndJurisdiction:
        matches = source
            .where((p) => p.actName.contains('Arbitration') || p.section.contains('28'))
            .toList();
        break;

      case LegalClauseType.penaltyAndDamages:
        matches = source
            .where((p) =>
                p.section.contains('2(46)') ||
                p.section.contains('74') ||
                p.actName.contains('Tenancy'))
            .toList();
        break;

      case LegalClauseType.nonCompeteRestraint:
        matches = source.where((p) => p.section.contains('27')).toList();
        break;

      default:
        matches = source
            .where((p) => p.actName.contains('Indian Contract Act') || p.isEnforceableInIndia)
            .toList();
    }

    // Explicitly sort so currently active and running modern Indian enactments appear first
    matches.sort((a, b) {
      final aRecency = _lawRecencyScore(a);
      final bRecency = _lawRecencyScore(b);
      return bRecency.compareTo(aRecency);
    });

    return matches;
  }

  static int _lawRecencyScore(StatutoryCitation c) {
    final name = c.actName.toLowerCase();
    if (name.contains('bharatiya nyaya') || name.contains('bns')) return 2024;
    if (name.contains('bharatiya sakshya') || name.contains('bsa')) return 2024;
    if (name.contains('data protection') || name.contains('dpdp')) return 2023;
    if (name.contains('model tenancy') || name.contains('tenancy')) return 2021;
    if (name.contains('consumer protection') || name.contains('2019')) return 2019;
    if (name.contains('rera') || name.contains('real estate')) return 2016;
    if (name.contains('arbitration')) return 2015;
    if (name.contains('registration')) return 1908;
    if (name.contains('contract')) return 1872;
    return 1900;
  }
}
