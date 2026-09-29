/// ChatGPT-style inline bill analysis result card.
/// Renders directly in the chat stream with progressive disclosure.
library;

import 'package:flutter/material.dart';
import '../../models/analysis_result.dart';
import '../../models/bill_model.dart';
import '../../theme/app_colors.dart';
import 'chat_finding_card.dart';

class BillAnalysisInlineCard extends StatefulWidget {
  final BillAnalysisResult result;
  final VoidCallback? onViewFullReport;
  final ValueChanged<String>? onFollowUp;

  const BillAnalysisInlineCard({
    super.key,
    required this.result,
    this.onViewFullReport,
    this.onFollowUp,
  });

  @override
  State<BillAnalysisInlineCard> createState() => _BillAnalysisInlineCardState();
}

class _BillAnalysisInlineCardState extends State<BillAnalysisInlineCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _verdictColor(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>() ?? AppColors.light;
    switch (widget.result.overallResult) {
      case OverallResult.looksCorrect: return appColors.success;
      case OverallResult.needsVerification: return appColors.warning;
      case OverallResult.suspiciousCharges: return appColors.error;
    }
  }

  IconData _verdictIcon() {
    switch (widget.result.overallResult) {
      case OverallResult.looksCorrect: return Icons.check_circle_rounded;
      case OverallResult.needsVerification: return Icons.warning_rounded;
      case OverallResult.suspiciousCharges: return Icons.error_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final r = widget.result;
    final color = _verdictColor(context);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B0424) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVerdictHeader(color, isDark, theme),
            _buildBillInfo(isDark, theme),
            Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.5)),
            _buildFinancialSummary(isDark, theme),
            if (r.findings.isNotEmpty) ...[
              Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.5)),
              _buildKeyFindings(isDark, theme),
            ],
            if (_expanded) ...[
              Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.5)),
              _buildExpandedDetails(isDark, theme),
            ],
            Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.5)),
            _buildActionRow(color, isDark, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildVerdictHeader(Color color, bool isDark, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.06),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Icon(_verdictIcon(), color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.result.overallLabel,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.3),
                ),
                if (widget.result.bill.sellerName != null)
                  Text(
                    widget.result.bill.sellerName!,
                    style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (widget.result.bill.isAiEnhanced)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF9D00FF).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('AI', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF9D00FF))),
            ),
        ],
      ),
    );
  }

  Widget _buildBillInfo(bool isDark, ThemeData theme) {
    final bill = widget.result.bill;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          _infoChip(bill.billType.emoji, bill.billType.displayName, theme),
          if (bill.invoiceNumber != null) _infoChip('📋', 'INV: ${bill.invoiceNumber}', theme),
          if (bill.gstin != null) _infoChip('🏢', bill.gstin!, theme),
        ],
      ),
    );
  }

  Widget _infoChip(String emoji, String label, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.textTheme.bodySmall?.color), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary(bool isDark, ThemeData theme) {
    final r = widget.result;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(child: _summaryColumn('Printed', r.printedTotal != null ? '₹${r.printedTotal!.toStringAsFixed(2)}' : '—', theme)),
          Expanded(child: _summaryColumn('Computed', r.computedTotal != null ? '₹${r.computedTotal!.toStringAsFixed(2)}' : '—', theme)),
          Expanded(child: _summaryColumn('Difference', r.totalDiscrepancy != null ? '₹${r.totalDiscrepancy!.toStringAsFixed(2)}' : '—', theme, valueColor: (r.totalDiscrepancy ?? 0) > 2 ? const Color(0xFFDC2626) : null)),
          if (r.potentialExcess != null && r.potentialExcess! > 0)
            Expanded(child: _summaryColumn('Excess', '₹${r.potentialExcess!.toStringAsFixed(2)}', theme, valueColor: const Color(0xFFDC2626))),
        ],
      ),
    );
  }

  Widget _summaryColumn(String label, String value, ThemeData theme, {Color? valueColor}) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6), letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: valueColor ?? theme.textTheme.bodyLarge?.color)),
      ],
    );
  }

  Widget _buildKeyFindings(bool isDark, ThemeData theme) {
    final r = widget.result;
    final critical = [...r.errorFindings, ...r.suspiciousFindings];
    final warnings = r.verifyFindings;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (critical.isNotEmpty) ...[
            Row(children: [
              const Icon(Icons.error_rounded, size: 14, color: Color(0xFFDC2626)),
              const SizedBox(width: 6),
              Text('${critical.length} Critical Issue${critical.length > 1 ? 's' : ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
            ]),
            const SizedBox(height: 8),
            ...critical.take(3).map((f) => Padding(padding: const EdgeInsets.only(bottom: 4), child: ChatFindingCard(finding: f, compact: true))),
            if (critical.length > 3)
              GestureDetector(
                onTap: () => setState(() => _expanded = true),
                child: Text('+${critical.length - 3} more', style: TextStyle(fontSize: 11, color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
              ),
          ],
          if (warnings.isNotEmpty) ...[
            if (critical.isNotEmpty) const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.warning_rounded, size: 14, color: Color(0xFFD97706)),
              const SizedBox(width: 6),
              Text('${warnings.length} Need Verification', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFD97706))),
            ]),
            const SizedBox(height: 8),
            ...warnings.take(2).map((f) => Padding(padding: const EdgeInsets.only(bottom: 4), child: ChatFindingCard(finding: f, compact: true))),
            if (warnings.length > 2)
              GestureDetector(
                onTap: () => setState(() => _expanded = true),
                child: Text('+${warnings.length - 2} more', style: TextStyle(fontSize: 11, color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
              ),
          ],
          if (critical.isEmpty && warnings.isEmpty)
            Row(children: [
              const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
              const SizedBox(width: 6),
              Text('All checks passed — no issues detected', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF16A34A).withValues(alpha: 0.8))),
            ]),
        ],
      ),
    );
  }

  Widget _buildExpandedDetails(bool isDark, ThemeData theme) {
    final r = widget.result;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (r.gstinVerification != null) ...[
            _sectionTitle('GSTIN Verification', theme),
            const SizedBox(height: 8),
            _gstinCard(r.gstinVerification!, isDark, theme),
            const SizedBox(height: 12),
          ],
          if (r.findings.isNotEmpty) ...[
            _sectionTitle('All Findings (${r.findings.length})', theme),
            const SizedBox(height: 8),
            ...r.findings.map((f) => Padding(padding: const EdgeInsets.only(bottom: 6), child: ChatFindingCard(finding: f))),
          ],
          if (r.bill.aiNotes != null && r.bill.aiNotes!.isNotEmpty) ...[
            _sectionTitle('AI Analysis', theme),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF9D00FF).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF9D00FF).withValues(alpha: 0.15)),
              ),
              child: Text(r.bill.aiNotes!, style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color, height: 1.5)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, ThemeData theme) {
    return Text(title.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: theme.colorScheme.primary));
  }

  Widget _gstinCard(GstinVerification v, bool isDark, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: v.status == GstinStatus.valid
            ? const Color(0xFF16A34A).withValues(alpha: 0.06)
            : const Color(0xFFDC2626).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(v.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.gstin, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'monospace', letterSpacing: 1)),
                const SizedBox(height: 2),
                Text(v.statusText, style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color)),
                if (v.legalName != null) Text(v.legalName!, style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(Color color, bool isDark, ThemeData theme) {
    final followUps = _getFollowUpSuggestions();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              if (widget.onViewFullReport != null)
                Expanded(
                  child: TextButton.icon(
                    onPressed: widget.onViewFullReport,
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: const Text('Full Report', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 14),
                  label: Text(_expanded ? 'Show Less' : 'Show Details', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.textTheme.bodySmall?.color,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (followUps.isNotEmpty && widget.onFollowUp != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: followUps.map((s) => GestureDetector(
                onTap: () => widget.onFollowUp!(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    s,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
                  ),
                ),
              )).toList(),
            ),
          ),
      ],
    );
  }

  List<String> _getFollowUpSuggestions() {
    final suggestions = <String>[];
    final r = widget.result;

    if (r.suspiciousFindings.isNotEmpty || r.errorFindings.isNotEmpty) {
      suggestions.add('Why is this suspicious?');
    }
    if (r.gstinVerification != null) {
      suggestions.add('Is the GSTIN valid?');
    }
    if (r.potentialExcess != null && r.potentialExcess! > 0) {
      suggestions.add('How much was I overcharged?');
    }
    if (r.bill.billType == BillType.restaurant) {
      suggestions.add('Is the service charge legal?');
    }
    if (r.findings.length > 3) {
      suggestions.add('Show all issues');
    }
    return suggestions.take(3).toList();
  }
}
