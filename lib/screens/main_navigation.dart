import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../theme/app_colors.dart';
import 'home_dashboard_screen.dart';
import 'history_screen.dart';
import 'updates_screen.dart';
import 'settings_screen.dart';
import 'scanner/ocr_screen.dart';
import 'scanner/scanner_hub_screen.dart';
import 'bill_analyzer/bill_analyzer_entry_screen.dart';
import 'legal_analyzer/legal_analyzer_entry_screen.dart';
import 'medicine_safety/medicine_entry_screen.dart';
import 'product_safety/product_safety_entry_screen.dart';
import '../services/ocr_service.dart';
import '../services/scan_history_service.dart';
import '../services/bill_analysis_orchestrator.dart';
import '../models/analysis_result.dart';

import '../widgets/translation_mode_sheet.dart';

class MainNavigation extends StatefulWidget {
  final bool isLightMode;
  final ValueChanged<bool> onThemeChanged;

  const MainNavigation({
    Key? key,
    required this.isLightMode,
    required this.onThemeChanged,
  }) : super(key: key);

  @override
  State<MainNavigation> createState() => MainNavigationState();
}

class MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  // Real service instances (shared across all screens)
  final OcrService _ocrService = OcrService();
  final ScanHistoryService _scanHistoryService = ScanHistoryService();

  // Lifted Active Chat State
  List<Map<String, dynamic>> activeMessages = [];
  bool isTyping = false;
  String? typingStatus;
  
  // Shared Document Repository for persistent tracking
  static final List<Map<String, dynamic>> customDocuments = [];

  // Dynamic history state
  List<Map<String, dynamic>> historyItems = [
    {
      'title': 'Quarterly Earnings Analysis',
      'time': '2:45 PM',
      'description': 'Summarized the Q3 earnings report, highlighting key growth metrics in the...',
      'tags': ['Finance', 'Summary'],
      'category': 'Finance',
      'color': const Color(0xFF2563EB),
      'dateGroup': 'TODAY',
      'chatLog': [
        {'isUser': true, 'text': 'Can you analyze the Q3 earnings report?'},
        {'isUser': false, 'text': 'I have analyzed the Q3 earnings report. Key highlights include:\n• Revenue increased by 15% year-over-year.\n• Operating margin expanded to 24%.\n• Main growth drivers were international expansion.'},
      ]
    },
    {
      'title': 'Meeting Notes - Design Sync',
      'time': '11:20 AM',
      'description': 'Digitized whiteboard notes from the UI design sync. Extracted action items fo...',
      'tags': ['OCR', 'Notes'],
      'category': 'OCR',
      'color': const Color(0xFF9D00FF),
      'dateGroup': 'TODAY',
      'chatLog': [
        {'isUser': true, 'text': 'Process these handwritten whiteboard notes for me.'},
        {'isUser': false, 'text': 'Notes processed successfully. Action items:\n1. Design new document upload flow.\n2. Review brand design system transitions.'},
      ]
    },
    {
      'title': 'Language Translation (JP to EN)',
      'time': '4:15 PM',
      'description': 'Translated project documentation from Japanese to English...',
      'tags': ['Legal', 'JP-EN'],
      'category': 'Translate',
      'color': const Color(0xFFFF6E84),
      'dateGroup': 'YESTERDAY',
      'chatLog': [
        {'isUser': true, 'text': 'Translate the project brief from JP to EN.'},
        {'isUser': false, 'text': 'Translated Text:\n"Project Scope & Goals: Term of milestone delivery starting Q3... Team agrees to implement automated validation..."'},
      ]
    },
  ];

  @override
  void initState() {
    super.initState();
    // Load persisted scan history
    _scanHistoryService.load();
    // Welcoming greeting message introducing NyayaSathi AI and its core safety features
    activeMessages.add({
      'isUser': false,
      'text': 'Namaste! I am NyayaSathi AI 🇮🇳 — your Citizen Legal, Financial & Consumer Safety Assistant.\n\n'
          'Here is what I can do for you:\n'
          '• ⚖️ Legal Risk: Scan rental agreements, loans & contracts for scam clauses & unfair terms\n'
          '• 🧾 Bill & GST: Audit restaurant & grocery bills for illegal service charges & tax errors\n'
          '• 🌐 Live Translate: Translate documents & photos across 12+ Indian languages\n'
          '• 🔍 Scanner Hub: QR & barcodes, Jan Aushadhi medicine savings & FSSAI food safety\n\n'
          'Tap any tool above or ask me any consumer protection question below!',
      'type': 'text',
    });
  }

  @override
  void dispose() {
    _ocrService.close();
    super.dispose();
  }

  void setTab(int index) {
    if (_currentIndex != index) {
      HapticFeedback.selectionClick();
      setState(() {
        _currentIndex = index;
      });
    }
  }

  void startChatWithMessage(String initialMessage) {
    setState(() {
      _currentIndex = 0;
    });
    addMessageAndReply(initialMessage);
  }

  void addMessageAndReply(String userMessage) {
    if (userMessage.trim().isEmpty) return;

    setState(() {
      activeMessages.add({
        'isUser': true,
        'text': userMessage,
        'type': 'text',
      });
      isTyping = true;
      typingStatus = 'NyayaSathi is analyzing';
    });

    _simulateAiReply(userMessage);
  }

  void _simulateAiReply(String userMessage) {
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;

      String reply = "";
      final lowerMsg = userMessage.toLowerCase();

      if (lowerMsg.contains('service charge') || (lowerMsg.contains('restaurant') && lowerMsg.contains('charge'))) {
        reply = "🚫 Restaurant Service Charge Rights in India:\n\n"
            "• Under CCPA Guidelines (July 2022), no hotel or restaurant can add service charge automatically or by default in the bill.\n"
            "• Service charge is purely voluntary and optional. You have the full right to ask them to remove it.\n"
            "• If they refuse to remove it, you can lodge a formal complaint on the National Consumer Helpline at 1915 or file on e-Daakhil.\n\n"
            "👉 Tap 'Bill Analyzer' to scan your bill and detect illegal service charges automatically!";
      } else if (lowerMsg.contains('rent') || lowerMsg.contains('deposit') || lowerMsg.contains('tenant') || lowerMsg.contains('landlord')) {
        reply = "🏠 Tenant Rights & Security Deposit Rules in India:\n\n"
            "• Under the Model Tenancy Act & Indian Contract Act (Sec 73/74), landlords cannot arbitrarily forfeit your full security deposit.\n"
            "• Deductions must be substantiated with itemized repair receipts for actual damages (normal wear & tear is excluded).\n"
            "• Notice period for termination must be mutual and reasonable (typically 30 days).\n\n"
            "👉 Tap 'Legal Analyzer' above to audit your Rental Agreement for unfair forfeiture clauses!";
      } else if (lowerMsg.contains('generic') || lowerMsg.contains('jan aushadhi') || lowerMsg.contains('dolo') || lowerMsg.contains('medicine') || lowerMsg.contains('paracetamol')) {
        reply = "💊 Jan Aushadhi (PMBJP) Medicine Savings:\n\n"
            "• Pradhan Mantri Bhartiya Janaushadhi Pariyojana provides identical therapeutic generic salts at 50% to 80% lower cost than branded medicines.\n"
            "• Example: Paracetamol 650mg generic costs ~₹1.20/strip vs branded Dolo 650 at ~₹34.00.\n"
            "• Over 10,000+ Jan Aushadhi Kendras are available across India.\n\n"
            "👉 Tap 'Medicine Safety' above to scan any medicine strip and discover generic alternatives!";
      } else if (lowerMsg.contains('fssai') || lowerMsg.contains('food') || lowerMsg.contains('expiry') || lowerMsg.contains('sugar')) {
        reply = "🥗 Food Safety & FSSAI Standards in India:\n\n"
            "• Every packaged food in India must carry a valid 14-digit FSSAI License Number (FSS Act 2006).\n"
            "• Products must clearly declare Expiry / Best Before date, allergen info, and Vegetarian (Green Dot) / Non-Veg (Brown Dot) symbol.\n"
            "• Under FSSAI HFSS regulations, foods with high added sugar (>10g/100ml) or high sodium (>600mg) require caution.\n\n"
            "👉 Tap 'Product Safety' above to scan food packaging!";
      } else if (lowerMsg.contains('helpline') || lowerMsg.contains('complaint') || lowerMsg.contains('consumer court') || lowerMsg.contains('1915')) {
        reply = "📞 Official Consumer Redressal Helplines in India:\n\n"
            "• National Consumer Helpline (NCH): Call Toll-Free 1915 or SMS 8800001915\n"
            "• Consumer Complaints Online: consumerhelpline.gov.in\n"
            "• Online Consumer Court Case Filing: edaakhil.nic.in\n"
            "• GST Fraud & Fake Invoices Reporting: cbic-gst.gov.in / reportfakegst@gov.in\n"
            "• National Food Safety Toll-Free: 1800-112-100 (FSSAI)";
      } else if (lowerMsg.contains('translate') || lowerMsg.contains('hindi') || lowerMsg.contains('tamil') || lowerMsg.contains('telugu') || lowerMsg.contains('marathi') || lowerMsg.contains('language')) {
        reply = "🌐 AI Live Translator & OCR Engine:\n\n"
            "• Supports on-device translation across English, Hindi, Marathi, Tamil, Telugu, Bengali, Gujarati, Kannada, Malayalam, Punjabi, Urdu, and more.\n"
            "• Choose Text Translation or Image Overlay Translation (translates text directly superimposed over photos).\n\n"
            "👉 Tap 'Live Translator' above or '+' below to translate any document or signboard!";
      } else if (lowerMsg.contains('ocr') || lowerMsg.contains('scan') || lowerMsg.contains('qr') || lowerMsg.contains('barcode')) {
        reply = "🔍 Universal Scanner Ready:\n\n"
            "• Scan QR codes, UPI barcodes, GS1 Made-in-India barcodes (890 prefix), or extract text from photos.\n\n"
            "👉 Tap 'Scanner' above to open the camera scanner instantly!";
      } else if (lowerMsg.contains('hello') || lowerMsg.contains('hi') || lowerMsg.contains('namaste') || lowerMsg.contains('help')) {
        reply = "Namaste! I am ready to help. You can:\n\n"
            "1. 📜 Scan a legal contract (Rental, Employment, Loan)\n"
            "2. 🧾 Verify a bill or invoice for GST fraud & hidden fees\n"
            "3. 💊 Check medicine strip for Jan Aushadhi generic alternatives\n"
            "4. 🥗 Audit food/product packaging for FSSAI & expiry\n"
            "5. 🌐 Translate any text or image into your native language\n\n"
            "What would you like to start with?";
      } else {
        reply = "I understand your query: \"$userMessage\".\n\n"
            "To analyze a document, bill, medicine strip, or food packet, tap the '+' button below or choose one of the 5 safety tools above. You can also ask me specific questions about Indian consumer law, GST, or tenant rights!";
      }

      setState(() {
        isTyping = false;
        typingStatus = null;
        activeMessages.add({
          'isUser': false,
          'text': reply,
          'type': 'text',
        });
      });

      _saveSessionToHistory(userMessage, reply);
    });
  }

  /// Routes the feature action to the real implementation screen.
  void executeFeatureAction({
    required String feature,
    required Map<String, dynamic> document,
    String? userPrompt,
  }) {
    final docName = document['name'] ?? 'Document';
    final docSize = document['size'] ?? '1.2 MB';
    final docType = document['type'] ?? 'PDF Document';
    final docPath = document['path'] as String?;

    // Add user message to chat
    setState(() {
      activeMessages.add({
        'isUser': true,
        'text': userPrompt ?? 'Apply $feature to $docName',
        'type': 'upload',
        'document': document,
        'feature': feature,
      });
    });

    final now = DateTime.now();
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final formattedDate = '${months[now.month - 1]} ${now.day}, ${now.year}';

    // Store in customDocuments repository
    final exists = customDocuments.any((d) => d['name'] == docName);
    if (!exists) {
      customDocuments.insert(0, {
        'name': docName,
        'status': 'Verified',
        'date': formattedDate,
        'size': docSize,
        'type': docType,
        'feature': feature,
      });
    }

    if (feature == 'Scanner') {
      // Route to Universal Scanner Hub (QR/Barcode, Product & Safety Scanner)
      final context = this.context;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScannerHubScreen(
            ocrService: _ocrService,
            historyService: _scanHistoryService,
            initialTab: 0,
          ),
        ),
      ).then((result) {
        if (mounted) {
          setState(() {
            activeMessages.add({
              'isUser': false,
              'type': 'ocr_launched',
              'documentName': docName,
              'message': 'Universal scan completed. Results saved to Scan History.',
            });
          });
          _saveSessionToHistory('Scanner: $docName', 'Scan completed');
        }
      });
      return;
    }

    if (feature == 'Translation' || feature == 'Translate') {
      // Open 2-Option Translation Selector (Text Translation vs. Image Translation)
      final context = this.context;
      TranslationModeSheet.show(
        context,
        ocrService: _ocrService,
        historyService: _scanHistoryService,
        initialImagePath: docPath,
        documentName: docName,
      ).then((_) {
        if (mounted && docName.isNotEmpty) {
          setState(() {
            activeMessages.add({
              'isUser': false,
              'type': 'translation_launched',
              'documentName': docName,
              'message': 'Translation session for "$docName" completed.',
            });
          });
          _saveSessionToHistory('Translation: $docName', 'Dual-mode translation completed');
        }
      });
      return;
    }

    if (feature == 'Bill Analyzer' || feature == 'Bill' || feature == 'GST') {
      final context = this.context;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BillAnalyzerEntryScreen(
            ocrService: _ocrService,
            historyService: _scanHistoryService,
          ),
        ),
      );
      return;
    }

    if (feature == 'Document Analyzer' ||
        feature == 'Legal Analyzer' ||
        feature == 'Legal Risk' ||
        feature == 'Legal') {
      // Open Document Risk & Scam Analyzer entry screen directly
      final context = this.context;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LegalAnalyzerEntryScreen(
            ocrService: _ocrService,
            historyService: _scanHistoryService,
          ),
        ),
      ).then((_) {
        if (mounted) {
          setState(() {
            activeMessages.add({
              'isUser': false,
              'type': 'text',
              'text': 'Document risk & scam analysis complete. Check the verified report for highlighted risks and statutory protections.',
            });
          });
        }
      });
      return;
    }

    if (feature == 'Medicine' ||
        feature == 'Medicine Safety' ||
        feature == 'Pharma' ||
        feature == 'Jan Aushadhi') {
      // Open Medicine Safety Screen directly
      final context = this.context;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MedicineEntryScreen(
            ocrService: _ocrService,
            historyService: _scanHistoryService,
          ),
        ),
      );
      return;
    }

    if (feature == 'Product Safety' ||
        feature == 'Food Safety' ||
        feature == 'Product' ||
        feature == 'Food' ||
        feature == 'FSSAI') {
      // Open Product & Food Safety Screen directly
      final context = this.context;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductSafetyEntryScreen(
            ocrService: _ocrService,
            historyService: _scanHistoryService,
          ),
        ),
      );
      return;
    }

    // Fallback: Documents feature or no file path → keep mock simulation
    setState(() {
      isTyping = true;
      typingStatus = 'Processing $docName';
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      final resultMessage = {
        'isUser': false,
        'type': 'document_result',
        'documentName': docName,
        'status': 'Verified & Indexed',
        'fileSize': docSize,
        'fileType': docType,
        'summary': 'Document stored in local repository. Tap Scanner or Translation to process it further.',
        'indexedDate': formattedDate,
        'totalDocs': customDocuments.length,
      };
      setState(() {
        isTyping = false;
        typingStatus = null;
        activeMessages.add(resultMessage);
      });
      _saveSessionToHistory('Documents: $docName', 'Indexed $docName into repository');
    });
  }

  void _saveSessionToHistory(String query, String response) {
    final newItem = {
      'title': query.length > 24 ? '${query.substring(0, 21)}...' : query,
      'time': 'Just Now',
      'description': response.length > 60 ? '${response.substring(0, 57)}...' : response,
      'tags': ['Chat', 'Aura'],
      'category': 'Chat',
      'color': const Color(0xFF2563EB),
      'dateGroup': 'TODAY',
      'chatLog': [
        {'isUser': true, 'text': query},
        {'isUser': false, 'text': response},
      ]
    };

    setState(() {
      historyItems.insert(0, newItem);
    });
  }

  void loadHistoryChat(Map<String, dynamic> item) {
    setState(() {
      _currentIndex = 0;
      activeMessages.clear();
      isTyping = false;
      typingStatus = null;
      final List<dynamic> logs = item['chatLog'] ?? [];
      for (var log in logs) {
        activeMessages.add({
          'isUser': log['isUser'] == true,
          'text': log['text'] ?? '',
          'type': 'text',
        });
      }
    });
  }

  // ─── Bill Analyzer Inline Flow ──────────────────────────────────────────

  void _showBillAnalyzerPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Scan Bill',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Take a photo or pick from gallery',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _billPickerOption(
                        ctx,
                        icon: Icons.camera_alt_rounded,
                        label: 'Camera',
                        onTap: () => Navigator.pop(ctx, ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _billPickerOption(
                        ctx,
                        icon: Icons.photo_library_rounded,
                        label: 'Gallery',
                        onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    ).then((source) {
      if (source != null && source is ImageSource) {
        _processBillInline(source);
      }
    });
  }

  Widget _billPickerOption(BuildContext ctx, {required IconData icon, required String label, required VoidCallback onTap}) {
    final theme = Theme.of(ctx);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
          ],
        ),
      ),
    );
  }

  Future<void> _processBillInline(ImageSource source) async {
    // Add user message
    setState(() {
      activeMessages.add({
        'isUser': true,
        'type': 'upload',
        'document': {'name': source == ImageSource.camera ? 'Bill (Camera)' : 'Bill (Gallery)'},
        'feature': 'Bill Analyzer',
      });
      isTyping = true;
      typingStatus = 'Scanning bill...';
    });

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, imageQuality: 85);
      if (pickedFile == null) {
        setState(() {
          isTyping = false;
          typingStatus = null;
          activeMessages.add({
            'isUser': false,
            'type': 'text',
            'text': 'No image selected. Please try again.',
          });
        });
        return;
      }

      // Update status
      setState(() {
        typingStatus = 'Reading text with OCR...';
      });

      // Run OCR
      final ocrResult = await _ocrService.recognizeFromPath(pickedFile.path);

      if (ocrResult.isEmpty) {
        setState(() {
          isTyping = false;
          typingStatus = null;
          activeMessages.add({
            'isUser': false,
            'type': 'text',
            'text': 'Could not read any text from the bill. Please try a clearer image.',
          });
        });
        return;
      }

      // Update status
      setState(() {
        typingStatus = 'Analyzing GST, charges & fraud patterns...';
      });

      // Run bill analysis
      final orchestrator = BillAnalysisOrchestrator();
      final result = await orchestrator.analyze(
        ocrResult.fullText,
        imagePath: pickedFile.path,
      );

      // Save to history
      _saveSessionToHistory('Bill: ${result.bill.sellerName ?? "Unknown"}', result.overallLabel);

      // Inject result into chat
      setState(() {
        isTyping = false;
        typingStatus = null;
        activeMessages.add({
          'isUser': false,
          'type': 'bill_analysis_result',
          'billResult': result,
          'imagePath': pickedFile.path,
          'text': _buildBillSummaryText(result),
        });
      });
    } catch (e) {
      setState(() {
        isTyping = false;
        typingStatus = null;
        activeMessages.add({
          'isUser': false,
          'type': 'text',
          'text': 'Analysis failed: ${e.toString()}. Please try again.',
        });
      });
    }
  }

  String _buildBillSummaryText(BillAnalysisResult result) {
    final buf = StringBuffer();
    buf.write('Bill analyzed');
    if (result.bill.sellerName != null) buf.write(' from ${result.bill.sellerName}');
    buf.write('. ${result.overallEmoji} ${result.overallLabel}.');
    if (result.potentialExcess != null && result.potentialExcess! > 0) {
      buf.write(' Potential excess of ₹${result.potentialExcess!.toStringAsFixed(2)} detected.');
    }
    final critical = result.errorFindings.length + result.suspiciousFindings.length;
    if (critical > 0) {
      buf.write(' $critical critical issue(s) found.');
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Screens corresponding to each tab index
    final List<Widget> screens = [
      HomeDashboardScreen(
        key: const ValueKey('home_tab'),
        activeMessages: activeMessages,
        isTyping: isTyping,
        typingStatus: typingStatus,
        onSendMessage: addMessageAndReply,
        onExecuteFeature: executeFeatureAction,
        onNavigateToTab: setTab,
        ocrService: _ocrService,
        historyService: _scanHistoryService,
      ),
      HistoryScreen(
        key: const ValueKey('history_tab'),
        historyItems: historyItems,
        onLoadChat: loadHistoryChat,
        scanHistoryService: _scanHistoryService,
      ),
      UpdatesScreen(
        key: const ValueKey('updates_tab'),
        onTryOcr: () {
          startChatWithMessage("I want to try the real-time OCR vision");
        },
      ),
      SettingsScreen(
        key: const ValueKey('settings_tab'),
        isLightMode: widget.isLightMode,
        onThemeChanged: widget.onThemeChanged,
      ),
    ];

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.015, 0.0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: screens[_currentIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.outlineVariant,
              width: 1.0,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.25 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
                _buildNavItem(1, Icons.history_rounded, Icons.history_rounded, 'History'),
                _buildNavItem(2, Icons.notifications_none_rounded, Icons.notifications_rounded, 'Updates'),
                _buildNavItem(3, Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData outlineIcon, IconData solidIcon, String label) {
    final isSelected = _currentIndex == index;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final activeColor = theme.colorScheme.primary;
    final inactiveColor = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.65);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setTab(index),
          borderRadius: BorderRadius.circular(16.0),
          splashColor: activeColor.withValues(alpha: 0.12),
          highlightColor: activeColor.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark
                            ? activeColor.withValues(alpha: 0.22)
                            : activeColor.withValues(alpha: 0.12))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: Icon(
                    isSelected ? solidIcon : outlineIcon,
                    color: isSelected ? activeColor : inactiveColor,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? activeColor : inactiveColor,
                    fontFamily: 'Inter',
                    letterSpacing: 0.2,
                  ),
                  child: Text(label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
