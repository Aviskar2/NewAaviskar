import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/bill_model.dart';
import '../../models/scan_result_model.dart';
import '../../services/bill_analysis_orchestrator.dart';
import '../../services/ocr_service.dart';
import '../../services/scan_history_service.dart';
import 'bill_analysis_screen.dart';

/// Entry screen for the Bill Analyzer.
/// User can pick an image (camera/gallery) or pass an existing OcrResult.
class BillAnalyzerEntryScreen extends StatefulWidget {
  final OcrService ocrService;
  final ScanHistoryService historyService;
  final OcrResult? existingOcrResult;

  const BillAnalyzerEntryScreen({
    Key? key,
    required this.ocrService,
    required this.historyService,
    this.existingOcrResult,
  }) : super(key: key);

  @override
  State<BillAnalyzerEntryScreen> createState() => _BillAnalyzerEntryScreenState();
}

class _BillAnalyzerEntryScreenState extends State<BillAnalyzerEntryScreen> {
  bool _isProcessing = false;
  String _statusMessage = '';
  String? _errorMessage;
  BillType _selectedType = BillType.unknown;

  final _orchestrator = BillAnalysisOrchestrator();

  @override
  void initState() {
    super.initState();
    if (widget.existingOcrResult != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runAnalysis(widget.existingOcrResult!);
      });
    }
  }

  Future<void> _runAnalysis(OcrResult ocr) async {
    final bool hasImage = ocr.imagePath.isNotEmpty;
    if (ocr.fullText.trim().isEmpty && !hasImage) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'No readable text or image was found. Please upload or capture a photo of the bill.';
        });
      }
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Auditing bill, GST & calculations…';
      _errorMessage = null;
    });

    try {
      final result = await _orchestrator.analyze(
        ocr.fullText,
        imagePath: hasImage ? ocr.imagePath : null,
        forcedBillType: _selectedType == BillType.unknown ? null : _selectedType,
      ).timeout(const Duration(seconds: 12));

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BillAnalysisScreen(
            result: result,
            imagePath: ocr.imagePath.isNotEmpty ? ocr.imagePath : null,
            historyService: widget.historyService,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Analysis failed: $e';
        });
      }
    }
  }

  Future<void> _pickAndAnalyze(ImageSource source) async {
    final picker = ImagePicker();
    XFile? image;
    try {
      image = await picker.pickImage(
        source: source,
        imageQuality: 95,
        preferredCameraDevice: CameraDevice.rear,
      );
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Could not open: $e');
      return;
    }
    if (image == null || !mounted) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Scanning bill (printed or handwritten)…';
      _errorMessage = null;
    });

    try {
      await widget.ocrService.validateFile(image.path);
      final ocr = await widget.ocrService.recognizeFromPath(image.path);
      await widget.historyService.addOcr(ocr);
      if (!mounted) return;
      await _runAnalysis(ocr);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Scan failed: $e';
        });
      }
    }
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
                  child: const Icon(Icons.receipt_long_rounded,
                      size: 40, color: Color(0xFF16A34A)),
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(color: Color(0xFF16A34A)),
                const SizedBox(height: 20),
                Text(_statusMessage,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('Verifying GST, financial calculations & items...',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isProcessing = false;
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
        title: const Text('Bill Analyzer'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF16A34A).withValues(alpha: isDark ? 0.25 : 0.12),
                      const Color(0xFF2563EB).withValues(alpha: isDark ? 0.15 : 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Text('🇮🇳', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 12),
                    Text(
                      'Indian Bill & Invoice Analyzer',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF16A34A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scan printed invoices or handwritten kirana/restaurant slips. '
                      'Get accurate GST breakdown, verified financial summary, and fraud check.',
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Feature chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  '✍️ Handwritten Slips',
                  '🧾 Printed Invoices',
                  '🧮 GST Breakdown',
                  '💰 Financial Audit',
                  '🏢 GSTIN Check',
                  '🚨 Charge Detection',
                ].map((label) => Chip(
                      label: Text(label, style: const TextStyle(fontSize: 12)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    )).toList(),
              ),

              const SizedBox(height: 20),

              // Bill type selector
              Text('Bill Type (optional)',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF22062C) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF32113D)
                        : const Color(0xFFE5EEFF),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<BillType>(
                    value: _selectedType,
                    isExpanded: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    borderRadius: BorderRadius.circular(14),
                    items: BillType.values.map((t) {
                      return DropdownMenuItem(
                        value: t,
                        child: Text(
                            '${t.emoji}  ${t.displayName}'),
                      );
                    }).toList(),
                    onChanged: (v) =>
                        setState(() => _selectedType = v ?? BillType.unknown),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Error
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMessage!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Action buttons
              FilledButton.icon(
                onPressed: () => _pickAndAnalyze(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Scan Bill with Camera'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter'),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _pickAndAnalyze(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Upload Bill from Gallery'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF16A34A),
                  side: const BorderSide(color: Color(0xFF16A34A), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter'),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _showPasteBillDialog,
                icon: const Icon(Icons.paste_rounded),
                label: const Text('Paste Bill Text / Receipt Data'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter'),
                ),
              ),
              const SizedBox(height: 24),

              // 1-Tap Quick Sample Bills
              Text('✨ Try Instant Sample Bills',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              _buildSampleBillCard(
                context,
                title: '🍽️ Restaurant Bill with Illegal Service Charge',
                subtitle: 'Detects 10% mandatory service charge + GST math error',
                color: const Color(0xFFDC2626),
                onTap: _loadSampleRestaurantBill,
              ),
              const SizedBox(height: 8),
              _buildSampleBillCard(
                context,
                title: '🛒 Kirana Store Receipt (Handwritten Slip)',
                subtitle: 'Detects calculation discrepancy and item line mismatch',
                color: const Color(0xFFD97706),
                onTap: _loadSampleKiranaSlip,
              ),
              const SizedBox(height: 8),
              _buildSampleBillCard(
                context,
                title: '📱 Electronics Store GST Invoice (Valid)',
                subtitle: 'Clean invoice with accurate 18% GST and valid GSTIN',
                color: const Color(0xFF16A34A),
                onTap: _loadSampleElectronicsBill,
              ),
              const SizedBox(height: 24),

              // Disclaimer
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1B0424)
                      : const Color(0xFFF8F9FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isDark ? const Color(0xFF32113D) : const Color(0xFFE5EEFF),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(height: 8),
                    Text(
                      'Results are based on deterministic calculations and cached government rules. '
                      'Potential issues are flagged for your verification — not legal conclusions. '
                      'Always verify suspicious findings with the establishment.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPasteBillDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paste Bill Text / Receipt Data'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'Paste OCR text, item lines, GST amounts or invoice summary here…',
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
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                _runAnalysis(OcrResult(fullText: text, blocks: const [], imagePath: '', timestamp: DateTime.now()));
              }
            },
            child: const Text('Analyze Bill'),
          ),
        ],
      ),
    );
  }

  void _loadSampleRestaurantBill() {
    const text = '''
SPICE VILLA RESTAURANT & BAR
GSTIN: 27AABCS1429B1Z1
Invoice No: SV-2026/894
Date: 20/02/2026

Items:
1. Butter Chicken (Full)      1 x 450.00 = 450.00
2. Garlic Naan               3 x  60.00 = 180.00
3. Dal Makhani               1 x 280.00 = 280.00
4. Mineral Water             2 x  40.00 =  80.00

Subtotal:                                990.00
Service Charge (10% Mandatory):           99.00
Taxable Amount:                         1089.00
CGST @ 2.5%:                              27.23
SGST @ 2.5%:                              27.23
Total GST:                                54.46

Grand Total:                            1143.46
Rounded Total:                          1144.00

* Mandatory Service Charge added as per house policy. Tips optional.
Thank You! Visit Again!
''';
    _runAnalysis(OcrResult(fullText: text, blocks: const [], imagePath: '', timestamp: DateTime.now()));
  }

  void _loadSampleKiranaSlip() {
    const text = '''
SHREE GANESH KIRANA & GENERAL STORE
Cash / Credit Memo
Date: 18/02/2026

1. Aashirvaad Atta 10kg      1 x 480.00 = 480.00
2. Fortune Sunlite Oil 1L     2 x 165.00 = 330.00
3. Tata Salt 1kg             2 x  28.00 =  56.00
4. Sugar (Madhur) 5kg        1 x 240.00 = 240.00
5. Toor Dal Premium 2kg      1 x 175.00 = 350.00

Total Items: 5
Estimated Total:                         1520.00
Amount Received:                         1550.00

* Goods once sold will not be taken back.
''';
    _runAnalysis(OcrResult(fullText: text, blocks: const [], imagePath: '', timestamp: DateTime.now()));
  }

  void _loadSampleElectronicsBill() {
    const text = '''
TECHWORLD DIGITAL RETAIL PVT LTD
GSTIN: 29AABCU9603R1ZM
Tax Invoice No: TW/2026/04812
Date: 14/02/2026

1. Wireless ANC Headphones (HSN: 8518)
   Qty: 1 | Rate: 3389.83 | Taxable: 3389.83
   CGST @ 9%: 305.08
   SGST @ 9%: 305.08
   Line Total: 4000.00

Subtotal:                               3389.83
Total CGST:                              305.08
Total SGST:                              305.08
Total GST (18%):                         610.17
Grand Total:                            4000.00

Payment: UPI / Paid in Full
Thank You For Shopping With TechWorld!
''';
    _runAnalysis(OcrResult(fullText: text, blocks: const [], imagePath: '', timestamp: DateTime.now()));
  }

  Widget _buildSampleBillCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? color.withValues(alpha: 0.12) : color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.play_arrow_rounded, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
          ],
        ),
      ),
    );
  }
}
