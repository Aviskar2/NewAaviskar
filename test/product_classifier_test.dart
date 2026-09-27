import 'package:flutter_test/flutter_test.dart';
import 'package:aura_ai/services/product_classifier.dart';

void main() {
  final classifier = ProductClassifier();

  // Helper to assert classification
  void expectCategory(String label, String text, ProductCategory expected) {
    final result = classifier.classify(text);
    test('$label → ${expected.name}', () {
      expect(result, expected,
          reason: 'Expected ${expected.name} but got ${result.name} for: $label');
    });
  }

  group('Medicine', () {
    expectCategory(
      'Dolo 650 tablet',
      'DOLO 650\nParacetamol 650mg Tablets\nSchedule H Prescription Drug\nMfg. Lic. No: M/1234\nEach film coated tablet contains:\nParacetamol IP 650mg\nDosage: As directed by physician\nIP 650',
      ProductCategory.medicine,
    );
    expectCategory(
      'Azithromycin capsules',
      'Azithromycin 500mg Capsules\nSchedule H1\nRx Only\nCapsules\nDosage: 500mg once daily\nMfg. Lic. No: 25/321\nDispensing',
      ProductCategory.medicine,
    );
    expectCategory(
      'Cetirizine syrup',
      'Cetirizine 5mg/5ml Syrup\nEach 5ml contains Cetirizine Dihydrochloride IP 5mg\nSchedule H\nPharmacist: Keep out of reach of children',
      ProductCategory.medicine,
    );
    expectCategory(
      'Metformin tablets',
      'Metformin Hydrochloride 500mg Tablets\nSchedule G\nTablets\nDrug Schedule\nMfg lic: AB/123',
      ProductCategory.medicine,
    );
  });

  group('Cosmetics', () {
    expectCategory(
      'Fair & Lovely cream',
      'Fair & Lovely Advanced Multi-Vitamin Cream\nSkin whitening cream with SPF\nMoisturizer for daily use\nContains: Niacinamide, Vitamin E\nCDSCO Cosmetic Rules',
      ProductCategory.cosmetics,
    );
    expectCategory(
      'Lakme sunscreen',
      'Lakme Sun Expert SPF 50\nSunscreen lotion\nParaben free\nFace wash before applying\nLotion for daily protection',
      ProductCategory.cosmetics,
    );
    expectCategory(
      'Head & Shoulders shampoo',
      'Head & Shoulders Classic Clean Shampoo\nAnti-dandruff shampoo\nContains: Zinc Pyrithione\nConditioner not required\nHair oil alternative',
      ProductCategory.cosmetics,
    );
    expectCategory(
      'Nivea deodorant',
      'Nivea Black & White Invisible Deodorant\nBody spray for 48hr protection\nEau de toilette\nPerfume for men\nDeodorant roll-on',
      ProductCategory.cosmetics,
    );
    expectCategory(
      'L\'Oreal Revitalift serum',
      'L\'Oreal Paris Revitalift Serum\nAnti-ageing serum with Retinol\nHyaluronic Acid + Vitamin C\nAnti aging formula\nGlycolic acid peel',
      ProductCategory.cosmetics,
    );
  });

  group('Food', () {
    expectCategory(
      'Maggi noodles',
      'Maggi 2-Minute Noodles\nMasala flavour\nFSSAI Lic: 10014022000951\nIngredients: Wheat flour, Salt, Spices\nNutritional Information per 100g\nBest before 12 months from mfg\nNon-veg',
      ProductCategory.food,
    );
    expectCategory(
      'Parle-G biscuits',
      'Parle-G Gluco Biscuits\nFSSAI: 10014022000951\nIngredients: Wheat flour, Sugar, Palm oil\nNutrition Facts per 100g: Energy 450kcal\nBest before 6 months\nBiscuit\nVeg',
      ProductCategory.food,
    );
    expectCategory(
      'Amul butter',
      'Amul Pasteurised Butter\nFSSAI Lic No: 10020042001289\nIngredients: Cream, Salt\nNutritional Information:\nTotal Fat 82g, Saturated Fat 51g\nPer 100g\nShelf life: 12 months\nGhee alternative',
      ProductCategory.food,
    );
    expectCategory(
      'Tata Salt',
      'Tata Iodised Salt 1kg\nPackaged food\nFSSAI: 10018012000146\nIngredients: Salt, Potassium Iodate\nBest before 24 months\nSpice\nMaida-free',
      ProductCategory.food,
    );
    expectCategory(
      'Top Ramen noodles',
      'Nissin Top Ramen Curry\nNoodles\nFSSAI: 10020042000432\nIngredients: Noodle cake (Wheat flour, Palm oil)\nPer serving: Energy 380kcal\nChips alternative\nSnack',
      ProductCategory.food,
    );
    expectCategory(
      'Coca-Cola',
      'Coca-Cola 300ml\nBeverage\nFSSAI: 10014023000789\nIngredients: Carbonated water, Sugar\nSoft drink\nPer 100ml: Energy 42kcal\nBest before 9 months',
      ProductCategory.food,
    );
  });

  group('Electronics', () {
    expectCategory(
      'Samsung phone',
      'Samsung Galaxy S24 Ultra\nMobile Phone\nBIS Mark: R-41123456\nWarranty: 12 months manufacturer\nModel number: SM-S928B\nSerial number: R5CX123ABCD\nBattery: 5000mAh\nCharger: 45W USB-C\nMade in India',
      ProductCategory.electronics,
    );
    expectCategory(
      'Boat headphones',
      'boAt Rockerz 450\nHeadphone\nBIS Certification: R-4198761\nWarranty: 1 year\nBattery: 750mAh\nBluetooth: 5.0\nCharger: USB-C\nMade in India',
      ProductCategory.electronics,
    );
    expectCategory(
      'HP laptop',
      'HP Pavilion 15\nLaptop\nModel number: 15-eh2031au\nSerial number: 5CG3214XYZ\nWarranty: 1 year standard\nBattery: 41Wh\nVoltage: 19.5V\nAdapter: 65W\nAssembled in China',
      ProductCategory.electronics,
    );
    expectCategory(
      'LG refrigerator',
      'LG 260L Double Door Refrigerator\nModel number: GL-I292RPZU\nSerial number: 404KRGZZZZZ\nVoltage: 230V, 50Hz\nWarranty: 1 year product + 10 years compressor\nMade in India',
      ProductCategory.electronics,
    );
  });

  group('Household', () {
    expectCategory(
      'Surf Excel detergent',
      'Surf Excel Easy Wash Detergent Powder\n1kg\nWashing powder\nDetergent for machine & hand wash\nIngredients: Sodium carbonate, Linear alkylbenzene sulfonate\nKeep away from children',
      ProductCategory.household,
    );
    expectCategory(
      'Colgate toothpaste',
      'Colgate MaxFresh\nToothpaste\nFluoride protection\nMouthwash alternative\nDental care\nNet wt: 150g\nSPF protection for gums',
      ProductCategory.household,
    );
    expectCategory(
      'Lizol floor cleaner',
      'Lizol Disinfectant Floor Cleaner\nCitrus Power\nFloor cleaner\nSurface cleaner\nKills 99.9% germs\nDisinfectant formula\nBottle: 500ml',
      ProductCategory.household,
    );
    expectCategory(
      'Harpic toilet cleaner',
      'Harpic Power Plus Toilet Cleaner\nToilet cleaner\nBleach action\nDisinfectant\nRemoves stains\nBottle: 500ml\nAntiseptic',
      ProductCategory.household,
    );
    expectCategory(
      'Hit insecticide',
      'Hit Anti-Roach Gel\nInsecticide\nKills cockroaches\nMosquito repellent alternative\nRaid formula\nKeep away from food\nRepellent for pests',
      ProductCategory.household,
    );
  });

  group('Edge cases — ambiguous keywords', () {
    expectCategory(
      'Amul ice cream (food, not cosmetics)',
      'Amul Vanilla Ice Cream\nFSSAI: 10014022000951\nIngredients: Milk cream, Sugar\nIce cream\nNutritional Information per 100ml\nBest before 12 months\nVeg',
      ProductCategory.food,
    );
    expectCategory(
      'Mysore Sandal soap (household, not cosmetics)',
      'Mysore Sandal Soap\nSoap with pure sandalwood oil\nHand wash\nAntiseptic properties\nBath soap\nNet wt: 75g',
      ProductCategory.household,
    );
    expectCategory(
      'Bisleri water bottle (food, not household)',
      'Bisleri Mineral Water 1L\nFSSAI: 10020042000432\nBeverage\nShelf life: 12 months\nPackaged drinking water\nPer 100ml: Sodium 5mg',
      ProductCategory.food,
    );
    expectCategory(
      'Nestle cream biscuit (food, not cosmetics)',
      'Nestle Cream Biscuit\nFSSAI: 10014022000951\nIngredients: Wheat flour, Sugar, Palm oil\nCream filling\nNutrition Facts per 100g\nBiscuit\nBest before 6 months',
      ProductCategory.food,
    );
    expectCategory(
      'Vivel soap with aloe (household)',
      'Vivel Aloe Vera Soap\nSoap\nHand wash\nMoisturizing soap\nAloe vera extract\nAntiseptic\nNet wt: 100g',
      ProductCategory.household,
    );
  });

  group('Unknown / low-signal', () {
    expectCategory(
      'Random text with no product signals',
      'Hello world, this is just some random text with no product information at all.',
      ProductCategory.unknown,
    );
    expectCategory(
      'Short label with no signals',
      'Made in India\nPrice: Rs 250',
      ProductCategory.unknown,
    );
  });
}
