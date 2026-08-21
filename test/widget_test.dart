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
    expect(find.text('Document Analyzer'), findsWidgets);
    expect(find.text('Bill'), findsWidgets);
    expect(find.text('Translation'), findsWidgets);
    expect(find.text('Scanner'), findsWidgets);
    expect(find.text('Documents'), findsWidgets);

    // Initial mode is 'Upload to Begin'
    expect(find.text('Upload to Begin'), findsOneWidget);
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
