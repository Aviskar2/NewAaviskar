import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scan_sure/main.dart';
import 'package:scan_sure/screens/splash_screen.dart';
import 'package:scan_sure/services/app_startup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppStartupService.resetForTesting();
  });

  group('SplashScreen Widget & Startup Tests', () {
    testWidgets('SplashScreen displays centered ScanSure logo and clean minimal UI',
        (WidgetTester tester) async {
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            isLightMode: true,
            duration: const Duration(seconds: 2),
            onSplashComplete: () => completed = true,
          ),
        ),
      );

      // Verify ScanSure logo emblem and wordmark exist
      expect(find.byIcon(Icons.security_rounded), findsOneWidget);
      expect(find.text('ScanSure'), findsOneWidget);

      // Verify no spinners, loading indicators, or unnecessary buttons
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.text('Loading...'), findsNothing);

      // Verify centered layout
      final centerFinder = find.byType(Center);
      expect(centerFinder, findsWidgets);

      // Fast-forward 1 second — splash should still be visible, completed should be false
      await tester.pump(const Duration(seconds: 1));
      expect(completed, isFalse);

      // Fast-forward another 1 second to reach the 2-second minimum
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(completed, isTrue);
    });

    testWidgets('AppStartupService runs safely without throwing or crashing',
        (WidgetTester tester) async {
      expect(AppStartupService.isInitialized, isFalse);
      await AppStartupService.initialize();
      expect(AppStartupService.isInitialized, isTrue);
    });

    testWidgets('ScanSureApp starts with Splash then transitions to MainNavigation',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ScanSureApp(
          splashDuration: Duration(seconds: 2),
        ),
      );

      // Immediately after start, SplashScreen is visible
      expect(find.byKey(const ValueKey('splash_screen')), findsOneWidget);
      expect(find.byKey(const ValueKey('main_navigation')), findsNothing);

      // Advance by 1 second — still on splash
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('splash_screen')), findsOneWidget);

      // Advance by another 1.5 seconds — finishes 2-second timer + transition
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();

      // Now MainNavigation is visible and SplashScreen is gone
      expect(find.byKey(const ValueKey('main_navigation')), findsOneWidget);
      expect(find.byKey(const ValueKey('splash_screen')), findsNothing);

      // Verify home screen elements are loaded
      expect(find.text('Features'), findsOneWidget);
    });

    testWidgets('Rebuilding app with theme change does NOT re-show splash screen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ScanSureApp(
          splashDuration: Duration(seconds: 2),
        ),
      );

      // Let splash finish
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('main_navigation')), findsOneWidget);

      // Trigger rebuild (e.g. pumpWidget with same widget)
      await tester.pumpWidget(
        const ScanSureApp(
          splashDuration: Duration(seconds: 2),
        ),
      );
      await tester.pump();

      // MainNavigation must stay active and NOT reset to splash screen
      expect(find.byKey(const ValueKey('main_navigation')), findsOneWidget);
    });
  });
}
