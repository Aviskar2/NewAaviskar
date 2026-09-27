import 'package:flutter_test/flutter_test.dart';
import 'package:aura_ai/main.dart';

void main() {
  testWidgets('NyayaSathi AI Home Screen displays safety tools and header', (WidgetTester tester) async {
    // Build app
    await tester.pumpWidget(const AuraApp());
    await tester.pumpAndSettle();

    // Verify initial header and safety pillar buttons
    expect(find.text('NyayaSathi AI'), findsOneWidget);
    expect(find.text('Features'), findsOneWidget);
    expect(find.text('Legal Risk'), findsWidgets);
    expect(find.text('Bill & GST'), findsWidgets);
    expect(find.text('Live Translate'), findsWidgets);
    expect(find.text('Scanner Hub'), findsWidgets);
  });

  testWidgets('Tapping Bill & GST card opens Bill Analyzer screen', (WidgetTester tester) async {
    await tester.pumpWidget(const AuraApp());
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
