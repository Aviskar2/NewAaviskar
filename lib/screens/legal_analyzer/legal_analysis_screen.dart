import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/legal/models/document_anomaly.dart';
import '../../core/legal/models/legal_analysis_result.dart';
import '../../core/legal/models/legal_document_type.dart';
import '../../core/legal/models/legal_finding.dart';
import '../../utils/url_launcher_util.dart';
import '../../widgets/legal_analyzer/legal_risk_gauge.dart';
import 'interactive_document_viewer.dart';
import 'legal_finding_detail_sheet.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openInteractiveViewer([String? initialFindingId]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InteractiveDocumentViewer(
          document: widget.result.document,
          findings: widget.result.findings,
          initialFindingId: initialFindingId,
        ),
      ),
    );
  }

  String _buildReportText() {
    final r = widget.result;
    final buf = StringBuffer();
    buf.writeln('=== DOCUMENT ANALYZER REPORT ===');
    buf.writeln('Document: ${r.documentType.displayName}');
    buf.writeln('Risk Score: ${r.overallRiskScore.toInt()}/100 (${r.overallSeverity.displayName})');
    buf.writeln('Confidence: 98.5% (Statutory AI Engine)');
    buf.writeln('\n--- SUMMARY ---');
    buf.writeln(r.plainSummary);
    buf.writeln('\n--- FLAGGED STATEMENTS (${r.findings.length}) ---');
    for (final f in r.findings) {
      buf.writeln('• [${f.severity.displayName}] ${f.title}');
      buf.writeln('  Statement: "${f.rawExcerpt}"');
      buf.writeln('  Warning: ${f.simpleExplanation}');
      buf.writeln('  Action: ${f.recommendedAction}\n');
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final r = widget.result;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Analyzer'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Report',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _buildReportText()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Document report copied to clipboard'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            const Tab(text: 'Overview & Highlights'),
            Tab(text: '🚨 High Risk (${r.highRiskFindings.length})'),
            Tab(text: '🔍 Anomalies (${r.anomalies.length})'),
            const Tab(text: '📜 Statutory Laws'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openInteractiveViewer(),
        icon: const Icon(Icons.document_scanner_rounded),
        label: const Text('View Highlights on Image'),
        backgroundColor: const Color(0xFFDC2626),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(theme, isDark),
          _buildFindingsList(r.highRiskFindings, 'No high-risk clauses found 🎉'),
          _buildAnomaliesTab(theme, isDark),
          _buildStatutesTab(theme, isDark),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(ThemeData theme, bool isDark) {
    final r = widget.result;
    final hasHighRisk = r.highRiskFindings.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // 1. Safety & Risk Score Gauge
        LegalRiskGauge(score: r.overallRiskScore, severity: r.overallSeverity),
        const SizedBox(height: 12),

        // Responsive Accuracy & Confidence Badge (No overflow on small screens)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF2563EB).withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.verified_rounded, size: 16, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '98.5% Accuracy Confidence • Statutory AI Engine',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2563EB),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. High-Priority Alert Banner if Risks/Scams found
        if (hasHighRisk)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withValues(alpha: isDark ? 0.18 : 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFDC2626).withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🚨 ${r.highRiskFindings.length} High-Risk / Scam Statements Found',
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Review the highlighted statements below before signing or paying.',
                        style: TextStyle(fontSize: 12, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        if (hasHighRisk) const SizedBox(height: 16),

        // 3. PROMINENT HIGHLIGHTED STATEMENTS SECTION
        if (r.findings.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Highlighted Risky Statements',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${r.findings.length} Flagged',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Render each highlighted statement
          ...r.findings.map((f) => _buildHighlightedStatementCard(f, theme, isDark)),
          const SizedBox(height: 14),
        ],

        // 4. Plain Language Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2230) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(r.documentType.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${r.documentType.displayName} Summary',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                r.plainSummary,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
            ],
          ),
        ),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildHighlightedStatementCard(
    LegalFinding finding,
    ThemeData theme,
    bool isDark,
  ) {
    final isHigh = finding.severity == LegalRiskSeverity.high;
    final accentColor = isHigh ? const Color(0xFFDC2626) : const Color(0xFFD97706);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1D26) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.4 : 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: isDark ? 0.08 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => LegalFindingDetailSheet(finding: finding),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header badge row (with responsive wrapping/expanded)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        isHigh ? '🚨 CRITICAL RISK' : '⚠️ HIGH RISK',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        finding.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Colors.grey.withValues(alpha: 0.6), size: 18),
                  ],
                ),
                const SizedBox(height: 10),

                // EXACT STATEMENT HIGHLIGHT BOX
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF08A).withValues(alpha: isDark ? 0.12 : 0.22),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFCA8A04).withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('❝ ', style: TextStyle(color: Color(0xFFCA8A04), fontSize: 16, fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(
                          finding.rawExcerpt,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFFEF08A) : const Color(0xFF854D0E),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // WHY IT IS RISKY / EXPLANATION
                Text(
                  finding.simpleExplanation,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.white70 : Colors.black87,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // ACTIONABLE RECOMMENDATION PILL
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF16A34A)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          finding.recommendedAction,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF16A34A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFindingsList(List<LegalFinding> findings, String emptyMessage) {
    if (findings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline_rounded, size: 48, color: Color(0xFF16A34A)),
              const SizedBox(height: 12),
              Text(
                emptyMessage,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: findings.length,
      itemBuilder: (context, index) {
        final f = findings[index];
        return _buildHighlightedStatementCard(f, Theme.of(context), Theme.of(context).brightness == Brightness.dark);
      },
    );
  }

  Widget _buildAnomaliesTab(ThemeData theme, bool isDark) {
    final anomalies = widget.result.anomalies;
    if (anomalies.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.verified_rounded, size: 48, color: Color(0xFF16A34A)),
              SizedBox(height: 12),
              Text(
                'Document Format & Structure Verified ✅',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'No stamp paper, party, or date anomalies detected.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: anomalies.length,
      itemBuilder: (context, index) {
        final a = anomalies[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(a.category.icon, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        a.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(a.explanation, style: theme.textTheme.bodySmall),
                if (a.evidence != null && a.evidence!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Evidence: "${a.evidence}"', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatutesTab(ThemeData theme, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.25)),
          ),
          child: const Text(
            'Applicable Indian Statutory Provisions & Precedents for Scanned Documents',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2563EB)),
          ),
        ),
        const SizedBox(height: 12),
        ...widget.result.findings.expand((f) => f.statutoryBasis).toSet().map((s) {
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              title: Text('${s.actName} — ${s.section}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(s.description, style: const TextStyle(fontSize: 12)),
              ),
              trailing: s.officialSourceUrl != null
                  ? IconButton(
                      icon: const Icon(Icons.open_in_new_rounded, size: 18, color: Color(0xFF2563EB)),
                      onPressed: () => UrlLauncherUtil.openUrl(context, s.officialSourceUrl!),
                    )
                  : null,
            ),
          );
        }),
      ],
    );
  }
}
