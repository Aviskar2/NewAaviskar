import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_ai/main.dart';

void main() {
  testWidgets('Aura AI Home Screen displays feature buttons and switches modes', (WidgetTester tester) async {
    // Build app
    await tester.pumpWidget(const AuraApp());
    await tester.pumpAndSettle();

    // Verify initial header and buttons
    expect(find.text('Aura Assistant'), findsOneWidget);
    expect(find.text('Translation'), findsWidgets);
    expect(find.text('Scanner'), findsWidgets);
    expect(find.text('Documents'), findsWidgets);

    // Initial mode is Translation Active
    expect(find.text('Translation Active'), findsOneWidget);

    // Tap Scanner button
    final scannerBtn = find.text('Scanner').first;
    await tester.tap(scannerBtn);
    await tester.pumpAndSettle();

    // Verify Scanner is now active
    expect(find.text('Scanner Active'), findsOneWidget);

    // Tap Documents button
    final docsBtn = find.text('Documents').first;
    await tester.tap(docsBtn);
    await tester.pumpAndSettle();

    // Verify Documents is now active
    expect(find.text('Documents Active'), findsOneWidget);

    // Tap Translation button
    final transBtn = find.text('Translation').first;
    await tester.tap(transBtn);
    await tester.pumpAndSettle();

    // Verify Translation is active again
    expect(find.text('Translation Active'), findsOneWidget);
  });

  testWidgets('Sending a message in chat adds message to stream', (WidgetTester tester) async {
    await tester.pumpWidget(const AuraApp());
    await tester.pumpAndSettle();

    final inputField = find.byType(TextField);
    expect(inputField, findsOneWidget);

    await tester.enterText(inputField, 'Hello Aura AI');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(find.text('Hello Aura AI'), findsOneWidget);
  });
}

