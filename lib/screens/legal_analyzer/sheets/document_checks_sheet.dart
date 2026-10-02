import 'package:flutter/material.dart';
import '../../../core/legal/models/document_anomaly.dart';
import '../../../core/legal/models/legal_analysis_result.dart';

/// Bottom sheet displaying the full breakdown of structural & authenticity checks
class DocumentChecksSheet extends StatelessWidget {
  final LegalAnalysisResult result;

  const DocumentChecksSheet({
    super.key,
    required this.result,
  });

  static Future<void> show(BuildContext context, {required LegalAnalysisResult result}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DocumentChecksSheet(result: result),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final anomalies = result.anomalies;
    final hasAnomalies = anomalies.isNotEmpty;

    // Define standard checklist items
    final checks = [
      _CheckItem(
        title: 'Document Structure & Layout',
        description: 'Format, recitals, and standard covenant hierarchy analyzed.',
        isPassed: !anomalies.any((a) => a.category == AnomalyCategory.abnormalFormattingOrFont),
        anomaly: anomalies.cast<DocumentAnomaly?>().firstWhere(
              (a) => a?.category == AnomalyCategory.abnormalFormattingOrFont,
              orElse: () => null,
            ),
      ),
      _CheckItem(
        title: 'Parties & Identification',
        description: 'First party, second party, and representative entity details.',
        isPassed: !anomalies.any((a) => a.category == AnomalyCategory.partyMismatch),
        anomaly: anomalies.cast<DocumentAnomaly?>().firstWhere(
              (a) => a?.category == AnomalyCategory.partyMismatch,
              orElse: () => null,
            ),
      ),
      _CheckItem(
        title: 'Dates & Chronological Consistency',
        description: 'Execution date, commencement date, and tenure consistency.',
        isPassed: !anomalies.any((a) => a.category == AnomalyCategory.dateInconsistency),
        anomaly: anomalies.cast<DocumentAnomaly?>().firstWhere(
              (a) => a?.category == AnomalyCategory.dateInconsistency,
              orElse: () => null,
            ),
      ),
      _CheckItem(
        title: 'Signatures, Stamps & Attestation',
        description: 'Presence of execution signatures, witness blocks, and stamp paper indicator.',
        isPassed: !anomalies.any((a) => a.category == AnomalyCategory.missingSignaturesOrStamps),
        anomaly: anomalies.cast<DocumentAnomaly?>().firstWhere(
              (a) => a?.category == AnomalyCategory.missingSignaturesOrStamps,
              orElse: () => null,
            ),
      ),
      _CheckItem(
        title: 'Financial Figures & Words Match',
        description: 'Verification that numbers match written amount strings.',
        isPassed: !anomalies.any((a) => a.category == AnomalyCategory.amountDiscrepancy),
        anomaly: anomalies.cast<DocumentAnomaly?>().firstWhere(
              (a) => a?.category == AnomalyCategory.amountDiscrepancy,
              orElse: () => null,
            ),
      ),
      _CheckItem(
        title: 'Jurisdiction & Domestic Law Reference',
        description: 'Dispute resolution seated in domestic Indian courts and tribunals.',
        isPassed: !anomalies.any((a) => a.category == AnomalyCategory.unusualJurisdiction),
        anomaly: anomalies.cast<DocumentAnomaly?>().firstWhere(
              (a) => a?.category == AnomalyCategory.unusualJurisdiction,
              orElse: () => null,
            ),
      ),
    ];

    final passedCount = checks.where((c) => c.isPassed).length;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
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
              padding: const EdgeInsets.fromLTRB(18, 6, 12, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: (hasAnomalies ? const Color(0xFFD97706) : const Color(0xFF16A34A)).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      hasAnomalies ? Icons.rule_rounded : Icons.verified_rounded,
                      size: 20,
                      color: hasAnomalies ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Document Checks',
                          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$passedCount of ${checks.length} passed'
                          '${hasAnomalies ? ' · ${anomalies.length} warning${anomalies.length == 1 ? '' : 's'}' : ' · All verified'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: hasAnomalies ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),

            // Checks list
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: checks.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final check = checks[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: check.isPassed
                            ? const Color(0xFF16A34A).withValues(alpha: 0.25)
                            : const Color(0xFFDC2626).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              check.isPassed ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                              size: 18,
                              color: check.isPassed ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                check.title,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: (check.isPassed ? const Color(0xFF16A34A) : const Color(0xFFDC2626)).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                check.isPassed ? 'Verified' : 'Warning',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: check.isPassed ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 26),
                          child: Text(
                            check.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        if (check.anomaly != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            margin: const EdgeInsets.only(left: 26),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626).withValues(alpha: isDark ? 0.15 : 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  check.anomaly!.explanation,
                                  style: const TextStyle(fontSize: 12, height: 1.3),
                                ),
                                if (check.anomaly!.evidence.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Evidence: "${check.anomaly!.evidence}"',
                                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),

            // Footer
            Divider(height: 1, color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckItem {
  final String title;
  final String description;
  final bool isPassed;
  final DocumentAnomaly? anomaly;

  const _CheckItem({
    required this.title,
    required this.description,
    required this.isPassed,
    this.anomaly,
  });
}
