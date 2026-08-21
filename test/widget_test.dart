import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_ai/main.dart';

void main() {
  testWidgets('NyayaSathi AI Home Screen displays safety tools and header', (WidgetTester tester) async {
    // Build app
    await tester.pumpWidget(const AuraApp());
    await tester.pumpAndSettle();

    // Verify initial header and safety pillar buttons
    expect(find.text('NyayaSathi AI'), findsOneWidget);
    expect(find.text('Universal Safety Tools'), findsOneWidget);
    expect(find.text('Legal Risk'), findsWidgets);
    expect(find.text('Bill & GST'), findsWidgets);
    expect(find.text('Medicine'), findsWidgets);
    expect(find.text('Food Safety'), findsWidgets);
    expect(find.text('Live Translate'), findsWidgets);
  });

  testWidgets('Sending a message in chat adds message to stream', (WidgetTester tester) async {
    await tester.pumpWidget(const AuraApp());
    await tester.pumpAndSettle();

    final inputField = find.byType(TextField);
    expect(inputField, findsOneWidget);

    await tester.enterText(inputField, 'Hello NyayaSathi');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Hello NyayaSathi'), findsOneWidget);
  });
}
