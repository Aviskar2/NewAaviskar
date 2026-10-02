import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/ocr_service.dart';
import '../../services/scan_history_service.dart';
import '../../services/product_classifier.dart';
import '../../services/product_safety/product_safety_orchestrator.dart';
import '../../services/medicine_safety/medicine_safety_orchestrator.dart';
import '../product_safety/product_safety_analysis_screen.dart';
import '../medicine_safety/medicine_analysis_screen.dart';
import '../medicine_safety/medicine_entry_screen.dart';
import '../food_safety/food_safety_home_screen.dart';

/// Unified Entry Screen for All Products.
/// Automatically classifies scanned text into the correct product category
/// and runs the appropriate Indian regulatory safety audit:
/// - Medicine: CDSCO Schedules (H/H1/X), Drug Lic, Jan Aushadhi generics
/// - Food: FSSAI, Expiry, HFSS Nutrition, Allergens, Additives
/// - Cosmetics/Personal Care: CDSCO Cosmetic Rules, Expiry, Ingredients
/// - Household/FMCG: FSSAI (if food-contact), Barcode GS1, Expiry
/// - Electronics: BIS Mark, Warranty, MRP Compliance
class UniversalProductEntryScreen extends StatefulWidget {
  final OcrService ocrService;
  final ScanHistoryService historyService;
  final String? initialBarcode;

  const UniversalProductEntryScreen({
    super.key,
    required this.ocrService,
    required this.historyService,
    this.initialBarcode,
  });

  @override
  State<UniversalProductEntryScreen> createState() => _UniversalProductEntryScreenState();
}

class _UniversalProductEntryScreenState extends State<UniversalProductEntryScreen> {
  final ProductSafetyOrchestrator _productOrchestrator = ProductSafetyOrchestrator();
  final MedicineSafetyOrchestrator _medicineOrchestrator = MedicineSafetyOrchestrator();
  final ProductClassifier _classifier = ProductClassifier();

  bool _isProcessing = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialBarcode != null && widget.initialBarcode!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runDirectAnalysis(
          'Product Barcode: ${widget.initialBarcode}',
          rawBarcode: widget.initialBarcode,
        );
      });
    }
  }



  // ─── Analysis Routing ────────────────────────────────────────────────────

  Future<void> _runDirectAnalysis(
    String text, {
    String? rawBarcode,
    String? imagePath,
  }) async {
    if (text.trim().isEmpty) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No readable text detected. Please use a clearer, well-lit photo.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final category = _classifier.classify(text);

    setState(() {
      _isProcessing = true;
      _statusMessage = _statusMessageFor(category);
    });

    try {
      if (category == ProductCategory.medicine) {
        final report = await _medicineOrchestrator
            .analyze(text, imagePath: imagePath)
            .timeout(const Duration(seconds: 10));

        if (!mounted) return;
        setState(() => _isProcessing = false);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MedicineAnalysisScreen(report: report),
          ),
        );
      } else {
        // Food, Cosmetics, Household, Electronics all go through ProductSafety
        // which handles FSSAI, expiry, barcode GS1, ingredients, nutrition
        final report = await _productOrchestrator
            .analyze(text, rawBarcode: rawBarcode, imagePath: imagePath)
            .timeout(const Duration(seconds: 10));

        if (!mounted) return;
        setState(() => _isProcessing = false);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductSafetyAnalysisScreen(report: report),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Product safety audit failed: $e')),
        );
      }
    }
  }

  String _statusMessageFor(ProductCategory cat) {
    switch (cat) {
      case ProductCategory.medicine:
        return 'Auditing Medicine: CDSCO Schedule, Mfg Lic & Jan Aushadhi…';
      case ProductCategory.food:
        return 'Auditing Food: FSSAI, Expiry & HFSS Nutrition…';
      case ProductCategory.cosmetics:
        return 'Auditing Cosmetic: CDSCO Rules, Expiry & Ingredients…';
      case ProductCategory.household:
        return 'Auditing Product: Barcode, Expiry & Safety Standards…';
      case ProductCategory.electronics:
        return 'Auditing Electronics: BIS Mark, Warranty & MRP…';
      case ProductCategory.unknown:
        return 'Analyzing product…';
    }
  }

  Future<void> _pickAndAnalyze(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, imageQuality: 95);
    if (image == null) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Scanning product label & barcode text…';
    });

    try {
      final ocr = await widget.ocrService.recognizeFromPath(image.path);
      await _runDirectAnalysis(ocr.fullText, imagePath: image.path);
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR Scan failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF2563EB)),
                  const SizedBox(height: 18),
                  Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Checking Indian statutory regulations & standards…',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F766E), Color(0xFF1E3A8A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F766E).withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.verified_user_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Universal Product Scanner',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Food, Medicine, Cosmetics, Electronics & FMCG',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Scan any product label or barcode. AI auto-detects the product type and audits against Indian regulatory standards — FSSAI, CDSCO, BIS, Legal Metrology, and consumer protection laws.',
                          style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Supported Categories Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _CategoryChip(
                        label: '💊 Medicine',
                        color: const Color(0xFF991B1B),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MedicineEntryScreen(
                                ocrService: widget.ocrService,
                                historyService: widget.historyService,
                              ),
                            ),
                          );
                        },
                      ),
                      _CategoryChip(
                        label: '🥗 Food & Beverages',
                        color: const Color(0xFF0F766E),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const FoodSafetyHomeScreen(),
                            ),
                          );
                        },
                      ),
                      const _CategoryChip(label: '💄 Cosmetics', color: Color(0xFF7C3AED)),
                      const _CategoryChip(label: '🧴 Personal Care', color: Color(0xFF6D28D9)),
                      const _CategoryChip(label: '🏠 Household', color: Color(0xFFD97706)),
                      const _CategoryChip(label: '📱 Electronics', color: Color(0xFF2563EB)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Scan Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _pickAndAnalyze(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_rounded),
                          label: const Text('Capture Label'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickAndAnalyze(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_rounded),
                          label: const Text('Upload Photo'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // What We Check
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B0424) : const Color(0xFFF8F9FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF32113D) : const Color(0xFFE5EEFF),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What We Auto-Detect & Verify',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _CheckItem(icon: '💊', text: 'Drug Schedule (H/H1/X), Mfg License, Jan Aushadhi generics'),
                        _CheckItem(icon: '🥗', text: 'FSSAI 14-digit license, Expiry dates, HFSS traffic lights'),
                        _CheckItem(icon: '💄', text: 'Cosmetic CDSCO rules, Paraben/SLS alerts, Expiry'),
                        _CheckItem(icon: '🏷️', text: 'Barcode GS1 country of origin (890 = Made in India)'),
                        _CheckItem(icon: '⚖️', text: 'MRP compliance, Legal Metrology, Consumer Protection Act'),
                        _CheckItem(icon: '⚠️', text: 'Allergen warnings, Banned FDC drugs, Trans fat alerts'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _CategoryChip({
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String icon;
  final String text;

  const _CheckItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
