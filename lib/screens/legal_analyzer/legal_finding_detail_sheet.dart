import 'package:flutter/material.dart';
import '../../core/legal/models/legal_finding.dart';
import '../../utils/url_launcher_util.dart';

class LegalFindingDetailSheet extends StatelessWidget {
  final LegalFinding finding;

  const LegalFindingDetailSheet({
    super.key,
    required this.finding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = finding.severity.color;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Text(finding.severity.emoji, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        finding.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        'Page ${finding.pageIndex + 1} · ${finding.severity.displayName}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Raw Excerpt
                if (finding.rawExcerpt.isNotEmpty) ...[
                  Text(
                    'HIGHLIGHTED CLAUSE TEXT',
                    style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161622) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border(left: BorderSide(color: color, width: 3)),
                    ),
                    child: Text(
                      '“${finding.rawExcerpt}”',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Plain Language Explanation
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lightbulb, size: 16, color: Color(0xFF16A34A)),
                          SizedBox(width: 6),
                          Text(
                            'What this means in plain language:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        finding.simpleExplanation,
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Legal Analysis
                Text(
                  'LEGAL ANALYSIS & PRECEDENT',
                  style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  finding.legalExplanation,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
                const SizedBox(height: 16),

                // Indian Statutes & Section Comparison
                if (finding.statutoryBasis.isNotEmpty) ...[
                  Row(
                    children: const [
                      Icon(Icons.balance_rounded, size: 16, color: Color(0xFF1E40AF)),
                      SizedBox(width: 6),
                      Text(
                        'STATUTORY COMPARISON (WHICH SECTION OF LAW)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E40AF),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...finding.statutoryBasis.map((s) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.12 : 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: s.isModernLaw
                                    ? const Color(0xFF16A34A).withValues(alpha: 0.15)
                                    : const Color(0xFF2563EB).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                s.statusBadgeText,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: s.isModernLaw ? const Color(0xFF15803D) : const Color(0xFF1E40AF),
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (s.officialSourceUrl != null)
                              InkWell(
                                onTap: () => UrlLauncherUtil.launch(s.officialSourceUrl!),
                                child: Padding(
                                  padding: const EdgeInsets.all(2.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Text(
                                        'India Code Source',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF2563EB),
                                          fontWeight: FontWeight.w700,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                      SizedBox(width: 2),
                                      Icon(Icons.open_in_new_rounded, size: 12, color: Color(0xFF2563EB)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${s.actName} — ${s.section}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // DIRECT SIDE-BY-SIDE STATUTORY COMPARISON
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Clause in Document
                              Row(
                                children: const [
                                  Icon(Icons.description_outlined, size: 13, color: Color(0xFFDC2626)),
                                  SizedBox(width: 4),
                                  Text(
                                    'DOCUMENT CLAUSE STATEMENT:',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '"${finding.rawExcerpt}"',
                                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 10),

                              // Divider / VS
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    '⚖️ COMPARED AGAINST ACTIVE INDIAN LAW MANDATE ⚖️',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // 2. What Indian Law Mandates
                              Row(
                                children: const [
                                  Icon(Icons.gavel_rounded, size: 13, color: Color(0xFF15803D)),
                                  SizedBox(width: 4),
                                  Text(
                                    'WHAT THE LAW ENFORCES IN INDIA:',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                s.description,
                                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12, height: 1.35),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
                  const SizedBox(height: 16),
                ],

                // Actionable advice
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.shield_outlined, size: 16, color: Color(0xFFF59E0B)),
                          SizedBox(width: 6),
                          Text(
                            'Recommended Next Step:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        finding.recommendedAction,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ],
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
