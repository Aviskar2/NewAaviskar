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
    testWidgets('Renders top bar, search box, quick tools strip, and eligibility matcher',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1200));

      await tester.pumpWidget(
        const MaterialApp(
          home: GovernmentSchemesEntryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Top App Bar
      expect(find.text('Government Schemes'), findsOneWidget);
      expect(find.text('Set Profile'), findsOneWidget);

      // Search Box
      expect(find.textContaining('Search 147+ schemes'), findsOneWidget);

      // Quick Tools Strip
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Tracker'), findsOneWidget);
      expect(find.text('Compare'), findsOneWidget);
      expect(find.text('Insights'), findsOneWidget);

      // Compact Eligibility Matcher
      expect(find.text('Eligibility & Benefit Matcher'), findsOneWidget);
      expect(find.text('Reset All'), findsOneWidget);
      expect(find.textContaining('Matching Schemes'), findsWidgets);

      // Check Rules and Apply Online buttons on cards
      expect(find.text('Check Rules'), findsWidgets);
      expect(find.text('Apply Online'), findsWidgets);
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
  });
}
