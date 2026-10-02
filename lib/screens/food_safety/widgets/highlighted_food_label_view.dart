import 'package:flutter/material.dart';
import '../../../core/food_safety/models/food_safety_models.dart';
import '../sheets/ingredient_detail_sheet.dart';

/// Screen 10: Highlighted Label View.
/// Highlights recognized ingredients directly on label text with semantic indicators.
/// Tapping an ingredient displays its statutory origin bottom sheet.
class HighlightedFoodLabelView extends StatelessWidget {
  final FoodLabelScanResult result;

  const HighlightedFoodLabelView({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Semantic Legend
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LABEL HIGHLIGHT LEGEND',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _legendItem(const Color(0xFF16A34A), 'Permitted additive'),
                    _legendItem(const Color(0xFFD97706), 'Requires verification'),
                    _legendItem(const Color(0xFFDC2626), 'Potential non-compliance'),
                    _legendItem(const Color(0xFF64748B), 'Normal ingredient'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Interactive Highlighted Ingredients Container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
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
                Row(
                  children: [
                    const Icon(Icons.touch_app_outlined, size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    const Text(
                      'Tap any highlighted ingredient for regulatory details',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (result.ingredients.isEmpty) ...[
                  const Text(
                    'No individual ingredients parsed from label text.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ] else ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: result.ingredients.map((item) {
                      return _buildIngredientChip(context, item);
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Raw Label OCR Excerpt
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SCANNED LABEL TEXT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  result.rawOcrText,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    fontFamily: 'monospace',
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
        ),
      ],
    );
  }

  Widget _buildIngredientChip(BuildContext context, IngredientItem item) {
    Color bg;
    Color border;
    Color text;

    switch (item.status) {
      case IngredientStatus.potentialNonCompliance:
        bg = const Color(0xFFFEF2F2);
        border = const Color(0xFFFCA5A5);
        text = const Color(0xFFB91C1C);
        break;
      case IngredientStatus.requiresVerification:
        bg = const Color(0xFFFFFBEB);
        border = const Color(0xFFFDE68A);
        text = const Color(0xFFB45309);
        break;
      case IngredientStatus.permitted:
        bg = const Color(0xFFF0FDF4);
        border = const Color(0xFFBBF7D0);
        text = const Color(0xFF15803D);
        break;
      case IngredientStatus.normal:
        bg = const Color(0xFFF8FAFC);
        border = const Color(0xFFE2E8F0);
        text = const Color(0xFF1E293B);
        break;
      case IngredientStatus.unknown:
        bg = const Color(0xFFF1F5F9);
        border = const Color(0xFFCBD5E1);
        text = const Color(0xFF475569);
        break;
    }

    return InkWell(
      onTap: () {
        FoodAdditive? additive;
        if (result.additives.isNotEmpty) {
          try {
            additive = result.additives.firstWhere(
              (a) => a.insNumber == item.insNumber || a.name.toLowerCase() == item.name.toLowerCase(),
            );
          } catch (_) {}
        }
        IngredientDetailSheet.show(
          context,
          ingredient: item,
          additive: additive,
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: item.status != IngredientStatus.normal ? FontWeight.w600 : FontWeight.w400,
                color: text,
              ),
            ),
            if (item.insNumber != null) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: border),
                ),
                child: Text(
                  item.insNumber!,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: text),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
