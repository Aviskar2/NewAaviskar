import 'package:flutter/material.dart';
import '../../core/legal/models/legal_clause.dart';
import '../../core/legal/models/legal_finding.dart';
import '../../utils/url_launcher_util.dart';

class LegalFindingCard extends StatefulWidget {
  final LegalFinding finding;
  final VoidCallback? onViewOnDocument;

  const LegalFindingCard({
    super.key,
    required this.finding,
    this.onViewOnDocument,
  });

  @override
  State<LegalFindingCard> createState() => _LegalFindingCardState();
}

class _LegalFindingCardState extends State<LegalFindingCard> {
  bool _showLegalExplanation = false;
  bool _showStatutes = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final f = widget.finding;
    final color = f.severity.color;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.35 : 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Text(f.clauseType.categoryIcon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    f.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    f.severity.displayName.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Raw excerpt quote
                if (f.rawExcerpt.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161622) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(color: color, width: 3),
                      ),
                    ),
                    child: Text(
                      '“${f.rawExcerpt}”',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Plain Language Explanation
                Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 16, color: Color(0xFF16A34A)),
                    const SizedBox(width: 6),
                    Text(
                      'Plain Language Summary:',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  f.simpleExplanation,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
                const SizedBox(height: 12),

                // Legal Explanation Toggle
                InkWell(
                  onTap: () => setState(() => _showLegalExplanation = !_showLegalExplanation),
                  child: Row(
                    children: [
                      Icon(
                        _showLegalExplanation ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _showLegalExplanation ? 'Hide Legal Analysis' : 'Show Formal Legal Analysis',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_showLegalExplanation) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      f.legalExplanation,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Statutory Basis
                if (f.statutoryBasis.isNotEmpty) ...[
                  InkWell(
                    onTap: () => setState(() => _showStatutes = !_showStatutes),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_outlined, size: 16, color: Color(0xFF9D00FF)),
                        const SizedBox(width: 6),
                        Text(
                          'Indian Legal References (${f.statutoryBasis.length})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF9D00FF),
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          _showStatutes ? Icons.expand_less : Icons.expand_more,
                          size: 18,
                          color: const Color(0xFF9D00FF),
                        ),
                      ],
                    ),
                  ),
                  if (_showStatutes) ...[
                    const SizedBox(height: 8),
                    ...f.statutoryBasis.map((s) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9D00FF).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${s.actName} — ${s.section}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: Color(0xFF9D00FF),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (s.officialSourceUrl != null)
                                InkWell(
                                  onTap: () => UrlLauncherUtil.launch(s.officialSourceUrl!),
                                  child: const Text(
                                    'India Code ↗',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF2563EB),
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(s.description, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
                        ],
                      ),
                    )),
                  ],
                  const SizedBox(height: 12),
                ],

                // Recommended Action
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.tips_and_updates_outlined, size: 16, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Action: ${f.recommendedAction}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.amber[200] : const Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // View on document button
                if (widget.onViewOnDocument != null && f.boundingBox != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: widget.onViewOnDocument,
                      icon: const Icon(Icons.highlight_rounded, size: 16),
                      label: Text('View Highlight on Page ${f.pageIndex + 1}'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: color,
                        side: BorderSide(color: color.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
