import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ocr_service.dart';
import '../services/scan_history_service.dart';
import 'scanner/scanner_hub_screen.dart';
import 'bill_analyzer/bill_analyzer_entry_screen.dart';
import 'legal_analyzer/legal_analyzer_entry_screen.dart';
import 'government_schemes/government_schemes_entry_screen.dart';
import '../widgets/translation_mode_sheet.dart';

/// Vibrant & Modern Home Dashboard inspired by Stitch Design System
class HomeDashboardScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? activeMessages;
  final bool? isTyping;
  final String? typingStatus;
  final ValueChanged<String>? onSendMessage;
  final void Function({
    required String feature,
    required Map<String, dynamic> document,
    String? userPrompt,
  })? onExecuteFeature;
  final ValueChanged<int>? onNavigateToTab;
  final OcrService? ocrService;
  final ScanHistoryService? historyService;

  const HomeDashboardScreen({
    super.key,
    this.activeMessages,
    this.isTyping,
    this.typingStatus,
    this.onSendMessage,
    this.onExecuteFeature,
    this.onNavigateToTab,
    this.ocrService,
    this.historyService,
  });

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  void _openFeature(String feature) {
    HapticFeedback.lightImpact();

    final ocrService = widget.ocrService ?? OcrService();
    final historyService = widget.historyService ?? ScanHistoryService();

    switch (feature) {
      case 'legal':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LegalAnalyzerEntryScreen(
              ocrService: ocrService,
              historyService: historyService,
            ),
          ),
        );
        break;

      case 'bill':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BillAnalyzerEntryScreen(
              ocrService: ocrService,
              historyService: historyService,
            ),
          ),
        );
        break;

      case 'translation':
        TranslationModeSheet.show(
          context,
          ocrService: ocrService,
          historyService: historyService,
        );
        break;

      case 'scanner':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScannerHubScreen(
              ocrService: ocrService,
              historyService: historyService,
            ),
          ),
        );
        break;

      case 'schemes':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const GovernmentSchemesEntryScreen(),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.95) : const Color(0xFFF8F9FD).withValues(alpha: 0.95),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        automaticallyImplyLeading: false,
        titleSpacing: 16.0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF6366F1)],
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.security_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'ScanSure',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_outline_rounded,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
                size: 20,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Features Section Header with Live Badge
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Features',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withValues(alpha: isDark ? 0.2 : 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.verified_rounded, size: 12, color: Color(0xFF16A34A)),
                          SizedBox(width: 4),
                          Text(
                            '5 Verified Tools',
                            style: TextStyle(
                              color: Color(0xFF16A34A),
                              fontWeight: FontWeight.w700,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // Feature 1: Legal & Contract Risk Analyzer (Warm Coral / Amber Accent)
              _buildStitchFeatureCard(
                category: 'Legal Risk',
                title: 'Legal & Contract Risk Analyzer',
                icon: Icons.gavel_rounded,
                gradientColors: isDark
                    ? [const Color(0xFF271413), const Color(0xFF1F0E0E)]
                    : [const Color(0xFFFFF8F7), const Color(0xFFFFF2EE)],
                borderColor: isDark ? const Color(0xFF5A2521) : const Color(0xFFFFDCD3),
                iconBgColor: isDark ? const Color(0xFF421C18) : const Color(0xFFFFE4DE),
                iconColor: const Color(0xFFD84315),
                categoryBgColor: isDark ? const Color(0xFF4A201C) : const Color(0xFFFFE4DE),
                categoryTextColor: isDark ? const Color(0xFFFF8A65) : const Color(0xFFBF360C),
                chips: [
                  '🏠 Rental Leases',
                  '💼 Job Bonds',
                  '💳 Loan Papers',
                ],
                chipBorderColor: isDark ? const Color(0xFF502723) : const Color(0xFFFFD5CA),
                onTap: () => _openFeature('legal'),
              ),

              const SizedBox(height: 12),

              // Feature 2: Food and Medicine Safety (Fresh Mint / Emerald Accent)
              _buildStitchFeatureCard(
                category: 'Scanner Hub',
                title: 'Food and Medicine Safety',
                icon: Icons.medication_rounded,
                gradientColors: isDark
                    ? [const Color(0xFF11261B), const Color(0xFF0C1D15)]
                    : [const Color(0xFFF4FAF6), const Color(0xFFE9F7EF)],
                borderColor: isDark ? const Color(0xFF1F4D36) : const Color(0xFFC6EAD4),
                iconBgColor: isDark ? const Color(0xFF1B3D2C) : const Color(0xFFD2F2DF),
                iconColor: const Color(0xFF1E7E46),
                categoryBgColor: isDark ? const Color(0xFF1C4230) : const Color(0xFFD2F2DF),
                categoryTextColor: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF145A32),
                chips: [
                  '🥗 Food Safety (FSSAI)',
                  '💊 Generic Meds (80% Off)',
                  '🧪 Expiry & Quality',
                ],
                chipBorderColor: isDark ? const Color(0xFF26543D) : const Color(0xFFC0E7CF),
                onTap: () => _openFeature('scanner'),
              ),

              const SizedBox(height: 12),

              // Feature 3: Bill & GST Fraud Detector (Emerald / Mint Accent)
              _buildStitchFeatureCard(
                category: 'Bill & GST',
                title: 'Bill & GST Fraud Detector',
                icon: Icons.receipt_long_rounded,
                gradientColors: isDark
                    ? [const Color(0xFF0D2517), const Color(0xFF081B10)]
                    : [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7)],
                borderColor: isDark ? const Color(0xFF194E2C) : const Color(0xFFBBF7D0),
                iconBgColor: isDark ? const Color(0xFF163E24) : const Color(0xFFDCFCE7),
                iconColor: const Color(0xFF16A34A),
                categoryBgColor: isDark ? const Color(0xFF184227) : const Color(0xFFDCFCE7),
                categoryTextColor: isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D),
                chips: [
                  '🍽️ Restaurant Bills',
                  '🔍 GSTIN Check',
                  '🚫 Service Charge',
                ],
                chipBorderColor: isDark ? const Color(0xFF1F5230) : const Color(0xFFA7F3D0),
                onTap: () => _openFeature('bill'),
              ),

              const SizedBox(height: 12),

              // Feature 4: AI Document & Live Translator (Electric Indigo / Violet Accent)
              _buildStitchFeatureCard(
                category: 'Live Translate',
                title: 'AI Document & Live Translator',
                icon: Icons.translate_rounded,
                gradientColors: isDark
                    ? [const Color(0xFF141733), const Color(0xFF0E1026)]
                    : [const Color(0xFFF7F8FE), const Color(0xFFEFF1FD)],
                borderColor: isDark ? const Color(0xFF27316A) : const Color(0xFFD5DCFB),
                iconBgColor: isDark ? const Color(0xFF21295C) : const Color(0xFFE0E5FD),
                iconColor: const Color(0xFF3B4CB8),
                categoryBgColor: isDark ? const Color(0xFF232C62) : const Color(0xFFE0E5FD),
                categoryTextColor: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF29368D),
                chips: [
                  '📸 Live Camera',
                  '📄 PDF & Forms',
                  '🗣️ 12+ Indian Languages',
                ],
                chipBorderColor: isDark ? const Color(0xFF2B3674) : const Color(0xFFCDD5FA),
                onTap: () => _openFeature('translation'),
              ),

              const SizedBox(height: 12),

              // Feature 5: Government Schemes & Rights (Warm Saffron / Amber Accent)
              _buildStitchFeatureCard(
                category: 'Govt Schemes',
                title: 'Government Schemes & Rights',
                icon: Icons.account_balance_rounded,
                gradientColors: isDark
                    ? [const Color(0xFF2A1E0B), const Color(0xFF1E1507)]
                    : [const Color(0xFFFFFBF2), const Color(0xFFFFF4DE)],
                borderColor: isDark ? const Color(0xFF553D15) : const Color(0xFFFDE1AC),
                iconBgColor: isDark ? const Color(0xFF453111) : const Color(0xFFFEE9BD),
                iconColor: const Color(0xFFB76E00),
                categoryBgColor: isDark ? const Color(0xFF4B3512) : const Color(0xFFFEE9BD),
                categoryTextColor: isDark ? const Color(0xFFFDE047) : const Color(0xFF8A5000),
                chips: [
                  '🎯 Eligibility Match',
                  '🌾 Welfare Benefits',
                  '🔗 Direct Apply',
                ],
                chipBorderColor: isDark ? const Color(0xFF533B14) : const Color(0xFFFADBA0),
                onTap: () => _openFeature('schemes'),
              ),

              const SizedBox(height: 18),

              // Emergency Citizen Helplines Strip
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF2563EB), size: 16),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'National Citizen Helplines',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Toll-Free 24/7',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildHelplineChip(
                          icon: Icons.support_agent_rounded,
                          label: 'Consumer: 1915',
                          isDark: isDark,
                        ),
                        _buildHelplineChip(
                          icon: Icons.shield_outlined,
                          label: 'Cyber Crime: 1930',
                          isDark: isDark,
                        ),
                        _buildHelplineChip(
                          icon: Icons.restaurant_rounded,
                          label: 'Food Safety: 1800-112-100',
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStitchFeatureCard({
    required String category,
    required String title,
    required IconData icon,
    required List<Color> gradientColors,
    required Color borderColor,
    required Color iconBgColor,
    required Color iconColor,
    required Color categoryBgColor,
    required Color categoryTextColor,
    required List<String> chips,
    required Color chipBorderColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: iconColor.withValues(alpha: 0.1),
        highlightColor: iconColor.withValues(alpha: 0.05),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header Row: Icon + Category/Title + Arrow
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: borderColor,
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: iconColor.withValues(alpha: 0.12),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: iconColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: categoryBgColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: categoryTextColor,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            letterSpacing: -0.3,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: iconBgColor.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: iconColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Topic Chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: chips.map((chipText) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: chipBorderColor,
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      chipText,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelplineChip({
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF2563EB)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}
