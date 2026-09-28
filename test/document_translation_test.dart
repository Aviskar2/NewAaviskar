
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:archive/archive.dart';
import 'package:scan_sure/services/translation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Document Translation Pipeline Tests', () {
    late TranslationService translationService;

    setUp(() {
      translationService = TranslationService();
    });

    tearDown(() async {
      await translationService.dispose();
    });

    test('Supported languages include core Indian languages', () {
      expect(SupportedLanguages.all.any((l) => l.displayName == 'English'), isTrue);
      expect(SupportedLanguages.all.any((l) => l.displayName == 'Hindi'), isTrue);
      expect(SupportedLanguages.all.any((l) => l.displayName == 'Marathi'), isTrue);
      expect(SupportedLanguages.all.any((l) => l.displayName == 'Tamil'), isTrue);
      expect(SupportedLanguages.all.any((l) => l.displayName == 'Gujarati'), isTrue);
    });

    test('PDF Document Generation & Extraction Round-Trip', () async {
      // Create a test PDF in memory
      final PdfDocument document = PdfDocument();
      final PdfPage page = document.pages.add();
      final PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, 12);

      page.graphics.drawString(
        'Contract Agreement: Section 1. The tenant agrees to pay rent on time.',
        font,
        bounds: const Rect.fromLTWH(0, 0, 400, 50),
      );

      final bytes = await document.save();
      document.dispose();

      // Read back with PdfTextExtractor
      final readDoc = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(readDoc);
      final text = extractor.extractText();
      readDoc.dispose();

      expect(text, contains('Contract Agreement'));
      expect(text, contains('tenant'));
    });

    test('DOCX XML Extraction and UTF-8 Decoding Test', () async {
      // Create a synthetic DOCX archive
      final archive = Archive();
      const sampleXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:pPr><w:pStyle w:val="Heading1"/></w:pPr>
      <w:r><w:t>Rental Agreement</w:t></w:r>
    </w:p>
    <w:p>
      <w:r><w:t>Clause 1: Monthly rent shall be ₹25,000 payable on 1st of every month.</w:t></w:r>
    </w:p>
  </w:body>
</w:document>''';

      final xmlBytes = utf8.encode(sampleXml);
      archive.addFile(ArchiveFile('word/document.xml', xmlBytes.length, xmlBytes));

      final encoder = ZipEncoder();
      final zipBytes = encoder.encode(archive)!;

      // Extract using docx logic
      final decodedArchive = ZipDecoder().decodeBytes(zipBytes);
      final docFile = decodedArchive.files.firstWhere((f) => f.name == 'word/document.xml');
      final xmlContent = utf8.decode(docFile.content as List<int>);

      final paragraphRegex = RegExp(r'<w:p(?:[^>]*)>(.*?)</w:p>', dotAll: true);
      final textRegex = RegExp(r'<w:t(?:[^>]*)>(.*?)</w:t>', dotAll: true);

      final matches = paragraphRegex.allMatches(xmlContent);
      final paragraphs = <String>[];

      for (final m in matches) {
        final pXml = m.group(1) ?? '';
        final tMatches = textRegex.allMatches(pXml);
        final pText = tMatches
            .map((tm) => tm.group(1) ?? '')
            .map((t) => t.replaceAll(RegExp(r'<[^>]+>'), ''))
            .join('')
            .trim();
        if (pText.isNotEmpty) {
          paragraphs.add(pText);
        }
      }

      expect(paragraphs.length, equals(2));
      expect(paragraphs[0], equals('Rental Agreement'));
      expect(paragraphs[1], contains('₹25,000'));
    });

    test('TranslationService handles batch translations and same-language correctly', () async {
      final input = ['Hello world', 'Welcome to our service'];
      final results = await translationService.translateBatch(
        input,
        from: SupportedLanguages.english,
        to: SupportedLanguages.english,
      );

      expect(results[0], equals('Hello world'));
      expect(results[1], equals('Welcome to our service'));
    });

    test('Indic / Gujarati Unicode PDF Generation without font errors', () async {
      final PdfDocument document = PdfDocument();
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      // Gujarati & Indic test strings (same as user screenshot)
      const gujaratiText = 'સેમેસ્ટર 1: 82.93% - બેચલર ઓફ મેનેજમેન્ટ';
      final textPainter = TextPainter(
        text: const TextSpan(
          text: gujaratiText,
          style: TextStyle(fontSize: 20, color: Color(0xFF0F172A)),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(maxWidth: 400);
      textPainter.paint(canvas, Offset.zero);

      final image = await recorder.endRecording().toImage(400, 200);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      expect(byteData, isNotNull);

      final pdfPage = document.pages.add();
      final pdfBitmap = PdfBitmap(byteData!.buffer.asUint8List());
      pdfPage.graphics.drawImage(
        pdfBitmap,
        Rect.fromLTWH(0, 0, pdfPage.getClientSize().width, pdfPage.getClientSize().height),
      );

      final bytes = await document.save();
      document.dispose();
      expect(bytes.isNotEmpty, isTrue);
    });
  });
}
