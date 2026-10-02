import 'package:flutter/material.dart';
import '../../../core/legal/models/legal_finding.dart';
import '../../../utils/url_launcher_util.dart';
import 'clause_comparison_sheet.dart';

/// Screen/bottom sheet displaying full law details following the Section 11 specifications
class LawDetailSheet extends StatelessWidget {
  final StatutoryCitation citation;
  final LegalFinding? relatedFinding;
  final VoidCallback? onViewInDocument;

  const LawDetailSheet({
    super.key,
    required this.citation,
    this.relatedFinding,
    this.onViewInDocument,
  });

  static Future<void> show(
    BuildContext context, {
    required StatutoryCitation citation,
    LegalFinding? relatedFinding,
    VoidCallback? onViewInDocument,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LawDetailSheet(
        citation: citation,
        relatedFinding: relatedFinding,
        onViewInDocument: onViewInDocument,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 12, 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, size: 22),
                    tooltip: 'Back',
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Law Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: citation.isModernLaw
                          ? const Color(0xFF16A34A).withValues(alpha: 0.15)
                          : const Color(0xFF2563EB).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      citation.statusBadgeText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: citation.isModernLaw ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),

            // Content
            Flexible(
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  // Law Act and Section
                  Text(
                    citation.actName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Section ${citation.section}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    citation.title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section: Why this law is relevant
                  Text(
                    'Why this law is relevant',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.12 : 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      relatedFinding?.simpleExplanation ??
                          'This statutory section establishes binding legal protections under Indian law against one-sided, fraudulent, or unreasonable contractual burdens.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section: Your document (short excerpt)
                  if (relatedFinding != null && relatedFinding!.rawExcerpt.isNotEmpty) ...[
                    Text(
                      'Your document',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF08A).withValues(alpha: isDark ? 0.12 : 0.22),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCA8A04).withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '“${relatedFinding!.rawExcerpt}”',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFFEF08A) : const Color(0xFF854D0E),
                              height: 1.35,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          if (onViewInDocument != null)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  onViewInDocument?.call();
                                },
                                icon: const Icon(Icons.document_scanner_outlined, size: 14),
                                label: const Text('View in document →', style: TextStyle(fontSize: 11.5)),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  foregroundColor: const Color(0xFF2563EB),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Section: Legal provision
                  Text(
                    'Legal provision',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          citation.description,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                          ),
                        ),
                        if (citation.officialSourceUrl != null && citation.officialSourceUrl!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => UrlLauncherUtil.openUrl(context, citation.officialSourceUrl!),
                            icon: const Icon(Icons.open_in_new_rounded, size: 14),
                            label: const Text('Open source ↗', style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF2563EB),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Comparison button at bottom
            if (relatedFinding != null) ...[
              Divider(height: 1, color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
              Padding(
                padding: const EdgeInsets.all(14),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    ClauseComparisonSheet.show(
                      context,
                      finding: relatedFinding!,
                      citation: citation,
                    );
                  },
                  icon: const Icon(Icons.compare_arrows_rounded, size: 16),
                  label: const Text('Compare with document'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
