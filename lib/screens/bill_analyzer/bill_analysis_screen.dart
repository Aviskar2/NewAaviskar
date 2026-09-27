import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/analysis_result.dart';
import '../../models/bill_model.dart';
import '../../theme/app_colors.dart';
import '../../services/scan_history_service.dart';
import '../../utils/url_launcher_util.dart';
import '../../widgets/bill_analysis/finding_card.dart';

/// Main bill analysis result dashboard — the full professional report.
class BillAnalysisScreen extends StatefulWidget {
  final BillAnalysisResult result;
  final String? imagePath;
  final ScanHistoryService historyService;

  const BillAnalysisScreen({
    Key? key,
    required this.result,
    this.imagePath,
    required this.historyService,
  }) : super(key: key);

  @override
  State<BillAnalysisScreen> createState() => _BillAnalysisScreenState();
}

class _BillAnalysisScreenState extends State<BillAnalysisScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Set<String> _expandedFindings = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _overallColor(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    switch (widget.result.overallResult) {
      case OverallResult.looksCorrect: return colors.success;
      case OverallResult.needsVerification: return colors.warning;
      case OverallResult.suspiciousCharges: return colors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = widget.result;
    final color = _overallColor(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Analysis'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share report',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _buildTextReport(r)));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Report copied to clipboard'),
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
          tabs: const [
            Tab(text: 'Summary'),
            Tab(text: '✅ OK'),
            Tab(text: '⚠️ Verify'),
            Tab(text: '🚨 Issues'),
            Tab(text: '🔍 Patterns'),
            Tab(text: '🏢 GSTIN'),
            Tab(text: '📜 Sources'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Overall verdict banner
          _OverallBanner(result: r, color: color, theme: theme),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _SummaryTab(result: r, imagePath: widget.imagePath),
                _FindingsTab(
                  findings: r.okFindings,
                  emptyLabel: 'No issues flagged as correct yet',
                  expandedIds: _expandedFindings,
                  onToggle: (id) => setState(() {
                    if (_expandedFindings.contains(id)) {
                      _expandedFindings.remove(id);
                    } else {
                      _expandedFindings.add(id);
                    }
                  }),
                ),
                _FindingsTab(
                  findings: r.verifyFindings,
                  emptyLabel: 'No items need verification ✅',
                  expandedIds: _expandedFindings,
                  onToggle: (id) => setState(() {
                    if (_expandedFindings.contains(id)) {
                      _expandedFindings.remove(id);
                    } else {
                      _expandedFindings.add(id);
                    }
                  }),
                ),
                _FindingsTab(
                  findings: [...r.errorFindings, ...r.suspiciousFindings],
                  emptyLabel: 'No suspicious charges found ✅',
                  expandedIds: _expandedFindings,
                  onToggle: (id) => setState(() {
                    if (_expandedFindings.contains(id)) {
                      _expandedFindings.remove(id);
                    } else {
                      _expandedFindings.add(id);
                    }
                  }),
                ),
                _PatternTab(result: r),
                _GstinTab(verification: r.gstinVerification),
                _SourcesTab(sources: r.sources),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildTextReport(BillAnalysisResult r) {
    final buf = StringBuffer();
    buf.writeln('=== BILL ANALYSIS REPORT ===');
    buf.writeln('Overall: ${r.overallEmoji} ${r.overallLabel}');
    buf.writeln('Bill Type: ${r.bill.billType.displayName}');
    if (r.bill.sellerName != null) buf.writeln('Seller: ${r.bill.sellerName}');
    if (r.bill.gstin != null) buf.writeln('GSTIN: ${r.bill.gstin}');
    if (r.printedTotal != null) buf.writeln('Printed Total: ₹${r.printedTotal!.toStringAsFixed(2)}');
    if (r.computedTotal != null) buf.writeln('Calculated Total: ₹${r.computedTotal!.toStringAsFixed(2)}');
    buf.writeln('\n--- FINDINGS ---');
    for (final f in r.findings) {
      buf.writeln('${f.severity.emoji} [${f.category}] ${f.title}');
      buf.writeln('   ${f.explanation}');
    }
    buf.writeln('\nAnalyzed: ${r.analyzedAt}');
    return buf.toString();
  }
}

// ─── Overall Banner ───────────────────────────────────────────────────────────

class _OverallBanner extends StatelessWidget {
  final BillAnalysisResult result;
  final Color color;
  final ThemeData theme;

  const _OverallBanner({
    required this.result,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        border: Border(
          bottom: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Text(result.overallEmoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.overallLabel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${result.bill.billType.emoji} ${result.bill.billType.displayName}'
                  '${result.bill.sellerName != null ? " · ${result.bill.sellerName}" : ""}',
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (result.bill.isAiEnhanced) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: appColors.aiPurple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '🤖 AI AUDITED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: appColors.aiPurple,
                    ),
                  ),
                ),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: result.isOnlineVerified
                      ? appColors.success.withValues(alpha: 0.15)
                      : appColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  result.isOnlineVerified ? '🟢 LIVE' : '🟡 CACHED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: result.isOnlineVerified ? appColors.success : appColors.warning,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${result.findings.length} findings',
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Pattern Analysis Tab ──────────────────────────────────────────────────

class _PatternTab extends StatelessWidget {
  final BillAnalysisResult result;

  const _PatternTab({
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Filter findings for Pattern, ML, and History categories
    final patternFindings = result.findings
        .where((f) => f.category == 'Pattern' || f.category == 'ML' || f.category == 'History')
        .toList();

    if (patternFindings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined,
                size: 64,
                color: theme.colorScheme.primary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'No pattern anomalies detected',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Round amounts, threshold abuse, vendor risk,\nand statistical anomalies were checked.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    // Group by category
    final grouped = <String, List<AnalysisFinding>>{};
    for (final f in patternFindings) {
      grouped.putIfAbsent(f.category, () => []).add(f);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Anomaly score summary
        _AnomalyScoreCard(findings: patternFindings),
        const SizedBox(height: 16),

        // Grouped findings
        for (final entry in grouped.entries) ...[
          _SectionHeader(title: entry.key),
          const SizedBox(height: 8),
          for (final finding in entry.value)
            _PatternFindingCard(finding: finding),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _AnomalyScoreCard extends StatelessWidget {
  final List<AnalysisFinding> findings;

  const _AnomalyScoreCard({
    required this.findings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appColors = theme.extension<AppColors>()!;
    final suspiciousCount = findings
        .where((f) => f.severity == FindingSeverity.suspicious)
        .length;
    final verifyCount = findings
        .where((f) => f.severity == FindingSeverity.verify)
        .length;
    final total = findings.length;

    final score = total > 0 ? ((suspiciousCount * 2 + verifyCount) / (total * 2) * 100).clamp(0, 100) : 0;
    final scoreColor = score > 60
        ? appColors.error
        : score > 30
            ? appColors.warning
            : appColors.success;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scoreColor.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            'Pattern Anomaly Score',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '${score.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: scoreColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$suspiciousCount suspicious · $verifyCount needs review',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatternFindingCard extends StatelessWidget {
  final AnalysisFinding finding;

  const _PatternFindingCard({
    required this.finding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;
    final color = finding.severity == FindingSeverity.suspicious
        ? appColors.error
        : finding.severity == FindingSeverity.verify
            ? appColors.warning
            : appColors.success;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(finding.severity.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  finding.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  finding.category,
                  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            finding.explanation,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          if (finding.recommendation != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Text('💡 ', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Text(
                      finding.recommendation!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

// ─── Summary Tab ──────────────────────────────────────────────────────────────

class _SummaryTab extends StatelessWidget {
  final BillAnalysisResult result;
  final String? imagePath;

  const _SummaryTab({
    required this.result,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    final r = result;
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Quick Verdict Card — most important info first
        _QuickVerdictCard(result: r, appColors: appColors, theme: theme),

        // Image thumbnail
        if (imagePath != null && File(imagePath!).existsSync())
          _SectionCard(
            title: '📸 Original Bill',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(imagePath!),
                height: 200,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
          ),

        // AI Insights Card
        if (r.bill.aiNotes != null && r.bill.aiNotes!.isNotEmpty)
          _SectionCard(
            title: '✨ AI Audit Summary (${r.bill.aiModelUsed?.split('/').last ?? 'LLM'})',
            child: Text(
              r.bill.aiNotes!,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

        // Financial summary
        _SectionCard(
          title: '💰 Bill Ka Pura Hisab',
          child: Column(
            children: [
              if (r.bill.itemsGrossTotal > 0)
                _SummaryRow(
                  'Saamaan Ki Kimat',
                  '₹${r.bill.itemsGrossTotal.toStringAsFixed(2)}',
                ),
              if (r.bill.totalDiscountAmount > 0)
                _SummaryRow(
                  'Discount / Bachat',
                  '-₹${r.bill.totalDiscountAmount.toStringAsFixed(2)}',
                  color: appColors.success,
                ),
              _SummaryRow(
                'Tax Lagane Se Pehle (Taxable)',
                r.bill.taxes.subtotal != null
                    ? '₹${r.bill.taxes.subtotal!.toStringAsFixed(2)}'
                    : (r.bill.computedSubtotal > 0
                        ? '₹${r.bill.computedSubtotal.toStringAsFixed(2)}'
                        : '—'),
              ),
              _SummaryRow(
                'Total GST / Tax',
                '₹${r.bill.taxes.totalPrintedTax.toStringAsFixed(2)}',
                color: r.bill.taxes.totalPrintedTax > 0 ? appColors.info : null,
              ),
              if (r.bill.totalCharges > 0)
                _SummaryRow(
                  'Extra Charges (Service/Packaging)',
                  '₹${r.bill.totalCharges.toStringAsFixed(2)}',
                  color: appColors.warning,
                ),
              if (r.bill.taxes.roundOff != null && r.bill.taxes.roundOff != 0)
                _SummaryRow(
                  'Round-Off Adjustment',
                  '${r.bill.taxes.roundOff! > 0 ? "+" : ""}₹${r.bill.taxes.roundOff!.toStringAsFixed(2)}',
                ),
              const Divider(height: 20),
              _SummaryRow(
                'Calculated Expected Total',
                '₹${(r.computedTotal ?? r.bill.calculatedNetTotal ?? r.printedTotal ?? 0.0).toStringAsFixed(2)}',
                color: appColors.success,
              ),
              _SummaryRow(
                'Amount Billed',
                r.printedTotal != null ? '₹${r.printedTotal!.toStringAsFixed(2)}' : '—',
              ),
              if (r.potentialExcess != null && r.potentialExcess! > 0)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: appColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: appColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: appColors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '⚠️ Overcharge Detected: ₹${r.potentialExcess!.toStringAsFixed(2)} excess amount charged!',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: appColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Accurate GST breakdown
        _SectionCard(
          title: '🧾 Complete GST Breakdown',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Supply type badge
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (r.bill.isInterState ? appColors.info : appColors.scannerCyan).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (r.bill.isInterState ? appColors.info : appColors.scannerCyan).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  r.bill.isInterState
                      ? '🌐 Inter-State Supply (IGST Applicable)'
                      : (r.bill.isIntraState
                          ? '🏛️ Intra-State Supply (CGST + SGST Applicable)'
                          : '📄 Composition / Non-GST Bill'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: r.bill.isInterState ? appColors.info : appColors.scannerCyan,
                  ),
                ),
              ),

              if (r.bill.taxes.cgstAmount != null)
                _SummaryRow(
                  'CGST (Central Tax)${r.bill.taxes.cgstRate != null ? " @ ${r.bill.taxes.cgstRate}%" : ""}',
                  '₹${r.bill.taxes.cgstAmount!.toStringAsFixed(2)}',
                ),
              if (r.bill.taxes.sgstAmount != null)
                _SummaryRow(
                  'SGST (State Tax)${r.bill.taxes.sgstRate != null ? " @ ${r.bill.taxes.sgstRate}%" : ""}',
                  '₹${r.bill.taxes.sgstAmount!.toStringAsFixed(2)}',
                ),
              if (r.bill.taxes.igstAmount != null)
                _SummaryRow(
                  'IGST (Integrated GST)${r.bill.taxes.igstRate != null ? " @ ${r.bill.taxes.igstRate}%" : ""}',
                  '₹${r.bill.taxes.igstAmount!.toStringAsFixed(2)}',
                ),
              if (r.bill.taxes.cessAmount != null && r.bill.taxes.cessAmount! > 0)
                _SummaryRow(
                  'Cess (Compensation)',
                  '₹${r.bill.taxes.cessAmount!.toStringAsFixed(2)}',
                ),

              if (r.bill.taxes.effectiveGstRate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _SummaryRow(
                    'Effective GST Rate',
                    '${r.bill.taxes.effectiveGstRate!.toStringAsFixed(1)}%',
                    color: appColors.info,
                  ),
                ),

              const Divider(height: 16),
              _SummaryRow(
                'Total GST Amount',
                '₹${r.bill.taxes.totalPrintedTax.toStringAsFixed(2)}',
                color: appColors.success,
              ),

              if (r.bill.taxes.cgstAmount == null &&
                  r.bill.taxes.sgstAmount == null &&
                  r.bill.taxes.igstAmount == null &&
                  r.bill.taxes.totalPrintedTax == 0)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'No separate GST breakdown found on this receipt.',
                    style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),

        // Extra charges
        if (r.bill.charges.isNotEmpty)
          _SectionCard(
            title: '🧮 Additional Charges',
            child: Column(
              children: r.bill.charges.map((c) {
                return _SummaryRow(
                  c.isServiceCharge ? 'Service Charge (Optional)' : c.label,
                  '₹${c.amount.toStringAsFixed(2)}',
                  color: c.isServiceCharge ? appColors.warning : null,
                );
              }).toList(),
            ),
          ),

        // Item list
        if (r.itemResults.isNotEmpty)
          _SectionCard(
            title: '🔍 Itemized Bill Details',
            child: Column(
              children: r.itemResults.map((ir) {
                final itemColor = ir.status == FindingSeverity.ok
                    ? appColors.success
                    : appColors.warning;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: itemColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: itemColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Text(ir.status.emoji, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ir.item.name,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                            if (ir.item.quantity != null && ir.item.unitPrice != null)
                              Text(
                                'Qty: ${ir.item.quantity} × ₹${ir.item.unitPrice!.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 11),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        ir.item.lineTotal != null
                            ? '₹${ir.item.lineTotal!.toStringAsFixed(2)}'
                            : '—',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: itemColor),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

// ─── Findings Tab ─────────────────────────────────────────────────────────────

class _FindingsTab extends StatelessWidget {
  final List<AnalysisFinding> findings;
  final String emptyLabel;
  final Set<String> expandedIds;
  final void Function(String id) onToggle;

  const _FindingsTab({
    required this.findings,
    required this.emptyLabel,
    required this.expandedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (findings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✅', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(emptyLabel,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: findings.map((f) {
        return FindingCard(
          finding: f,
          isExpanded: expandedIds.contains(f.id),
          onTap: () => onToggle(f.id),
        );
      }).toList(),
    );
  }
}

// ─── GSTIN Tab ────────────────────────────────────────────────────────────────

class _GstinTab extends StatelessWidget {
  final GstinVerification? verification;

  const _GstinTab({
    required this.verification,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = Theme.of(context).extension<AppColors>()!;

    if (verification == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚪', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            const Text('No GSTIN found on this bill',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'GSTIN is required on all invoices where the supplier is GST-registered.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    final v = verification!;
    final color = v.status == GstinStatus.valid ? appColors.success : appColors.error;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Text(v.emoji, style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text(v.gstin,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontFamily: 'monospace',
                    letterSpacing: 1.5,
                  )),
              const SizedBox(height: 6),
              Text(v.statusText,
                  style: TextStyle(fontWeight: FontWeight.w600, color: color)),
              if (v.isLiveVerified)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('🟢 Live verified from GST Portal',
                      style: TextStyle(fontSize: 12, color: appColors.success)),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('🟡 Offline checksum validation only',
                      style: TextStyle(fontSize: 12, color: appColors.warning)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (v.legalName != null) _InfoRow('Legal Name', v.legalName!),
        if (v.tradeName != null) _InfoRow('Trade Name', v.tradeName!),
        if (v.registrationStatus != null)
          _InfoRow('Status', v.registrationStatus!),
        if (v.registrationDate != null)
          _InfoRow('Registered On', v.registrationDate!),
        if (v.stateCode != null) _InfoRow('State', v.stateCode!),
        if (v.errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: appColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: appColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: appColors.warning, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(v.errorMessage!,
                      style: TextStyle(fontSize: 12, color: appColors.warning)),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => UrlLauncherUtil.openUrl(
              context, 'https://www.gst.gov.in/searchtaxpayer'),
          icon: const Icon(Icons.open_in_new, size: 16),
          label: const Text('Verify on GST Portal'),
        ),
      ],
    );
  }
}

// ─── Sources Tab ──────────────────────────────────────────────────────────────

class _SourcesTab extends StatelessWidget {
  final List<GovernmentSource> sources;

  const _SourcesTab({
    required this.sources,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: appColors.aiPurple.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: appColors.aiPurple.withValues(alpha: 0.2)),
          ),
          child: Text(
            'All rules and findings are based on official Indian government sources. '
            'Cached rules are from publicly available government notifications and are '
            'clearly marked as cached vs live.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
          ),
        ),
        const SizedBox(height: 12),
        ...sources.map((s) => _SourceCard(source: s)),
      ],
    );
  }
}

class _SourceCard extends StatelessWidget {
  final GovernmentSource source;

  const _SourceCard({required this.source});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_rounded, size: 16, color: appColors.aiPurple),
              const SizedBox(width: 8),
              Expanded(
                child: Text(source.title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: source.status == SourceVerificationStatus.live
                      ? appColors.success.withValues(alpha: 0.15)
                      : appColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  source.statusLabel,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: source.status == SourceVerificationStatus.live
                        ? appColors.success
                        : appColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(source.description,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12, height: 1.4)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.business_outlined, size: 12, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(
                child: Text(source.organization,
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
              ),
            ],
          ),
          if (source.effectiveDate != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 12, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('Effective: ${source.effectiveDate}',
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => UrlLauncherUtil.openUrl(context, source.url),
            child: Row(
              children: [
                Icon(Icons.open_in_new, size: 14, color: appColors.info),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    source.url,
                    style: TextStyle(
                      fontSize: 11,
                      color: appColors.info,
                      decoration: TextDecoration.underline,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────

/// Quick Verdict Card — shows the most important info at a glance
class _QuickVerdictCard extends StatelessWidget {
  final BillAnalysisResult result;
  final AppColors appColors;
  final ThemeData theme;

  const _QuickVerdictCard({
    required this.result,
    required this.appColors,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final r = result;
    final isDark = theme.brightness == Brightness.dark;

    Color verdictColor;
    String verdictTitle;
    String verdictSubtitle;
    IconData verdictIcon;

    switch (r.overallResult) {
      case OverallResult.looksCorrect:
        verdictColor = appColors.success;
        verdictTitle = 'Bill Appears Legitimate';
        verdictSubtitle = 'No major issues detected';
        verdictIcon = Icons.check_circle_rounded;
        break;
      case OverallResult.needsVerification:
        verdictColor = appColors.warning;
        verdictTitle = 'Requires Verification';
        verdictSubtitle = '${r.verifyFindings.length} items flagged for review';
        verdictIcon = Icons.warning_amber_rounded;
        break;
      case OverallResult.suspiciousCharges:
        verdictColor = appColors.error;
        verdictTitle = 'Potential Fraud / Overcharge!';
        verdictSubtitle = '${r.errorFindings.length + r.suspiciousFindings.length} serious issues found';
        verdictIcon = Icons.error_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            verdictColor.withValues(alpha: isDark ? 0.2 : 0.1),
            verdictColor.withValues(alpha: isDark ? 0.08 : 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: verdictColor.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(verdictIcon, color: verdictColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      verdictTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: verdictColor,
                      ),
                    ),
                    Text(
                      verdictSubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Key numbers in a row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.cardColor.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                if (r.printedTotal != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Amount on Bill:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(
                        '₹${r.printedTotal!.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: verdictColor),
                      ),
                    ],
                  ),
                if (r.computedTotal != null && r.computedTotal != r.printedTotal) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Calculated Expected:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(
                        '₹${r.computedTotal!.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.green),
                      ),
                    ],
                  ),
                ],
                if (r.potentialExcess != null && r.potentialExcess! > 0) ...[
                  const Divider(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Excess Charged:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.red)),
                      Text(
                        '₹${r.potentialExcess!.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.red),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // GST Rate info
          if (r.bill.taxes.effectiveGstRate != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _GstRateChip(
                  label: 'GST Rate',
                  rate: '${r.bill.taxes.effectiveGstRate!.toStringAsFixed(1)}%',
                  color: appColors.info,
                ),
                const SizedBox(width: 8),
                if (r.bill.taxes.cgstRate != null)
                  _GstRateChip(
                    label: 'CGST',
                    rate: '${r.bill.taxes.cgstRate}%',
                    color: appColors.info,
                  ),
                if (r.bill.taxes.sgstRate != null) ...[
                  const SizedBox(width: 8),
                  _GstRateChip(
                    label: 'SGST',
                    rate: '${r.bill.taxes.sgstRate}%',
                    color: appColors.scannerCyan,
                  ),
                ],
                if (r.bill.taxes.igstRate != null) ...[
                  const SizedBox(width: 8),
                  _GstRateChip(
                    label: 'IGST',
                    rate: '${r.bill.taxes.igstRate}%',
                    color: appColors.scannerCyan,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _GstRateChip extends StatelessWidget {
  final String label;
  final String rate;
  final Color color;

  const _GstRateChip({
    required this.label,
    required this.rate,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label: $rate',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(title,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          ),
          Divider(height: 16, color: theme.dividerTheme.color),
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: child),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _SummaryRow(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
