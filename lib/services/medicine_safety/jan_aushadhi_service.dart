import '../../models/medicine_safety_model.dart';

/// Database and comparator for Active Pharmaceutical Ingredients (APIs),
/// matching branded medicines against PMBJP (Jan Aushadhi) Generic equivalents.
class JanAushadhiService {
  /// Known Indian Branded Drugs mapped to PMBJP Generic equivalents & National Essential Medicines List
  static final List<Map<String, dynamic>> _genericMedicineDb = [
    {
      'genericSalt': 'Paracetamol Tablets IP',
      'strength': '650 mg',
      'brandAliases': ['DOLO 650', 'CALPOL 650', 'PACIMOL 650', 'CRO公众 650'],
      'brandedMrp': 34.0,
      'janAushadhiPrice': 10.0,
      'pmbjpCode': 'PMBJP-0012',
    },
    {
      'genericSalt': 'Pantoprazole Gastro-Resistant Tablets IP',
      'strength': '40 mg',
      'brandAliases': ['PAN 40', 'PANTOCID', 'PANTOSEC', 'PANTOP 40'],
      'brandedMrp': 165.0,
      'janAushadhiPrice': 22.0,
      'pmbjpCode': 'PMBJP-0145',
    },
    {
      'genericSalt': 'Amoxicillin & Potassium Clavulanate Tablets IP',
      'strength': '625 mg (500mg + 125mg)',
      'brandAliases': ['AUGMENTIN 625', 'MOXIKIND CV 625', 'CLAVAM 625', 'MEGACV 625'],
      'brandedMrp': 220.0,
      'janAushadhiPrice': 55.0,
      'pmbjpCode': 'PMBJP-0089',
    },
    {
      'genericSalt': 'Azithromycin Tablets IP',
      'strength': '500 mg',
      'brandAliases': ['AZITHRAL 500', 'AZIWIN 500', 'AZAX 500', 'ZITHROMAX'],
      'brandedMrp': 130.0,
      'janAushadhiPrice': 38.0,
      'pmbjpCode': 'PMBJP-0210',
    },
    {
      'genericSalt': 'Metformin Hydrochloride Prolonged-Release Tablets IP',
      'strength': '500 mg',
      'brandAliases': ['GLYCOMET 500', 'GLUCOPHAGE', 'OBIMET 500', 'ZOMET 500'],
      'brandedMrp': 48.0,
      'janAushadhiPrice': 9.0,
      'pmbjpCode': 'PMBJP-0312',
    },
    {
      'genericSalt': 'Montelukast Sodium & Levocetirizine Hydrochloride Tablets',
      'strength': '10 mg + 5 mg',
      'brandAliases': ['MONTEK LC', 'MONTICOPE', 'LEVOZET M', 'TELEKAST L'],
      'brandedMrp': 195.0,
      'janAushadhiPrice': 30.0,
      'pmbjpCode': 'PMBJP-0488',
    },
    {
      'genericSalt': 'Atorvastatin Tablets IP',
      'strength': '10 mg',
      'brandAliases': ['ATORVA 10', 'LIPITOR', 'STORVAS 10', 'ATOCOR 10'],
      'brandedMrp': 110.0,
      'janAushadhiPrice': 18.0,
      'pmbjpCode': 'PMBJP-0512',
    },
    {
      'genericSalt': 'Telmisartan Tablets IP',
      'strength': '40 mg',
      'brandAliases': ['TELMA 40', 'TELVAS 40', 'TELMIKIND 40', 'TELISTA 40'],
      'brandedMrp': 125.0,
      'janAushadhiPrice': 15.0,
      'pmbjpCode': 'PMBJP-0640',
    },
    {
      'genericSalt': 'Cetirizine Hydrochloride Tablets IP',
      'strength': '10 mg',
      'brandAliases': ['CITRAZINE', 'ALERID', 'CETZINE', 'OKACET'],
      'brandedMrp': 40.0,
      'janAushadhiPrice': 6.0,
      'pmbjpCode': 'PMBJP-0710',
    },
    {
      'genericSalt': 'Omeprazole & Domperidone Capsules IP',
      'strength': '20 mg + 10 mg',
      'brandAliases': ['OMEZ D', 'OCID D', 'OMECIP D', 'DOMSTAL O'],
      'brandedMrp': 175.0,
      'janAushadhiPrice': 26.0,
      'pmbjpCode': 'PMBJP-0820',
    },
  ];

