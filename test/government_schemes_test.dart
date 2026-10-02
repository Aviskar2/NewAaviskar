import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scan_sure/models/government_scheme_model.dart';
import 'package:scan_sure/services/scheme_database.dart';
import 'package:scan_sure/services/scheme_matcher.dart';
import 'package:scan_sure/services/scheme_service.dart';
import 'package:scan_sure/screens/government_schemes/government_schemes_entry_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Government Schemes Unit & Logic Tests', () {
    test('SchemeDatabase contains rich catalog of Central and State schemes', () {
      expect(SchemeDatabase.schemes.isNotEmpty, isTrue);
      final central = SchemeDatabase.schemes.where((s) => s.level == SchemeLevel.central);
      final state = SchemeDatabase.schemes.where((s) => s.level != SchemeLevel.central);
      expect(central.isNotEmpty, isTrue);
      expect(state.isNotEmpty, isTrue);
    });

    test('SchemeMatcher matches schemes based on profile attributes', () {
      final farmerProfile = const CitizenProfile(
        name: 'Ramesh Kumar',
        age: 42,
        gender: 'Male',
        state: 'Uttar Pradesh',
        annualIncome: 120000,
        occupation: 'Farmer',
        isFarmer: true,
        isBPL: true,
      );

      final matches = SchemeMatcher.matchAll(farmerProfile);
      expect(matches.isNotEmpty, isTrue);
      final topMatch = matches.first;
      expect(topMatch.score, greaterThan(0.0));
    });

    test('SchemeService persists and toggles bookmarks correctly', () async {
      final service = SchemeService();
      await service.load();

      const testSchemeId = 'ayushman_bharat_pmjay';
      expect(service.isBookmarked(testSchemeId), isFalse);

      await service.toggleBookmark(testSchemeId);
      expect(service.isBookmarked(testSchemeId), isTrue);

      await service.toggleBookmark(testSchemeId);
      expect(service.isBookmarked(testSchemeId), isFalse);
    });
  });

  group('Government Schemes Redesigned UI Tests', () {
    testWidgets('Renders top bar, search box, and eligibility matcher',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 5000));

      await tester.pumpWidget(
        const MaterialApp(
          home: GovernmentSchemesEntryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Top App Bar
      expect(find.text('Government Schemes'), findsOneWidget);
      expect(find.text('Saved schemes'), findsOneWidget);

      // Search Box
      expect(find.textContaining('Search 147+ schemes'), findsOneWidget);

      // Matcher trigger
      expect(find.textContaining('Personalize results'), findsOneWidget);

      // View details button on cards (display first 10 cards initially)
      expect(find.text('View scheme details'), findsNWidgets(10));

      // Verify unwanted secondary texts are completely removed
      expect(find.text('0 schemes'), findsNothing);
      expect(find.text('0 pending'), findsNothing);
      expect(find.text('0/3 added'), findsNothing);
      expect(find.text('High fit'), findsNothing);
      expect(find.text('Based on official Ministry criteria • No sign-up required'), findsNothing);
    });

    testWidgets('Header has no hamburger menu and no My Profile tab',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1200));

      await tester.pumpWidget(
        const MaterialApp(
          home: GovernmentSchemesEntryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // No hamburger menu icon
      expect(find.byIcon(Icons.menu_rounded), findsNothing);

      // No My Profile tab in the UI
      expect(find.text('My Profile'), findsNothing);

      // Saved schemes button is present in the header
      expect(find.text('Saved schemes'), findsOneWidget);
    });

    testWidgets('Tapping Personalize results expands inline eligibility matcher',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1600));

      await tester.pumpWidget(
        const MaterialApp(
          home: GovernmentSchemesEntryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Personalize results'));
      await tester.pumpAndSettle();

      expect(find.text('Eligibility & Benefit Matcher'), findsOneWidget);
      expect(find.text('Reset All'), findsOneWidget);
      expect(find.textContaining('Matching Schemes'), findsWidgets);
    });

    testWidgets('More Filters section is collapsed by default and expands with social categories',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1600));

      await tester.pumpWidget(
        const MaterialApp(
          home: GovernmentSchemesEntryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Personalize results to expand matcher
      await tester.tap(find.textContaining('Personalize results'));
      await tester.pumpAndSettle();

      // Social category chips should NOT be visible while collapsed
      expect(find.text('BPL / Antyodaya'), findsNothing);
      expect(find.text('SC / ST'), findsNothing);

      // Tap on More Filters toggle
      await tester.tap(find.textContaining('More Filters'));
      await tester.pumpAndSettle();

      // Social category chips are now visible
      expect(find.text('BPL / Antyodaya'), findsOneWidget);
      expect(find.text('SC / ST'), findsOneWidget);
      expect(find.text('OBC'), findsOneWidget);
      expect(find.text('Person with Disability (PwD)'), findsOneWidget);
      expect(find.text('Women / Widow'), findsOneWidget);
      expect(find.text('Minority Community'), findsOneWidget);
      expect(find.text('Student / Enrolled'), findsOneWidget);
      expect(find.text('Daily Wage / Unorganized'), findsOneWidget);
    });

    testWidgets('Progressive loading loads next batch of schemes on demand',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 8000));

      await tester.pumpWidget(
        const MaterialApp(
          home: GovernmentSchemesEntryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Exactly 10 cards initially
      expect(find.text('View scheme details'), findsNWidgets(10));

      // Tap "Scroll or tap for more"
      final tapForMore = find.textContaining('Scroll or tap for more');
      expect(tapForMore, findsOneWidget);
      await tester.tap(tapForMore);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Now 20 cards are rendered
      expect(find.text('View scheme details'), findsNWidgets(20));
    });

    testWidgets('Searching schemes filters the displayed scheme list',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1200));

      await tester.pumpWidget(
        const MaterialApp(
          home: GovernmentSchemesEntryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Enter search text
      await tester.enterText(find.byType(TextField).first, 'Ayushman');
      await tester.pumpAndSettle();

      expect(find.textContaining('Ayushman'), findsWidgets);
    });

    testWidgets('Filtering by Goa, Student, 3L-8L, and Male applies strict matching',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 3000));

      await tester.pumpWidget(
        const MaterialApp(
          home: GovernmentSchemesEntryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Personalize results to open matcher
      await tester.tap(find.textContaining('Personalize results'));
      await tester.pumpAndSettle();

      // Initially 147 schemes exist in the full database
      expect(find.textContaining('Matching Schemes'), findsWidgets);

      // Select State: Goa
      await tester.tap(find.text('All States'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Goa').last);
      await tester.pumpAndSettle();

      // Select Occupation: Student / Youth
      await tester.tap(find.text('All Occupations'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Student / Youth').last);
      await tester.pumpAndSettle();

      // Select Income: ₹3.0L – ₹8.0 Lakh
      await tester.tap(find.text('Any Income'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('₹3.0L – ₹8.0 Lakh').last);
      await tester.pumpAndSettle();

      // Select Age & Gender: Male (All ages)
      await tester.tap(find.text('Any'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Male (All ages)').last);
      await tester.pumpAndSettle();

      // Verify that candidate count on the button is strictly reduced (NOT 147)
      final buttonFinder = find.ancestor(
        of: find.textContaining('Matching Schemes'),
        matching: find.byType(ElevatedButton),
      );
      expect(buttonFinder, findsOneWidget);
      expect(find.textContaining('Show 147 Matching Schemes'), findsNothing);

      // Tap the action button to apply filters
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 2000));

      // Verify that only the relevant matching schemes are displayed and farmer/women-only schemes are excluded
      expect(find.text('PM-KISAN'), findsNothing);
      expect(find.text('Beti Bachao Beti Padhao'), findsNothing);
      expect(find.text('Sukanya Samriddhi Yojana'), findsNothing);
    });
  });
}
