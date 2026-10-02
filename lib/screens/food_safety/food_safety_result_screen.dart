import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/food_safety/models/food_safety_models.dart';
import 'sheets/food_regulatory_details_sheet.dart';
import 'widgets/highlighted_food_label_view.dart';
import 'widgets/nutrition_summary_card.dart';

/// Master Result Screen covering:
/// - Screen 5: No label-based issue found (✓)
/// - Screen 6: Review recommended (⚠)
/// - Screen 7: Potential non-compliance identified (✕)
/// - Screen 8: Cannot fully verify (ⓘ)
/// And tabs for Highlighted Label (Screen 10) and Nutrition (Screen 11).
class FoodSafetyResultScreen extends StatefulWidget {
  final FoodLabelScanResult result;

  const FoodSafetyResultScreen({
    super.key,
    required this.result,
  });

  @override
  State<FoodSafetyResultScreen> createState() => _FoodSafetyResultScreenState();
}

class _FoodSafetyResultScreenState extends State<FoodSafetyResultScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _otherObservationsExpanded = false;

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

  Color _getStatusThemeColor() {
    switch (widget.result.status) {
      case FoodVerificationStatus.noIssue:
        return const Color(0xFF16A34A); // Green
      case FoodVerificationStatus.reviewRecommended:
        return const Color(0xFFD97706); // Amber
      case FoodVerificationStatus.potentialNonCompliance:
        return const Color(0xFFDC2626); // Red
      case FoodVerificationStatus.cannotFullyVerify:
        return const Color(0xFF2563EB); // Blue
    }
  }

  Color _getStatusBgColor() {
    switch (widget.result.status) {
      case FoodVerificationStatus.noIssue:
        return const Color(0xFFF0FDF4);
      case FoodVerificationStatus.reviewRecommended:
        return const Color(0xFFFFFBEB);
      case FoodVerificationStatus.potentialNonCompliance:
        return const Color(0xFFFEF2F2);
      case FoodVerificationStatus.cannotFullyVerify:
        return const Color(0xFFEFF6FF);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Food Safety Result',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF2563EB),
                unselectedLabelColor: const Color(0xFF64748B),
                indicatorColor: const Color(0xFF2563EB),
                indicatorWeight: 2.5,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                tabs: const [
                  Tab(text: 'Screening'),
                  Tab(text: 'Highlighted Label'),
                  Tab(text: 'Nutrition'),
                ],
              ),
              Container(color: const Color(0xFFE2E8F0), height: 1),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScreeningTab(),
          HighlightedFoodLabelView(result: widget.result),
          _buildNutritionTab(),
        ],
      ),
    );
  }

  Widget _buildNutritionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NutritionSummaryCard(nutrition: widget.result.nutritionSummary),
          const SizedBox(height: 16),
          if (widget.result.allergens.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Declared Allergens',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: widget.result.allergens.map((a) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          a,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Screening Tab covering Screen 5, 6, 7, 8
  Widget _buildScreeningTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Large Simple Status Icon & Header
          Center(
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _getStatusBgColor(),
                    shape: BoxShape.circle,
                    border: Border.all(color: _getStatusThemeColor().withValues(alpha: 0.3)),
                  ),
                  child: Center(
                    child: Text(
                      widget.result.status.iconSymbol,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: _getStatusThemeColor(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.result.status.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.result.status.subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Product & Category Metadata
          if (widget.result.productName != null || widget.result.detectedCategory.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.fastfood_outlined, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.result.productName ?? widget.result.detectedCategory,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      widget.result.detectedCategory,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),

          // Render status-specific view
          if (widget.result.status == FoodVerificationStatus.noIssue) ...[
            _buildNoIssueView(),
          ] else if (widget.result.status == FoodVerificationStatus.reviewRecommended) ...[
            _buildReviewRecommendedView(),
          ] else if (widget.result.status == FoodVerificationStatus.potentialNonCompliance) ...[
            _buildPotentialNonComplianceView(),
          ] else if (widget.result.status == FoodVerificationStatus.cannotFullyVerify) ...[
            _buildCannotFullyVerifyView(),
          ],

          const SizedBox(height: 28),

          // Disclaimer (Screens 5, 6, 7, 8)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'This check reviews information printed on the label. It does not replace laboratory testing.',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Screen 5: Compact Summary for No Label-Based Issue Found
  Widget _buildNoIssueView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              _summaryRow('Ingredients', '✓ Reviewed'),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _summaryRow('Additives', '✓ Reviewed'),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _summaryRow('Allergens', '✓ Reviewed'),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _summaryRow('Label information', '✓ Reviewed'),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Secondary Action: View Details
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => FoodRegulatoryDetailsSheet.show(context, result: widget.result),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              side: const BorderSide(color: Color(0xFF2563EB)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'View details',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1E293B),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF16A34A),
            ),
          ),
        ],
      ),
    );
  }

  /// Screen 6: Primary Finding Only for Review Recommended
  Widget _buildReviewRecommendedView() {
    final primary = widget.result.primaryFinding;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (primary != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            primary.finding,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Text(
                                'Status: ',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                              Text(
                                primary.ruleStatus,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Row(
                            children: [
                              Text(
                                'Detected in: ',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                              Text(
                                'Ingredients',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => FoodRegulatoryDetailsSheet.show(context, result: widget.result),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    child: const Text('View rule', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Other observations (collapsed)
          if (widget.result.otherObservations.isNotEmpty) ...[
            InkWell(
              onTap: () {
                setState(() {
                  _otherObservationsExpanded = !_otherObservationsExpanded;
                });
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Other observations (${widget.result.otherObservations.length})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    Icon(
                      _otherObservationsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: const Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            ),
            if (_otherObservationsExpanded) ...[
              const SizedBox(height: 8),
              ...widget.result.otherObservations.map((obs) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            obs.finding,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                        Text(
                          obs.ruleStatus,
                          style: const TextStyle(fontSize: 11, color: Color(0xFFD97706), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ],
      ],
    );
  }

  /// Screen 7: Prohibited / Non-Compliance Finding
  Widget _buildPotentialNonComplianceView() {
    final primary = widget.result.primaryFinding;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (primary != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ingredient / additive:\n${primary.finding}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Status: ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    Text(
                      primary.ruleStatus,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Why:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 4),
                Text(
                  primary.why,
                  style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Source:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 4),
                Text(
                  primary.source,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      launchUrl(
                        Uri.parse(primary.officialSourceUrl),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('View regulatory source', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Screen 8: Cannot Fully Verify (Neutral State)
  Widget _buildCannotFullyVerifyView() {
    final missing = widget.result.missingInformation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Missing information:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 10),
              if (missing.isEmpty) ...[
                const Text(
                  '• Quantity/concentration not visible\n• Product category unclear\n• Label image unclear',
                  style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF475569)),
                ),
              ] else ...[
                ...missing.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
                          Expanded(
                            child: Text(
                              item,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Action Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => FoodRegulatoryDetailsSheet.show(context, result: widget.result),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              side: const BorderSide(color: Color(0xFF2563EB)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('View details', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ),
      ],
    );
  }
}
