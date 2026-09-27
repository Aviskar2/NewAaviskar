import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
    super.key,
    required this.ocrService,
    required this.historyService,
    this.initialBarcode,
  });

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


