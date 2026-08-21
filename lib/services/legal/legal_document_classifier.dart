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

    // Rental / Lease
    checkKeywords(LegalDocumentType.rentalAgreement, [
      'rental agreement', 'lease agreement', 'rent agreement', 'tenancy agreement',
      'landlord', 'lessor', 'tenant', 'lessee', 'monthly rent', 'security deposit',
      'premises', 'fixtures and fittings', 'handover of key', 'lock-in period',
    ], 2.0);

    // Employment
    checkKeywords(LegalDocumentType.employmentContract, [
      'employment agreement', 'appointment letter', 'offer letter', 'employment contract',
      'probation period', 'ctc', 'remuneration', 'employee', 'employer', 'salary',
      'working hours', 'confidentiality and non-compete', 'notice period',
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
      'schedule of property', 'survey number', 'katha number', 'rera registration',
      'consideration amount', 'possession date', 'stamp duty',
    ], 2.0);

    // Loan / Financial
    checkKeywords(LegalDocumentType.loanAgreement, [
      'loan agreement', 'credit facility', 'borrower', 'lender', 'principal amount',
      'interest rate', 'emi', 'equated monthly installment', 'collateral', 'hypothecation',
      'event of default', 'repayment schedule',
    ], 2.0);

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

    // Partnership / Business
    checkKeywords(LegalDocumentType.partnershipDeed, [
      'partnership deed', 'partners', 'profit sharing ratio', 'capital contribution',
      'llp agreement', 'firm name', 'dissolution of partnership',
    ], 2.0);

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
