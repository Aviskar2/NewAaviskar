import 'package:flutter/material.dart';
import '../config/app_settings.dart';
import '../theme/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  final bool isLightMode;
  final ValueChanged<bool> onThemeChanged;

  const SettingsScreen({
    Key? key,
    required this.isLightMode,
    required this.onThemeChanged,
  }) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _userName = 'John Doe';
  String _userEmail = 'user@example.com';
  String _apiKeyPreview = AppSettings.maskedApiKey;

  void _editApiKey() {
    final controller = TextEditingController(text: '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('AI Enhancement Key'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppSettings.hasApiKey
                      ? 'Current key: $_apiKeyPreview'
                      : 'No key configured. AI features run in offline mode.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'OpenRouter API key',
                    hintText: 'sk-or-v1-...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Optional — unlocks AI vision bill audit and AI legal '
                  'review. Get a free key at openrouter.ai. The app works '
                  'fully offline without it. Stored only on this device.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            if (AppSettings.hasApiKey)
              TextButton(
                onPressed: () async {
                  await AppSettings.setApiKey('');
                  setState(() => _apiKeyPreview = AppSettings.maskedApiKey);
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Remove'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await AppSettings.setApiKey(controller.text);
                setState(() => _apiKeyPreview = AppSettings.maskedApiKey);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppSettings.hasApiKey
                            ? 'AI enhancement enabled'
                            : 'AI key cleared',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _editProfile() {
    final controller = TextEditingController(text: _userName);
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('Edit Profile'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _userName = controller.text;
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _editEmail() {
    final controller = TextEditingController(text: _userEmail);
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('Edit Email'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Email Address'),
            keyboardType: TextInputType.emailAddress,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _userEmail = controller.text;
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Log Out'),
          content: const Text('Are you sure you want to log out of Aura AI?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logged out successfully (Simulated)')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Log Out', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.menu, color: theme.colorScheme.primary),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Drawer menu clicked (mock)')),
            );
          },
        ),
        title: Text(
          'Aura AI',
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(Icons.person, color: theme.colorScheme.primary, size: 20),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Settings',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage your account, preferences, and security.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),

              // Account Card (Blue Top Border)
              _buildSectionCard(
                title: 'Account',
                stripeColor: const Color(0xFF2563EB),
                children: [
                  _buildSettingRow(
                    icon: Icons.person_outline,
                    iconBgColor: Colors.blue.shade50,
                    iconColor: Colors.blue.shade600,
                    title: 'Profile',
                    subtitle: _userName,
                    onTap: _editProfile,
                  ),
                  _buildSettingRow(
                    icon: Icons.mail_outline,
                    iconBgColor: Colors.blue.shade50,
                    iconColor: Colors.blue.shade600,
                    title: 'Email Address',
                    subtitle: _userEmail,
                    onTap: _editEmail,
                  ),
                  _buildSettingRow(
                    icon: Icons.card_membership,
                    iconBgColor: Colors.orange.shade50,
                    iconColor: Colors.orange.shade600,
                    title: 'Subscription',
                    subtitle: 'Pro Plan - Active',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Subscription info (mock)')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Preferences Card (Purple Top Border)
              _buildSectionCard(
                title: 'Preferences',
                stripeColor: const Color(0xFF9D00FF),
                children: [
                  // Appearance Row (Custom toggle)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.brightness_3,
                            color: Colors.purple.shade600,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Appearance',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.isLightMode ? 'Light mode active' : 'Vibrant theme active',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: widget.isLightMode,
                          onChanged: (bool value) {
                            widget.onThemeChanged(value);
                          },
                          activeColor: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.black12),
                  _buildSettingRow(
                    icon: Icons.language,
                    iconBgColor: Colors.purple.shade50,
                    iconColor: Colors.purple.shade600,
                    title: 'Language',
                    subtitle: 'English (US)',
                    onTap: () {},
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // AI Features Card (Teal Top Border)
              _buildSectionCard(
                title: 'AI Features',
                stripeColor: const Color(0xFF009688),
                children: [
                  _buildSettingRow(
                    icon: Icons.auto_awesome,
                    iconBgColor: Colors.teal.shade50,
                    iconColor: Colors.teal.shade600,
                    title: 'AI Enhancement',
                    subtitle:
                        AppSettings.hasApiKey ? _apiKeyPreview : 'Offline mode',
                    onTap: _editApiKey,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Privacy & Security (Blue Top Border)
              _buildSectionCard(
                title: 'Privacy & Security',
                stripeColor: const Color(0xFF2563EB),
                children: [
                  _buildSettingRow(
                    icon: Icons.lock_outline,
                    iconBgColor: Colors.blue.shade50,
                    iconColor: Colors.blue.shade600,
                    title: 'Password & Authentication',
                    onTap: () {},
                  ),
                  _buildSettingRow(
                    icon: Icons.shield_outlined,
                    iconBgColor: Colors.blue.shade50,
                    iconColor: Colors.blue.shade600,
                    title: 'Data Privacy',
                    onTap: () {},
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Support Card (Green Top Border)
              _buildSectionCard(
                title: 'Support',
                stripeColor: Colors.green,
                children: [
                  _buildSettingRow(
                    icon: Icons.help_center_outlined,
                    iconBgColor: Colors.green.shade50,
                    iconColor: Colors.green.shade600,
                    title: 'Help Center',
                    onTap: () {},
                  ),
                  _buildSettingRow(
                    icon: Icons.contact_support_outlined,
                    iconBgColor: Colors.green.shade50,
                    iconColor: Colors.green.shade600,
                    title: 'Contact Support',
                    onTap: () {},
                  ),
                  _buildSettingRow(
                    icon: Icons.info_outline,
                    iconBgColor: Colors.green.shade50,
                    iconColor: Colors.green.shade600,
                    title: 'About Aura AI',
                    subtitle: 'Version 2.4.1',
                    onTap: () {},
                  ),
                  const SizedBox(height: 16),

                  // Log Out Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _showLogoutDialog,
                      icon: Icon(Icons.logout, color: theme.colorScheme.error),
                      label: Text(
                        'Log Out',
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5), width: 1.0),
                        backgroundColor: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Color stripeColor,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;

    return Container(
      decoration: BoxDecoration(
        color: appColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appColors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top border stripe
            Container(
              height: 3,
              width: double.infinity,
              color: stripeColor,
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...children,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: appColors.surfaceSubtle,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: theme.dividerTheme.color),
      ],
    );
  }
}
