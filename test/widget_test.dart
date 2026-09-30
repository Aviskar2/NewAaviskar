import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scan_sure/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ScanSure Home Screen displays safety tools and header', (WidgetTester tester) async {
    // Build app and advance past 2-second splash screen and transition
    await tester.pumpWidget(const ScanSureApp());
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();

    // Verify initial header and safety pillar buttons
    expect(find.text('ScanSure'), findsOneWidget);
    expect(find.text('Features'), findsOneWidget);
    expect(find.text('Legal Risk'), findsWidgets);
    expect(find.text('Bill & GST'), findsWidgets);
    expect(find.text('Live Translate'), findsWidgets);
    expect(find.text('Scanner Hub'), findsWidgets);
  });

  testWidgets('Tapping Bill & GST card opens Bill Analyzer screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ScanSureApp());
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();

    // Tap on Bill & GST card
    final billCard = find.text('Bill & GST');
    expect(billCard, findsWidgets);
    await tester.tap(billCard.first);
    await tester.pumpAndSettle();

    // Verify Bill Analyzer Entry screen is loaded
    expect(find.text('Indian Bill & Invoice Analyzer'), findsOneWidget);
  });
}
