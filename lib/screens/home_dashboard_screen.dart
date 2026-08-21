import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ocr_service.dart';
import '../services/scan_history_service.dart';
import '../models/analysis_result.dart';
import '../widgets/bill_analysis/bill_analysis_inline_card.dart';
import '../widgets/translation_mode_sheet.dart';
import 'scanner/qr_scanner_screen.dart';
import 'scanner/scanner_hub_screen.dart';
import 'bill_analyzer/bill_analyzer_entry_screen.dart';
import 'bill_analyzer/bill_analysis_screen.dart';
import 'legal_analyzer/legal_analyzer_entry_screen.dart';
import 'legal_analyzer/legal_analysis_screen.dart';
import 'medicine_safety/medicine_entry_screen.dart';
import 'medicine_safety/medicine_analysis_screen.dart';
import 'product_safety/product_safety_entry_screen.dart';
import 'product_safety/product_safety_analysis_screen.dart';
import '../services/legal/legal_orchestrator.dart';
import '../services/medicine_safety/medicine_safety_orchestrator.dart';
import '../services/product_safety/product_safety_orchestrator.dart';
import '../services/bill_analysis_orchestrator.dart';
import '../models/scan_result_model.dart';
import '../core/legal/models/legal_document_type.dart';

class HomeDashboardScreen extends StatefulWidget {
  final List<Map<String, dynamic>> activeMessages;
  final bool isTyping;
  final String? typingStatus;
  final ValueChanged<String> onSendMessage;
  final void Function({
    required String feature,
    required Map<String, dynamic> document,
    String? userPrompt,
  }) onExecuteFeature;
  final ValueChanged<int> onNavigateToTab;
  final OcrService? ocrService;
  final ScanHistoryService? historyService;

  const HomeDashboardScreen({
    Key? key,
    required this.activeMessages,
    required this.isTyping,
    this.typingStatus,
    required this.onSendMessage,
    required this.onExecuteFeature,
    required this.onNavigateToTab,
    this.ocrService,
    this.historyService,
  }) : super(key: key);

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Attached document waiting in input bar
  Map<String, dynamic>? _pendingAttachment;

  @override
  void initState() {
    super.initState();
    _scrollToBottom();
  }

  @override
  void didUpdateWidget(HomeDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeMessages.length != oldWidget.activeMessages.length ||
        widget.isTyping != oldWidget.isTyping) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _onFeatureButtonTapped(String feature) {
    HapticFeedback.lightImpact();

    // If an attachment exists, execute with that attachment
    if (_pendingAttachment != null) {
      final prompt = _messageController.text.trim();
      _executeWithPendingAttachment(feature, prompt: prompt.isNotEmpty ? prompt : null);
      _messageController.clear();
      return;
    }

    // Direct routing to the full screen
    widget.onExecuteFeature(
      feature: feature,
      document: {},
      userPrompt: null,
    );
  }

  Color _getFeatureColor(String? feature) {
    switch (feature) {
      case 'Translation':
      case 'Translate':
        return const Color(0xFF2563EB); // Electric Blue
      case 'Scanner':
      case 'QR':
        return const Color(0xFF9D00FF); // Vibrant Purple
      case 'Documents':
        return const Color(0xFFFF4081); // Coral / Pink
      case 'Bill Analyzer':
      case 'Bill':
      case 'GST':
        return const Color(0xFF16A34A); // Emerald Green
      case 'Document Analyzer':
      case 'Legal Analyzer':
      case 'Legal Risk':
      case 'Legal':
        return const Color(0xFFDC2626); // Crimson Red
      case 'Product Safety':
      case 'Food Safety':
      case 'Food':
      case 'FSSAI':
        return const Color(0xFF0F766E); // Teal / Food Green
      case 'Medicine':
      case 'Medicine Safety':
      case 'Pharma':
      case 'Jan Aushadhi':
        return const Color(0xFFBE185D); // Rose / Pharma Red
      default:
        return const Color(0xFF2563EB);
    }
  }

