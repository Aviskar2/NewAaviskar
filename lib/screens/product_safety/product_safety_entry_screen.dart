import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/product_safety_model.dart';
import '../../services/ocr_service.dart';
import '../../services/product_safety/product_safety_orchestrator.dart';
import '../../services/scan_history_service.dart';
import 'product_safety_analysis_screen.dart';

/// Entry Screen for Product & Food Safety Scanner (Barcode, Expiry, FSSAI & Nutrition).
class ProductSafetyEntryScreen extends StatefulWidget {
  final OcrService ocrService;
  final ScanHistoryService historyService;
  final String? initialBarcode;

  const ProductSafetyEntryScreen({
    Key? key,
    required this.ocrService,
    required this.historyService,
    this.initialBarcode,
  }) : super(key: key);

  @override
  State<ProductSafetyEntryScreen> createState() => _ProductSafetyEntryScreenState();
}

class _ProductSafetyEntryScreenState extends State<ProductSafetyEntryScreen> {
  final ProductSafetyOrchestrator _orchestrator = ProductSafetyOrchestrator();
  bool _isProcessing = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialBarcode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runDirectAnalysis(
          'Product Barcode: ${widget.initialBarcode}',
          rawBarcode: widget.initialBarcode,
        );
      });
    }
  }

  Future<void> _runDirectAnalysis(String text, {String? rawBarcode, String? imagePath}) async {
    if (text.trim().isEmpty) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No text detected in packaging image. Please use a clearer, well-lit photo.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Auditing Expiry, FSSAI & Nutrition facts…';
    });

    try {
      final report = await _orchestrator
          .analyze(text, rawBarcode: rawBarcode, imagePath: imagePath)
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;
      setState(() => _isProcessing = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductSafetyAnalysisScreen(report: report),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Analysis failed: $e')),
        );
      }
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
          SnackBar(content: Text('OCR failed: $e')),
        );
      }
    }
  }

  // ─── Preset Sample Products for Live Demo ──────────────────────────────────

  void _loadHighSugarDrink() {
    const text = '''
REAL MANGO NECTAR BEVERAGE
Mfg Dt: 10/01/2026
EXP: 10/10/2026
Barcode: 8901491102034
FSSAI Lic No: 10012011000168
NUTRITIONAL INFORMATION (Per 100ml):
Energy: 65 kcal
Protein: 0.2g
Carbohydrate: 16.0g
Total Sugars: 15.0g
Added Sugars: 13.5g
Total Fat: 0g
Sodium: 15mg
Ingredients: Water, Mango Pulp (20%), Sugar, Acidity Regulator (INS 330), Stabilizer (INS 440), Antioxidant (INS 300).
100% Vegetarian (Green Dot).
''';
    _runDirectAnalysis(text, rawBarcode: '8901491102034');
  }

  void _loadInstantNoodlesWithMsg() {
    const text = '''
MASALA INSTANT NOODLES
Mfg: 01/02/2026
Best Before 9 Months from Manufacturing
Barcode: 8901058852140
FSSAI Lic No: 10012022000249
NUTRITIONAL FACTS (Per 100g):
Energy: 440 kcal
Protein: 8.5g
Carbohydrates: 62.0g
Total Sugars: 2.2g
Total Fat: 17.5g
Saturated Fat: 8.2g
Trans Fat: 0.1g
Sodium: 980mg
Ingredients: Wheat Flour (Atta), Palm Oil, Salt, Flavour Enhancer INS 621 (MSG), INS 627, INS 631, Acidity Regulators, Turmeric.
Contains Gluten and Wheat.
''';
    _runDirectAnalysis(text, rawBarcode: '8901058852140');
  }

  void _loadExpiredDairyProduct() {
    const text = '''
PASTEURIZED COW MILK (HOMOGENIZED)
PKD: 01/01/2026
USE BY: 04/01/2026
Barcode: 8901262010123
FSSAI Lic No: 10015021000045
NUTRITIONAL VALUES (Per 100ml):
Energy: 62 kcal
Total Fat: 3.5g
Saturated Fat: 2.1g
Protein: 3.1g
Carbohydrates: 4.8g
Total Sugars: 4.8g
Added Sugar: 0.0g
Sodium: 50mg
Calcium: 120mg
Contains: Milk. 100% Vegetarian.
''';
    _runDirectAnalysis(text, rawBarcode: '8901262010123');
  }

  void _loadCertifiedOrganicAtta() {
    const text = '''
AASHIRVAAD SELECT 100% SHARBATI WHOLE WHEAT ATTA
Mfg Dt: 15/05/2026
EXPIRY: 15/11/2026
Barcode: 8901725123456
FSSAI Lic No: 10012031000085
NUTRITIONAL INFORMATION (Per 100g):
Energy: 360 kcal
Protein: 12.0g
Carbohydrates: 73.0g
Total Sugars: 2.5g
Added Sugar: 0.0g
Total Fat: 1.8g
Saturated Fat: 0.4g
Trans Fat: 0.0g
Dietary Fiber: 11.2g
Sodium: 5mg
Ingredients: 100% Whole Wheat Grain. Free from chemical additives, artificial colours, or preservatives.
''';
    _runDirectAnalysis(text, rawBarcode: '8901725123456');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isProcessing) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded, size: 40, color: Color(0xFF16A34A)),
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(color: Color(0xFF16A34A)),
                const SizedBox(height: 20),
                Text(
                  _statusMessage,
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Verifying 14-Digit FSSAI License & ICMR Nutritional Limits',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _isProcessing = false);
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Cancel'),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product & Food Safety Scanner'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF16A34A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 26),
                    SizedBox(width: 10),
                    Text(
                      'Indian Food & Product Verifier',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Scan barcodes (EAN-13), package expiry dates, 14-digit FSSAI licenses, and analyze High Fat/Sugar/Salt (HFSS) traffic lights under Indian Food Safety laws.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Text('CAPTURE OR UPLOAD PRODUCT', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionTile(
                  icon: Icons.camera_alt_rounded,
                  label: 'Scan Barcode / Label',
                  color: const Color(0xFF16A34A),
                  onTap: () => _pickAndAnalyze(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionTile(
                  icon: Icons.photo_library_rounded,
                  label: 'Upload Packaging',
                  color: const Color(0xFF0F766E),
                  onTap: () => _pickAndAnalyze(ImageSource.gallery),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Presets for Live Testing
          Text('OR TEST WITH SAMPLE INDIAN PRODUCTS', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _PresetProductTile(
            title: 'High-Sugar Fruit Drink',
            subtitle: '15g Sugar/100ml (HFSS Alert) · FSSAI License 10012011000168',
            badge: 'Sugar Warning',
            badgeColor: Colors.orange,
            onTap: _loadHighSugarDrink,
          ),
          _PresetProductTile(
            title: 'Instant Masala Noodles',
            subtitle: 'High Sodium (980mg) · INS 621 (MSG) · Best Before 9 Months',
            badge: 'High Sodium & MSG',
            badgeColor: Colors.orange,
            onTap: _loadInstantNoodlesWithMsg,
          ),
          _PresetProductTile(
            title: 'Expired Pasteurized Milk',
            subtitle: 'Use By Date Expired · CPA 2019 Consumer Rights Violation',
            badge: 'Expired 🔴',
            badgeColor: Colors.red,
            onTap: _loadExpiredDairyProduct,
          ),
          _PresetProductTile(
            title: 'Organic Sharbati Whole Wheat Atta',
            subtitle: 'Made in India (890) · 0g Added Sugar · Clean Certified',
            badge: 'Safe & Clean ✅',
            badgeColor: Colors.green,
            onTap: _loadCertifiedOrganicAtta,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetProductTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final VoidCallback onTap;

  const _PresetProductTile({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        onTap: onTap,
        title: Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badge,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
              ),
            ),
          ],
        ),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      ),
    );
  }
}
