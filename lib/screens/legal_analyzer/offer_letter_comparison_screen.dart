import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:archive/archive.dart';
import '../../core/legal/constants/sample_offer_letters.dart';
import '../../services/legal/offer_letter_analyzer_service.dart';
import '../../services/ocr_service.dart';
import 'offer_letter_result_screen.dart';

class OfferLetterComparisonScreen extends StatefulWidget {
  final OcrService ocrService;

  const OfferLetterComparisonScreen({
    super.key,
    required this.ocrService,
  });

  @override
  State<OfferLetterComparisonScreen> createState() =>
      _OfferLetterComparisonScreenState();
}

class _OfferLetterComparisonScreenState
    extends State<OfferLetterComparisonScreen> {
  final OfferLetterAnalyzerService _analyzerService =
      OfferLetterAnalyzerService();

  String _previousOfferText = '';
  String _newOfferText = '';
  String _previousOfferSource = '';
  String _newOfferSource = '';

  bool _isComparing = false;
  String _statusMessage = '';

  // Background isolate extractors
  static List<String> _extractPdfPagesSync(List<int> bytes) {
    final pdfDocument = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(pdfDocument);
    final pageTexts = <String>[];
    for (int i = 0; i < pdfDocument.pages.count; i++) {
      final text =
          extractor.extractText(startPageIndex: i, endPageIndex: i).trim();
      if (text.isNotEmpty) {
        pageTexts.add(text);
      }
    }
    pdfDocument.dispose();
    return pageTexts;
  }

  static String _extractDocxTextSync(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final docFile = archive.files.firstWhere(
      (f) => f.name == 'word/document.xml',
      orElse: () => archive.files.first,
    );
    final xmlContent = String.fromCharCodes(docFile.content as List<int>);
    return xmlContent
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // ==========================================
  // DOCUMENT PICKERS FOR SLOT A / B
  // ==========================================

  void _showDocumentSourceSheet(bool isNewOffer) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isNewOffer ? 'Upload New Offer Letter' : 'Upload Previous Company Offer',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose a method to scan or import the offer letter clauses.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFDC2626)),
                ),
                title: const Text('Upload PDF File'),
                subtitle: const Text('Digital PDF with compensation breakdown'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPdfFile(isNewOffer);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF2563EB)),
                ),
                title: const Text('Camera / Photo OCR'),
                subtitle: const Text('Take photos of printed offer letter pages'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhotos(isNewOffer);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9333EA).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.description_rounded, color: Color(0xFF9333EA)),
                ),
                title: const Text('Word Document (.docx) or Text (.txt)'),
                subtitle: const Text('Upload draft or employment agreement'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickDocxOrTxt(isNewOffer);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.edit_note_rounded, color: Color(0xFF059669)),
                ),
                title: const Text('Paste Text Manually'),
                subtitle: const Text('Paste salary table or terms directly'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPasteDialog(isNewOffer);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickPdfFile(bool isNewOffer) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.first.path;
      if (path == null) return;

      setState(() {
        _isComparing = true;
        _statusMessage = 'Extracting text from PDF…';
      });

      final bytes = await File(path).readAsBytes();
      final pageTexts = await Isolate.run(() => _extractPdfPagesSync(bytes));
      final combined = pageTexts.join('\n\n');

      if (!mounted) return;
      setState(() {
        _isComparing = false;
        if (isNewOffer) {
          _newOfferText = combined;
          _newOfferSource = result.files.first.name;
        } else {
          _previousOfferText = combined;
          _previousOfferSource = result.files.first.name;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isComparing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed reading PDF: $e')),
        );
      }
    }
  }

  Future<void> _pickPhotos(bool isNewOffer) async {
    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage(imageQuality: 95);
      if (images.isEmpty) return;

      setState(() {
        _isComparing = true;
        _statusMessage = 'Recognizing offer letter text via OCR…';
      });

      final texts = <String>[];
      for (int i = 0; i < images.length; i++) {
        if (!mounted) return;
        setState(() {
          _statusMessage = 'Reading page ${i + 1} of ${images.length}…';
        });
        final res = await widget.ocrService.recognizeFromPath(images[i].path);
        if (res.fullText.trim().isNotEmpty) {
          texts.add(res.fullText.trim());
        }
      }

      if (!mounted) return;
      setState(() {
        _isComparing = false;
        final combined = texts.join('\n\n');
        if (isNewOffer) {
          _newOfferText = combined;
          _newOfferSource = '${images.length} Scanned Page(s)';
        } else {
          _previousOfferText = combined;
          _previousOfferSource = '${images.length} Scanned Page(s)';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isComparing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR extraction failed: $e')),
        );
      }
    }
  }

  Future<void> _pickDocxOrTxt(bool isNewOffer) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['docx', 'txt'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.first.path;
      if (path == null) return;

      setState(() {
        _isComparing = true;
        _statusMessage = 'Reading document text…';
      });

      String text = '';
      if (path.toLowerCase().endsWith('.docx')) {
        final bytes = await File(path).readAsBytes();
        text = await Isolate.run(() => _extractDocxTextSync(bytes));
      } else {
        text = await File(path).readAsString();
      }

      if (!mounted) return;
      setState(() {
        _isComparing = false;
        if (isNewOffer) {
          _newOfferText = text;
          _newOfferSource = result.files.first.name;
        } else {
          _previousOfferText = text;
          _previousOfferSource = result.files.first.name;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isComparing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed reading document: $e')),
        );
      }
    }
  }

  void _showPasteDialog(bool isNewOffer) {
    final controller = TextEditingController(
      text: isNewOffer ? _newOfferText : _previousOfferText,
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isNewOffer ? 'Paste New Offer Text' : 'Paste Previous Offer Text'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: 10,
            decoration: InputDecoration(
              hintText: isNewOffer
                  ? 'Paste compensation table, bonds, notice period, or full new offer text here...'
                  : 'Paste current/previous company CTC breakdown and terms here...',
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              Navigator.pop(ctx);
              if (text.isNotEmpty) {
                setState(() {
                  if (isNewOffer) {
                    _newOfferText = text;
                    _newOfferSource = 'Pasted Text (${text.split(' ').length} words)';
                  } else {
                    _previousOfferText = text;
                    _previousOfferSource = 'Pasted Text (${text.split(' ').length} words)';
                  }
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save Text'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  void _loadDemoOffers() {
    setState(() {
      _previousOfferText = SampleOfferLetters.previousCompanyOffer;
      _previousOfferSource = 'Demo: TCS / Enterprise (12 LPA)';
      _newOfferText = SampleOfferLetters.newCompanyOffer;
      _newOfferSource = 'Demo: FinNext Tech (18.5 LPA + Bond)';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Loaded sample offer letters! Tap "Compare & Find Which is More Beneficial" below.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==========================================
  // COMPARISON EXECUTION
  // ==========================================

  Future<void> _runComparison() async {
    if (_previousOfferText.trim().isEmpty || _newOfferText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide both the Previous and New offer letters to compare.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isComparing = true;
      _statusMessage = 'Evaluating CTC, Fixed Pay & Benefits…';
    });

    try {
      // Simulate status progression for UX transparency
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted && _isComparing) {
          setState(() {
            _statusMessage = 'Auditing Indian Contract Act Sec 27 & Sec 74 bonds…';
          });
        }
      });

      final result = await _analyzerService.compareOffers(
        previousOfferText: _previousOfferText,
        newOfferText: _newOfferText,
      );

      if (!mounted) return;
      setState(() => _isComparing = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OfferLetterResultScreen(result: result),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isComparing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Comparison failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isComparing) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _statusMessage,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Scrutinizing exit clauses, lock-in penalties & take-home compensation',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: () => setState(() => _isComparing = false),
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

    final hasBoth =
        _previousOfferText.trim().isNotEmpty && _newOfferText.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offer Letter Comparison'),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: _loadDemoOffers,
            icon: const Icon(Icons.bolt_rounded, size: 18, color: Color(0xFFEA580C)),
            label: const Text('Try Demo', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
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
                    Icon(Icons.balance_rounded, color: Colors.white, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Offer Letter Audit & Comparison',
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
                  'Upload your previous company offer letter and your new offer letter. We compare real take-home CTC, hidden bonds, notice periods, non-competes, and identify which is truly more beneficial.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Slot 1: Previous Offer
          _buildOfferSlotCard(
            title: '1. PREVIOUS / CURRENT COMPANY OFFER',
            subtitle: 'Base reference for compensation, leaves & terms',
            text: _previousOfferText,
            source: _previousOfferSource,
            color: const Color(0xFF2563EB),
            icon: Icons.business_rounded,
            isNew: false,
            isDark: isDark,
          ),

          const SizedBox(height: 16),

          // Slot 2: New Offer
          _buildOfferSlotCard(
            title: '2. NEW PROSPECTIVE OFFER LETTER',
            subtitle: 'Offer to evaluate for benefits, bonds & traps',
            text: _newOfferText,
            source: _newOfferSource,
            color: const Color(0xFF059669),
            icon: Icons.local_fire_department_rounded,
            isNew: true,
            isDark: isDark,
          ),

          const SizedBox(height: 24),

          // Compare CTA Button
          ElevatedButton(
            onPressed: hasBoth ? _runComparison : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: hasBoth ? 3 : 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.analytics_rounded, size: 20),
                const SizedBox(width: 8),
                Text(
                  hasBoth
                      ? 'Compare & Find Which is More Beneficial'
                      : 'Upload Both Offers to Compare',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Legal Insights Footer
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF2563EB)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Protected under Indian Contract Act, 1872 (Section 27: Post-employment restraints are void; Section 74: Liquidated damages must represent actual loss).',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferSlotCard({
    required String title,
    required String subtitle,
    required String text,
    required String source,
    required Color color,
    required IconData icon,
    required bool isNew,
    required bool isDark,
  }) {
    final isLoaded = text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLoaded ? color.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.2),
          width: isLoaded ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: color,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              if (isLoaded)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                  tooltip: 'Clear Offer',
                  onPressed: () {
                    setState(() {
                      if (isNew) {
                        _newOfferText = '';
                        _newOfferSource = '';
                      } else {
                        _previousOfferText = '';
                        _previousOfferSource = '';
                      }
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (isLoaded) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          source,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        Text(
                          '${text.split(RegExp(r'\s+')).length} words loaded',
                          style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showDocumentSourceSheet(isNew),
                    child: const Text('Replace', style: TextStyle(fontSize: 11.5)),
                  ),
                ],
              ),
            ),
          ] else ...[
            OutlinedButton.icon(
              onPressed: () => _showDocumentSourceSheet(isNew),
              icon: Icon(Icons.file_upload_outlined, size: 18, color: color),
              label: Text('Upload Offer Letter (PDF / OCR / Text)',
                  style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12.5)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                side: BorderSide(color: color.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
