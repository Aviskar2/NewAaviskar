import 'package:flutter/material.dart';

class UpdatesScreen extends StatefulWidget {
  final VoidCallback onTryOcr;

  const UpdatesScreen({
    Key? key,
    required this.onTryOcr,
  }) : super(key: key);

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  bool _allRead = false;

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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Updates',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "What's new in Aura AI",
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _allRead = true;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('All updates marked as read')),
                      );
                    },
                    icon: Icon(
                      Icons.done_all,
                      color: theme.colorScheme.primary,
                      size: 16,
                    ),
                    label: Text(
                      'Mark all read',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Updates List
              Expanded(
                child: ListView(
                  children: [
                    // Card 1
                    _buildUpdateCard(
                      title: 'Real-time OCR Vision',
                      tag: 'NEW FEATURE',
                      description:
                          'Aura can now instantly read and process text from your live camera feed. Point, scan, and ask questions about any document in real-time.',
                      icon: Icons.qr_code_scanner,
                      badgeColor: const Color(0xFF2563EB),
                      stripeColor: const Color(0xFF2563EB),
                      isNew: !_allRead,
                      actionButton: Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: ElevatedButton(
                            onPressed: widget.onTryOcr,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Try it now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Card 2
                    _buildUpdateCard(
                      title: 'Voice Commands',
                      tag: 'PRO TIP',
                      description:
                          'Hold the chat button to activate seamless voice dictation. Aura listens perfectly even in noisy environments.',
                      icon: Icons.mic_none,
                      badgeColor: const Color(0xFF9D00FF),
                      stripeColor: const Color(0xFF9D00FF),
                      isNew: !_allRead,
                    ),

                    // Card 3
                    _buildUpdateCard(
                      title: 'Performance Boost',
                      tag: 'UPDATE v2.4',
                      description:
                          'Response times have been reduced by 40% across all heavy logic tasks. Experience the speed.',
                      icon: Icons.speed,
                      badgeColor: const Color(0xFFFF6E84),
                      stripeColor: const Color(0xFFFF6E84),
                      isNew: false, // pre-read
                    ),

                    // Card 4
                    _buildUpdateCard(
                      title: 'Vibrant Themes Available',
                      tag: 'CUSTOMIZATION',
                      description:
                          'Personalize your workspace with the new energetic color palettes. Navigate to Settings > Appearance to switch things up.',
                      icon: Icons.palette_outlined,
                      badgeColor: const Color(0xFF006686),
                      stripeColor: const Color(0xFF006686),
                      isNew: false, // pre-read
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateCard({
    required String title,
    required String tag,
    required String description,
    required IconData icon,
    required Color badgeColor,
    required Color stripeColor,
    required bool isNew,
    Widget? actionButton,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF22062C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF32113D) : const Color(0xFFE5EEFF),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: badgeColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row with Badge and Unread dot
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: badgeColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  color: badgeColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            if (isNew)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (actionButton != null) actionButton,
                      ],
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
}
