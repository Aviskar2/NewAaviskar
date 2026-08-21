/// Supported Indian legal and official document classifications.
enum LegalDocumentType {
  rentalAgreement,
  employmentContract,
  nonDisclosureAgreement,
  saleAgreement,
  loanAgreement,
  insurancePolicy,
  powerOfAttorney,
  affidavit,
  partnershipDeed,
  serviceAgreement,
  termsAndConditions,
  willOrTestament,
  legalNotice,
  consumerContract,
  otherOrUnknown,
}

extension LegalDocumentTypeExt on LegalDocumentType {
  String get displayName {
    switch (this) {
      case LegalDocumentType.rentalAgreement:
        return 'Rental / Lease Agreement';
      case LegalDocumentType.employmentContract:
        return 'Employment Contract';
      case LegalDocumentType.nonDisclosureAgreement:
        return 'Non-Disclosure Agreement (NDA)';
      case LegalDocumentType.saleAgreement:
        return 'Agreement for Sale / Sale Deed';
      case LegalDocumentType.loanAgreement:
        return 'Loan / Credit Agreement';
      case LegalDocumentType.insurancePolicy:
        return 'Insurance Policy Document';
      case LegalDocumentType.powerOfAttorney:
        return 'Power of Attorney (PoA)';
      case LegalDocumentType.affidavit:
        return 'Sworn Affidavit';
      case LegalDocumentType.partnershipDeed:
        return 'Partnership Deed';
      case LegalDocumentType.serviceAgreement:
        return 'Service / Freelance Contract';
      case LegalDocumentType.termsAndConditions:
        return 'Terms & Conditions / ToS';
      case LegalDocumentType.willOrTestament:
        return 'Will / Testament';
      case LegalDocumentType.legalNotice:
        return 'Court / Legal Notice';
      case LegalDocumentType.consumerContract:
        return 'Consumer Purchase Contract';
      case LegalDocumentType.otherOrUnknown:
        return 'General Legal Document';
    }
  }

  String get emoji {
    switch (this) {
      case LegalDocumentType.rentalAgreement:
        return '🏠';
      case LegalDocumentType.employmentContract:
        return '💼';
      case LegalDocumentType.nonDisclosureAgreement:
        return '🔒';
      case LegalDocumentType.saleAgreement:
        return '📜';
      case LegalDocumentType.loanAgreement:
        return '💳';
      case LegalDocumentType.insurancePolicy:
        return '🛡️';
      case LegalDocumentType.powerOfAttorney:
        return '⚖️';
      case LegalDocumentType.affidavit:
        return '✍️';
      case LegalDocumentType.partnershipDeed:
        return '🤝';
      case LegalDocumentType.serviceAgreement:
        return '🛠️';
      case LegalDocumentType.termsAndConditions:
        return '📋';
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
      case LegalDocumentType.employmentContract:
        return 'Indian Contract Act, 1872 (Sec 27) & Industrial Relations Code';
      case LegalDocumentType.nonDisclosureAgreement:
        return 'Indian Contract Act, 1872 & IT Act, 2000';
      case LegalDocumentType.saleAgreement:
        return 'Transfer of Property Act, 1882 & RERA, 2016';
      case LegalDocumentType.loanAgreement:
        return 'RBI Fair Practices Code & Indian Contract Act, 1872';
      case LegalDocumentType.insurancePolicy:
        return 'Insurance Regulatory and Development Authority (IRDAI) Act';
      case LegalDocumentType.powerOfAttorney:
        return 'Powers of Attorney Act, 1882 & Registration Act, 1908';
      case LegalDocumentType.affidavit:
        return 'Notaries Act, 1952 & Indian Oaths Act, 1969';
      case LegalDocumentType.partnershipDeed:
        return 'Indian Partnership Act, 1932 / LLP Act, 2008';
      case LegalDocumentType.serviceAgreement:
        return 'Indian Contract Act, 1872 & Specific Relief Act, 1963';
      case LegalDocumentType.termsAndConditions:
        return 'Consumer Protection Act, 2019 & IT Act, 2000';
      case LegalDocumentType.willOrTestament:
        return 'Indian Succession Act, 1925';
      case LegalDocumentType.legalNotice:
        return 'Code of Civil Procedure, 1908 & Specific Relief Act, 1963';
      case LegalDocumentType.consumerContract:
        return 'Consumer Protection Act, 2019 (Sec 2(46) Unfair Contracts)';
      case LegalDocumentType.otherOrUnknown:
        return 'Indian Contract Act, 1872 & General Law of India';
    }
  }
}
