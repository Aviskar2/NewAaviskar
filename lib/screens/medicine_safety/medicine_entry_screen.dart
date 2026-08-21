import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/ocr_service.dart';
import '../../services/medicine_safety/medicine_safety_orchestrator.dart';
import '../../services/scan_history_service.dart';
import 'medicine_analysis_screen.dart';

/// Entry Screen for Indian Medicine & Pharma Safety Scanner.
class MedicineEntryScreen extends StatefulWidget {
  final OcrService ocrService;
  final ScanHistoryService historyService;

  const MedicineEntryScreen({
    Key? key,
    required this.ocrService,
    required this.historyService,
  }) : super(key: key);

  @override
  State<MedicineEntryScreen> createState() => _MedicineEntryScreenState();
}

class _MedicineEntryScreenState extends State<MedicineEntryScreen> {
  final MedicineSafetyOrchestrator _orchestrator = MedicineSafetyOrchestrator();
  bool _isProcessing = false;
  String _statusMessage = '';

  Future<void> _runDirectAnalysis(String text, {String? imagePath}) async {
    if (text.trim().isEmpty) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No readable text detected on medicine packaging. Please ensure good lighting.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Auditing Drug Schedule, Mfg License & Jan Aushadhi…';
    });

    try {
      final report = await _orchestrator
          .analyze(text, imagePath: imagePath)
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;
      setState(() => _isProcessing = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MedicineAnalysisScreen(report: report),
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
      _statusMessage = 'Scanning medicine strip text & batch details…';
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

  // ─── Preset Sample Medicines for Live Demo ─────────────────────────────────

  void _loadDolo650() {
    const text = '''
DOLO 650 TABLETS
Each uncoated tablet contains:
Paracetamol IP 650 mg
Mfg. Lic. No.: G/25/1458
B.No.: DL9042
MFD.: 01/2026
EXP.: 12/2028
MRP Rs. 34.00 (Incl. of all taxes)
Dosage: As directed by the physician.
Storage: Store below 30°C in a dry place. Protect from light.
Manufactured in India by: Micro Labs Limited, Gujarat.
''';
    _runDirectAnalysis(text);
  }

  void _loadAugmentin625H1() {
    const text = '''
AUGMENTIN 625 DUO TABLETS
SCHEDULE H1 PRESCRIPTION DRUG - CAUTION
Warning: It is dangerous to take this preparation except in accordance with medical advice.
Not to be sold by retail without the prescription of a Registered Medical Practitioner.
Composition:
Amoxicillin Trihydrate IP eq. to Amoxicillin 500 mg
Potassium Clavulanate Diluted IP eq. to Clavulanic Acid 125 mg
Mfg. Lic. No.: MNB/05/189
Batch No.: AG8821
MFG. DATE: 15/02/2026
EXPIRY DATE: 14/02/2028
MRP: Rs. 220.00
Marketed by: GlaxoSmithKline Pharmaceuticals Ltd.
''';
    _runDirectAnalysis(text);
  }

  void _loadExpiredMedicine() {
    const text = '''
CETZINE 10MG TABLETS
Each film coated tablet contains:
Cetirizine Hydrochloride IP 10 mg
Mfg. Lic. No.: MH/102/2019
B.No.: CT4109
MFD: 01/01/2024
EXP: 31/12/2025
Warning: Schedule H Prescription Drug.
Store in a cool dry place.
Manufactured by: Dr. Reddy's Laboratories.
''';
    _runDirectAnalysis(text);
  }

  void _loadBannedFdc() {
    const text = '''
NIMESULIDE AND PARACETAMOL DISPERSIBLE TABLETS
Each dispersible tablet contains:
Nimesulide BP 100 mg
Paracetamol IP 325 mg
Batch No.: NM7011
MFD: 10/2025
EXP: 09/2027
Mfg Lic No: UA/2018/442
Warning: Combination banned for pediatric use under S.O. 560(E).
''';
    _runDirectAnalysis(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                    color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.medication_rounded, size: 40, color: Color(0xFFDC2626)),
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(color: Color(0xFFDC2626)),
                const SizedBox(height: 20),
                Text(
                  _statusMessage,
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Verifying Drugs & Cosmetics Rules 1945 & PMBJP Jan Aushadhi',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: () => setState(() => _isProcessing = false),
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
        title: const Text('Medicine & Pharma Safety Scanner'),
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
                colors: [Color(0xFF991B1B), Color(0xFFDC2626)],
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
                    Icon(Icons.medical_services_rounded, color: Colors.white, size: 26),
                    SizedBox(width: 10),
                    Text(
                      'Indian Medicine & Generic Verifier',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Scan any medicine foil strip or box to verify Drug Manufacturing Licenses (Mfg Lic No), detect Schedule H/H1 prescription warnings, audit batch expiry, and find PMBJP Jan Aushadhi generic cost savings.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Text('CAPTURE OR UPLOAD MEDICINE', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MedicineActionTile(
                  icon: Icons.camera_alt_rounded,
                  label: 'Scan Strip / Box',
                  color: const Color(0xFFDC2626),
                  onTap: () => _pickAndAnalyze(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MedicineActionTile(
                  icon: Icons.photo_library_rounded,
                  label: 'Upload Packaging',
                  color: const Color(0xFF991B1B),
                  onTap: () => _pickAndAnalyze(ImageSource.gallery),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Presets for Live Testing
          Text('OR TEST WITH SAMPLE MEDICINES', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _PresetMedTile(
            title: 'Dolo 650 (Paracetamol 650mg)',
            subtitle: 'Branded MRP ₹34 vs Jan Aushadhi ₹10 · Save 70%',
            badge: 'Save 70% 💰',
            badgeColor: Colors.green,
            onTap: _loadDolo650,
          ),
          _PresetMedTile(
            title: 'Augmentin 625 Duo (Antibiotic)',
            subtitle: 'Schedule H1 Warning (Red Border Box) · Rx Required',
            badge: 'Schedule H1 🚨',
            badgeColor: Colors.red,
            onTap: _loadAugmentin625H1,
          ),
          _PresetMedTile(
            title: 'Expired Allergy Medicine (Cetzine)',
            subtitle: 'Past Expiry Date · Rule 65 Prohibited Consumption',
            badge: 'Expired 🔴',
            badgeColor: Colors.red,
            onTap: _loadExpiredMedicine,
          ),
          _PresetMedTile(
            title: 'Banned Fixed-Dose Combination',
            subtitle: 'Nimesulide + Paracetamol · CDSCO Section 26A Banned FDC',
            badge: 'Banned FDC ⛔',
            badgeColor: Colors.red,
            onTap: _loadBannedFdc,
          ),
        ],
      ),
    );
  }
}

class _MedicineActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MedicineActionTile({
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

class _PresetMedTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final VoidCallback onTap;

  const _PresetMedTile({
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
