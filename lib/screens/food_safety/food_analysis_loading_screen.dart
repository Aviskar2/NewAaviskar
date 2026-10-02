import 'package:flutter/material.dart';
import '../../core/food_safety/models/food_safety_models.dart';

/// Screen 4: Analyzing Label Screen.
/// Clean, technical vertical sequence reflecting real backend processing states.
class FoodAnalysisLoadingScreen extends StatelessWidget {
  final FoodAnalysisStep currentStep;

  const FoodAnalysisLoadingScreen({
    super.key,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    const allSteps = [
      FoodAnalysisStep.readingLabel,
      FoodAnalysisStep.identifyingIngredients,
      FoodAnalysisStep.matchingIngredients,
      FoodAnalysisStep.checkingCategory,
      FoodAnalysisStep.checkingRegulations,
      FoodAnalysisStep.preparingResult,
    ];

    final currentIndex = allSteps.indexOf(currentStep);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Checking Label',
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Regulatory Screening in Progress',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Analyzing visible ingredients and declarations against FSSAI regulatory standards.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 36),

              // Vertical Step Progress Sequence
              ...List.generate(allSteps.length, (index) {
                final step = allSteps[index];
                final isCompleted = index < currentIndex;
                final isCurrent = index == currentIndex;
                final isLast = index == allSteps.length - 1;

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Circle & Connecting Line
                      Column(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCompleted
                                  ? const Color(0xFF16A34A)
                                  : isCurrent
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFFF1F5F9),
                              border: Border.all(
                                color: isCompleted
                                    ? const Color(0xFF16A34A)
                                    : isCurrent
                                        ? const Color(0xFF2563EB)
                                        : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Center(
                              child: isCompleted
                                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                                  : isCurrent
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: isCompleted
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFE2E8F0),
                                margin: const EdgeInsets.symmetric(vertical: 4),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),

                      // Step Label
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 24),
                          child: Text(
                            step.displayName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                              color: isCompleted
                                  ? const Color(0xFF0F172A)
                                  : isCurrent
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const Spacer(),

              // Bottom Notice
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Text(
                  'Notice: This screening reviews information printed on the label. It does not replace laboratory testing.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
