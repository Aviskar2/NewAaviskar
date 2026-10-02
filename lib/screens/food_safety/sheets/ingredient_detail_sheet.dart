import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/food_safety/models/food_safety_models.dart';

/// Screen 9: Ingredient Detail Bottom Sheet.
/// Displays plain-English explanation, regulatory status, and official FSSAI source.
class IngredientDetailSheet extends StatelessWidget {
  final IngredientItem ingredient;
  final FoodAdditive? additive;

  const IngredientDetailSheet({
    super.key,
    required this.ingredient,
    this.additive,
  });

  static Future<void> show(
    BuildContext context, {
    required IngredientItem ingredient,
    FoodAdditive? additive,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => IngredientDetailSheet(
        ingredient: ingredient,
        additive: additive,
      ),
    );
  }

  Color _getStatusColor() {
    switch (ingredient.status) {
      case IngredientStatus.potentialNonCompliance:
        return const Color(0xFFDC2626); // Red
      case IngredientStatus.requiresVerification:
        return const Color(0xFFD97706); // Amber
      case IngredientStatus.permitted:
        return const Color(0xFF16A34A); // Green
      case IngredientStatus.normal:
        return const Color(0xFF475569); // Slate neutral
      case IngredientStatus.unknown:
        return const Color(0xFF64748B); // Gray
    }
  }

  Color _getStatusBg() {
    switch (ingredient.status) {
      case IngredientStatus.potentialNonCompliance:
        return const Color(0xFFFEF2F2);
      case IngredientStatus.requiresVerification:
        return const Color(0xFFFFFBEB);
      case IngredientStatus.permitted:
        return const Color(0xFFF0FDF4);
      case IngredientStatus.normal:
        return const Color(0xFFF8FAFC);
      case IngredientStatus.unknown:
        return const Color(0xFFF1F5F9);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final statusBg = _getStatusBg();
    final ins = ingredient.insNumber ?? additive?.insNumber;
    final source = additive?.regulatorySource ?? ingredient.source;
    final why = additive?.explanation ?? ingredient.why;
    final condition = additive?.condition;
    final maxLevel = additive?.maxLevel;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header: Name & INS
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ingredient.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (ins != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        ins,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  ingredient.status == IngredientStatus.potentialNonCompliance
                      ? Icons.cancel_outlined
                      : ingredient.status == IngredientStatus.requiresVerification
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline,
                  size: 16,
                  color: statusColor,
                ),
                const SizedBox(width: 8),
                Text(
                  ingredient.status.displayName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Detection & Type
          _buildInfoRow('Type', ingredient.type),
          _buildInfoRow('Detection', 'Found in ingredients list'),
          if (maxLevel != null) _buildInfoRow('Maximum limit', maxLevel),
          if (condition != null) _buildInfoRow('Permitted use', condition),

          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),

          // Plain English Explanation
          const Text(
            'Explanation',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            why,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),

          // Regulatory Source
          const Text(
            'Regulatory source',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              source,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF334155),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                final url = additive?.officialSourceUrl ?? 'https://www.fssai.gov.in';
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: const BorderSide(color: Color(0xFF2563EB)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'View full rule',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
