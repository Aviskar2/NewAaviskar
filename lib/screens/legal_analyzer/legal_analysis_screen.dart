import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/legal/models/document_analysis_status.dart';
import '../../core/legal/models/legal_analysis_result.dart';
import '../../core/legal/models/legal_document_type.dart';
import '../../core/legal/models/legal_finding.dart';
import '../../utils/url_launcher_util.dart';
import '../../widgets/legal_analyzer/highlighted_document_paper.dart';
import 'interactive_document_viewer.dart';
import 'sheets/all_issues_sheet.dart';
import 'sheets/clause_comparison_sheet.dart';
import 'sheets/document_checks_sheet.dart';
import 'sheets/full_clause_sheet.dart';
import 'sheets/interactive_clause_sheet.dart';
import 'sheets/law_detail_sheet.dart';
import 'sheets/legal_sources_sheet.dart';

/// Streamlined, user-friendly Document Analyzer screen following progressive disclosure.
class LegalAnalysisScreen extends StatefulWidget {
  final LegalAnalysisResult result;

  const LegalAnalysisScreen({
    super.key,
    required this.result,
  });

  @override
  State<LegalAnalysisScreen> createState() => _LegalAnalysisScreenState();
}

class _LegalAnalysisScreenState extends State<LegalAnalysisScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _selectedLawFilterIndex = 0; // 0: All, 1: High Relevance, 2: Active 2024, 3: Penal

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String? _activeDocumentFindingId;

  void _openInteractiveViewer([String? initialFindingId]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InteractiveDocumentViewer(
          document: widget.result.document,
          findings: widget.result.findings,
          initialFindingId: initialFindingId ?? _activeDocumentFindingId,
        ),
      ),
    );
  }

  void _jumpToDocumentTab([String? findingId]) {
    setState(() {
      _activeDocumentFindingId = findingId;
    });
    _tabController.animateTo(2);
  }

  String _buildReportText() {
    final r = widget.result;
    final buf = StringBuffer();
    buf.writeln('=== DOCUMENT ANALYZER REPORT ===');
    buf.writeln('Document: ${r.documentType.displayName}');
    buf.writeln('Risk Level: ${r.overallSeverity.displayName.toUpperCase()} (${r.overallRiskScore.toInt()}/100)');
    if (r.isAiEnhanced && r.aiModelUsed != null) {
      buf.writeln('AI Engine: ${r.aiModelUsed}');
    }
    buf.writeln('\n--- SUMMARY ---');
    buf.writeln(r.plainSummary);
    buf.writeln('\n--- FLAGGED CLAUSES (${r.findings.length}) ---');
    for (final f in r.findings) {
      buf.writeln('• [${f.severity.displayName}] ${f.title}');
      buf.writeln('  Excerpt: "${f.rawExcerpt}"');
      buf.writeln('  Warning: ${f.simpleExplanation}');
      buf.writeln('  Action: ${f.recommendedAction}');
      if (f.statutoryBasis.isNotEmpty) {
        for (final s in f.statutoryBasis) {
          buf.writeln('  📜 ${s.actName} — §${s.section}: ${s.title}');
        }
      }
      buf.writeln();
    }
    buf.writeln('--- DOCUMENT CHECKS ---');
    buf.writeln('Passed: ${r.anomalies.isEmpty ? 'All standard checks verified' : '${r.anomalies.length} warnings detected'}');
    return buf.toString();
  }

  void _shareReport() {
    Clipboard.setData(ClipboardData(text: _buildReportText()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Document analysis report copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  List<StatutoryCitation> _getAllUniqueCitations() {
    final seen = <String>{};
    final list = <StatutoryCitation>[];
    for (final f in widget.result.findings) {
      for (final s in f.statutoryBasis) {
        final key = '${s.actName}_${s.section}';
        if (seen.add(key)) {
          list.add(s);
        }
      }
    }
    return list;
  }

  List<LegalFinding> get _sortedFindings {
    final list = List<LegalFinding>.from(widget.result.findings);
    list.sort((a, b) {
      if (a.severity == LegalRiskSeverity.high && b.severity != LegalRiskSeverity.high) return -1;
      if (b.severity == LegalRiskSeverity.high && a.severity != LegalRiskSeverity.high) return 1;
      return 0;
    });
    return list;
  }

  List<LegalFinding> get _findings => widget.result.findings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final citations = _getAllUniqueCitations();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text(
          'Document Analyzer',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, size: 21),
            tooltip: 'Legal Sources & Registry',
            onPressed: () => LegalSourcesSheet.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 21),
            tooltip: 'Share Report',
            onPressed: _shareReport,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF2563EB),
              unselectedLabelColor: isDark ? Colors.white60 : const Color(0xFF64748B),
              indicatorColor: const Color(0xFF2563EB),
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
              tabs: [
                const Tab(text: 'Overview'),
                Tab(text: 'Laws (${citations.length})'),
                Tab(text: 'Document (${_findings.length})'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(context, theme, isDark, citations),
          _buildLawsTab(context, theme, isDark, citations),
          _buildDocumentTab(context, theme, isDark),
        ],
      ),
    );
  }

  // ========================================================================
  // 1. OVERVIEW TAB
  // Hierarchy:
  // - Risk Summary
  // - Flagged Issue (Primary + link to others)
  // - Why It Matters
  // - Relevant Law (Primary + view more)
  // - Highlighted Document (Compact Preview + Fullscreen)
  // - Document Checks (Summary + View All)
  // ========================================================================
  Widget _buildOverviewTab(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    List<StatutoryCitation> citations,
  ) {
    final r = widget.result;
    final sorted = _sortedFindings;
    final hasIssues = sorted.isNotEmpty;
    final topFinding = hasIssues ? sorted.first : null;
    final primaryStatute = topFinding?.primaryStatute ?? (citations.isNotEmpty ? citations.first : null);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // A. RISK SUMMARY (Section 5, 40, 52)
        _buildRiskSummaryCard(r, isDark),
        const SizedBox(height: 14),

        // B. FLAGGED ISSUE CARD (Section 6, 7, 24, 42)
        if (hasIssues && topFinding != null) ...[
          _buildFlaggedIssueCard(context, topFinding, sorted.length, isDark),
          const SizedBox(height: 14),

          // C. WHY IT MATTERS (Section 8)
          _buildWhyItMattersSection(topFinding, isDark),
          const SizedBox(height: 14),
        ] else ...[
          _buildNoIssuesCard(r, isDark),
          const SizedBox(height: 14),
        ],

        // D. RELEVANT LAW (Section 9, 45)
        if (primaryStatute != null) ...[
          _buildRelevantLawSection(context, primaryStatute, topFinding, citations.length, isDark),
          const SizedBox(height: 14),
        ],

        // E. HIGHLIGHTED DOCUMENT (Section 13, 25, 43)
        _buildHighlightedDocumentSection(context, isDark),
        const SizedBox(height: 14),

        // F. DOCUMENT CHECKS (Section 16, 17, 51)
        _buildDocumentChecksSection(context, r, isDark),
        const SizedBox(height: 14),

        // G. MODEL TRANSPARENCY & DETAILS (Section 49)
        _buildAnalysisDetailsSection(r, isDark),
        const SizedBox(height: 24),
      ],
    );
  }

  // ========================================================================
  // RISK SUMMARY CARD (Section 5, 40, 52)
  // Clean, white/tinted card, non-dominant score, strong severity label
  // ========================================================================
  Widget _buildRiskSummaryCard(LegalAnalysisResult r, bool isDark) {
    final isPoorOcr = r.status == DocumentAnalysisStatus.poorOcrQuality;
    final isUnavailable = r.status == DocumentAnalysisStatus.analysisUnavailable;
    final isHigh = r.overallSeverity == LegalRiskSeverity.high && !isPoorOcr && !isUnavailable;
    final isMedium = r.overallSeverity == LegalRiskSeverity.medium && !isPoorOcr && !isUnavailable;
    final riskColor = isPoorOcr || isUnavailable
        ? const Color(0xFFF59E0B)
        : r.overallSeverity.color;

    String advice;
    String statusLabel;

    if (isPoorOcr) {
      statusLabel = 'ANALYSIS INCOMPLETE';
      advice = r.statusMessage ?? 'The document text quality was insufficient for reliable analysis.';
    } else if (isUnavailable) {
      statusLabel = 'ANALYSIS UNAVAILABLE';
      advice = r.statusMessage ?? 'Unable to connect to analysis service. Please retry.';
    } else if (isHigh) {
      statusLabel = 'HIGH RISK';
      advice = 'Review this document carefully. Flagged terms require modification.';
    } else if (isMedium) {
      statusLabel = 'MEDIUM RISK';
      advice = 'Caution advised. Review one-sided clauses before proceeding.';
    } else {
      statusLabel = 'SAFE / LOW RISK';
      advice = 'No significant risk indicators detected. Standard provisions.';
    }

    final issueCount = r.findings.length;
    final issueText = isPoorOcr || isUnavailable
        ? 'Text quality low'
        : issueCount == 0
            ? 'No risk indicators detected'
            : '$issueCount risk indicator${issueCount == 1 ? '' : 's'} detected';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHigh
              ? const Color(0xFFDC2626).withValues(alpha: isDark ? 0.35 : 0.25)
              : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row with small risk indicator + Strong severity label + Issue count
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: riskColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: riskColor,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '•  $issueText',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Short concise advice (one single sentence)
          Text(
            advice,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),

          // Secondary Evidence-First Risk Score + Confidence (Section 40 & 52)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 14, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      isPoorOcr || r.confidenceLevel == DocumentAnalysisConfidence.insufficientEvidence
                          ? 'Risk score: Unavailable'
                          : 'Risk score: ${r.overallRiskScore.toInt()}/100',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: riskColor.withValues(alpha: isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    r.confidenceLevel.badgeText,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: riskColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // FLAGGED ISSUE CARD (Section 6, 7, 24)
  // Single primary card with severity, type, short excerpt, view full clause
  // ========================================================================
  Widget _buildFlaggedIssueCard(
    BuildContext context,
    LegalFinding finding,
    int totalIssues,
    bool isDark,
  ) {
    final isHigh = finding.severity == LegalRiskSeverity.high;
    final accentColor = isHigh ? const Color(0xFFDC2626) : const Color(0xFFD97706);
    final primaryStatute = finding.primaryStatute;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.35 : 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: isDark ? 0.05 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Badge + Issue Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    isHigh ? 'CRITICAL RISK' : 'FLAGGED ISSUE',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    finding.title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Short 2-line explanation
            Text(
              finding.simpleExplanation,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),

            // Flagged clause section: short excerpt ONLY
            Text(
              'Flagged clause:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF08A).withValues(alpha: isDark ? 0.12 : 0.22),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCA8A04).withValues(alpha: 0.35)),
              ),
              child: Text(
                '“${finding.rawExcerpt}”',
                style: TextStyle(
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFFEF08A) : const Color(0xFF854D0E),
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 10),

            // Action row: View full clause ->
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () {
                    FullClauseSheet.show(
                      context,
                      finding: finding,
                      onCompare: primaryStatute != null
                          ? () => ClauseComparisonSheet.show(
                                context,
                                finding: finding,
                                citation: primaryStatute,
                              )
                          : null,
                      onViewInDocument: () => _jumpToDocumentTab(finding.id),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                  label: const Text('View full clause'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(0, 36),
                  ),
                ),
                if (totalIssues > 1)
                  TextButton(
                    onPressed: () {
                      AllIssuesSheet.show(
                        context,
                        findings: _sortedFindings,
                        onViewInDocument: (f) => _jumpToDocumentTab(f.id),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? Colors.white70 : const Color(0xFF475569),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: const Size(0, 36),
                    ),
                    child: Text(
                      '+ ${totalIssues - 1} more issue${totalIssues - 1 == 1 ? '' : 's'} →',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoIssuesCard(LegalAnalysisResult r, bool isDark) {
    if (r.status == DocumentAnalysisStatus.poorOcrQuality) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Analysis Incomplete',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD97706),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'The document text quality was insufficient for reliable analysis.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No significant risk indicators detected.',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF16A34A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Confidence: ${r.confidenceLevel.displayName}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // WHY IT MATTERS SECTION (Section 8)
  // 2-4 lines concise explanation + Learn more
  // ========================================================================
  Widget _buildWhyItMattersSection(LegalFinding finding, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Why it matters',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            finding.legalExplanation.isNotEmpty
                ? finding.legalExplanation
                : 'This clause may create an unbalanced legal or financial obligation under Indian law. Review the terms before signing.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {
                FullClauseSheet.show(
                  context,
                  finding: finding,
                  onViewInDocument: () => _jumpToDocumentTab(finding.id),
                );
              },
              child: const Text(
                'Learn more →',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2563EB),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // RELEVANT LAW SECTION (Section 9)
  // Shows primary matched law first + [Compare] [View Law] + "+ X more laws"
  // ========================================================================
  Widget _buildRelevantLawSection(
    BuildContext context,
    StatutoryCitation primaryStatute,
    LegalFinding? relatedFinding,
    int totalCitations,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          const Text(
            'Relevant Law',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          // Act & Section
          Text(
            primaryStatute.actName,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2563EB),
            ),
          ),
          Text(
            '§${primaryStatute.section}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            primaryStatute.title,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          // Actions: [Compare] [View Law]
          Row(
            children: [
              if (relatedFinding != null) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ClauseComparisonSheet.show(
                        context,
                        finding: relatedFinding,
                        citation: primaryStatute,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(38),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Compare', style: TextStyle(fontSize: 12.5)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    LawDetailSheet.show(
                      context,
                      citation: primaryStatute,
                      relatedFinding: relatedFinding,
                      onViewInDocument: relatedFinding != null
                          ? () => _jumpToDocumentTab(relatedFinding.id)
                          : null,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(38),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('View Law', style: TextStyle(fontSize: 12.5)),
                ),
              ),
            ],
          ),

          // More laws action
          if (totalCitations > 1) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _tabController.animateTo(1),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  '+ ${totalCitations - 1} more relevant laws →',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ========================================================================
  // HIGHLIGHTED DOCUMENT SECTION (Section 13, 25)
  // Compact preview, NO giant red floating button, clear actions
  // ========================================================================
  Widget _buildHighlightedDocumentSection(BuildContext context, bool isDark) {
    final findingsCount = _findings.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Highlighted Document',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: findingsCount > 0
                      ? const Color(0xFFDC2626).withValues(alpha: 0.1)
                      : const Color(0xFF16A34A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$findingsCount flagged clause${findingsCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: findingsCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Compact document preview (height ~200)
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
            ),
            clipBehavior: Clip.antiAlias,
            child: HighlightedDocumentPaper(
              rawText: widget.result.document.rawText,
              findings: widget.result.findings,
              onFindingTap: (finding) {
                InteractiveClauseSheet.show(
                  context,
                  finding: finding,
                  onViewInDocument: () => _jumpToDocumentTab(finding.id),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Action row: [View Document ->] [Fullscreen]
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => _tabController.animateTo(2),
                icon: const Icon(Icons.description_outlined, size: 16),
                label: const Text('View document →'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 36),
                ),
              ),
              TextButton.icon(
                onPressed: () => _openInteractiveViewer(),
                icon: const Icon(Icons.fullscreen_rounded, size: 16),
                label: const Text('Fullscreen'),
                style: TextButton.styleFrom(
                  foregroundColor: isDark ? Colors.white70 : const Color(0xFF475569),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 36),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // DOCUMENT CHECKS SECTION (Section 16, 17)
  // Compact summary with View all ->
  // ========================================================================
  Widget _buildDocumentChecksSection(
    BuildContext context,
    LegalAnalysisResult r,
    bool isDark,
  ) {
    final anomalies = r.anomalies;
    final hasAnomalies = anomalies.isNotEmpty;
    final passedCount = 6 - anomalies.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Document Checks',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => DocumentChecksSheet.show(context, result: r),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('View all →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row of checks: ✓ Structure   ✓ Parties   ✓ Dates
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: const [
              _CheckBadge(label: 'Structure'),
              _CheckBadge(label: 'Parties'),
              _CheckBadge(label: 'Dates'),
              _CheckBadge(label: 'Signatures'),
            ],
          ),
          const SizedBox(height: 10),

          // Summary status line
          Row(
            children: [
              Icon(
                hasAnomalies ? Icons.info_outline_rounded : Icons.check_circle_rounded,
                size: 15,
                color: hasAnomalies ? const Color(0xFFD97706) : const Color(0xFF16A34A),
              ),
              const SizedBox(width: 6),
              Text(
                hasAnomalies
                    ? '$passedCount passed · ${anomalies.length} warning${anomalies.length == 1 ? '' : 's'}'
                    : 'All standard document checks passed',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: hasAnomalies ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // ANALYSIS DETAILS SECTION (Section 49)
  // Transparent, non-dominant details: method, model, analysis ID, timestamp
  // ========================================================================
  Widget _buildAnalysisDetailsSection(LegalAnalysisResult r, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 14, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(
                'Analysis details',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildDetailRow('Analysis method', r.analysisMethod, isDark),
          const SizedBox(height: 4),
          _buildDetailRow('Model', r.aiModelUsed ?? 'ScanSure Risk Pipeline', isDark),
          const SizedBox(height: 4),
          _buildDetailRow('Analysis ID', r.analysisId, isDark),
          const SizedBox(height: 4),
          _buildDetailRow(
            'Analyzed',
            '${r.analyzedAt.year}-${r.analyzedAt.month.toString().padLeft(2, '0')}-${r.analyzedAt.day.toString().padLeft(2, '0')} ${r.analyzedAt.hour.toString().padLeft(2, '0')}:${r.analyzedAt.minute.toString().padLeft(2, '0')}',
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: isDark ? Colors.white54 : const Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white.withValues(alpha: 0.87) : const Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  // ========================================================================
  // 2. LAWS TAB (Section 10, 11, 26)
  // Compact Law cards, filter chips, no repeated long clause texts
  // ========================================================================
  Widget _buildLawsTab(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    List<StatutoryCitation> citations,
  ) {
    if (citations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline_rounded, size: 48, color: Color(0xFF16A34A)),
              const SizedBox(height: 12),
              const Text(
                'No Statutory Violations',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'No provisions of Indian law were violated in this document.',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Filter citations according to selected chip
    final filtered = citations.where((s) {
      if (_selectedLawFilterIndex == 1) {
        // High relevance (has related finding with high risk)
        return widget.result.findings.any((f) =>
            f.severity == LegalRiskSeverity.high &&
            f.statutoryBasis.any((b) => b.actName == s.actName && b.section == s.section));
      } else if (_selectedLawFilterIndex == 2) {
        // Active 2024 laws
        return s.isModernLaw;
      } else if (_selectedLawFilterIndex == 3) {
        // Penal / Criminal (e.g. BNS / IPC)
        final lower = s.actName.toLowerCase();
        return lower.contains('nyaya') || lower.contains('penal') || lower.contains('bns');
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Filter bar (Section 26)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0))),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All (${citations.length})', 0, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('High Relevance', 1, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Active 2024 Laws', 2, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Penal / Criminal', 3, isDark),
              ],
            ),
          ),
        ),

        // List of compact statutory law cards (Section 10)
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final citation = filtered[index];
              final relatedFindings = widget.result.findings
                  .where((f) => f.statutoryBasis.any((b) => b.actName == citation.actName && b.section == citation.section))
                  .toList();
              final matchingFinding = relatedFindings.isNotEmpty ? relatedFindings.first : null;

              return _buildCompactLawCard(context, citation, matchingFinding, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, int index, bool isDark) {
    final isSelected = _selectedLawFilterIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedLawFilterIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }

  // ========================================================================
  // COMPACT LAW CARD (Section 10)
  // Law name, Section, Short title, One-line relevance, Compare, Source
  // Avoid displaying long text walls or repeating excerpts here
  // ========================================================================
  Widget _buildCompactLawCard(
    BuildContext context,
    StatutoryCitation citation,
    LegalFinding? relatedFinding,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            LawDetailSheet.show(
              context,
              citation: citation,
              relatedFinding: relatedFinding,
              onViewInDocument: relatedFinding != null
                  ? () => _jumpToDocumentTab(relatedFinding.id)
                  : null,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Law name + Section + Status badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            citation.actName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          Text(
                            '§${citation.section}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: citation.isModernLaw
                            ? const Color(0xFF16A34A).withValues(alpha: 0.15)
                            : const Color(0xFF2563EB).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        citation.statusBadgeText,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: citation.isModernLaw ? const Color(0xFF15803D) : const Color(0xFF1E40AF),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Short title
                Text(
                  citation.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // One-line relevance (compact reference per Section 7 & 10)
                Text(
                  relatedFinding != null
                      ? 'Matched to 1 flagged clause in your document'
                      : 'Statutory compliance safeguard',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 10),

                // Actions row: [Compare] [Source ↗]
                Row(
                  children: [
                    if (relatedFinding != null) ...[
                      OutlinedButton.icon(
                        onPressed: () {
                          ClauseComparisonSheet.show(
                            context,
                            finding: relatedFinding,
                            citation: citation,
                          );
                        },
                        icon: const Icon(Icons.compare_arrows_rounded, size: 14),
                        label: const Text('Compare', style: TextStyle(fontSize: 11.5)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (citation.officialSourceUrl != null && citation.officialSourceUrl!.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => UrlLauncherUtil.openUrl(context, citation.officialSourceUrl!),
                        icon: const Icon(Icons.open_in_new_rounded, size: 13),
                        label: const Text('Source ↗', style: TextStyle(fontSize: 11.5)),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ========================================================================
  // 3. DOCUMENT TAB (Section 14, 15)
  // Dedicated document view, fullscreen action, helper bottom bar
  // ========================================================================
  Widget _buildDocumentTab(BuildContext context, ThemeData theme, bool isDark) {
    final findingsCount = _findings.length;

    return Column(
      children: [
        // Subheader banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$findingsCount flagged clause${findingsCount == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: () => _openInteractiveViewer(),
                icon: const Icon(Icons.fullscreen_rounded, size: 16),
                label: const Text('Fullscreen', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 32),
                ),
              ),
            ],
          ),
        ),

        // Scrollable document
        Expanded(
          child: HighlightedDocumentPaper(
            rawText: widget.result.document.rawText,
            findings: widget.result.findings,
            initialFindingId: _activeDocumentFindingId,
            onFindingTap: (finding) {
              InteractiveClauseSheet.show(
                context,
                finding: finding,
                onViewInDocument: () => _jumpToDocumentTab(finding.id),
              );
            },
          ),
        ),

        // Bottom helper bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(top: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              const Icon(Icons.touch_app_outlined, size: 16, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$findingsCount flagged clause${findingsCount == 1 ? '' : 's'} · Tap a highlight to inspect the issue.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CheckBadge extends StatelessWidget {
  final String label;

  const _CheckBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF16A34A).withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_rounded, size: 12, color: Color(0xFF16A34A)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF16A34A),
            ),
          ),
        ],
      ),
    );
  }
}
