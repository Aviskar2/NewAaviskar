import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_dashboard_screen.dart';
import 'history_screen.dart';
import 'updates_screen.dart';
import 'settings_screen.dart';

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
    // Default greeting message guiding the user to upload first
    activeMessages.add({
      'isUser': false,
      'text': 'Hello! I am Aura AI. 📄 Tap the \'+\' button below to upload a photo or document, then choose a feature (Translation, Scanner, or Documents) to process it!',
      'type': 'text',
    });
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
      typingStatus = 'Aura is analyzing';
    });

    _simulateAiReply(userMessage);
  }

  void _simulateAiReply(String userMessage) {
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;

      String reply = "";
      final lowerMsg = userMessage.toLowerCase();

      if (lowerMsg.contains('translate') || lowerMsg.contains('japanese') || lowerMsg.contains('spanish')) {
        reply = "Translation engine ready! Tap '+' below to attach a document or photo, then tap Translation to translate it instantly.";
      } else if (lowerMsg.contains('ocr') || lowerMsg.contains('scan') || lowerMsg.contains('qr')) {
        reply = "OCR Scanner ready! Tap '+' below to capture or upload an image/document, then tap Scanner to extract text and data fields.";
      } else if (lowerMsg.contains('document') || lowerMsg.contains('track') || lowerMsg.contains('repository')) {
        if (customDocuments.isEmpty) {
          reply = "Your Document Repository is currently empty. Tap the '+' button below to upload a file to verify and track it.";
        } else {
          final count = customDocuments.length;
          final docList = customDocuments
              .take(3)
              .map((d) => "• ${d['name']} (${d['status']})")
              .join('\n');
          reply = "You currently have $count document(s) in your repository:\n\n$docList\n\nUpload another document or select 'Documents' to track more.";
        }
      } else if (lowerMsg.contains('hello') || lowerMsg.contains('hi') || lowerMsg.contains('hey')) {
        reply = "Hello! Upload a photo or document using the '+' button below and choose Translation, Scanner, or Documents to get started.";
      } else {
        reply = "I've received your query: \"$userMessage\". To process a document or photo, attach it using '+' below and choose one of the three features.";
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

  void executeFeatureAction({
    required String feature,
    required Map<String, dynamic> document,
    String? userPrompt,
  }) {
    final docName = document['name'] ?? 'Document';
    final docSize = document['size'] ?? '1.2 MB';
    final docType = document['type'] ?? 'PDF Document';

    setState(() {
      activeMessages.add({
        'isUser': true,
        'text': userPrompt ?? 'Apply $feature to $docName',
        'type': 'upload',
        'document': document,
        'feature': feature,
      });
      isTyping = true;
      typingStatus = 'Aura is executing $feature';
    });

    final now = DateTime.now();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final formattedDate = '${months[now.month - 1]} ${now.day}, ${now.year}';

    // Store in customDocuments if not already there
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

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;

      Map<String, dynamic> resultMessage = {};

      if (feature == 'Translation') {
        resultMessage = {
          'isUser': false,
          'type': 'translation_result',
          'documentName': docName,
          'sourceLang': 'Japanese (Auto-detected)',
          'targetLang': 'English',
          'originalSnippet': '本四半期の総収益は前年比15％増の4,500万ドルに達しました。業務効率化と国際展開が主な成長要因です。',
          'translatedText': 'Total revenue for this quarter reached \$45 million, representing a 15% increase year-over-year. Key growth drivers were operational efficiency and international market expansion.',
          'confidence': '99.8%',
        };
      } else if (feature == 'Scanner') {
        resultMessage = {
          'isUser': false,
          'type': 'scanner_result',
          'documentName': docName,
          'scanType': docType.contains('Image') || docType.contains('Photo') ? 'Visual OCR & QR Code' : 'Structured OCR Scan',
          'detectedCode': 'https://aura.ai/docs/verified-sync-8942',
          'confidence': '99.4%',
          'extractedFields': [
            {'label': 'Invoice / Document ID', 'value': 'AURA-2026-9921'},
            {'label': 'Date of Record', 'value': formattedDate},
            {'label': 'Extracted Text Lines', 'value': '38 lines indexed successfully'},
            {'label': 'Barcode / QR Payload', 'value': 'Verified Authentic (Aura-Seal)'},
          ],
        };
      } else {
        // Documents feature
        resultMessage = {
          'isUser': false,
          'type': 'document_result',
          'documentName': docName,
          'status': 'Verified & Indexed',
          'fileSize': docSize,
          'fileType': docType,
          'summary': 'Document integrity verified with SHA-256 validation. 0 compliance flags detected. Fully indexed in Aura AI local repository for contextual queries.',
          'indexedDate': formattedDate,
          'totalDocs': customDocuments.length,
        };
      }

      setState(() {
        isTyping = false;
        typingStatus = null;
        activeMessages.add(resultMessage);
      });

      final historyDesc = feature == 'Translation'
          ? 'Translated $docName to English'
          : feature == 'Scanner'
              ? 'Scanned $docName and extracted OCR data'
              : 'Verified and indexed $docName into repository';

      _saveSessionToHistory('$feature: $docName', historyDesc);
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
      ),
      HistoryScreen(
        key: const ValueKey('history_tab'),
        historyItems: historyItems,
        onLoadChat: loadHistoryChat,
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
          color: isDark ? const Color(0xFF180524) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF2E0F38) : const Color(0xFFE9EFFB),
              width: 1.0,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
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
