import '../../core/legal/models/legal_document_type.dart';

class ClassificationResult {
  final LegalDocumentType type;
  final double confidence;
  final List<String> detectedParties;
  final List<String> detectedKeywords;

  const ClassificationResult({
    required this.type,
    required this.confidence,
    this.detectedParties = const [],
    this.detectedKeywords = const [],
  });
}

class LegalDocumentClassifier {
  /// Classifies legal document type from raw OCR text deterministically.
  ClassificationResult classify(String text) {
    final lower = text.toLowerCase();
    final scores = <LegalDocumentType, double>{};
    final matchedKeywords = <LegalDocumentType, List<String>>{};

    void checkKeywords(LegalDocumentType type, List<String> keywords, double weight) {
      for (final kw in keywords) {
        if (lower.contains(kw)) {
          scores[type] = (scores[type] ?? 0.0) + weight;
          matchedKeywords.putIfAbsent(type, () => []).add(kw);
        }
      }
    }

    // Residential Rental / Lease
    checkKeywords(LegalDocumentType.rentalAgreement, [
      'rental agreement', 'residential lease agreement', 'rent agreement', 'tenancy agreement',
      'landlord', 'lessor', 'tenant', 'lessee', 'monthly rent', 'security deposit',
      'premises', 'fixtures and fittings', 'handover of key', 'residential purpose',
    ], 2.0);

    // Commercial Lease / Shop & Office
    checkKeywords(LegalDocumentType.commercialLeaseAgreement, [
      'commercial lease', 'office lease', 'shop agreement', 'commercial premises',
      'lock-in period', 'fit-out period', 'gst registration', 'maintenance charges',
      'commercial use', 'sub-lease', 'common area maintenance', 'hvac charges',
    ], 2.5);

    // Employment
    checkKeywords(LegalDocumentType.employmentContract, [
      'employment agreement', 'appointment letter', 'offer letter', 'employment contract',
      'probation period', 'ctc', 'remuneration', 'employee', 'employer', 'salary',
      'working hours', 'confidentiality and non-compete', 'notice period', 'service bond',
    ], 2.0);

    // NDA
    checkKeywords(LegalDocumentType.nonDisclosureAgreement, [
      'non-disclosure agreement', 'non disclosure agreement', 'confidentiality agreement',
      'nda', 'disclosing party', 'receiving party', 'confidential information',
      'proprietary information', 'standard of care', 'return of materials',
    ], 2.5);

    // Sale / Property
    checkKeywords(LegalDocumentType.saleAgreement, [
      'agreement for sale', 'sale deed', 'conveyance deed', 'vendor', 'purchaser',
      'schedule of property', 'survey number', 'katha number', 'consideration amount',
      'possession date', 'stamp duty', 'registration charges',
    ], 2.0);

    // Builder-Buyer Agreement (BBA) / Allotment
    checkKeywords(LegalDocumentType.builderBuyerAgreement, [
      'builder buyer agreement', 'flat buyer agreement', 'allotment letter', 'allottee',
      'promoter', 'builder', 'rera registration', 'carpet area', 'super built-up area',
      'possession delay', 'grace period', 'undivided share of land', 'uds',
    ], 2.5);

    // Loan / Financial
    checkKeywords(LegalDocumentType.loanAgreement, [
      'loan agreement', 'credit facility', 'borrower', 'lender', 'principal amount',
      'interest rate', 'emi', 'equated monthly installment', 'collateral',
      'event of default', 'repayment schedule', 'sanction letter',
    ], 2.0);

    // Mortgage / Hypothecation Deed
    checkKeywords(LegalDocumentType.mortgageDeed, [
      'mortgage deed', 'deed of simple mortgage', 'equitable mortgage', 'mortgagor',
      'mortgagee', 'hypothecation', 'title deeds deposit', 'sarfaesi', 'equity of redemption',
      'secured debt', 'charge created',
    ], 2.5);

    // Vendor / Supply & Purchase (MSME)
    checkKeywords(LegalDocumentType.vendorSupplyAgreement, [
      'vendor agreement', 'supply agreement', 'purchase order', 'supplier', 'purchaser',
      'msme', 'msmed act', 'payment within 45 days', 'specifications of goods',
      'delivery terms', 'inspection and rejection', 'warranty period',
    ], 2.5);

    // Consultancy / Retainership
    checkKeywords(LegalDocumentType.consultancyAgreement, [
      'consultancy agreement', 'retainer agreement', 'consultant', 'retainership fee',
      'scope of consultancy', 'independent professional', 'deliverables', 'tds deduction',
    ], 2.5);

    // Shareholders / Founders Agreement (SHA)
    checkKeywords(LegalDocumentType.shareholdersAgreement, [
      'shareholders agreement', 'share purchase agreement', 'founders agreement',
      'equity shares', 'tag-along right', 'drag-along right', 'pre-emptive right',
      'board of directors', 'rofr', 'right of first refusal', 'liquidation preference',
    ], 2.5);

    // Partnership / LLP
    checkKeywords(LegalDocumentType.partnershipDeed, [
      'partnership deed', 'partners', 'profit sharing ratio', 'capital contribution',
      'llp agreement', 'firm name', 'dissolution of partnership', 'designated partners',
    ], 2.0);

    // Service / Freelancer SLA
    checkKeywords(LegalDocumentType.serviceAgreement, [
      'service agreement', 'master service agreement', 'msa', 'statement of work',
      'sow', 'freelancer', 'independent contractor', 'service level agreement', 'sla',
      'service credits', 'intellectual property rights',
    ], 2.0);

    // Franchise / Brand Licensing
    checkKeywords(LegalDocumentType.franchiseAgreement, [
      'franchise agreement', 'franchisor', 'franchisee', 'franchise fee', 'royalty fee',
      'trademark license', 'brand guidelines', 'territory rights', 'store audit',
    ], 2.5);

    // Settlement / Compromise
    checkKeywords(LegalDocumentType.settlementAgreement, [
      'settlement agreement', 'compromise deed', 'memorandum of settlement',
      'full and final settlement', 'withdraw all pending claims', 'cpc order xxiii',
      'quash criminal proceedings', 'mutual release',
    ], 2.5);

    // Gift / Relinquishment
    checkKeywords(LegalDocumentType.giftDeed, [
      'gift deed', 'donor', 'donee', 'out of natural love and affection',
      'without any monetary consideration', 'relinquishment deed', 'release deed',
    ], 2.5);

    // Indemnity Bond / Guarantee
    checkKeywords(LegalDocumentType.indemnityBond, [
      'indemnity bond', 'deed of indemnity', 'indemnifier', 'indemnity holder',
      'save harmless', 'reimburse and indemnify', 'bond of guarantee', 'surety',
    ], 2.5);

    // Power of Attorney
    checkKeywords(LegalDocumentType.powerOfAttorney, [
      'power of attorney', 'general power of attorney', 'special power of attorney',
      'gpa', 'spa', 'executant', 'attorney', 'constituted attorney', 'nominate, constitute',
    ], 2.5);

    // Affidavit
    checkKeywords(LegalDocumentType.affidavit, [
      'affidavit', 'solemnly affirm', 'deponent', 'sworn before me', 'notary public',
      'oath', 'verification at', 'contents of this affidavit',
    ], 2.5);

    // Insurance
    checkKeywords(LegalDocumentType.insurancePolicy, [
      'insurance policy', 'policyholder', 'insured', 'premium', 'sum assured',
      'deductible', 'claim procedure', 'grace period', 'irda', 'irdai',
    ], 2.0);

    // Terms & Conditions / E-Commerce ToS
    checkKeywords(LegalDocumentType.termsAndConditions, [
      'terms of service', 'terms and conditions', 'terms of use', 'user agreement',
      'privacy policy', 'cookie policy', 'platform rules', 'account suspension',
    ], 2.0);

    // Consumer Contract
    checkKeywords(LegalDocumentType.consumerContract, [
      'consumer contract', 'purchase terms', 'warranty card', 'end user license agreement',
      'eula', 'customer agreement', 'refund policy', 'cancellation policy',
    ], 2.0);

    // Will / Testament
    checkKeywords(LegalDocumentType.willOrTestament, [
      'last will and testament', 'testator', 'executor', 'bequeath', 'legatee',
      'probate', 'codicil', 'sound mind and disposing memory',
    ], 2.5);

    // Legal Notice
    checkKeywords(LegalDocumentType.legalNotice, [
      'legal notice', 'under instructions from my client', 'demand notice',
      'without prejudice', 'call upon you to', 'failing which legal proceedings',
    ], 2.5);

    if (scores.isEmpty) {
      return const ClassificationResult(
        type: LegalDocumentType.otherOrUnknown,
        confidence: 0.50,
      );
    }

    // Find highest scoring type
    LegalDocumentType bestType = LegalDocumentType.otherOrUnknown;
    double maxScore = 0.0;
    scores.forEach((type, score) {
      if (score > maxScore) {
        maxScore = score;
        bestType = type;
      }
    });

    final confidence = (maxScore / 10.0).clamp(0.65, 0.98);
    final parties = _extractParties(text);

    return ClassificationResult(
      type: bestType,
      confidence: confidence,
      detectedParties: parties,
      detectedKeywords: matchedKeywords[bestType] ?? [],
    );
  }

  List<String> _extractParties(String text) {
    final parties = <String>[];
    final regex = RegExp(r'(?:between|by and between)\s+([^\n,]+)(?:and|,)\s+([^\n,\.]+)', caseSensitive: false);
    final m = regex.firstMatch(text);
    if (m != null) {
      final p1 = m.group(1)?.replaceAll(RegExp(r'\s+'), ' ').trim();
      final p2 = m.group(2)?.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (p1 != null && p1.length > 3 && p1.length < 80) parties.add(p1);
      if (p2 != null && p2.length > 3 && p2.length < 80) parties.add(p2);
    }
    return parties;
  }
}
