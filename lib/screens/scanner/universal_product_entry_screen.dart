import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/ocr_service.dart';
import '../../services/scan_history_service.dart';
import '../../services/product_safety/product_safety_orchestrator.dart';
import '../../services/medicine_safety/medicine_safety_orchestrator.dart';
import '../product_safety/product_safety_analysis_screen.dart';
import '../medicine_safety/medicine_analysis_screen.dart';

/// Unified Entry Screen for All Products (Food, Medicine, Cosmetics, FMCG & Barcodes).
/// Automatically classifies the product and performs rigorous Indian regulatory safety checks:
/// - Food: FSSAI 14-digit structure, HFSS Traffic Lights, Expiry, Allergens
/// - Medicine: CDSCO Schedules (H/H1/X), Drug Lic No, Jan Aushadhi generic savings
class UniversalProductEntryScreen extends StatefulWidget {
  final OcrService ocrService;
  final ScanHistoryService historyService;
  final String? initialBarcode;

  const UniversalProductEntryScreen({
    Key? key,
    required this.ocrService,
    required this.historyService,
    this.initialBarcode,
  }) : super(key: key);

  @override
  State<UniversalProductEntryScreen> createState() => _UniversalProductEntryScreenState();
}

class _UniversalProductEntryScreenState extends State<UniversalProductEntryScreen> {
  final ProductSafetyOrchestrator _foodOrchestrator = ProductSafetyOrchestrator();
  final MedicineSafetyOrchestrator _medicineOrchestrator = MedicineSafetyOrchestrator();
  final TextEditingController _textController = TextEditingController();

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

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  /// Automatically classifies text as Medicine vs Food/FMCG based on regulatory markers.
  bool _isMedicine(String text) {
    final lower = text.toLowerCase();
    final medicineKeywords = [
      'schedule h',
      'schedule h1',
      'schedule x',
      'schedule g',
      'rx only',
      'mfg. lic. no',
      'mfg lic',
      'tablet',
      'tablets',
      'capsule',
      'capsules',
      'syrup',
      'injection',
      'ointment',
      'dosage:',
      'each film coated',
      'each uncoated',
      'paracetamol',
      'amoxicillin',
      'azithromycin',
      'ibuprofen',
      'pantoprazole',
      'cetirizine',
      'fexofenadine',
      'metformin',
      'atorvastatin',
      'ciprofloxacin',
      'ip 650',
      'ip 500',
      'ip 250',
      'ip 100',
      'ip ',
      'usp ',
      'bp ',
    ];

    for (final kw in medicineKeywords) {
      if (lower.contains(kw)) return true;
    }
    return false;
  }

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

    final isMed = _isMedicine(text);

    setState(() {
      _isProcessing = true;
      _statusMessage = isMed
          ? 'Auditing Medicine: CDSCO Schedule, Mfg Lic & Jan Aushadhi…'
          : 'Auditing Food/Product: FSSAI, Expiry & HFSS Nutrition…';
    });

