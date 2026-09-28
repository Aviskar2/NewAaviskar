import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_sure/core/legal/constants/sample_offer_letters.dart';
import 'package:scan_sure/core/legal/models/offer_letter_models.dart';
import 'package:scan_sure/screens/legal_analyzer/offer_letter_comparison_screen.dart';
import 'package:scan_sure/screens/legal_analyzer/offer_letter_result_screen.dart';
import 'package:scan_sure/services/legal/offer_letter_analyzer_service.dart';
import 'package:scan_sure/services/ocr_service.dart';

void main() {
  group('Offer Letter Comparison Engine Tests', () {
    late OfferLetterAnalyzerService service;

    setUp(() {
      service = OfferLetterAnalyzerService();
    });

    test('Compares realistic Indian IT offers and detects bonds, notice periods & beneficial trade-offs', () async {
      final result = await service.compareOffers(
        previousOfferText: SampleOfferLetters.previousCompanyOffer,
        newOfferText: SampleOfferLetters.newCompanyOffer,
      );

      // Verify Extraction
      expect(result.offerA.ctcTotal, isNotNull);
      expect(result.offerA.ctcTotal, greaterThanOrEqualTo(11.0));
      expect(result.offerA.hasBond, isFalse);
      expect(result.offerA.noticePeriodDays, equals(60));

      expect(result.offerB.ctcTotal, isNotNull);
      expect(result.offerB.ctcTotal, greaterThanOrEqualTo(18.0));
      expect(result.offerB.hasBond, isTrue);
      expect(result.offerB.noticePeriodDays, equals(90));
      expect(result.offerB.hasNonCompete, isTrue);

      // Verify Dimensional Scoring
      expect(result.financialScoreB, greaterThan(result.financialScoreA));
      expect(result.legalFreedomScoreA, greaterThan(result.legalFreedomScoreB));
      expect(result.workLifeScoreA, greaterThan(result.workLifeScoreB));

      // Verify Metric comparisons
      expect(result.comparisons.length, greaterThanOrEqualTo(5));
      final noticeMetric = result.comparisons.firstWhere((c) => c.metricTitle.contains('Notice Period'));
      expect(noticeMetric.favorable, equals(OfferChoice.offerA)); // 60d is better than 90d

      final bondMetric = result.comparisons.firstWhere((c) => c.metricTitle.contains('Bond'));
      expect(bondMetric.favorable, equals(OfferChoice.offerA)); // zero bond is safer

      // Verify Actionable Advice & Red Flags
      expect(result.keyRisksNew, isNotEmpty);
      expect(result.keyAdvantagesNew, isNotEmpty);
      expect(result.negotiationActionItems, isNotEmpty);
      expect(result.legalAdvisory, contains('Section 27'));
      expect(result.legalAdvisory, contains('Section 74'));

      // Verify Winner: Because B has high CTC (+18.5 LPA) but severe bond & 90d notice, it flags conditional or evaluated
      expect(result.winner, isIn([OfferWinner.conditional, OfferWinner.offerB]));
    });

    test('Identifies clear winner when new offer is unambiguously superior without traps', () async {
      const cleanNewOffer = '''
GOOGLE INDIA PRIVATE LIMITED
OFFER LETTER
Candidate: Rahul Verma
Position: Senior Staff Engineer
CTC: INR 35,00,000/- per annum (Fixed: Rs. 30,00,000, Bonus: Rs. 5,00,000)
Work Mode: Remote / Hybrid
Notice Period: 30 Days
No employment bond or liquidated damages.
''';

      final result = await service.compareOffers(
        previousOfferText: SampleOfferLetters.previousCompanyOffer,
        newOfferText: cleanNewOffer,
      );

      expect(result.offerB.ctcTotal, greaterThan(30.0));
      expect(result.offerB.hasBond, isFalse);
      expect(result.offerB.noticePeriodDays, equals(30));
      expect(result.winner, equals(OfferWinner.offerB));
      expect(result.scoreB, greaterThan(result.scoreA));
    });

    test('Identifies previous offer as more favorable when new offer has trivial hike and massive penalties', () async {
      const predatoryLowHikeOffer = '''
TECH SWEATSHOP PRIVATE LIMITED
OFFER LETTER
CTC: INR 12,50,000/- per annum (Fixed: Rs. 8,00,000, Variable: Rs. 4,50,000)
Notice Period: 90 Days strict notice
Service Bond: Mandatory 36 months bond with Rs. 5,00,000 penalty for leaving early
Non-compete: 2 years restraint from working in software
Work Mode: 6 Days a week on-site
''';

      final result = await service.compareOffers(
        previousOfferText: SampleOfferLetters.previousCompanyOffer,
        newOfferText: predatoryLowHikeOffer,
      );

      expect(result.scoreA, greaterThan(result.scoreB));
      expect(result.winner, equals(OfferWinner.offerA));
    });
  });

  group('Offer Letter UI Screen Tests', () {
    testWidgets('Renders OfferLetterComparisonScreen and loads demo offers', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final ocrService = OcrService();

      await tester.pumpWidget(
        MaterialApp(
          home: OfferLetterComparisonScreen(ocrService: ocrService),
        ),
      );

      expect(find.text('Offer Letter Comparison'), findsOneWidget);
      expect(find.text('1. PREVIOUS / CURRENT COMPANY OFFER'), findsOneWidget);
      expect(find.text('2. NEW PROSPECTIVE OFFER LETTER'), findsOneWidget);
      expect(find.text('Upload Both Offers to Compare'), findsOneWidget);

      // Tap 'Try Demo'
      final demoButton = find.text('Try Demo');
      expect(demoButton, findsOneWidget);
      await tester.tap(demoButton);
      await tester.pumpAndSettle();

      // Verify that demo offers are loaded and button is active
      expect(find.text('Demo: TCS / Enterprise (12 LPA)'), findsOneWidget);
      expect(find.text('Demo: FinNext Tech (18.5 LPA + Bond)'), findsOneWidget);
      expect(find.text('Compare & Find Which is More Beneficial'), findsOneWidget);
    });

    testWidgets('Renders OfferLetterResultScreen with comparison tabs and verdicts', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = OfferLetterAnalyzerService();
      final result = await service.compareOffers(
        previousOfferText: SampleOfferLetters.previousCompanyOffer,
        newOfferText: SampleOfferLetters.newCompanyOffer,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: OfferLetterResultScreen(result: result),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Offer Letter Comparison'), findsOneWidget);
      expect(find.text('KEY DIMENSION BREAKDOWN'), findsOneWidget);
      expect(find.text('Side-by-Side'), findsOneWidget);
      expect(find.text('Risks & Bonds'), findsOneWidget);
      expect(find.text('Negotiation'), findsOneWidget);

      // Tap on Risks & Bonds tab
      await tester.tap(find.text('Risks & Bonds'));
      await tester.pumpAndSettle();
      expect(find.text('Indian Contract Act Statutory Safeguards'), findsOneWidget);

      // Tap on Negotiation tab
      await tester.tap(find.text('Negotiation'));
      await tester.pumpAndSettle();
      expect(find.text('Strategic Counter-Offer Guide'), findsOneWidget);
      expect(find.text('Copy Email to Clipboard'), findsOneWidget);
    });
  });
}
