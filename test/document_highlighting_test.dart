import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scan_sure/core/legal/models/document_highlight.dart';
import 'package:scan_sure/core/legal/models/legal_clause.dart';
import 'package:scan_sure/core/legal/models/legal_finding.dart';
import 'package:scan_sure/core/legal/models/ocr_document.dart';
import 'package:scan_sure/services/legal/legal_orchestrator.dart';
import 'package:scan_sure/services/legal/pipeline/document_highlight_mapper.dart';
import 'package:scan_sure/widgets/legal_analyzer/highlighted_document_paper.dart';

LegalFinding createTestFinding({
  required String id,
  String? clauseId,
  LegalClauseType clauseType = LegalClauseType.upfrontFeeScam,
  required LegalRiskSeverity severity,
  required String title,
  required String simpleExplanation,
  String legalExplanation = 'Assessment under applicable Indian statutory law.',
  required String rawExcerpt,
  int pageIndex = 0,
  String recommendedAction = 'Review and renegotiate terms before execution.',
  double confidence = 0.90,
  String? evidence,
  DocumentHighlight? highlight,
}) {
  return LegalFinding(
    id: id,
    clauseId: clauseId,
    clauseType: clauseType,
    severity: severity,
    title: title,
    simpleExplanation: simpleExplanation,
    legalExplanation: legalExplanation,
    rawExcerpt: rawExcerpt,
    pageIndex: pageIndex,
    recommendedAction: recommendedAction,
    confidence: confidence,
    evidence: evidence,
    highlight: highlight,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Section 84: Final Acceptance Test Suite', () {
    const acceptanceDocText =
        'LOAN AGREEMENT\n'
        '1. Loan Terms\n'
        'The Borrower shall pay a registration fee of ₹50,000 before the loan is released.\n'
        '2. Repayment Schedule\n'
        'Monthly installments shall begin on the first of next month.';

    test('Section 84: Complete Acceptance Test Pipeline', () async {
      final orchestrator = LegalOrchestrator();

      // Create OCR document with word/token and line bounding boxes
      final doc = OcrDocument(
        rawText: acceptanceDocText,
        overallConfidence: 0.96,
        scannedAt: DateTime(2024, 10, 1),
        pages: [
          OcrPage(
            pageIndex: 0,
            pageSize: const Size(600, 800),
            averageConfidence: 0.96,
            lines: [
              const OcrLine(
                text: 'LOAN AGREEMENT',
                confidence: 0.98,
                pageIndex: 0,
                boundingBox: OcrBoundingBox(left: 0.1, top: 0.05, width: 0.8, height: 0.04),
              ),
              const OcrLine(
                text: '1. Loan Terms',
                confidence: 0.97,
                pageIndex: 0,
                boundingBox: OcrBoundingBox(left: 0.1, top: 0.12, width: 0.4, height: 0.03),
              ),
              const OcrLine(
                text: 'The Borrower shall pay a registration fee of ₹50,000 before the loan is released.',
                confidence: 0.95,
                pageIndex: 0,
                boundingBox: OcrBoundingBox(left: 0.1, top: 0.18, width: 0.8, height: 0.04),
                tokens: [
                  OcrToken(text: 'The', confidence: 0.98, pageIndex: 0, boundingBox: OcrBoundingBox(left: 0.10, top: 0.18, width: 0.04, height: 0.03)),
                  OcrToken(text: 'Borrower', confidence: 0.98, pageIndex: 0, boundingBox: OcrBoundingBox(left: 0.15, top: 0.18, width: 0.08, height: 0.03)),
                  OcrToken(text: 'shall', confidence: 0.98, pageIndex: 0, boundingBox: OcrBoundingBox(left: 0.24, top: 0.18, width: 0.05, height: 0.03)),
                  OcrToken(text: 'pay', confidence: 0.98, pageIndex: 0, boundingBox: OcrBoundingBox(left: 0.30, top: 0.18, width: 0.04, height: 0.03)),
                  OcrToken(text: 'a', confidence: 0.98, pageIndex: 0, boundingBox: OcrBoundingBox(left: 0.35, top: 0.18, width: 0.02, height: 0.03)),
                  OcrToken(text: 'registration', confidence: 0.98, pageIndex: 0, boundingBox: OcrBoundingBox(left: 0.38, top: 0.18, width: 0.12, height: 0.03)),
                  OcrToken(text: 'fee', confidence: 0.98, pageIndex: 0, boundingBox: OcrBoundingBox(left: 0.51, top: 0.18, width: 0.04, height: 0.03)),
                  OcrToken(text: 'of', confidence: 0.98, pageIndex: 0, boundingBox: OcrBoundingBox(left: 0.56, top: 0.18, width: 0.03, height: 0.03)),
                  OcrToken(text: '₹50,000', confidence: 0.98, pageIndex: 0, boundingBox: OcrBoundingBox(left: 0.60, top: 0.18, width: 0.08, height: 0.03)),
                  OcrToken(text: 'before', confidence: 0.98, pageIndex: 0, boundingBox: OcrBoundingBox(left: 0.69, top: 0.18, width: 0.06, height: 0.03)),
                  OcrToken(text: 'the', confidence: 0.98, pageIndex: 0, boundingBox: OcrBoundingBox(left: 0.76, top: 0.18, width: 0.04, height: 0.03)),
                  OcrToken(text: 'loan', confidence: 0.98, pageIndex: 0, boundingBox: OcrBoundingBox(left: 0.81, top: 0.18, width: 0.04, height: 0.03)),
                  OcrToken(text: 'is', confidence: 0.98, pageIndex: 0, boundingBox: OcrBoundingBox(left: 0.86, top: 0.18, width: 0.02, height: 0.03)),
                  OcrToken(text: 'released.', confidence: 0.98, pageIndex: 0, boundingBox: OcrBoundingBox(left: 0.89, top: 0.18, width: 0.08, height: 0.03)),
                ],
              ),
              const OcrLine(
                text: '2. Repayment Schedule',
                confidence: 0.97,
                pageIndex: 0,
                boundingBox: OcrBoundingBox(left: 0.1, top: 0.25, width: 0.5, height: 0.03),
              ),
              const OcrLine(
                text: 'Monthly installments shall begin on the first of next month.',
                confidence: 0.96,
                pageIndex: 0,
                boundingBox: OcrBoundingBox(left: 0.1, top: 0.30, width: 0.8, height: 0.03),
              ),
            ],
          ),
        ],
      );

      final result = await orchestrator.analyze(doc, enableAiEnhancement: false);

      // 1. Detect the potentially suspicious payment term
      expect(result.findings.isNotEmpty, isTrue, reason: 'Must detect suspicious loan fee clause');
      final upfrontFeeFinding = result.findings.firstWhere(
        (f) => f.rawExcerpt.contains('registration fee') || f.title.toLowerCase().contains('fee') || f.title.toLowerCase().contains('upfront'),
      );

      // 2. Create a finding with valid ID and severity
      expect(upfrontFeeFinding.id, isNotEmpty);
      expect(upfrontFeeFinding.severity, isIn([LegalRiskSeverity.high, LegalRiskSeverity.medium]));

      // 3. Store the exact sentence (never AI hallucinated)
      expect(upfrontFeeFinding.highlight, isNotNull);
      final highlight = upfrontFeeFinding.highlight!;
      expect(highlight.exactText, contains('registration fee'));
      expect(acceptanceDocText, contains(highlight.exactText));

      // 4. Identify the correct page (1-indexed pageNumber == 1)
      expect(highlight.pageNumber, equals(1));
      expect(highlight.pageIndex, equals(0));

      // 5. Identify the exact words / coordinates
      expect(highlight.rectangles.isNotEmpty, isTrue);

      // 6. Calculate bounding boxes
      final mainRect = highlight.rectangles.first;
      expect(mainRect.x, greaterThanOrEqualTo(0.0));
      expect(mainRect.x + mainRect.width, lessThanOrEqualTo(1.0));
      expect(mainRect.y, greaterThanOrEqualTo(0.0));
      expect(mainRect.y + mainRect.height, lessThanOrEqualTo(1.0));

      // 7. Verify coordinates are normalized and match line 3 area (top ~ 0.18)
      expect(mainRect.top, closeTo(0.18, 0.05));

      // 8. Finding links directly to highlight
      expect(highlight.findingId, equals(upfrontFeeFinding.id));
      expect(highlight.hasValidLocation, isTrue);
    });
  });

  group('Section 58, 62, 63: Location Mapping & Slicing', () {
    const mapper = DocumentHighlightMapper();

    test('Section 62: Word-Level Highlighting - smallest meaningful region', () {
      const docText = 'The Borrower shall pay a registration fee of ₹50,000 before the loan is released.';
      final doc = OcrDocument(
        rawText: docText,
        overallConfidence: 0.95,
        scannedAt: DateTime(2024, 10, 1),
        pages: const [
          OcrPage(
            pageIndex: 0,
            pageSize: Size(600, 800),
            averageConfidence: 0.95,
            lines: [
              OcrLine(
                text: docText,
                confidence: 0.95,
                pageIndex: 0,
                boundingBox: OcrBoundingBox(left: 0.1, top: 0.2, width: 0.8, height: 0.05),
                tokens: [
                  OcrToken(text: 'The', confidence: 0.95, pageIndex: 0, boundingBox: OcrBoundingBox(left: 0.10, top: 0.2, width: 0.04, height: 0.03)),
                  OcrToken(text: 'Borrower', confidence: 0.95, pageIndex: 0, boundingBox: OcrBoundingBox(left: 0.15, top: 0.2, width: 0.08, height: 0.03)),
                  OcrToken(text: 'shall', confidence: 0.95, pageIndex: 0, boundingBox: OcrBoundingBox(left: 0.24, top: 0.2, width: 0.05, height: 0.03)),
                  OcrToken(text: 'pay', confidence: 0.95, pageIndex: 0, boundingBox: OcrBoundingBox(left: 0.30, top: 0.2, width: 0.04, height: 0.03)),
                  OcrToken(text: 'a', confidence: 0.95, pageIndex: 0, boundingBox: OcrBoundingBox(left: 0.35, top: 0.2, width: 0.02, height: 0.03)),
                  OcrToken(text: 'registration', confidence: 0.95, pageIndex: 0, boundingBox: OcrBoundingBox(left: 0.38, top: 0.2, width: 0.12, height: 0.03)),
                  OcrToken(text: 'fee', confidence: 0.95, pageIndex: 0, boundingBox: OcrBoundingBox(left: 0.51, top: 0.2, width: 0.04, height: 0.03)),
                  OcrToken(text: 'of', confidence: 0.95, pageIndex: 0, boundingBox: OcrBoundingBox(left: 0.56, top: 0.2, width: 0.03, height: 0.03)),
                  OcrToken(text: '₹50,000', confidence: 0.95, pageIndex: 0, boundingBox: OcrBoundingBox(left: 0.60, top: 0.2, width: 0.08, height: 0.03)),
                  OcrToken(text: 'before', confidence: 0.95, pageIndex: 0, boundingBox: OcrBoundingBox(left: 0.69, top: 0.2, width: 0.06, height: 0.03)),
                ],
              ),
            ],
          ),
        ],
      );

      final finding = createTestFinding(
        id: 'finding_001',
        clauseId: 'clause_001',
        title: 'Upfront Registration Fee',
        simpleExplanation: 'Requires upfront payment',
        rawExcerpt: 'registration fee of ₹50,000',
        severity: LegalRiskSeverity.high,
      );

      final highlight = mapper.createHighlightForFinding(
        document: doc,
        finding: finding,
        highlightId: 'highlight_001',
      );

      expect(highlight.hasValidLocation, isTrue);
      expect(highlight.exactText, equals('registration fee of ₹50,000'));
      expect(highlight.rectangles.length, equals(1));

      // Bounding box must cover "registration fee of ₹50,000" (~0.38 to 0.68), NOT entire line (0.1 to 0.9)
      final rect = highlight.rectangles.first;
      expect(rect.left, greaterThanOrEqualTo(0.35));
      expect(rect.right, lessThanOrEqualTo(0.70));
    });

    test('Section 63: Multi-Line Clause Highlighting generates individual rectangles', () {
      const line1 = 'The Borrower agrees to pay a registration fee';
      const line2 = 'of ₹50,000 before the loan amount is released.';
      const docText = '$line1\n$line2';

      final doc = OcrDocument(
        rawText: docText,
        overallConfidence: 0.95,
        scannedAt: DateTime(2024, 10, 1),
        pages: const [
          OcrPage(
            pageIndex: 0,
            pageSize: Size(600, 800),
            averageConfidence: 0.95,
            lines: [
              OcrLine(
                text: line1,
                confidence: 0.95,
                pageIndex: 0,
                boundingBox: OcrBoundingBox(left: 0.1, top: 0.20, width: 0.7, height: 0.04),
              ),
              OcrLine(
                text: line2,
                confidence: 0.95,
                pageIndex: 0,
                boundingBox: OcrBoundingBox(left: 0.1, top: 0.26, width: 0.6, height: 0.04),
              ),
            ],
          ),
        ],
      );

      final finding = createTestFinding(
        id: 'finding_multi',
        clauseId: 'clause_multi',
        title: 'Multi-line fee clause',
        simpleExplanation: 'Clause spans two lines',
        rawExcerpt: 'registration fee of ₹50,000 before the loan',
        severity: LegalRiskSeverity.high,
      );

      final highlight = mapper.createHighlightForFinding(
        document: doc,
        finding: finding,
        highlightId: 'highlight_multi',
      );

      expect(highlight.hasValidLocation, isTrue);
      // Must generate separate rectangles for each line, NOT one giant box
      expect(highlight.rectangles.length, equals(2));
      expect(highlight.rectangles[0].top, closeTo(0.20, 0.02));
      expect(highlight.rectangles[1].top, closeTo(0.26, 0.02));
    });

    test('Section 72: Fuzzy OCR typo tolerance (e.g. ₹50,OOO)', () {
      // Document text has OCR typo "₹50,OOO" with capital O's instead of zeros
      const docText = 'The Borrower shall pay a registration fee of ₹50,OOO before loan release.';
      final doc = OcrDocument(
        rawText: docText,
        overallConfidence: 0.92,
        scannedAt: DateTime(2024, 10, 1),
        pages: const [
          OcrPage(
            pageIndex: 0,
            pageSize: Size(600, 800),
            averageConfidence: 0.92,
            lines: [
              OcrLine(
                text: docText,
                confidence: 0.92,
                pageIndex: 0,
                boundingBox: OcrBoundingBox(left: 0.1, top: 0.3, width: 0.8, height: 0.04),
              ),
            ],
          ),
        ],
      );

      // Finding has normalized clean query with zeros: "₹50,000"
      final finding = createTestFinding(
        id: 'finding_typo',
        clauseId: 'clause_typo',
        title: 'Upfront Fee',
        simpleExplanation: 'Suspicious fee',
        rawExcerpt: 'registration fee of ₹50,000',
        severity: LegalRiskSeverity.high,
      );

      final highlight = mapper.createHighlightForFinding(
        document: doc,
        finding: finding,
        highlightId: 'highlight_typo',
      );

      expect(highlight.hasValidLocation, isTrue);
      // Original document text with "₹50,OOO" must be preserved, never altered (Section 72)
      expect(highlight.exactText, contains('₹50,OOO'));
    });

    test('Section 71: Multiple Occurrences Disambiguation using Context', () {
      const docText =
          'Clause 1: Definitions include registration fee for reference.\n'
          'Clause 2: The Borrower shall pay a registration fee of ₹50,000 immediately.\n'
          'Clause 3: On termination, registration fee is non-refundable.';

      final doc = OcrDocument(
        rawText: docText,
        overallConfidence: 0.95,
        scannedAt: DateTime(2024, 10, 1),
        pages: const [
          OcrPage(
            pageIndex: 0,
            pageSize: Size(600, 800),
            averageConfidence: 0.95,
            lines: [
              OcrLine(
                text: 'Clause 1: Definitions include registration fee for reference.',
                confidence: 0.95,
                pageIndex: 0,
                boundingBox: OcrBoundingBox(left: 0.1, top: 0.1, width: 0.8, height: 0.04),
              ),
              OcrLine(
                text: 'Clause 2: The Borrower shall pay a registration fee of ₹50,000 immediately.',
                confidence: 0.95,
                pageIndex: 0,
                boundingBox: OcrBoundingBox(left: 0.1, top: 0.3, width: 0.8, height: 0.04),
              ),
              OcrLine(
                text: 'Clause 3: On termination, registration fee is non-refundable.',
                confidence: 0.95,
                pageIndex: 0,
                boundingBox: OcrBoundingBox(left: 0.1, top: 0.5, width: 0.8, height: 0.04),
              ),
            ],
          ),
        ],
      );

      // Target finding is specifically about Clause 2 payment
      final finding = createTestFinding(
        id: 'finding_occ',
        clauseId: 'clause_002',
        title: 'Mandatory Payment',
        simpleExplanation: 'Immediate upfront payment',
        rawExcerpt: 'pay a registration fee of ₹50,000 immediately',
        evidence: 'Clause 2: The Borrower shall pay a registration fee of ₹50,000 immediately.',
        severity: LegalRiskSeverity.high,
      );

      final highlight = mapper.createHighlightForFinding(
        document: doc,
        finding: finding,
        highlightId: 'highlight_occ',
      );

      expect(highlight.hasValidLocation, isTrue);
      // Should correctly locate line 2 (top ~ 0.3), not line 1 or line 3
      expect(highlight.rectangles.first.top, closeTo(0.3, 0.05));
    });

    test('Section 81: Validation - Unmapped finding does not place fake highlight', () {
      const docText = 'Standard non-disclosure agreement with mutual confidentiality.';
      final doc = OcrDocument(
        rawText: docText,
        overallConfidence: 0.95,
        scannedAt: DateTime(2024, 10, 1),
        pages: const [
          OcrPage(
            pageIndex: 0,
            pageSize: Size(600, 800),
            averageConfidence: 0.95,
            lines: [
              OcrLine(
                text: docText,
                confidence: 0.95,
                pageIndex: 0,
                boundingBox: OcrBoundingBox(left: 0.1, top: 0.2, width: 0.8, height: 0.04),
              ),
            ],
          ),
        ],
      );

      final finding = createTestFinding(
        id: 'finding_unmapped',
        clauseId: 'clause_none',
        title: 'Non-existent clause',
        simpleExplanation: 'Not in this document',
        rawExcerpt: 'Arbitration shall take place in London under LCIA rules',
        severity: LegalRiskSeverity.medium,
      );

      final highlight = mapper.createHighlightForFinding(
        document: doc,
        finding: finding,
        highlightId: 'highlight_unmapped',
      );

      // Section 81: Mapping fails -> hasValidLocation must be false, no fake coordinates
      expect(highlight.hasValidLocation, isFalse);
      expect(highlight.rectangles.isEmpty, isTrue);
    });
  });

  group('Section 73: Data Model & Serialization', () {
    test('DocumentHighlight and HighlightRect JSON roundtrip', () {
      const rect = HighlightRect(x: 0.12, y: 0.45, width: 0.75, height: 0.04);
      final highlight = DocumentHighlight(
        id: 'hl_001',
        findingId: 'f_001',
        clauseId: 'c_001',
        pageNumber: 1,
        exactText: 'The Borrower shall pay a registration fee of ₹50,000.',
        normalizedText: 'the borrower shall pay a registration fee of 50000',
        rectangles: const [rect],
        severity: LegalRiskSeverity.high,
        confidence: 0.95,
        category: 'unfair_clause',
        highlightType: 'sentence',
        startOffset: 120,
        endOffset: 175,
        occurrenceIndex: 1,
        hasValidLocation: true,
      );

      final json = highlight.toJson();
      final deserialized = DocumentHighlight.fromJson(json);

      expect(deserialized.id, equals('hl_001'));
      expect(deserialized.findingId, equals('f_001'));
      expect(deserialized.pageNumber, equals(1));
      expect(deserialized.pageIndex, equals(0));
      expect(deserialized.rectangles.length, equals(1));
      expect(deserialized.rectangles.first.x, closeTo(0.12, 0.001));
      expect(deserialized.rectangles.first.y, closeTo(0.45, 0.001));
      expect(deserialized.rectangles.first.width, closeTo(0.75, 0.001));
      expect(deserialized.rectangles.first.height, closeTo(0.04, 0.001));
      expect(deserialized.severity, equals(LegalRiskSeverity.high));
      expect(deserialized.hasValidLocation, isTrue);
    });
  });

  group('Section 78: HighlightedDocumentPaper UI Widget', () {
    testWidgets('Renders exact phrase highlight, legend, navigation, and bottom issue card', (tester) async {
      const docText =
          'LOAN AGREEMENT\n'
          'The Borrower shall pay a registration fee of ₹50,000 before the loan is released.\n'
          'All payments are non-refundable.';

      final finding = createTestFinding(
        id: 'finding_test',
        clauseId: 'clause_001',
        title: 'Upfront payment requirement',
        simpleExplanation: 'Requires upfront payment before loan release',
        rawExcerpt: 'registration fee of ₹50,000',
        severity: LegalRiskSeverity.high,
        pageIndex: 0,
      );

      LegalFinding? tappedFinding;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HighlightedDocumentPaper(
              rawText: docText,
              findings: [finding],
              initialFindingId: finding.id,
              onFindingTap: (f) => tappedFinding = f,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify Legend Bar renders issue count and severity dot
      expect(find.text('1 of 1 issues'), findsOneWidget);
      expect(find.text('High (1)'), findsOneWidget);

      // 2. Verify filter chips are present
      expect(find.text('All (1)'), findsOneWidget);
      expect(find.text('High (1)'), findsOneWidget);

      // 3. Verify exact highlighted phrase is rendered
      expect(find.text('registration fee of ₹50,000'), findsOneWidget);

      // 4. Verify surrounding unhighlighted text is rendered in the same line
      expect(find.textContaining('The Borrower shall pay a'), findsOneWidget);
      expect(find.textContaining('before the loan is released.'), findsOneWidget);

      // 5. Verify Floating Bottom Issue Card (Section 78)
      expect(find.text('Upfront payment requirement'), findsOneWidget);
      expect(find.textContaining('Page 1 · High Risk · Tap for details'), findsOneWidget);

      // 6. Tap the highlighted phrase -> triggers onFindingTap
      await tester.tap(find.text('registration fee of ₹50,000'));
      await tester.pumpAndSettle();
      expect(tappedFinding, isNotNull);
      expect(tappedFinding!.id, equals('finding_test'));
    });

    testWidgets('Section 77: Filter chips filter highlights properly', (tester) async {
      const docText =
          '1. The Borrower pays registration fee of ₹50,000.\n'
          '2. Jurisdiction exclusively in New Delhi courts.';

      final highFinding = createTestFinding(
        id: 'f_high',
        clauseId: 'c_high',
        title: 'Upfront Fee',
        simpleExplanation: 'High risk upfront fee',
        rawExcerpt: 'registration fee of ₹50,000',
        severity: LegalRiskSeverity.high,
      );

      final medFinding = createTestFinding(
        id: 'f_med',
        clauseId: 'c_med',
        title: 'Exclusive Jurisdiction',
        simpleExplanation: 'Medium risk forum selection',
        rawExcerpt: 'exclusively in New Delhi courts',
        severity: LegalRiskSeverity.medium,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HighlightedDocumentPaper(
              rawText: docText,
              findings: [highFinding, medFinding],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('1 of 2 issues'), findsOneWidget);

      // Tap 'High (1)' filter chip
      await tester.tap(find.text('High (1)'));
      await tester.pumpAndSettle();

      // Now active visible list shows 1 of 1 issues
      expect(find.text('1 of 1 issues'), findsOneWidget);
    });

    testWidgets('Section 81: Displays validation fallback for unmapped findings', (tester) async {
      const docText = 'Mutual Non-Disclosure Agreement between Party A and Party B.';

      final unmappedFinding = createTestFinding(
        id: 'f_missing',
        clauseId: 'c_missing',
        title: 'Missing Term',
        simpleExplanation: 'Clause not in doc',
        rawExcerpt: 'Non-compete worldwide for 5 years',
        severity: LegalRiskSeverity.medium,
        highlight: const DocumentHighlight(
          id: 'hl_missing',
          findingId: 'f_missing',
          pageNumber: 1,
          exactText: 'Non-compete worldwide for 5 years',
          normalizedText: 'noncompete worldwide for 5 years',
          rectangles: [],
          severity: LegalRiskSeverity.medium,
          hasValidLocation: false, // Mapping failed!
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HighlightedDocumentPaper(
              rawText: docText,
              findings: [unmappedFinding],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Section 81 requirement:
      // Display: "Finding detected, but exact document location could not be determined."
      expect(
        find.text('Finding detected, but exact document location could not be determined.'),
        findsOneWidget,
      );
      expect(find.text('View finding'), findsOneWidget);
    });
  });
}