  IconData _getFeatureIcon(String? feature) {
    switch (feature) {
      case 'Translation':
      case 'Translate':
        return Icons.translate_rounded;
      case 'Scanner':
      case 'QR':
        return Icons.qr_code_scanner_rounded;
      case 'Documents':
        return Icons.description_rounded;
      case 'Bill Analyzer':
      case 'Bill':
      case 'GST':
        return Icons.receipt_long_rounded;
      case 'Document Analyzer':
      case 'Legal Analyzer':
      case 'Legal Risk':
      case 'Legal':
        return Icons.gavel_rounded;
      case 'Product Safety':
      case 'Food Safety':
      case 'Food':
      case 'FSSAI':
        return Icons.health_and_safety_rounded;
      case 'Medicine':
      case 'Medicine Safety':
      case 'Pharma':
      case 'Jan Aushadhi':
        return Icons.medication_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  void _showMinimalToast(String message, IconData icon, Color color) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        elevation: 3,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        margin: const EdgeInsets.only(bottom: 16, left: 24, right: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(milliseconds: 2400),
      ),
    );
  }

  void _sendMessage() {
    final text = _messageController.text.trim();

    if (_pendingAttachment != null) {
      _executeWithPendingAttachment('Legal Analyzer', prompt: text.isNotEmpty ? text : null);
      _messageController.clear();
      return;
    }

    if (text.isEmpty) return;
    _messageController.clear();
    widget.onSendMessage(text);
  }

  void _executeWithPendingAttachment(String feature, {String? prompt}) {
    if (_pendingAttachment == null) return;
    final doc = _pendingAttachment!;
    setState(() {
      _pendingAttachment = null;
    });
    widget.onExecuteFeature(
      feature: feature,
      document: doc,
      userPrompt: prompt,
    );
  }

  // Option 1: Gallery or files
  Future<void> _pickFromGalleryOrFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final name = file.name;
        final sizeInBytes = file.size;
        String size;
        if (sizeInBytes < 1024) {
          size = '$sizeInBytes B';
        } else if (sizeInBytes < 1024 * 1024) {
          size = '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
        } else {
          size = '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
        }

        final ext = (file.extension ?? '').toLowerCase();
        String docType;
        if (['pdf'].contains(ext)) {
          docType = 'PDF Document';
        } else if (['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
          docType = 'Photo / Image';
        } else if (['doc', 'docx'].contains(ext)) {
          docType = 'Word Document';
        } else {
          docType = 'Document';
        }

        final docData = {
          'name': name,
          'size': size,
          'type': docType,
          'path': file.path,
        };

        setState(() {
          _pendingAttachment = docData;
        });

        if (mounted) {
          _showMinimalToast(
            'Attached "$name". Select an analyzer above or send to process.',
            Icons.check_circle_outline,
            Theme.of(context).colorScheme.primary,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showMinimalToast('Failed to pick file: $e', Icons.error_outline, Colors.redAccent);
      }
    }
  }

