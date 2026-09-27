/// Supported Indian legal and official document classifications.
enum LegalDocumentType {
  rentalAgreement,
  commercialLeaseAgreement,
  employmentContract,
  nonDisclosureAgreement,
  saleAgreement,
  builderBuyerAgreement,
  loanAgreement,
  mortgageDeed,
  vendorSupplyAgreement,
  consultancyAgreement,
  shareholdersAgreement,
  partnershipDeed,
  serviceAgreement,
  franchiseAgreement,
  settlementAgreement,
  giftDeed,
  indemnityBond,
  powerOfAttorney,
  affidavit,
  termsAndConditions,
  insurancePolicy,
  willOrTestament,
  legalNotice,
  consumerContract,
  otherOrUnknown,
}

extension LegalDocumentTypeExt on LegalDocumentType {
  String get displayName {
    switch (this) {
      case LegalDocumentType.rentalAgreement:
        return 'Residential Rental / Lease Agreement';
      case LegalDocumentType.commercialLeaseAgreement:
        return 'Commercial Lease / Shop Agreement';
      case LegalDocumentType.employmentContract:
        return 'Employment Contract / Bond';
      case LegalDocumentType.nonDisclosureAgreement:
        return 'Non-Disclosure Agreement (NDA)';
      case LegalDocumentType.saleAgreement:
        return 'Agreement for Sale / Sale Deed';
      case LegalDocumentType.builderBuyerAgreement:
        return 'Builder-Buyer Agreement (BBA) / Allotment';
      case LegalDocumentType.loanAgreement:
        return 'Loan / Credit Facility Agreement';
      case LegalDocumentType.mortgageDeed:
        return 'Mortgage Deed / Hypothecation Agreement';
      case LegalDocumentType.vendorSupplyAgreement:
        return 'Vendor / Supply & Purchase Agreement';
      case LegalDocumentType.consultancyAgreement:
        return 'Consultancy / Retainership Agreement';
      case LegalDocumentType.shareholdersAgreement:
        return 'Shareholders / Founders Agreement (SHA)';
      case LegalDocumentType.partnershipDeed:
        return 'Partnership Deed / LLP Agreement';
      case LegalDocumentType.serviceAgreement:
        return 'Service / Freelancer Agreement (SLA)';
      case LegalDocumentType.franchiseAgreement:
        return 'Franchise / Brand Licensing Agreement';
      case LegalDocumentType.settlementAgreement:
        return 'Settlement & Compromise Agreement';
      case LegalDocumentType.giftDeed:
        return 'Gift Deed / Relinquishment Deed';
      case LegalDocumentType.indemnityBond:
        return 'Indemnity Bond / Guarantee Deed';
      case LegalDocumentType.powerOfAttorney:
        return 'Power of Attorney (General / Special PoA)';
      case LegalDocumentType.affidavit:
        return 'Sworn Affidavit';
      case LegalDocumentType.termsAndConditions:
        return 'Terms & Conditions / E-Commerce ToS';
      case LegalDocumentType.insurancePolicy:
        return 'Insurance Policy Document';
      case LegalDocumentType.willOrTestament:
        return 'Will / Testament';
      case LegalDocumentType.legalNotice:
        return 'Court / Legal Notice';
      case LegalDocumentType.consumerContract:
        return 'Consumer Purchase / Service Contract';
      case LegalDocumentType.otherOrUnknown:
        return 'General Legal Document';
    }
  }

  String get emoji {
    switch (this) {
      case LegalDocumentType.rentalAgreement:
        return '🏠';
      case LegalDocumentType.commercialLeaseAgreement:
        return '🏢';
      case LegalDocumentType.employmentContract:
        return '💼';
      case LegalDocumentType.nonDisclosureAgreement:
        return '🔒';
      case LegalDocumentType.saleAgreement:
        return '📜';
      case LegalDocumentType.builderBuyerAgreement:
        return '🏗️';
      case LegalDocumentType.loanAgreement:
        return '💳';
      case LegalDocumentType.mortgageDeed:
        return '🏦';
      case LegalDocumentType.vendorSupplyAgreement:
        return '📦';
      case LegalDocumentType.consultancyAgreement:
        return '👔';
      case LegalDocumentType.shareholdersAgreement:
        return '📈';
      case LegalDocumentType.partnershipDeed:
        return '🤝';
      case LegalDocumentType.serviceAgreement:
        return '🛠️';
      case LegalDocumentType.franchiseAgreement:
        return '🏪';
      case LegalDocumentType.settlementAgreement:
        return '⚖️';
      case LegalDocumentType.giftDeed:
        return '🎁';
      case LegalDocumentType.indemnityBond:
        return '🛡️';
      case LegalDocumentType.powerOfAttorney:
        return '📜';
      case LegalDocumentType.affidavit:
        return '✍️';
      case LegalDocumentType.termsAndConditions:
        return '📋';
      case LegalDocumentType.insurancePolicy:
        return '🛡️';
      case LegalDocumentType.willOrTestament:
        return '🏛️';
      case LegalDocumentType.legalNotice:
        return '🚨';
      case LegalDocumentType.consumerContract:
        return '🛍️';
      case LegalDocumentType.otherOrUnknown:
        return '📄';
    }
  }

