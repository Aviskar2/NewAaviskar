import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_sure/core/legal/models/document_anomaly.dart';
import 'package:scan_sure/core/legal/models/legal_analysis_result.dart';
import 'package:scan_sure/core/legal/models/legal_clause.dart';
import 'package:scan_sure/core/legal/models/legal_document_type.dart';
import 'package:scan_sure/core/legal/models/legal_finding.dart';
import 'package:scan_sure/core/legal/models/ocr_document.dart';
import 'package:scan_sure/screens/legal_analyzer/legal_analysis_screen.dart';

void main() {
  late LegalAnalysisResult sampleResult;

  setUp(() {
    const rawDocumentText = '''
EMPLOYMENT AGREEMENT & BOND
1. The employee promises to pay an upfront mandatory training fee of INR 50,000 prior to joining.
2. Employee agrees to a 3-year strict non-compete within all of India.
3. Employer may terminate immediately without notice or reason.
''';

    final finding1 = LegalFinding(
      id: 'f1',
      clauseType: LegalClauseType.upfrontFeeScam,
      severity: LegalRiskSeverity.high,
      title: 'Potential Scam / Mandatory Upfront Fee',
      simpleExplanation: 'Demanding upfront payment before employment is a common scam tactic under Indian law.',
      legalExplanation: 'Violates fair trade principles and may amount to cheating under Bharatiya Nyaya Sanhita, 2023.',
      rawExcerpt: 'The employee promises to pay an upfront mandatory training fee of INR 50,000 prior to joining.',
      pageIndex: 0,
      recommendedAction: 'Do not transfer any money before formal onboarding.',
      statutoryBasis: const [
        StatutoryCitation(
          actName: 'Bharatiya Nyaya Sanhita, 2023',
          section: '318',
          title: 'Cheating and dishonest inducement of delivery of property',
          description: 'Whoever cheats dishonestly induces the person deceived to deliver any property is punishable.',
          officialSourceUrl: 'https://www.indiacode.nic.in',
        ),
      ],
    );

    final finding2 = LegalFinding(
      id: 'f2',
      clauseType: LegalClauseType.nonCompeteRestraint,
      severity: LegalRiskSeverity.high,
      title: 'Unreasonable Post-Employment Restraint',
      simpleExplanation: 'A 3-year non-compete clause is legally void under Indian contract law.',
      legalExplanation: 'Section 27 of Indian Contract Act declares all restraints on lawful profession void.',
      rawExcerpt: 'Employee agrees to a 3-year strict non-compete within all of India.',
      pageIndex: 0,
      recommendedAction: 'Request complete removal of non-compete covenant.',
      statutoryBasis: const [
        StatutoryCitation(
          actName: 'Indian Contract Act, 1872',
          section: '27',
          title: 'Agreement in restraint of trade void',
          description: 'Every agreement by which anyone is restrained from exercising a lawful profession is void.',
          officialSourceUrl: 'https://www.indiacode.nic.in',
        ),
      ],
    );

    sampleResult = LegalAnalysisResult(
      document: OcrDocument(
        rawText: rawDocumentText,
        pages: const [
          OcrPage(
            pageIndex: 0,
            pageSize: Size(600, 800),
            lines: [],
            averageConfidence: 0.95,
          )
        ],
        overallConfidence: 0.95,
        scannedAt: DateTime.now(),
      ),
      documentType: LegalDocumentType.employmentContract,
      documentTypeConfidence: 0.95,
      overallRiskScore: 91.0,
      overallSeverity: LegalRiskSeverity.high,
      riskBreakdown: const RiskBreakdown(
        legalRisk: 90,
        financialRisk: 85,
        terminationRisk: 80,
        documentAnomalyRisk: 10,
      ),
      findings: [finding1, finding2],
      anomalies: const [
        DocumentAnomaly(
          id: 'a1',
          category: AnomalyCategory.dateInconsistency,
          severity: AnomalySeverity.advisory,
          title: 'Execution Date Format Advisory',
          explanation: 'Standard DD/MM/YYYY format recommended.',
          evidence: '2026',
          verificationTip: 'Verify with signatory date.',
        ),
      ],
      plainSummary: 'High-risk employment contract with illegal fee collection and restraint.',
      executiveLegalSummary: 'Critical unenforceable clauses identified.',
      analyzedAt: DateTime.now(),
      isAiEnhanced: true,
      aiModelUsed: 'Gemini 1.5 Flash Legal Engine',
    );
  });

  testWidgets('Renders redesigned Document Analyzer with compact hierarchy and 3 tabs', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: LegalAnalysisScreen(result: sampleResult),
      ),
    );
    await tester.pumpAndSettle();

    // 1. App Bar
    expect(find.text('Document Analyzer'), findsOneWidget);
    expect(find.byIcon(Icons.share_outlined), findsOneWidget);
    expect(find.byTooltip('Legal Sources & Registry'), findsOneWidget);

    // 2. 3-Tab Bar
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Laws (2)'), findsOneWidget);
    expect(find.text('Document (2)'), findsOneWidget);

    // 3. Compact Risk Summary (Non-dominant score, strong severity label)
    expect(find.text('HIGH RISK'), findsOneWidget);
    expect(find.text('•  2 risk indicators detected'), findsOneWidget);
    expect(find.textContaining('Review this document'), findsOneWidget);
    expect(find.text('Risk score: 91/100'), findsOneWidget);

    // 4. Primary Flagged Issue Card (short excerpt, View full clause action)
    expect(find.text('CRITICAL RISK'), findsWidgets);
    expect(find.text('Potential Scam / Mandatory Upfront Fee'), findsWidgets);
    expect(find.text('View full clause'), findsOneWidget);
    expect(find.text('+ 1 more issue →'), findsOneWidget);

    // 5. Why It Matters Section
    expect(find.text('Why it matters'), findsOneWidget);
    expect(find.text('Learn more →'), findsOneWidget);

    // 6. Relevant Law Section
    expect(find.text('Relevant Law'), findsOneWidget);
    expect(find.text('Bharatiya Nyaya Sanhita, 2023'), findsWidgets);
    expect(find.text('§318'), findsOneWidget);
    expect(find.text('Compare'), findsWidgets);
    expect(find.text('View Law'), findsOneWidget);

    // 7. Highlighted Document Section
    expect(find.text('Highlighted Document'), findsOneWidget);
    expect(find.text('View document →'), findsOneWidget);
    expect(find.text('Fullscreen'), findsOneWidget);

    // 8. Document Checks Section
    expect(find.text('Document Checks'), findsOneWidget);
    expect(find.text('Structure'), findsOneWidget);
    expect(find.text('Parties'), findsOneWidget);
    expect(find.text('Dates'), findsOneWidget);
    expect(find.text('View all →'), findsOneWidget);
  });

  testWidgets('Tapping View full clause opens FullClauseSheet with complete excerpt', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LegalAnalysisScreen(result: sampleResult),
      ),
    );
    await tester.pumpAndSettle();

    final viewFullClauseBtn = find.text('View full clause');
    expect(viewFullClauseBtn, findsOneWidget);
    await tester.tap(viewFullClauseBtn);
    await tester.pumpAndSettle();

    // Verify Full Clause Sheet content
    expect(find.text('COMPLETE DOCUMENT CLAUSE'), findsOneWidget);
    expect(find.text('WHY THIS WAS FLAGGED'), findsOneWidget);
    expect(find.text('Recommended Action'), findsOneWidget);
    expect(find.text('View in Document'), findsOneWidget);
  });

  testWidgets('Tapping Compare opens ClauseComparisonSheet side-by-side view', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: LegalAnalysisScreen(result: sampleResult),
      ),
    );
    await tester.pumpAndSettle();

    final compareBtn = find.text('Compare').first;
    await tester.tap(compareBtn);
    await tester.pumpAndSettle();

    // Verify Comparison Sheet
    expect(find.text('Legal Comparison'), findsOneWidget);
    expect(find.text('YOUR DOCUMENT CLAUSE'), findsOneWidget);
    expect(find.text('WHAT INDIAN STATUTE MANDATES'), findsOneWidget);
    expect(find.text('Understood'), findsOneWidget);
  });

  testWidgets('Tapping View all on Document Checks opens DocumentChecksSheet', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: LegalAnalysisScreen(result: sampleResult),
      ),
    );
    await tester.pumpAndSettle();

    final viewAllChecksBtn = find.text('View all →');
    await tester.tap(viewAllChecksBtn);
    await tester.pumpAndSettle();

    // Verify Document Checks Sheet
    expect(find.text('Document Checks'), findsWidgets);
    expect(find.text('Document Structure & Layout'), findsOneWidget);
    expect(find.text('Dates & Chronological Consistency'), findsOneWidget);
    expect(find.text('Signatures, Stamps & Attestation'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('Tapping Info icon opens LegalSourcesSheet with registry details', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LegalAnalysisScreen(result: sampleResult),
      ),
    );
    await tester.pumpAndSettle();

    final infoIcon = find.byIcon(Icons.info_outline_rounded);
    await tester.tap(infoIcon);
    await tester.pumpAndSettle();

    // Verify Legal Sources Sheet
    expect(find.text('Legal Sources & Registry'), findsOneWidget);
    expect(find.text('Live Indian Statutory Registry Active'), findsOneWidget);
    expect(find.text('Bharatiya Nyaya Sanhita, 2023 (BNS)'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('Switching to Laws tab displays compact cards and filter chips', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LegalAnalysisScreen(result: sampleResult),
      ),
    );
    await tester.pumpAndSettle();

    // Tap on Laws tab
    final lawsTab = find.text('Laws (2)');
    await tester.tap(lawsTab);
    await tester.pumpAndSettle();

    // Verify filter chips
    expect(find.text('All (2)'), findsOneWidget);
    expect(find.text('High Relevance'), findsOneWidget);
    expect(find.text('Active 2024 Laws'), findsOneWidget);

    // Verify compact law cards
    expect(find.text('§318'), findsOneWidget);
    expect(find.text('§27'), findsOneWidget);
    expect(find.text('Matched to 1 flagged clause in your document'), findsWidgets);
    expect(find.text('Source ↗'), findsWidgets);
  });

  testWidgets('Switching to Document tab displays full readable document without giant floating button', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LegalAnalysisScreen(result: sampleResult),
      ),
    );
    await tester.pumpAndSettle();

    // Tap on Document tab
    final docTab = find.text('Document (2)');
    await tester.tap(docTab);
    await tester.pumpAndSettle();

    // Verify no giant floating action button
    expect(find.byType(FloatingActionButton), findsNothing);

    // Verify helper bar
    expect(find.text('2 flagged clauses · Tap a highlight to inspect the issue.'), findsOneWidget);
  });
}