  // Option 2: Camera capture
  Future<void> _captureFromCamera() async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo != null) {
        final name = photo.name.isNotEmpty
            ? photo.name
            : 'Camera_Photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final bytes = await photo.readAsBytes();
        final sizeInBytes = bytes.length;
        String size;
        if (sizeInBytes < 1024) {
          size = '$sizeInBytes B';
        } else if (sizeInBytes < 1024 * 1024) {
          size = '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
        } else {
          size = '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
        }

        final docData = {
          'name': name,
          'size': size,
          'type': 'Camera Photo',
          'path': photo.path,
        };

        setState(() {
          _pendingAttachment = docData;
        });

        if (mounted) {
          _showMinimalToast(
            'Photo captured! Select an analyzer above or send.',
            Icons.check_circle_outline,
            Theme.of(context).colorScheme.primary,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showMinimalToast('Camera error: $e', Icons.error_outline, Colors.redAccent);
      }
    }
  }

  void _openQrScanner() {
    final historyService = widget.historyService;
    if (historyService == null) {
      _showMinimalToast('Scanner not available', Icons.error_outline, Colors.redAccent);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QrScannerScreen(historyService: historyService),
      ),
    );
  }

  // Upload options bottom sheet
  void _showUploadBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Add Document, Bill or Photo',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                const SizedBox(height: 14),

                // Option 1: Gallery / Files
                _buildSheetOption(
                  context,
                  title: 'Upload Photo or Document from Gallery / Files',
                  subtitle: 'PDF contracts, receipts, medicine strips or labels',
                  icon: Icons.photo_library_outlined,
                  iconColor: const Color(0xFF2563EB),
                  onTap: () {
                    Navigator.pop(context);
                    _pickFromGalleryOrFiles();
                  },
                ),

                const SizedBox(height: 10),

                // Option 2: Camera
                _buildSheetOption(
                  context,
                  title: 'Capture with Camera',
                  subtitle: 'Take a clear photo of contract, bill, or product packaging',
                  icon: Icons.camera_alt_outlined,
                  iconColor: const Color(0xFF16A34A),
                  onTap: () {
                    Navigator.pop(context);
                    _captureFromCamera();
                  },
                ),

                const SizedBox(height: 10),

                // Option 3: QR / Barcode
                _buildSheetOption(
                  context,
                  title: 'Scan QR Code or Barcode',
                  subtitle: 'Instant barcode verification & product lookups',
                  icon: Icons.qr_code_scanner_rounded,
                  iconColor: const Color(0xFF9D00FF),
                  onTap: () {
                    Navigator.pop(context);
                    _openQrScanner();
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF22062C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF32113D) : const Color(0xFFE5EEFF),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }

  // ─── Help & Feature Guide Modal ──────────────────────────────────────────
  void _showHelpGuideSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '🛡️ How NyayaSathi AI Protects You',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your citizen safety assistant powered by Indian law & determinism',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 18),

                  _buildHelpPillarItem(
                    title: '1. Legal & Contract Risk Analyzer',
                    subtitle: 'Scans rental leases, employment bonds & builder agreements. Detects illegal forfeiture, non-compete void clauses (Sec 27), and RERA violations.',
                    icon: Icons.gavel_rounded,
                    color: const Color(0xFFDC2626),
                  ),
                  const SizedBox(height: 12),
                  _buildHelpPillarItem(
                    title: '2. Bill & GST Fraud Detector',
                    subtitle: 'Verifies 15-digit GSTIN, audits CGST/SGST/IGST tax math, and flags illegal mandatory restaurant service charges (CCPA 2022).',
                    icon: Icons.receipt_long_rounded,
                    color: const Color(0xFF16A34A),
                  ),
                  const SizedBox(height: 12),
                  _buildHelpPillarItem(
                    title: '3. Medicine & Generic Savings (PMBJP)',
                    subtitle: 'Finds therapeutic generic alternatives at Jan Aushadhi Kendras (save 50-80%), checks Drug Schedules (H, H1, X) & expiry dates.',
                    icon: Icons.medication_rounded,
                    color: const Color(0xFFBE185D),
                  ),
                  const SizedBox(height: 12),
                  _buildHelpPillarItem(
                    title: '4. Food & Product Safety (FSSAI)',
                    subtitle: 'Audits 14-digit FSSAI licenses, high sugar/fat traffic light alerts, banned additives & Made-in-India 890 GS1 barcodes.',
                    icon: Icons.health_and_safety_rounded,
                    color: const Color(0xFF0F766E),
                  ),
                  const SizedBox(height: 12),
                  _buildHelpPillarItem(
                    title: '5. AI Live Translator & OCR Vision',
                    subtitle: 'Translates printed/handwritten documents and camera overlays across 12+ Indian languages (Hindi, Tamil, Telugu, Marathi, etc.).',
                    icon: Icons.translate_rounded,
                    color: const Color(0xFF2563EB),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF2563EB), size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('National Consumer Helpline: 1915', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              SizedBox(height: 2),
                              Text('Toll-free consumer grievance redressal by Govt of India.', style: TextStyle(fontSize: 11.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHelpPillarItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? color.withValues(alpha: 0.1) : color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 4),
                Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(height: 1.4, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── App Navigation Drawer ───────────────────────────────────────────────
  Widget _buildAppDrawer(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    const Color(0xFF1E40AF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Icon(Icons.security_rounded, color: theme.colorScheme.primary, size: 28),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'NyayaSathi AI',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Citizen Safety Hub 🇮🇳',
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
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                children: [
                  _buildDrawerTile(
                    title: 'Legal & Contract Analyzer',
                    icon: Icons.gavel_rounded,
                    color: const Color(0xFFDC2626),
                    onTap: () {
                      Navigator.pop(context);
                      _onFeatureButtonTapped('Legal Analyzer');
                    },
                  ),
                  _buildDrawerTile(
                    title: 'Bill & GST Fraud Detector',
                    icon: Icons.receipt_long_rounded,
                    color: const Color(0xFF16A34A),
                    onTap: () {
                      Navigator.pop(context);
                      _onFeatureButtonTapped('Bill Analyzer');
                    },
                  ),
                  _buildDrawerTile(
                    title: 'Medicine & Pharma Safety',
                    icon: Icons.medication_rounded,
                    color: const Color(0xFFBE185D),
                    onTap: () {
                      Navigator.pop(context);
                      _onFeatureButtonTapped('Medicine Safety');
                    },
                  ),
                  _buildDrawerTile(
                    title: 'Food & Product Safety (FSSAI)',
                    icon: Icons.health_and_safety_rounded,
                    color: const Color(0xFF0F766E),
                    onTap: () {
                      Navigator.pop(context);
                      _onFeatureButtonTapped('Product Safety');
                    },
                  ),
                  _buildDrawerTile(
                    title: 'Live Camera Translator',
                    icon: Icons.translate_rounded,
                    color: const Color(0xFF2563EB),
                    onTap: () {
                      Navigator.pop(context);
                      _onFeatureButtonTapped('Translation');
                    },
                  ),
                  _buildDrawerTile(
                    title: 'QR & Barcode Scanner',
                    icon: Icons.qr_code_scanner_rounded,
                    color: const Color(0xFF9D00FF),
                    onTap: () {
                      Navigator.pop(context);
                      _onFeatureButtonTapped('Scanner');
                    },
                  ),
                  const Divider(height: 24),
                  _buildDrawerTile(
                    title: 'Scan History',
                    icon: Icons.history_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                    onTap: () {
                      Navigator.pop(context);
                      widget.onNavigateToTab(1);
                    },
                  ),
                  _buildDrawerTile(
                    title: 'Safety Updates & Alerts',
                    icon: Icons.notifications_none_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                    onTap: () {
                      Navigator.pop(context);
                      widget.onNavigateToTab(2);
                    },
                  ),
                  _buildDrawerTile(
                    title: 'Settings & Theme',
                    icon: Icons.settings_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                    onTap: () {
                      Navigator.pop(context);
                      widget.onNavigateToTab(3);
                    },
                  ),
                  const Divider(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E0C2B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Helpline Directory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          SizedBox(height: 4),
                          Text('• Consumer Helpline: 1915\n• Food Safety (FSSAI): 1800-112-100\n• Cyber Crime: 1930', style: TextStyle(fontSize: 11, height: 1.4)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerTile({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
      onTap: onTap,
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  // ─── Instant Sample Preset Testers ───────────────────────────────────────
  void _runSampleRentalAgreement() {
    final orchestrator = LegalOrchestrator();
    const text = '''
RESIDENTIAL LEASE AGREEMENT
This Agreement made on 15th Day of March, 2024 between Mr. Rajesh Sharma (Lessor) and Priya Verma (Lessee).

1. PREMISES: Flat 402, Sunshine Heights, Mumbai. Monthly rent of Rs. 35,000.
2. SECURITY DEPOSIT: Lessee deposits Rs. 2,50,000. In case of any dispute, the security deposit is strictly non-refundable and the Lessor shall forfeit the entire deposit without inquiry.
3. TERMINATION: The Lessor reserves the right to terminate immediately without notice or cause.
4. LATE PAYMENT: Penalty of Rs. 10,000 plus interest @ 24% per annum.
5. RESTRICTIONS: Lessee agrees not to practice any profession from home.
''';
    final doc = orchestrator.createDocumentFromText(text);
    orchestrator.analyze(doc, forcedType: LegalDocumentType.rentalAgreement).then((result) {
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => LegalAnalysisScreen(result: result)));
      }
    });
  }

  void _runSampleRestaurantBill() {
    final orchestrator = BillAnalysisOrchestrator();
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
''';
    orchestrator.analyze(text).then((result) {
      if (mounted) {
        final histService = widget.historyService ?? ScanHistoryService();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BillAnalysisScreen(
              result: result,
              historyService: histService,
            ),
          ),
        );
      }
    });
  }

  void _runSampleDolo650() {
    final orchestrator = MedicineSafetyOrchestrator();
    const text = '''
DOLO 650 TABLETS
Each uncoated tablet contains:
Paracetamol IP 650 mg
Mfg. Lic. No.: G/25/1458
B.No.: DL9042
MFD.: 01/2026
EXP.: 12/2028
MRP Rs. 34.00 (Incl. of all taxes)
Manufactured in India by: Micro Labs Limited, Gujarat.
''';
    orchestrator.analyze(text).then((report) {
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => MedicineAnalysisScreen(report: report)));
      }
    });
  }

  void _runSampleHighSugarDrink() {
    final orchestrator = ProductSafetyOrchestrator();
    const text = '''
REAL MANGO NECTAR BEVERAGE
Mfg Dt: 10/01/2026
EXP: 10/10/2026
Barcode: 8901491102034
FSSAI Lic No: 10012011000168
NUTRITIONAL INFORMATION (Per 100ml):
Energy: 65 kcal
Total Sugars: 15.0g
Added Sugars: 13.5g
Sodium: 15mg
Ingredients: Water, Mango Pulp (20%), Sugar, Acidity Regulator (INS 330).
''';
    orchestrator.analyze(text, rawBarcode: '8901491102034').then((report) {
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProductSafetyAnalysisScreen(report: report)));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      drawer: _buildAppDrawer(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Icon(Icons.menu_rounded, color: theme.colorScheme.primary),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
            tooltip: 'Navigation Menu',
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.security_rounded, color: theme.colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 8),
            Text(
              'NyayaSathi AI',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
                fontSize: 19,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline_rounded, color: theme.colorScheme.primary),
            onPressed: () => _showHelpGuideSheet(context),
            tooltip: 'Feature Guide & Help',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Section: 5 Core Safety Pillars
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Universal Safety Tools',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: 0.2,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.check_circle, size: 10, color: Color(0xFF16A34A)),
                            SizedBox(width: 4),
                            Text(
                              '5 Offline Analyzers Ready',
                              style: TextStyle(
                                color: Color(0xFF16A34A),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 5 Main Pillar Cards (Horizontal Scroll)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildHeroFeatureCard(
                          title: 'Legal Risk',
                          subtitle: 'Contracts & Scams',
                          icon: Icons.gavel_rounded,
                          color: const Color(0xFFDC2626),
                          featureKey: 'Legal Analyzer',
                        ),
                        const SizedBox(width: 8),
                        _buildHeroFeatureCard(
                          title: 'Bill & GST',
                          subtitle: 'Audit Tax & Charges',
                          icon: Icons.receipt_long_rounded,
                          color: const Color(0xFF16A34A),
                          featureKey: 'Bill Analyzer',
                        ),
                        const SizedBox(width: 8),
                        _buildHeroFeatureCard(
                          title: 'Medicine',
                          subtitle: 'Jan Aushadhi Gen.',
                          icon: Icons.medication_rounded,
                          color: const Color(0xFFBE185D),
                          featureKey: 'Medicine Safety',
                        ),
                        const SizedBox(width: 8),
                        _buildHeroFeatureCard(
                          title: 'Food Safety',
                          subtitle: 'FSSAI & Expiry',
                          icon: Icons.health_and_safety_rounded,
                          color: const Color(0xFF0F766E),
                          featureKey: 'Product Safety',
                        ),
                        const SizedBox(width: 8),
                        _buildHeroFeatureCard(
                          title: 'Live Translate',
                          subtitle: 'Camera OCR & 12+',
                          icon: Icons.translate_rounded,
                          color: const Color(0xFF2563EB),
                          featureKey: 'Translation',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),
            const Divider(height: 1),

            // Middle Section: Chat Conversations Stream
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                itemCount: widget.activeMessages.length,
                itemBuilder: (context, index) {
                  final message = widget.activeMessages[index];
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    child: _buildMessageRouter(message),
                  );
                },
              ),
            ),

            // Typing Indicator with smooth fade
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: widget.isTyping ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              firstChild: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
                child: Row(
                  children: [
                    Text(
                      widget.typingStatus ?? 'NyayaSathi is analyzing',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              secondChild: const SizedBox.shrink(),
            ),

            // 1-Tap Quick Sample Chips row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
              child: Row(
                children: [
                  _buildQuickSamplePill('📄 Rental Lease Sample', _runSampleRentalAgreement, const Color(0xFFDC2626)),
                  const SizedBox(width: 6),
                  _buildQuickSamplePill('🧾 Restaurant Bill Sample', _runSampleRestaurantBill, const Color(0xFF16A34A)),
                  const SizedBox(width: 6),
                  _buildQuickSamplePill('💊 Dolo 650 Generic Sample', _runSampleDolo650, const Color(0xFFBE185D)),
                  const SizedBox(width: 6),
                  _buildQuickSamplePill('🥤 Real Mango Sugar Sample', _runSampleHighSugarDrink, const Color(0xFF0F766E)),
                  const SizedBox(width: 6),
                  _buildPromptChip('Is restaurant service charge mandatory?'),
                  const SizedBox(width: 6),
                  _buildPromptChip('Can landlord forfeit my deposit?'),
                  const SizedBox(width: 6),
                  _buildPromptChip('How to file complaint on 1915?'),
                ],
              ),
            ),

            // Pending Attachment Card (if user has selected a file)
            if (_pendingAttachment != null)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2E103A) : const Color(0xFFEEF4FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _pendingAttachment!['type']?.toString().contains('Photo') == true ||
                                _pendingAttachment!['type']?.toString().contains('Image') == true
                            ? Icons.image_outlined
                            : Icons.description_outlined,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _pendingAttachment!['name'] ?? 'Uploaded Document',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_pendingAttachment!['size']} • Tap a safety tool above or press send',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        setState(() {
                          _pendingAttachment = null;
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

            // Bottom Input Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF22062C) : Colors.white,
                  borderRadius: BorderRadius.circular(28.0),
                  border: Border.all(
                    color: _pendingAttachment != null
                        ? theme.colorScheme.primary.withValues(alpha: 0.5)
                        : (isDark ? const Color(0xFF32113D) : const Color(0xFFE2E8F0)),
                    width: _pendingAttachment != null ? 1.5 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                  child: Row(
                    children: [
                      // Upload Attachment Button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _showUploadBottomSheet,
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _pendingAttachment != null
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _pendingAttachment != null ? Icons.attach_file : Icons.add_rounded,
                              color: _pendingAttachment != null ? Colors.white : theme.colorScheme.primary,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: InputDecoration(
                            hintText: _pendingAttachment != null
                                ? 'Add notes or tap an analyzer above…'
                                : 'Ask legal/safety questions or tap + to scan…',
                            hintStyle: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
                              fontSize: 13.0,
                            ),
                            border: InputBorder.none,
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13.5),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _sendMessage,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 17,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Hero Feature Card ───────────────────────────────────────────────────
  Widget _buildHeroFeatureCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String featureKey,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () => _onFeatureButtonTapped(featureKey),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 124,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? color.withValues(alpha: 0.12) : color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                color: isDark ? Colors.white : color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10.5,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Quick Sample Pill ───────────────────────────────────────────────────
  Widget _buildQuickSamplePill(String label, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_filled_rounded, color: color, size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptChip(String prompt) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ActionChip(
      label: Text(
        prompt,
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
          fontSize: 11.5,
        ),
      ),
      onPressed: () {
        widget.onSendMessage(prompt);
      },
      backgroundColor: isDark ? const Color(0xFF2A0B35) : const Color(0xFFE5EEFF),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }

  // ─── Message Routers ─────────────────────────────────────────────────────
  Widget _buildMessageRouter(Map<String, dynamic> message) {
    final type = message['type'] ?? 'text';
    final isUser = message['isUser'] == true;

    if (isUser) {
      if (type == 'upload') {
        return _buildUserUploadBubble(message);
      }
      return _buildUserTextBubble(message['text'] ?? '');
    } else {
      switch (type) {
        case 'translation_result':
          return _buildTranslationResultCard(message);
        case 'scanner_result':
          return _buildScannerResultCard(message);
        case 'document_result':
          return _buildDocumentResultCard(message);
        case 'bill_analysis_result':
          return _buildBillAnalysisResultCard(message);
        case 'text':
        default:
          return _buildAiTextBubble(message['text'] ?? '');
      }
    }
  }

  Widget _buildUserTextBubble(String text) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10.0, left: 48.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 11.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16.0),
            topRight: Radius.circular(16.0),
            bottomLeft: Radius.circular(16.0),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14.0,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildUserUploadBubble(Map<String, dynamic> message) {
    final doc = message['document'] as Map<String, dynamic>? ?? {};
    final feature = message['feature'] as String? ?? 'Analysis';
    final accentColor = _getFeatureColor(feature);

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10.0, left: 40.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: accentColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16.0),
            topRight: Radius.circular(16.0),
            bottomLeft: Radius.circular(16.0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.attach_file, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc['name'] ?? 'Document',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${doc['size'] ?? ''} • $feature',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (message['text'] != null &&
                message['text'] != 'Apply $feature to ${doc['name']}') ...[
              const SizedBox(height: 6),
              Text(
                message['text'],
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAiTextBubble(String text) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0, right: 36.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF22062C) : const Color(0xFFF1F5F9),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16.0),
            topRight: Radius.circular(16.0),
            bottomRight: Radius.circular(16.0),
          ),
          border: Border.all(
            color: isDark ? const Color(0xFF32113D) : const Color(0xFFE2E8F0),
          ),
        ),
        child: SelectableText(
          text,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w400,
            color: theme.colorScheme.onSurface,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildTranslationResultCard(Map<String, dynamic> msg) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const accent = Color(0xFF2563EB);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0, right: 20.0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E0C2B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.translate, color: accent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Translation: ${msg['documentName']}',
                      style: const TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(msg['translatedText'] ?? '', style: const TextStyle(fontSize: 13, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerResultCard(Map<String, dynamic> msg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = Color(0xFF9D00FF);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0, right: 20.0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E0C2B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_scanner, color: accent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Scan Result: ${msg['documentName']}',
                      style: const TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(msg['extractedText'] ?? msg['summary'] ?? '', style: const TextStyle(fontSize: 13, height: 1.4)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentResultCard(Map<String, dynamic> msg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = Color(0xFFFF4081);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0, right: 20.0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E0C2B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_rounded, color: accent, size: 18),
                  const SizedBox(width: 8),
                  Text(msg['documentName'] ?? 'Document', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                ],
              ),
              const SizedBox(height: 6),
              Text(msg['summary'] ?? 'Indexed & verified.', style: const TextStyle(fontSize: 12.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBillAnalysisResultCard(Map<String, dynamic> msg) {
    final result = msg['billResult'] as BillAnalysisResult?;
    if (result == null) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14.0, right: 16.0),
        child: BillAnalysisInlineCard(
          result: result,
          onViewFullReport: () {
            final histService = widget.historyService ?? ScanHistoryService();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BillAnalysisScreen(
                  result: result,
                  imagePath: msg['imagePath'] as String?,
                  historyService: histService,
                ),
              ),
            );
          },
          onFollowUp: (question) {
            widget.onSendMessage(question);
          },
        ),
      ),
    );
  }
}