  String get governingActDescription {
    switch (this) {
      case LegalDocumentType.rentalAgreement:
        return 'Model Tenancy Act, 2021 & State Rent Control Acts';
      case LegalDocumentType.commercialLeaseAgreement:
        return 'Commercial Courts Act, 2015 & Transfer of Property Act, 1882';
      case LegalDocumentType.employmentContract:
        return 'Indian Contract Act, 1872 (Sec 27) & Industrial Relations Code';
      case LegalDocumentType.nonDisclosureAgreement:
        return 'DPDP Act, 2023 & Indian Contract Act, 1872';
      case LegalDocumentType.saleAgreement:
        return 'Transfer of Property Act, 1882 & Registration Act, 1908';
      case LegalDocumentType.builderBuyerAgreement:
        return 'RERA, 2016 (Sec 13 & 18) & Consumer Protection Act, 2019';
      case LegalDocumentType.loanAgreement:
        return 'RBI Master Directions & Indian Contract Act, 1872';
      case LegalDocumentType.mortgageDeed:
        return 'Transfer of Property Act, 1882 (Sec 58/60) & SARFAESI Act, 2002';
      case LegalDocumentType.vendorSupplyAgreement:
        return 'Sale of Goods Act, 1930 & MSMED Act, 2006 (Sec 15/16 Mandatory 45-day rule)';
      case LegalDocumentType.consultancyAgreement:
        return 'Indian Contract Act, 1872 & Income Tax Act, 1961';
      case LegalDocumentType.shareholdersAgreement:
        return 'Companies Act, 2013 & Indian Contract Act, 1872';
      case LegalDocumentType.partnershipDeed:
        return 'Indian Partnership Act, 1932 & Limited Liability Partnership Act, 2008';
      case LegalDocumentType.serviceAgreement:
        return 'Indian Contract Act, 1872 & Information Technology Act, 2000';
      case LegalDocumentType.franchiseAgreement:
        return 'Trademarks Act, 1999 & Competition Act, 2002';
      case LegalDocumentType.settlementAgreement:
        return 'Arbitration & Conciliation Act, 1996 (Sec 73) & CPC 1908';
      case LegalDocumentType.giftDeed:
        return 'Transfer of Property Act, 1882 (Sec 122/123) & Registration Act, 1908';
      case LegalDocumentType.indemnityBond:
        return 'Indian Contract Act, 1872 (Sec 124/126) & Indian Stamp Act, 1899';
      case LegalDocumentType.powerOfAttorney:
        return 'Powers of Attorney Act, 1882 & Registration Act, 1908';
      case LegalDocumentType.affidavit:
        return 'Notaries Act, 1952 & Indian Oaths Act, 1969';
      case LegalDocumentType.termsAndConditions:
        return 'Consumer Protection Act, 2019 & Information Technology Act, 2000';
      case LegalDocumentType.insurancePolicy:
        return 'Insurance Regulatory and Development Authority (IRDAI) Act, 1999';
      case LegalDocumentType.willOrTestament:
        return 'Indian Succession Act, 1925';
      case LegalDocumentType.legalNotice:
        return 'Code of Civil Procedure, 1908 & Specific Relief Act, 1963';
      case LegalDocumentType.consumerContract:
        return 'Consumer Protection Act, 2019 (Sec 2(46) Unfair Contract Terms)';
      case LegalDocumentType.otherOrUnknown:
        return 'Indian Contract Act, 1872 & Bharatiya Nyaya Sanhita, 2023';
    }
  }
}