    try {
      if (isMed) {
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
        final report = await _foodOrchestrator
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

  // ─── Preset Sample Demos (Food & Medicine) ───────────────────────────────────

  void _loadDolo650() {
    const text = '''
DOLO 650 TABLETS
Each uncoated tablet contains:
Paracetamol IP 650 mg
Excipients q.s.
Mfg Lic No: 25/UA/2012
Batch No: DL-88421
Mfg Date: 01/2026
Exp Date: 12/2028
Dosage: As directed by Physician.
SCHEDULE H PRESCRIPTION DRUG - CAUTION:
Not to be sold by retail without prescription of Registered Medical Practitioner.
Manufactured by: Micro Labs Limited, Uttarakhand.
Price: Rs. 34.00 for 15 tablets
''';
    _runDirectAnalysis(text);
  }

  void _loadAugmentin625() {
    const text = '''
AUGMENTIN 625 DUO TABLETS
Each film coated tablet contains:
Amoxicillin Trihydrate IP eq to Amoxicillin 500 mg
Potassium Clavulanate Diluted IP eq to Clavulanic Acid 125 mg
Mfg Lic No: G/25/1890
Batch No: AG-7729
Mfg Dt: 02/2026
Expiry Date: 08/2027
SCHEDULE H1 PRESCRIPTION DRUG - CAUTION:
It is dangerous to take this preparation except in accordance with medical advice.
Not to be sold by retail without the prescription of a Registered Medical Practitioner.
Store below 25°C in a dry place.
Price: Rs. 204.50 for 10 tablets
''';
    _runDirectAnalysis(text);
  }

  void _loadMangoNectar() {
    const text = '''
REAL MANGO NECTAR BEVERAGE
Mfg Dt: 10/01/2026
EXP: 10/10/2026
Barcode: 8901491102034
FSSAI Lic No: 10012011000168
NUTRITIONAL INFORMATION (Per 100ml):
Energy: 65 kcal
Total Sugars: 15.2 g
Added Sugars: 13.5 g
Total Fat: 0.1 g
Saturated Fat: 0.0 g
Sodium: 45 mg
Ingredients: Water, Mango Pulp (20%), Sugar, Acidity Regulator (INS 330), Antioxidant (INS 300).
Contains Permitted Natural Color (INS 160a).
''';
    _runDirectAnalysis(text, rawBarcode: '8901491102034');
  }

  void _loadMaggiNoodles() {
    const text = '''
MAGGI 2-MINUTE NOODLES (MASALA)
Batch: 40120452AA
MFD: 15/02/2026
BEST BEFORE 9 MONTHS FROM MANUFACTURE
Barcode: 8901058852391
FSSAI Lic No: 10012011000168
NUTRITIONAL INFORMATION (Per 100g):
Energy: 427 kcal
Total Fat: 15.7 g
Saturated Fat: 6.8 g
Total Sugars: 2.1 g
Added Sugars: 1.2 g
Sodium: 1080 mg
Ingredients: Wheat Flour (Maida), Palm Oil, Salt, Wheat Gluten, Mineral (Calcium Carbonate), Guar Gum.
Masala Tastemaker: Hydrolysed peanut protein, Mixed spices, Onion powder, Sugar, Garlic powder.
Allergen: Contains Wheat, Peanut and Soy. May contain Milk and Mustard.
''';
    _runDirectAnalysis(text, rawBarcode: '8901058852391');
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
                  // Hero Header Card
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
                          color: const Color(0xFF0F766E).withOpacity(0.25),
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
                                color: Colors.white.withOpacity(0.2),
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
                                    'Food, Medicine, Cosmetics & FMCG',
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
                          'Scan any product packaging or barcode. Aura AI instantly audits Expiry dates, FSSAI licenses, Drug Schedules (H/H1/X), HFSS traffic lights, and Jan Aushadhi generic alternatives.',
                          style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

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

                  // Manual Text/Barcode Audit Box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.grey.shade300,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Or Paste Label Text / Barcode:',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _textController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Enter ingredients, FSSAI Lic No, drug name, or barcode…',
                            hintStyle: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.all(10),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final text = _textController.text.trim();
                              if (text.isNotEmpty) {
                                _runDirectAnalysis(text);
                              }
                            },
                            icon: const Icon(Icons.search_rounded, size: 16),
                            label: const Text('Audit Text'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Quick Demo Samples Header
                  Row(
                    children: [
                      const Icon(Icons.bolt_rounded, color: Color(0xFFEAB308), size: 20),
                      const SizedBox(width: 6),
                      Text(
                        'Live Test Samples (Tap to Demo)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Medicine Samples
                  Text(
                    'MEDICINES & PHARMA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: const Color(0xFF991B1B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDemoCard(
                          title: 'Dolo 650 mg',
                          subtitle: 'Paracetamol IP (Generic)',
                          icon: Icons.medication_rounded,
                          color: const Color(0xFF991B1B),
                          onTap: _loadDolo650,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildDemoCard(
                          title: 'Augmentin 625',
                          subtitle: 'Schedule H1 Antibiotic',
                          icon: Icons.medical_services_rounded,
                          color: const Color(0xFFB91C1C),
                          onTap: _loadAugmentin625,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Food Samples
                  Text(
                    'FOOD & PACKAGED GOODS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: const Color(0xFF0F766E),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDemoCard(
                          title: 'Mango Nectar',
                          subtitle: 'High Sugar HFSS Alert',
                          icon: Icons.local_drink_rounded,
                          color: const Color(0xFF0F766E),
                          onTap: _loadMangoNectar,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildDemoCard(
                          title: 'Maggi Noodles',
                          subtitle: 'Sodium & Allergen Audit',
                          icon: Icons.restaurant_rounded,
                          color: const Color(0xFFD97706),
                          onTap: _loadMaggiNoodles,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDemoCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 18),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios_rounded, size: 12, color: color),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
