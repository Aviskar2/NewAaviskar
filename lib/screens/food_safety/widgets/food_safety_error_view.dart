import 'package:flutter/material.dart';
import '../../../core/food_safety/models/food_safety_models.dart';

/// Screen 13: Empty & Error States View.
/// Displays clean, helpful error recovery with Try Again and Upload Another Photo options.
class FoodSafetyErrorView extends StatelessWidget {
  final FoodSafetyErrorType errorType;
  final VoidCallback onTryAgain;
  final VoidCallback? onUploadAnother;

  const FoodSafetyErrorView({
    super.key,
    required this.errorType,
    required this.onTryAgain,
    this.onUploadAnother,
  });

  IconData _getErrorIcon() {
    switch (errorType) {
      case FoodSafetyErrorType.blurryImage:
        return Icons.blur_on_rounded;
      case FoodSafetyErrorType.noIngredientsDetected:
        return Icons.search_off_rounded;
      case FoodSafetyErrorType.unsupportedLabel:
        return Icons.no_food_outlined;
      case FoodSafetyErrorType.ocrFailure:
        return Icons.document_scanner_outlined;
      case FoodSafetyErrorType.networkFailure:
        return Icons.wifi_off_rounded;
      case FoodSafetyErrorType.regulatoryDataUnavailable:
        return Icons.cloud_off_rounded;
      case FoodSafetyErrorType.partialScan:
        return Icons.crop_free_rounded;
      case FoodSafetyErrorType.multipleProductsDetected:
        return Icons.filter_none_rounded;
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
          'Food Safety Check',
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Neutral Error Icon Container
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Icon(
                  _getErrorIcon(),
                  size: 34,
                  color: const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                errorType.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                errorType.description,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(),

              // Try Again Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onTryAgain,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Upload Another Photo Button
              if (errorType.allowUploadAnother && onUploadAnother != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onUploadAnother,
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Upload Another Photo'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