  /// Extracts active generic salts / molecules from packaging text.
  List<String> extractActiveIngredients(String rawText) {
    final clean = rawText.toUpperCase();
    final extracted = <String>[];

    final saltPatterns = [
      RegExp(r'\b(PARACETAMOL|ACETAMINOPHEN)\s*(?:\d+\s*MG)?\b'),
      RegExp(r'\b(PANTOPRAZOLE|OMEPRAZOLE|RABEPRAZOLE|ESOMEPRAZOLE)\s*(?:\d+\s*MG)?\b'),
      RegExp(r'\b(AMOXICILLIN|AZITHROMYCIN|CIPROFLOXACIN|LEVOFLOXACIN|CEFIXIME)\s*(?:\d+\s*MG)?\b'),
      RegExp(r'\b(METFORMIN|GLIMEPIRIDE|VILDAGLIPTIN|DAPAGLIFLOZIN)\s*(?:\d+\s*MG)?\b'),
      RegExp(r'\b(TELMISARTAN|AMLODIPINE|ATORVASTATIN|ROSUVASTATIN)\s*(?:\d+\s*MG)?\b'),
      RegExp(r'\b(MONTELUKAST|LEVOCETIRIZINE|CETIRIZINE|FEXOFENADINE)\s*(?:\d+\s*MG)?\b'),
      RegExp(r'\b(DICLOFENAC|ACECLOFENAC|IBUPROFEN|TRAMADOL)\s*(?:\d+\s*MG)?\b'),
      RegExp(r'\b(CLAVULANIC ACID|POTASSIUM CLAVULANATE)\s*(?:\d+\s*MG)?\b'),
    ];

    for (final pattern in saltPatterns) {
      final matches = pattern.allMatches(clean);
      for (final match in matches) {
        final salt = match.group(0);
        if (salt != null && !extracted.contains(salt)) {
          extracted.add(salt.trim());
        }
      }
    }

    return extracted;
  }

  /// Identifies if the scanned medicine has a known Jan Aushadhi generic alternative and computes price savings.
  JanAushadhiGenericComparison? findGenericAlternative(String rawText, List<String> activeSalts) {
    final clean = rawText.toUpperCase();

    for (final med in _genericMedicineDb) {
      final brandAliases = med['brandAliases'] as List<String>;
      final genericSalt = med['genericSalt'] as String;

      bool brandMatched = brandAliases.any((brand) => clean.contains(brand));
      bool saltMatched = clean.contains(genericSalt.toUpperCase()) ||
          activeSalts.any((s) => genericSalt.toUpperCase().contains(s));

      if (brandMatched || saltMatched) {
        final brandedMrp = (med['brandedMrp'] as num).toDouble();
        final janAushadhiPrice = (med['janAushadhiPrice'] as num).toDouble();
        final amountSaved = brandedMrp - janAushadhiPrice;
        final savingsPercentage = ((amountSaved / brandedMrp) * 100).clamp(0.0, 100.0);

        String detectedBrand = brandAliases.firstWhere(
          (b) => clean.contains(b),
          orElse: () => brandAliases.first,
        );

        return JanAushadhiGenericComparison(
          brandName: detectedBrand,
          genericSalt: genericSalt,
          strength: med['strength'] as String,
          estimatedBrandedMrp: brandedMrp,
          janAushadhiPrice: janAushadhiPrice,
          savingsPercentage: savingsPercentage,
          amountSaved: amountSaved,
          pmbjpCode: med['pmbjpCode'] as String,
        );
      }
    }

    return null;
  }
}
