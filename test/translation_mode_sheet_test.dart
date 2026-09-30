import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scan_sure/services/ocr_service.dart';
import 'package:scan_sure/services/scan_history_service.dart';
import 'package:scan_sure/widgets/translation_mode_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TranslationModeSheet Redesign Widget Tests', () {
    late ScanHistoryService historyService;
    late OcrService ocrService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      historyService = ScanHistoryService();
      ocrService = OcrService();
    });

    testWidgets('Displays only the 2 primary translation choices with clean UI', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TranslationModeSheet(
              ocrService: ocrService,
              historyService: historyService,
            ),
          ),
        ),
      );

      // Verify Header Title & Subtitle
      expect(find.text('How would you like to translate?'), findsOneWidget);
      expect(find.text('Choose a camera or file to get started.'), findsOneWidget);

      // Verify Option 1: Camera
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Translate text using your camera'), findsOneWidget);
      expect(find.byIcon(Icons.photo_camera_rounded), findsOneWidget);

      // Verify Option 2: Browse Files
      expect(find.text('Browse Files'), findsOneWidget);
      expect(find.text('Choose a PDF, Word document, image, or other file'), findsOneWidget);
      expect(find.text('PDF • DOC • DOCX • JPG • PNG'), findsOneWidget);
      expect(find.byIcon(Icons.folder_open_rounded), findsOneWidget);

      // Verify Chevrons are present for both options
      expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(2));

      // Verify old 3-option clutter is completely removed
      expect(find.text('1) Camera & Image Translation'), findsNothing);
      expect(find.text('2) Document Translation (PDF / Word)'), findsNothing);
      expect(find.text('3) Text & Speech Translation'), findsNothing);
      expect(find.text('In-Place Overlay'), findsNothing);
      expect(find.text('Multi-Page & PDF Export'), findsNothing);
      expect(find.text('Instant Typing'), findsNothing);
    });
  });
}
