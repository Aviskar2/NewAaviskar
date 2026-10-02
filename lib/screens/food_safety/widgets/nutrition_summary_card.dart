import 'package:flutter/material.dart';
import '../../../core/food_safety/models/food_safety_models.dart';

/// Screen 11: Objective Nutrition Summary Card.
/// Strictly informational data extracted from visible packaging.
/// Per product principles: Never labels food "unhealthy", separating nutritional facts
/// from statutory regulatory compliance.
class NutritionSummaryCard extends StatelessWidget {
  final NutritionSummary nutrition;

  const NutritionSummaryCard({
    super.key,
    required this.nutrition,
  });

  @override
  Widget build(BuildContext context) {
    if (nutrition.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Column(
          children: [
            Icon(Icons.table_rows_outlined, size: 28, color: Color(0xFF94A3B8)),
            SizedBox(height: 8),
            Text(
              'Nutrition panel not detected on visible label',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Nutrition Information',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                if (nutrition.servingSize != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Per ${nutrition.servingSize}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF475569),
                      ),
                    ),
                  )
                else
                  const Text(
                    'Per 100g / ml',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Compact Clean Metric Rows
          _metricRow(
            label: 'Energy',
            value: nutrition.energyKcal != null ? '${nutrition.energyKcal!.toStringAsFixed(0)} kcal' : '—',
          ),
          _metricRow(
            label: 'Total sugar',
            value: nutrition.totalSugarGrams != null ? '${nutrition.totalSugarGrams!.toStringAsFixed(1)} g' : '—',
          ),
          if (nutrition.addedSugarGrams != null)
            _metricRow(
              label: '  • Added sugar',
              value: '${nutrition.addedSugarGrams!.toStringAsFixed(1)} g',
              isIndent: true,
            ),
          _metricRow(
            label: 'Total fat',
            value: nutrition.totalFatGrams != null ? '${nutrition.totalFatGrams!.toStringAsFixed(1)} g' : '—',
          ),
          _metricRow(
            label: '  • Saturated fat',
            value: nutrition.saturatedFatGrams != null ? '${nutrition.saturatedFatGrams!.toStringAsFixed(1)} g' : '—',
            isIndent: true,
          ),
          _metricRow(
            label: '  • Trans fat',
            value: nutrition.transFatGrams != null ? '${nutrition.transFatGrams!.toStringAsFixed(1)} g' : '—',
            isIndent: true,
          ),
          _metricRow(
            label: 'Sodium',
            value: nutrition.sodiumMg != null ? '${nutrition.sodiumMg!.toStringAsFixed(0)} mg' : '—',
          ),
          if (nutrition.proteinGrams != null)
            _metricRow(
              label: 'Protein',
              value: '${nutrition.proteinGrams!.toStringAsFixed(1)} g',
            ),

          // Informational note
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
            ),
            child: const Text(
              'Information extracted directly from printed nutrition table. Values are presented objectively without health scoring.',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricRow({
    required String label,
    required String value,
    bool isIndent = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        left: isIndent ? 24 : 16,
        right: 16,
        top: 10,
        bottom: 10,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isIndent ? FontWeight.w400 : FontWeight.w500,
              color: isIndent ? const Color(0xFF64748B) : const Color(0xFF1E293B),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
              color: isIndent ? const Color(0xFF475569) : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
