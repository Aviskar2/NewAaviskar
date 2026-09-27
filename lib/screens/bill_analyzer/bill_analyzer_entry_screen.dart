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
    super.key,
    required this.ocrService,
    required this.historyService,
    this.existingOcrResult,
  });

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
      ).timeout(const Duration(seconds: 15));

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
                ].map((label) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E0C2B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? const Color(0xFF381552) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
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
}

