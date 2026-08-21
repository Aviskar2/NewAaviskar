import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/legal/models/legal_document_type.dart';
import '../../services/legal/legal_orchestrator.dart';
import '../../services/ocr_service.dart';
import '../../services/scan_history_service.dart';
import 'legal_analysis_screen.dart';

class LegalAnalyzerEntryScreen extends StatefulWidget {
  final OcrService ocrService;
  final ScanHistoryService historyService;

  const LegalAnalyzerEntryScreen({
    super.key,
    required this.ocrService,
    required this.historyService,
  });

  @override
  State<LegalAnalyzerEntryScreen> createState() => _LegalAnalyzerEntryScreenState();
}

class _LegalAnalyzerEntryScreenState extends State<LegalAnalyzerEntryScreen> {
  final LegalOrchestrator _orchestrator = LegalOrchestrator();
  bool _isAnalyzing = false;
  String _statusMessage = '';

  Future<void> _analyzeRawText(String text, {String? imagePath, LegalDocumentType? forcedType}) async {
    if (text.trim().isEmpty) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No readable text found in this document. Please ensure good lighting and clear focus.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _statusMessage = 'Extracting legal clauses & risk factors…';
    });

    try {
      final doc = _orchestrator.createDocumentFromText(text, imagePath: imagePath);
      final result = await _orchestrator
          .analyze(doc, forcedType: forcedType)
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;
      setState(() => _isAnalyzing = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LegalAnalysisScreen(result: result),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, imageQuality: 95);
    if (image == null) return;

    setState(() {
      _isAnalyzing = true;
      _statusMessage = 'Running OCR text & coordinate detection…';
    });

    try {
      final ocrResult = await widget.ocrService.recognizeFromPath(image.path);
      await _analyzeRawText(ocrResult.fullText, imagePath: image.path);
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OCR failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showTextInputDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paste Document Text'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'Paste clause or contract text here…',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _analyzeRawText(controller.text);
            },
            child: const Text('Analyze'),
          ),
        ],
      ),
    );
  }

  // ─── Preset Sample Contracts for Testing ──────────────────────────────────
  void _loadSampleRental() {
    const text = '''
RESIDENTIAL LEASE AGREEMENT
This Agreement made on 15th Day of March, 2024 by and between Mr. Rajesh Sharma (Lessor) and Priya Verma (Lessee).

1. PREMISES: Flat 402, Sunshine Heights, Mumbai. Monthly rent of Rs. 35,000 (Rupees Thirty Five Thousand Only).
2. SECURITY DEPOSIT: The Lessee deposits Rs. 2,50,000. In case of any dispute, the security deposit is strictly non-refundable and the Lessor shall forfeit the entire deposit without inquiry.
3. TERMINATION: The Lessor reserves the right to terminate immediately without notice or cause with immediate effect.
4. LATE PAYMENT: Any late payment shall incur a penalty of Rs. 10,000 plus interest @ 24% per annum.
5. MODIFICATION: The Lessor reserves the right to modify these terms at any time without notice.
''';
    _analyzeRawText(text, forcedType: LegalDocumentType.rentalAgreement);
  }

  void _loadSampleEmployment() {
    const text = '''
EMPLOYMENT CONTRACT AND NON-COMPETE AGREEMENT
Between Apex Technologies Pvt Ltd (Employer) and Amit Kumar (Employee).

1. POSITION: Senior Software Engineer at Bengaluru.
2. NON-COMPETE RESTRAINT: The Employee shall not engage in any competing business, work for any competitor, or join any competitor for a period of 2 years post-termination in India.
3. INDEMNITY: Employee shall indemnify and hold harmless against all claims, losses, and damages whatsoever regardless of negligence.
4. PENALTY: Employee shall pay a penalty of Rs. 5,00,000 as liquidated damages if resigning before 24 months.
5. JURISDICTION: This contract shall be governed exclusively by the Courts of Singapore.
''';
    _analyzeRawText(text, forcedType: LegalDocumentType.employmentContract);
  }

  void _loadSampleFairNda() {
    const text = '''
MUTUAL NON-DISCLOSURE AGREEMENT
This Agreement is entered into by Alpha Tech Solutions and Beta Services.

1. CONFIDENTIAL INFORMATION: Both parties agree to protect proprietary technical data with reasonable care.
2. TERM: This agreement shall remain in effect for 2 years from the date of disclosure.
3. RETURN OF MATERIALS: Upon written request, all confidential materials shall be returned or securely destroyed.
4. GOVERNING LAW: Governed by the Indian Contract Act, 1872 with jurisdiction in New Delhi, India.
''';
    _analyzeRawText(text, forcedType: LegalDocumentType.nonDisclosureAgreement);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isAnalyzing) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 24),
                Text(
                  _statusMessage,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Cross-referencing India Code & statutory precedents',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isAnalyzing = false;
                    });
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Cancel'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Analyzer'),
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
                    Icon(Icons.shield_rounded, color: Colors.white, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Document Risk & Scam Analyzer',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Scan contracts, lease deeds, offer letters, or agreements to detect scams, unfair penalties, void restraints (Sec 27), and traps under Indian Law.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Primary Actions
          Text('CAPTURE OR UPLOAD', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionTile(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera Scan',
                  color: const Color(0xFF2563EB),
                  onTap: () => _pickImage(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionTile(
                  icon: Icons.photo_library_rounded,
                  label: 'Upload Document',
                  color: const Color(0xFF9D00FF),
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Presets for Instant Testing
          Text('OR TEST WITH PRESET CONTRACTS', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _PresetTile(
            title: 'Onerous Rental Agreement',
            subtitle: 'Deposit forfeiture, 24% late penalty & 1-day eviction',
            badge: 'High Risk',
            badgeColor: Colors.red,
            onTap: _loadSampleRental,
          ),
          _PresetTile(
            title: 'Harsh Employment Contract',
            subtitle: '2-Year Non-Compete (Sec 27) & Unlimited Indemnity',
            badge: 'High Risk',
            badgeColor: Colors.red,
            onTap: _loadSampleEmployment,
          ),
          _PresetTile(
            title: 'Standard Fair NDA',
            subtitle: 'Reciprocal confidentiality with Indian governing law',
            badge: 'Standard',
            badgeColor: Colors.green,
            onTap: _loadSampleFairNda,
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
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final VoidCallback onTap;

  const _PresetTile({
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
