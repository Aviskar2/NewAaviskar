import 'package:flutter/material.dart';
import '../../models/analysis_result.dart';

/// Severity-colored finding card for the bill analysis dashboard.
class FindingCard extends StatelessWidget {
  final AnalysisFinding finding;
  final bool isExpanded;
  final VoidCallback onTap;

  const FindingCard({
    super.key,
    required this.finding,
    required this.isExpanded,
    required this.onTap,
  });

  Color _severityColor() {
    switch (finding.severity) {
      case FindingSeverity.ok: return const Color(0xFF16A34A);
      case FindingSeverity.verify: return const Color(0xFFD97706);
      case FindingSeverity.suspicious: return const Color(0xFFDC2626);
      case FindingSeverity.error: return const Color(0xFFB91C1C);
    }
  }

  Color _severityBg(bool isDark) {
    switch (finding.severity) {
      case FindingSeverity.ok: return isDark ? const Color(0xFF052E16) : const Color(0xFFF0FDF4);
      case FindingSeverity.verify: return isDark ? const Color(0xFF1C1407) : const Color(0xFFFFFBEB);
      case FindingSeverity.suspicious: return isDark ? const Color(0xFF1C0505) : const Color(0xFFFFF1F2);
      case FindingSeverity.error: return isDark ? const Color(0xFF1C0505) : const Color(0xFFFEF2F2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = _severityColor();
    final bg = _severityBg(isDark);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(finding.severity.emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          finding.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: color,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          finding.explanation,
                          style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                          maxLines: isExpanded ? null : 2,
                          overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: color,
                    size: 20,
                  ),
                ],
              ),
            ),
            if (isExpanded) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (finding.whatFound != null) ...[
                      _DetailRow('Found:', finding.whatFound!, color),
                      const SizedBox(height: 6),
                    ],
                    if (finding.whatExpected != null) ...[
                      _DetailRow('Expected:', finding.whatExpected!, const Color(0xFF16A34A)),
                      const SizedBox(height: 6),
                    ],
                    if (finding.difference != null) ...[
                      _DetailRow(
                        'Difference:',
                        '₹${finding.difference!.toStringAsFixed(2)}',
                        const Color(0xFFDC2626),
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (finding.recommendation != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.tips_and_updates_outlined,
                                size: 16, color: Color(0xFF2563EB)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                finding.recommendation!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF2563EB),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (finding.source != null)
                      _SourceChip(source: finding.source!),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DetailRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

class _SourceChip extends StatelessWidget {
  final GovernmentSource source;
  const _SourceChip({required this.source});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF9D00FF).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF9D00FF).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_outlined,
              size: 12, color: Color(0xFF9D00FF)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${source.statusLabel} · ${source.organization}',
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF9D00FF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
