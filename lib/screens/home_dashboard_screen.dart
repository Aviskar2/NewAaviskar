import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ocr_service.dart';
import '../services/scan_history_service.dart';
import 'scanner/scanner_hub_screen.dart';
import 'bill_analyzer/bill_analyzer_entry_screen.dart';
import 'legal_analyzer/legal_analyzer_entry_screen.dart';
import 'government_schemes/government_schemes_entry_screen.dart';
import '../widgets/translation_mode_sheet.dart';

/// Clean, Executive Home Dashboard displaying the 4 Core Safety Pillars.
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
                    '🛡️ NyayaSathi AI Safety Hub',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'All legal, financial & safety tools verified with deterministic Indian statutory engines.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 18),

                  _buildHelpItem(
                    title: '1. Legal & Contract Risk Analyzer',
                    subtitle: 'Audits rental agreements, employment bonds, and loans for unlawful forfeiture, unilateral termination, and Section 27 non-compete void clauses.',
                    icon: Icons.gavel_rounded,
                    color: const Color(0xFFDC2626),
                  ),
                  const SizedBox(height: 12),
                  _buildHelpItem(
                    title: '2. Bill & GST Fraud Detector',
                    subtitle: 'Audits CGST/SGST/IGST breakdown, verifies 15-digit GSTIN, and detects illegal mandatory restaurant service charges (CCPA 2022).',
                    icon: Icons.receipt_long_rounded,
                    color: const Color(0xFF16A34A),
                  ),
                  const SizedBox(height: 12),
                  _buildHelpItem(
                    title: '3. AI Live Document Translator',
                    subtitle: 'On-device translation across 12+ Indian languages for contracts, invoices, and photos with image overlay support.',
                    icon: Icons.translate_rounded,
                    color: const Color(0xFF2563EB),
                  ),
                  const SizedBox(height: 12),
                  _buildHelpItem(
                    title: '4. Universal Scanner Hub',
                    subtitle: 'Integrates QR/Barcode scanning, Jan Aushadhi generic medicine savings (save up to 80%), and FSSAI 14-digit food safety audit all in one scanner.',
                    icon: Icons.qr_code_scanner_rounded,
                    color: const Color(0xFF7C3AED),
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

  Widget _buildHelpItem({
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

  Widget _buildAppDrawer(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
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
                      _openFeature('legal');
                    },
                  ),
                  _buildDrawerTile(
                    title: 'Bill & GST Fraud Detector',
                    icon: Icons.receipt_long_rounded,
                    color: const Color(0xFF16A34A),
                    onTap: () {
                      Navigator.pop(context);
                      _openFeature('bill');
                    },
                  ),
                  _buildDrawerTile(
                    title: 'AI Document Translator',
                    icon: Icons.translate_rounded,
                    color: const Color(0xFF2563EB),
                    onTap: () {
                      Navigator.pop(context);
                      _openFeature('translation');
                    },
                  ),
                  _buildDrawerTile(
                    title: 'Universal Scanner (QR, Med & Food)',
                    icon: Icons.qr_code_scanner_rounded,
                    color: const Color(0xFF7C3AED),
                    onTap: () {
                      Navigator.pop(context);
                      _openFeature('scanner');
                    },
                  ),
                  const Divider(height: 24),
                  _buildDrawerTile(
                    title: 'Scan History',
                    icon: Icons.history_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                    onTap: () {
                      Navigator.pop(context);
                      widget.onNavigateToTab?.call(1);
                    },
                  ),
                  _buildDrawerTile(
                    title: 'Safety Updates & Alerts',
                    icon: Icons.notifications_none_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                    onTap: () {
                      Navigator.pop(context);
                      widget.onNavigateToTab?.call(2);
                    },
                  ),
                  _buildDrawerTile(
                    title: 'Settings & Theme',
                    icon: Icons.settings_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                    onTap: () {
                      Navigator.pop(context);
                      widget.onNavigateToTab?.call(3);
                    },
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
              padding: const EdgeInsets.all(6),
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
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Clean, Executive Welcome & Status Header (Completely Overflow-Safe)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E1030), const Color(0xFF140A20)]
                        : [const Color(0xFFEEF4FF), const Color(0xFFE0ECFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF381552) : const Color(0xFFBFDBFE),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🇮🇳', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Citizen Safety & Consumer Hub',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                              letterSpacing: 0.1,
                              color: theme.colorScheme.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF16A34A).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.check_circle, size: 12, color: Color(0xFF16A34A)),
                              SizedBox(width: 4),
                              Text(
                                '5 Active Tools',
                                style: TextStyle(
                                  color: Color(0xFF16A34A),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              Text(
                'Features',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 12),

              // Feature 1: Legal & Contract Risk Analyzer
              _buildFeatureCard(
                context,
                category: 'Legal Risk',
                title: 'Legal & Contract Risk Analyzer',
                icon: Icons.gavel_rounded,
                color: const Color(0xFFDC2626),
                tags: ['🏠 Rental Leases', '💼 Job Bonds', '💳 Loan Papers'],
                onTap: () => _openFeature('legal'),
              ),

              const SizedBox(height: 14),

              // Feature 2: Bill & GST Fraud Detector
              _buildFeatureCard(
                context,
                category: 'Bill & GST',
                title: 'Bill & GST Fraud Detector',
                icon: Icons.receipt_long_rounded,
                color: const Color(0xFF16A34A),
                tags: ['🍽️ Restaurant Bills', '🔍 GSTIN Check', '🚫 Service Charge'],
                onTap: () => _openFeature('bill'),
              ),

              const SizedBox(height: 14),

              // Feature 3: AI Document & Camera Translator
              _buildFeatureCard(
                context,
                category: 'Live Translate',
                title: 'AI Document & Live Translator',
                icon: Icons.translate_rounded,
                color: const Color(0xFF2563EB),
                tags: ['📸 Live Camera', '📄 PDF & Forms', '🗣️ 12+ Indian Languages'],
                onTap: () => _openFeature('translation'),
              ),

              const SizedBox(height: 14),

              // Feature 4: Universal Scanner Hub
              _buildFeatureCard(
                context,
                category: 'Scanner Hub',
                title: 'Universal Scanner & Safety Hub',
                icon: Icons.qr_code_scanner_rounded,
                color: const Color(0xFF7C3AED),
                tags: ['💊 Generic Meds (80% Off)', '🥗 Food Safety Check', '📱 QR & Barcode'],
                onTap: () => _openFeature('scanner'),
              ),

              const SizedBox(height: 14),

              // Feature 5: Government Schemes & Rights
              _buildFeatureCard(
                context,
                category: 'Govt Schemes',
                title: 'Government Schemes & Rights',
                icon: Icons.account_balance_rounded,
                color: const Color(0xFF0369A1),
                tags: ['🎯 Eligibility Match', '🌾 Welfare Benefits', '🔗 Direct Apply'],
                onTap: () => _openFeature('schemes'),
              ),

              const SizedBox(height: 20),

              // Emergency Helplines Card (Completely Overflow-Safe)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A0A26) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2D1040) : const Color(0xFFE2E8F0),
                  ),
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
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Toll-Free 24/7',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
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
                          theme: theme,
                          isDark: isDark,
                        ),
                        _buildHelplineChip(
                          icon: Icons.shield_outlined,
                          label: 'Cyber Crime: 1930',
                          theme: theme,
                          isDark: isDark,
                        ),
                        _buildHelplineChip(
                          icon: Icons.restaurant_rounded,
                          label: 'Food Safety: 1800-112-100',
                          theme: theme,
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

  Widget _buildHelplineChip({
    required IconData icon,
    required String label,
    required ThemeData theme,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF261238) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF3B1C54) : const Color(0xFFCBD5E1),
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
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required String category,
    required String title,
    required IconData icon,
    required Color color,
    required List<String> tags,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: isDark ? color.withValues(alpha: 0.12) : color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.35 : 0.25),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isDark ? 0.15 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Icon + Title/Category + Arrow
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: color,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5,
                            letterSpacing: -0.2,
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
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Statements / Badges
              Wrap(
                spacing: 6,
                runSpacing: 5,
                children: tags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E0C2B) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: color.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: color,
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
}
