import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_settings.dart';
import '../theme/app_colors.dart';

/// Redesigned Settings & Preferences Screen matching the Stitch Design System.
/// Features clean grouped section cards, AI detection engine controls,
/// scanner parameters, language selection, biometric privacy, and diagnostics.
class SettingsScreen extends StatefulWidget {
  final bool isLightMode;
  final ValueChanged<bool> onThemeChanged;

  const SettingsScreen({
    super.key,
    required this.isLightMode,
    required this.onThemeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // User Profile State
  String _userName = 'John Doe';
  String _userEmail = 'john.doe@example.com';
  String _apiKeyPreview = AppSettings.maskedApiKey;
  String _geminiApiKeyPreview = AppSettings.maskedGeminiApiKey;

  // Scanner & AI Features State
  bool _offlineScanProcessing = true;
  bool _autoCaptureEdgeDetection = true;
  String _scanResolution = 'High (300 DPI)';

  // Preferences State
  String _selectedLanguage = 'English (US)';
  bool _hapticFeedback = true;

  // Privacy & Data State
  bool _biometricLock = false;
  bool _cloudSync = false;
  String _storageUsage = '14.8 MB';

  void _triggerHaptic() {
    if (_hapticFeedback) {
      HapticFeedback.selectionClick();
    }
  }

  // ─── AI Engine & API Key Dialog ─────────────────────────────────────────────
  void _editAiEngineAndKeys() {
    _triggerHaptic();
    final openRouterController = TextEditingController(text: AppSettings.openRouterApiKey);
    final geminiController = TextEditingController(text: AppSettings.geminiApiKey);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final appColors = theme.extension<AppColors>() ?? AppColors.light;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.psychology_rounded,
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI Detection Engine',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Configure multi-model vision & audit keys',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppSettings.hasApiKey
                            ? appColors.successContainer.withValues(alpha: 0.5)
                            : appColors.infoContainer.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppSettings.hasApiKey
                              ? appColors.success.withValues(alpha: 0.3)
                              : appColors.info.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            AppSettings.hasApiKey ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                            size: 18,
                            color: AppSettings.hasApiKey ? appColors.success : appColors.info,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AppSettings.hasApiKey
                                  ? 'Hybrid Mode Active ($_apiKeyPreview)'
                                  : 'Offline Mode Active (High-Speed Local OCR)',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppSettings.hasApiKey ? appColors.success : appColors.info,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // OpenRouter API Key Input
                    Text(
                      'OpenRouter API Key (Claude / GPT-4o / DeepSeek)',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: openRouterController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'sk-or-v1-...',
                        prefixIcon: const Icon(Icons.key_rounded, size: 18),
                        suffixIcon: openRouterController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  openRouterController.clear();
                                  setSheetState(() {});
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Gemini API Key Input
                    Text(
                      'Custom Gemini Vision API Key ($_geminiApiKeyPreview)',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: geminiController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'AIzaSy...',
                        prefixIcon: const Icon(Icons.auto_awesome_rounded, size: 18),
                        suffixIcon: geminiController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  geminiController.clear();
                                  setSheetState(() {});
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      'Keys are encrypted and stored solely on your local device. The app operates with 100% functionality offline without any API keys.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Action Buttons
                    Row(
                      children: [
                        if (AppSettings.hasApiKey || AppSettings.hasGeminiApiKey)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final navigator = Navigator.of(ctx);
                                await AppSettings.setApiKey('');
                                await AppSettings.setGeminiApiKey('');
                                if (mounted) {
                                  setState(() {
                                    _apiKeyPreview = AppSettings.maskedApiKey;
                                    _geminiApiKeyPreview = AppSettings.maskedGeminiApiKey;
                                  });
                                  navigator.pop();
                                  scaffoldMessenger.showSnackBar(
                                    const SnackBar(content: Text('AI keys cleared. Switched to offline mode.')),
                                  );
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme.colorScheme.error,
                                side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Clear Keys'),
                            ),
                          ),
                        if (AppSettings.hasApiKey || AppSettings.hasGeminiApiKey)
                          const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () async {
                              final navigator = Navigator.of(ctx);
                              await AppSettings.setApiKey(openRouterController.text);
                              await AppSettings.setGeminiApiKey(geminiController.text);
                              if (mounted) {
                                setState(() {
                                  _apiKeyPreview = AppSettings.maskedApiKey;
                                  _geminiApiKeyPreview = AppSettings.maskedGeminiApiKey;
                                });
                                navigator.pop();
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      AppSettings.hasApiKey
                                          ? 'AI engine settings updated successfully!'
                                          : 'Settings saved.',
                                    ),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                            ),
                            child: const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      // Dispose controllers created for this sheet to avoid leaking their
      // internal listeners once the sheet is dismissed.
      openRouterController.dispose();
      geminiController.dispose();
    });
  }

  // ─── Resolution Picker ──────────────────────────────────────────────────────
  void _showResolutionPicker() {
    _triggerHaptic();
    final resolutions = [
      {'title': 'Standard (150 DPI)', 'desc': 'Fastest capture, lower memory footprint'},
      {'title': 'High (300 DPI)', 'desc': 'Recommended for OCR & fine legal clauses'},
      {'title': 'Ultra (600 DPI)', 'desc': 'Maximum clarity for faded thermal receipts & stamps'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Scan Resolution',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Select optical density for document capture',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              ...resolutions.map((res) {
                final isSelected = _scanResolution == res['title'];
                return InkWell(
                  onTap: () {
                    _triggerHaptic();
                    setState(() => _scanResolution = res['title']!);
                    Navigator.pop(ctx);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                res['title']!,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                res['desc']!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ─── Language Picker ────────────────────────────────────────────────────────
  void _showLanguagePicker() {
    _triggerHaptic();
    final languages = [
      {'name': 'English (US)', 'native': 'English'},
      {'name': 'Hindi (हिन्दी)', 'native': 'हिन्दी'},
      {'name': 'Marathi (मराठी)', 'native': 'मराठी'},
      {'name': 'Tamil (தமிழ்)', 'native': 'தமிழ்'},
      {'name': 'Telugu (తెలుగు)', 'native': 'తెలుగు'},
      {'name': 'Bengali (বাংলা)', 'native': 'বাংলা'},
      {'name': 'Gujarati (ગુજરાતી)', 'native': 'ગુજરાતી'},
      {'name': 'Kannada (ಕನ್ನಡ)', 'native': 'ಕನ್ನಡ'},
      {'name': 'Malayalam (മലയാളം)', 'native': 'മലയാളം'},
      {'name': 'Punjabi (ਪੰਜਾਬੀ)', 'native': 'ਪੰਜਾਬੀ'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.65,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'App & Translation Language',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Select primary language for interface and OCR outputs',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: languages.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final lang = languages[index];
                    final isSelected = _selectedLanguage == lang['name'];
                    return InkWell(
                      onTap: () {
                        _triggerHaptic();
                        setState(() => _selectedLanguage = lang['name']!);
                        Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary.withValues(alpha: 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                lang['name']!,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                lang['native']!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Storage Management Sheet ──────────────────────────────────────────────
  void _showStorageManagement() {
    _triggerHaptic();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Storage Management',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage local document caches and extracted OCR text',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      children: [
                        _buildStorageItem(
                          label: 'OCR Cache & Temp Images',
                          size: _storageUsage,
                          icon: Icons.image_outlined,
                        ),
                        const Divider(height: 20),
                        _buildStorageItem(
                          label: 'Persisted Scan Database',
                          size: '2.4 MB',
                          icon: Icons.data_object_rounded,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _triggerHaptic();
                        setState(() {
                          _storageUsage = '0.0 KB';
                        });
                        setSheetState(() {});
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Temporary cache cleared successfully!')),
                        );
                      },
                      icon: const Icon(Icons.delete_sweep_rounded),
                      label: const Text('Clear Temporary Cache'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStorageItem({
    required String label,
    required String size,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
          ),
        ),
        Text(
          size,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // ─── Edit Profile Dialog ────────────────────────────────────────────────────
  void _editProfile() {
    _triggerHaptic();
    final nameCtrl = TextEditingController(text: _userName);
    final emailCtrl = TextEditingController(text: _userEmail);

    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: const Icon(Icons.mail_outline_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _userName = nameCtrl.text.trim().isEmpty ? _userName : nameCtrl.text.trim();
                  _userEmail = emailCtrl.text.trim().isEmpty ? _userEmail : emailCtrl.text.trim();
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile updated successfully')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    ).whenComplete(() {
      nameCtrl.dispose();
      emailCtrl.dispose();
    });
  }

  // ─── Help & Documentation Dialog ────────────────────────────────────────────
  void _showHelpDocumentation() {
    _triggerHaptic();
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.help_outline_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              const Text('Help & Citizen Guides'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHelpGuideRow('🚫 Illegal Service Charges', 'CCPA July 2022 guidelines prohibit mandatory restaurant tips.'),
                _buildHelpGuideRow('🏠 Tenant Rights in India', 'Section 73/74 protection against arbitrary security deposit forfeiture.'),
                _buildHelpGuideRow('💊 Jan Aushadhi Kendras', 'Affordable generic salt equivalents at 50-80% lower cost.'),
                _buildHelpGuideRow('🥗 FSSAI Packaging Safety', 'Mandatory 14-digit FSSAI licensing and HFSS nutrition alerts.'),
                _buildHelpGuideRow('📞 Consumer Helpline', 'Dial toll-free 1915 or file complaints online on e-Daakhil.'),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHelpGuideRow(String title, String desc) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          const SizedBox(height: 2),
          Text(desc, style: theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
        ],
      ),
    );
  }

  // ─── Reset Preferences ──────────────────────────────────────────────────────
  void _showResetPreferencesDialog() {
    _triggerHaptic();
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Reset Preferences?'),
          content: const Text('This will reset your scanner settings, DPI resolutions, and toggles back to default values.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _triggerHaptic();
                setState(() {
                  _offlineScanProcessing = true;
                  _autoCaptureEdgeDetection = true;
                  _scanResolution = 'High (300 DPI)';
                  _selectedLanguage = 'English (US)';
                  _hapticFeedback = true;
                  _biometricLock = false;
                  _cloudSync = false;
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Preferences reset to default')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }

  // ─── Logout Dialog ──────────────────────────────────────────────────────────
  void _showLogoutDialog() {
    _triggerHaptic();
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Log Out'),
          content: const Text('Are you sure you want to log out of your ScanSure account?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logged out successfully (Simulated)')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final containerBg = isDark
        ? const Color(0xFF161619)
        : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF26262B)
        : const Color(0xFFE5E5E7);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.95),
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 20,
        title: Row(
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
                    color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.security_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'ScanSure',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: InkWell(
              onTap: _editProfile,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.surfaceContainerHighest,
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    width: 1.0,
                  ),
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Profile Overview Header Card ───────────────────────────────
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: containerBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                      child: Text(
                        _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _userName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'PRO',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _userEmail,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      onPressed: _editProfile,
                      tooltip: 'Edit Profile',
                    ),
                  ],
                ),
              ),

              // ─── Section 1: Scanner & AI Features ───────────────────────────
              _buildSectionTitle('Scanner & AI Features'),
              _buildSectionCard(
                containerBg: containerBg,
                borderColor: borderColor,
                children: [
                  _buildNavRow(
                    icon: Icons.psychology_outlined,
                    title: 'AI Detection Engine',
                    subtitle: AppSettings.hasApiKey ? 'Hybrid ($_apiKeyPreview)' : 'Offline OCR Mode',
                    badge: AppSettings.hasApiKey ? 'Hybrid' : 'Offline',
                    onTap: _editAiEngineAndKeys,
                  ),
                  _buildDivider(borderColor),
                  _buildToggleRow(
                    icon: Icons.offline_pin_outlined,
                    title: 'Offline Scan Processing',
                    value: _offlineScanProcessing,
                    onChanged: (val) {
                      _triggerHaptic();
                      setState(() => _offlineScanProcessing = val);
                    },
                  ),
                  _buildDivider(borderColor),
                  _buildToggleRow(
                    icon: Icons.crop_free_rounded,
                    title: 'Auto-Capture & Edge Detection',
                    value: _autoCaptureEdgeDetection,
                    onChanged: (val) {
                      _triggerHaptic();
                      setState(() => _autoCaptureEdgeDetection = val);
                    },
                  ),
                  _buildDivider(borderColor),
                  _buildNavRow(
                    icon: Icons.high_quality_outlined,
                    title: 'Scan Resolution',
                    subtitle: _scanResolution,
                    onTap: _showResolutionPicker,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ─── Section 2: Preferences ─────────────────────────────────────
              _buildSectionTitle('Preferences'),
              _buildSectionCard(
                containerBg: containerBg,
                borderColor: borderColor,
                children: [
                  _buildToggleRow(
                    icon: Icons.palette_outlined,
                    title: 'Appearance',
                    subtitle: widget.isLightMode ? 'Light mode active' : 'Dark vibrant mode active',
                    value: widget.isLightMode,
                    onChanged: (val) {
                      _triggerHaptic();
                      widget.onThemeChanged(val);
                    },
                  ),
                  _buildDivider(borderColor),
                  _buildNavRow(
                    icon: Icons.translate_rounded,
                    title: 'Language',
                    subtitle: _selectedLanguage,
                    onTap: _showLanguagePicker,
                  ),
                  _buildDivider(borderColor),
                  _buildToggleRow(
                    icon: Icons.vibration_rounded,
                    title: 'Haptic Feedback',
                    subtitle: 'Tactile response on successful capture',
                    value: _hapticFeedback,
                    onChanged: (val) {
                      setState(() => _hapticFeedback = val);
                      if (val) HapticFeedback.mediumImpact();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ─── Section 3: Privacy & Data ──────────────────────────────────
              _buildSectionTitle('Privacy & Data'),
              _buildSectionCard(
                containerBg: containerBg,
                borderColor: borderColor,
                children: [
                  _buildToggleRow(
                    icon: Icons.fingerprint_rounded,
                    title: 'Biometric & App Lock',
                    subtitle: 'Require fingerprint or passcode',
                    value: _biometricLock,
                    onChanged: (val) {
                      _triggerHaptic();
                      setState(() => _biometricLock = val);
                    },
                  ),
                  _buildDivider(borderColor),
                  _buildToggleRow(
                    icon: Icons.cloud_sync_outlined,
                    title: 'Cloud Sync & Backup',
                    subtitle: 'Encrypted document sync across devices',
                    value: _cloudSync,
                    onChanged: (val) {
                      _triggerHaptic();
                      setState(() => _cloudSync = val);
                    },
                  ),
                  _buildDivider(borderColor),
                  _buildNavRow(
                    icon: Icons.storage_outlined,
                    title: 'Storage Management',
                    subtitle: 'Cache: $_storageUsage • Clear temporary scans',
                    onTap: _showStorageManagement,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ─── Section 4: Support & About ─────────────────────────────────
              _buildSectionTitle('Support & About'),
              _buildSectionCard(
                containerBg: containerBg,
                borderColor: borderColor,
                children: [
                  _buildNavRow(
                    icon: Icons.help_outline_rounded,
                    title: 'Help & Documentation',
                    subtitle: 'Citizen consumer guides & scan tutorials',
                    onTap: _showHelpDocumentation,
                  ),
                  _buildDivider(borderColor),
                  _buildNavRow(
                    icon: Icons.system_update_alt_rounded,
                    title: 'Check for Updates',
                    subtitle: 'ScanSure v2.4.1 (Latest build)',
                    onTap: () {
                      _triggerHaptic();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('ScanSure is running the latest version (v2.4.1)'),
                        ),
                      );
                    },
                  ),
                  _buildDivider(borderColor),
                  _buildNavRow(
                    icon: Icons.support_agent_rounded,
                    title: 'Contact Support',
                    subtitle: 'Helpline: 1915 • support@scansure.ai',
                    onTap: () {
                      _triggerHaptic();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('National Consumer Helpline: Dial 1915 or email support@scansure.ai'),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ─── Footer Action Buttons ──────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: _showResetPreferencesDialog,
                  style: TextButton.styleFrom(
                    backgroundColor: theme.colorScheme.surfaceContainerLow,
                    foregroundColor: theme.colorScheme.onSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: borderColor),
                    ),
                  ),
                  child: const Text(
                    'Reset Preferences',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _showLogoutDialog,
                  icon: Icon(Icons.logout_rounded, color: theme.colorScheme.error, size: 18),
                  label: Text(
                    'Log Out',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.3)),
                    backgroundColor: theme.colorScheme.errorContainer.withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Helper Widgets ─────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required Color containerBg,
    required Color borderColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildDivider(Color borderColor) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 52,
      endIndent: 12,
      color: borderColor.withValues(alpha: 0.6),
    );
  }

  Widget _buildNavRow({
    required IconData icon,
    required String title,
    String? subtitle,
    String? badge,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
          child: Row(
            children: [
              Icon(
                icon,
                color: const Color(0xFF6E6E73),
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6E6E73),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (badge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF6E6E73),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFF6E6E73),
            size: 22,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6E6E73),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }
}
