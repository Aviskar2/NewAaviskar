import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/food_safety/models/food_safety_models.dart';

/// Screen 12: Legal / Regulatory Details Screen.
/// Provides deep statutory traceability for all findings with FSSAI citations.
class FoodRegulatoryDetailsSheet extends StatelessWidget {
  final FoodLabelScanResult result;

  const FoodRegulatoryDetailsSheet({
    super.key,
    required this.result,
  });

  static void show(BuildContext context, {required FoodLabelScanResult result}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => FoodRegulatoryDetailsSheet(result: result),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allFindings = <RegulatoryFinding>[];
    if (result.primaryFinding != null) {
      allFindings.add(result.primaryFinding!);
    }
    allFindings.addAll(result.otherObservations);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Regulatory Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Regulatory Framework Overview Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.gavel_outlined, size: 18, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      const Text(
                        'Statutory Framework: FSSAI (India)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Evaluated against Food Safety and Standards (Food Products Standards and Food Additives) Regulations, 2011 and (Labelling and Display) Regulations, 2020.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            Text(
              'FINDINGS & STATUTORY CITATIONS (${allFindings.length})',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),

            if (allFindings.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.check_circle_outline, size: 32, color: Color(0xFF16A34A)),
                    SizedBox(height: 8),
                    Text(
                      'No specific regulatory warnings',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF15803D),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'All detected substances and visible declarations conform to standard permitted schedules under FSSAI rules.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF166534), height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ] else ...[
              ...allFindings.map((finding) => _FindingCard(finding: finding, defaultExpanded: finding.isPrimaryFinding)),
            ],

            const SizedBox(height: 24),
            // Disclaimer footer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Notice: Regulatory screening reflects codified schedules under the Food Safety and Standards Act, 2006. Actual compliance is subject to laboratory verification and batch testing by authorized food analysts.',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.4),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _FindingCard extends StatefulWidget {
  final RegulatoryFinding finding;
  final bool defaultExpanded;

  const _FindingCard({
    required this.finding,
    this.defaultExpanded = false,
  });

  @override
  State<_FindingCard> createState() => _FindingCardState();
}

class _FindingCardState extends State<_FindingCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.defaultExpanded;
  }

  Color _getStatusColor() {
    if (widget.finding.ruleStatus.toLowerCase().contains('prohibited')) {
      return const Color(0xFFDC2626);
    }
    if (widget.finding.ruleStatus.toLowerCase().contains('category') ||
        widget.finding.ruleStatus.toLowerCase().contains('restricted')) {
      return const Color(0xFFD97706);
    }
    return const Color(0xFF16A34A);
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Summary Row (tap to toggle)
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.finding.finding,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.finding.ruleStatus,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),

          // Expanded Content
          if (_expanded) ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('Finding', widget.finding.finding),
                  _detailRow('Rule status', widget.finding.ruleStatus),
                  _detailRow('Food category', widget.finding.foodCategory),
                  if (widget.finding.condition != null)
                    _detailRow('Condition', widget.finding.condition!),
                  if (widget.finding.maxLevel != null)
                    _detailRow('Maximum level', widget.finding.maxLevel!),
                  _detailRow('Source', widget.finding.source),
                  _detailRow('Effective date', widget.finding.effectiveDate),
                  _detailRow('Last verified', widget.finding.lastVerified),

                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        launchUrl(
                          Uri.parse(widget.finding.officialSourceUrl),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      icon: const Icon(Icons.open_in_new, size: 14),
                      label: const Text('Official source'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
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

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
