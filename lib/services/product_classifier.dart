/// Standalone product classifier — score-based multi-signal classification.
library;

/// Extracted from UniversalProductEntryScreen for testability.

enum ProductCategory { medicine, food, cosmetics, household, electronics, unknown }

class ProductClassifier {
  static final _spfWithNumber = RegExp(r'spf\s+\d');

  ProductCategory classify(String text) {
    final lower = text.toLowerCase();

    int medicine = 0, cosmetics = 0, food = 0, electronics = 0, household = 0;

    // ── Medicine signals ──────────────────────────────────────────────────
    if (_hasAny(lower, ['schedule h', 'schedule h1', 'schedule x', 'schedule g'])) { medicine += 5; }
    if (_hasAny(lower, ['rx only', 'prescription drug', 'drug license', 'drug schedule', 'cdsco'])) { medicine += 5; }
    if (_hasAny(lower, ['mfg. lic. no', 'mfg lic'])) { medicine += 4; }
    if (_hasAny(lower, ['tablet', 'tablets', 'capsule', 'capsules', 'syrup', 'injection', 'ointment'])) { medicine += 3; }
    if (_hasAny(lower, ['dosage:', 'each film coated', 'each uncoated'])) { medicine += 3; }
    if (_hasAny(lower, ['paracetamol', 'amoxicillin', 'azithromycin', 'ibuprofen',
        'pantoprazole', 'cetirizine', 'fexofenadine', 'metformin',
        'atorvastatin', 'ciprofloxacin', 'diclofenac', 'omeprazole',
        'levocetirizine', 'montelukast', 'azelastine', 'ranitidine'])) { medicine += 4; }
    if (_hasAny(lower, ['ip 650', 'ip 500', 'ip 250', 'ip 100'])) { medicine += 4; }
    if (_hasAny(lower, ['dispensing', 'pharmacist'])) { medicine += 3; }

    // ── Cosmetics signals ─────────────────────────────────────────────────
    if (_hasAny(lower, ['moisturiser', 'moisturizer', 'sunscreen',
        'foundation', 'lipstick', 'mascara', 'eyeliner', 'kajal',
        'nail polish', 'nail enamel']) || _spfWithNumber.hasMatch(lower)) { cosmetics += 5; }
    if (_hasAny(lower, ['face wash', 'face pack', 'scrub', 'toner', 'cleanser'])) { cosmetics += 4; }
    if (_hasAny(lower, ['shampoo', 'conditioner', 'hair dye', 'hair colour', 'hair oil'])) { cosmetics += 4; }
    if (_hasAny(lower, ['deodorant', 'perfume', 'eau de', 'body spray'])) { cosmetics += 4; }
    if (_hasAny(lower, ['shaving', 'aftershave', 'beard oil'])) { cosmetics += 4; }
    if (_hasAny(lower, ['skin whitening', 'fairness', 'anti ageing', 'anti-aging'])) { cosmetics += 5; }
    if (_hasAny(lower, ['paraben', 'sodium lauryl sulfate', ' sls ', ' sles '])) { cosmetics += 3; }
    if (_hasAny(lower, ['retinol', 'salicylic acid', 'glycolic acid', 'niacinamide',
        'hyaluronic acid'])) { cosmetics += 3; }
    if (_hasAny(lower, ['cdso cosmetic', 'cosmetic rules', 'drug and cosmetic'])) { cosmetics += 5; }
    if (lower.contains('cream') && cosmetics > 0) { cosmetics += 2; }

    // ── Food signals ──────────────────────────────────────────────────────
    if (_hasAny(lower, ['fssai'])) { food += 5; }
    if (_hasAny(lower, ['nutritional information', 'nutrition facts', 'ingredients:'])) { food += 4; }
    if (_hasAny(lower, ['allergen', 'energy:', 'total fat', 'saturated fat',
        'trans fat', 'cholesterol', 'sodium'])) { food += 3; }
    if (_hasAny(lower, ['total carbohydrate', 'dietary fibre', 'total sugars',
        'added sugars', 'protein'])) { food += 3; }
    if (_hasAny(lower, ['best before', 'use by', 'mfg dt', 'mfd:', 'exp:',
        'shelf life', 'per 100g', 'per 100ml', 'per serving', 'serving size'])) { food += 3; }
    if (_hasAny(lower, ['non-veg', 'veg', 'green dot', 'brown dot',
        'packaged food', 'food product', 'food item'])) { food += 4; }
    if (_hasAny(lower, ['biscuit', 'noodles', 'chips', 'snack', 'cereal',
        'ice cream', 'chocolate', 'candy', 'sweets'])) { food += 4; }
    if (_hasAny(lower, ['atta', 'maida', 'ghee', 'pickles', 'sauce',
        'ketchup', 'spice', 'masala', 'honey', 'jam', 'vinegar'])) { food += 3; }
    if (_hasAny(lower, ['beverage', 'soft drink', 'juice'])) { food += 3; }
    if (lower.contains('cream') && _hasAny(lower, ['ice cream', 'biscuit', 'chocolate'])) { food += 3; }

    // ── Electronics signals ───────────────────────────────────────────────
    if (_hasAny(lower, ['bis mark', 'bis certification', 'isi mark'])) { electronics += 5; }
    if (_hasAny(lower, ['warranty', 'guarantee', 'service center'])) { electronics += 3; }
    if (_hasAny(lower, ['model number', 'serial number'])) { electronics += 3; }
    if (_hasAny(lower, ['voltage', 'watt', 'ampere', 'frequency'])) { electronics += 3; }
    if (_hasAny(lower, ['mobile', 'phone', 'laptop', 'tablet',
        'headphone', 'earphone', 'speaker', 'charger', 'adapter',
        'battery', 'power bank', 'cable', 'usb', 'hdmi'])) { electronics += 4; }
    if (_hasAny(lower, ['television', ' tv ', 'monitor', 'camera', 'printer',
        'air conditioner', 'refrigerator', 'washing machine',
        'microwave', 'oven', 'mixer', 'grinder'])) { electronics += 4; }
    if (_hasAny(lower, ['fan', 'cooler', 'iron', 'vacuum', 'router', 'modem', 'set top box'])) { electronics += 3; }
    if (_hasAny(lower, ['made in india', 'assembled in'])) { electronics += 2; }

    // ── Household signals ─────────────────────────────────────────────────
    if (_hasAny(lower, ['detergent', 'washing powder', 'dishwash', 'dish soap'])) { household += 5; }
    if (_hasAny(lower, ['floor cleaner', 'surface cleaner', 'toilet cleaner'])) { household += 5; }
    if (_hasAny(lower, ['bleach', 'disinfectant', 'antiseptic'])) { household += 4; }
    if (_hasAny(lower, ['hand wash', 'hand sanitizer', 'body wash', 'shower gel'])) { household += 4; }
    if (_hasAny(lower, ['toothpaste', 'toothbrush', 'mouthwash', 'dental'])) { household += 5; }
    if (_hasAny(lower, ['insecticide', 'mosquito', 'repellent', 'raid'])) { household += 5; }
    if (_hasAny(lower, ['air freshener', 'candle', 'incense', 'agarbatti'])) { household += 3; }
    if (_hasAny(lower, ['broom', 'mop', 'sponge', 'scrubber'])) { household += 4; }
    if (_hasAny(lower, ['paint', 'varnish', 'adhesive', 'glue'])) { household += 3; }
    if (lower.contains('soap') && household > 0) { household += 2; }
    if (lower.contains('bottle') && _hasAny(lower, ['cleaner', 'detergent', 'bleach'])) { household += 2; }
    if (_hasAny(lower, ['tissue', 'napkin', 'towel', 'paper']) && household > 0) { household += 2; }

    // ── Pick winner ───────────────────────────────────────────────────────
    final scores = {
      ProductCategory.medicine: medicine,
      ProductCategory.cosmetics: cosmetics,
      ProductCategory.food: food,
      ProductCategory.electronics: electronics,
      ProductCategory.household: household,
    };

    const threshold = 3;
    final qualified = scores.entries.where((e) => e.value >= threshold).toList();
    if (qualified.isEmpty) { return ProductCategory.unknown; }

    qualified.sort((a, b) => b.value.compareTo(a.value));
    return qualified.first.key;
  }

  bool _hasAny(String text, List<String> keywords) {
    return keywords.any((kw) => text.contains(kw));
  }
}
