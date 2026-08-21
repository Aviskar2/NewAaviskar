import '../../models/product_safety_model.dart';

/// Service to parse and analyze Barcodes (EAN-13, UPC-A, GS1) and QR codes.
class BarcodeGs1Service {
  /// Known Indian GS1 FMCG brand prefix database (Prefix 890 + manufacturer digits)
  static final Map<String, Map<String, String>> _indianBrandRegistry = {
    '8901030': {'brand': 'Hindustan Unilever (HUL)', 'category': 'Personal Care / Food'},
    '8901063': {'brand': 'Britannia Industries', 'category': 'Biscuits & Dairy'},
    '8901262': {'brand': 'Amul (GCMMF)', 'category': 'Dairy & Beverages'},
    '8901058': {'brand': 'Nestlé India', 'category': 'Food & Nutrition'},
    '8901725': {'brand': 'ITC Limited (Sunfeast/Aashirvaad)', 'category': 'Packaged Foods'},
    '8901491': {'brand': 'Dabur India', 'category': 'Ayurvedic & Health'},
    '8901719': {'brand': 'Parle Products', 'category': 'Biscuits & Confectionery'},
    '8901088': {'brand': 'Tata Consumer Products', 'category': 'Tea, Salt & Pulses'},
    '8901012': {'brand': 'Marico (Parachute / Saffola)', 'category': 'Oils & Health'},
    '8901233': {'brand': 'Haldiram Snacks', 'category': 'Namkeen & Sweets'},
    '8904109': {'brand': 'Patanjali Ayurved', 'category': 'Consumer Goods'},
    '8901571': {'brand': 'Mother Dairy', 'category': 'Dairy & Ice Cream'},
    '8901103': {'brand': 'Godrej Consumer Products', 'category': 'Household & Personal Care'},
    '8906001': {'brand': 'Balaji Wafers', 'category': 'Snacks & Wafers'},
    '8906010': {'brand': 'Bikaji Foods', 'category': 'Namkeen & Sweets'},
    '8901023': {'brand': 'Cadbury / Mondelēz India', 'category': 'Chocolates & Confectionery'},
    '8902080': {'brand': 'Pepsico India (Lay\'s / Kurkure)', 'category': 'Beverages & Snacks'},
    '8901764': {'brand': 'Coca-Cola India', 'category': 'Beverages'},
  };

  /// Country prefix mapping (GS1 General Specifications)
  static final Map<String, String> _countryPrefixes = {
    '890': 'India (GS1 India)',
    '000': 'USA / Canada',
    '001': 'USA / Canada',
    '002': 'USA / Canada',
    '003': 'USA / Canada',
    '004': 'USA / Canada',
    '005': 'USA / Canada',
    '006': 'USA / Canada',
    '007': 'USA / Canada',
    '008': 'USA / Canada',
    '009': 'USA / Canada',
    '400': 'Germany',
    '450': 'Japan',
    '490': 'Japan',
    '500': 'United Kingdom',
    '590': 'Poland',
    '690': 'China',
    '691': 'China',
    '692': 'China',
    '730': 'Sweden',
    '760': 'Switzerland',
    '800': 'Italy',
    '840': 'Spain',
    '880': 'South Korea',
    '885': 'Thailand',
    '888': 'Singapore',
    '893': 'Vietnam',
    '899': 'Indonesia',
    '930': 'Australia',
    '940': 'New Zealand',
  };

  /// Parse raw barcode string into structured metadata.
  BarcodeProductInfo parseBarcode(String rawBarcode, {String format = 'EAN-13'}) {
    final cleaned = rawBarcode.replaceAll(RegExp(r'\s+'), '').trim();
    final isIndia = cleaned.startsWith('890');

    String country = 'International';
    for (final entry in _countryPrefixes.entries) {
      if (cleaned.startsWith(entry.key)) {
        country = entry.value;
        break;
      }
    }

    String? brand;
    String? category;

    // Check Indian brand registry (first 7 digits)
    if (cleaned.length >= 7) {
      final prefix7 = cleaned.substring(0, 7);
      if (_indianBrandRegistry.containsKey(prefix7)) {
        brand = _indianBrandRegistry[prefix7]!['brand'];
        category = _indianBrandRegistry[prefix7]!['category'];
      }
    }

    return BarcodeProductInfo(
      barcode: cleaned,
      format: format,
      isMadeInIndia: isIndia,
      countryOfOrigin: country,
      brandName: brand,
      category: category,
      productName: brand != null ? '$brand Packaged Product' : null,
    );
  }

  /// Extracts barcode sequence from OCR raw text if printed as digits.
  String? extractBarcodeFromText(String text) {
    // Look for 13-digit EAN-13 numbers or 890 prefixes
    final eanRegex = RegExp(r'\b(890\d{10})\b');
    final match = eanRegex.firstMatch(text);
    if (match != null) return match.group(1);

    final generic13 = RegExp(r'\b(\d{13})\b');
    final match13 = generic13.firstMatch(text);
    if (match13 != null) return match13.group(1);

    return null;
  }
}
