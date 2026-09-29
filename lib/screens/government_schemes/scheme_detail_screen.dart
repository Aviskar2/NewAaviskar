import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/government_scheme_model.dart';
import '../../services/scheme_matcher.dart';
import '../../services/scheme_service.dart';
import '../../utils/url_launcher_util.dart';

class SchemeDetailScreen extends StatefulWidget {
  final GovernmentScheme scheme;
  final CitizenProfile profile;

  const SchemeDetailScreen({
    super.key,
    required this.scheme,
    required this.profile,
  });

  @override
  State<SchemeDetailScreen> createState() => _SchemeDetailScreenState();
}

class _SchemeDetailScreenState extends State<SchemeDetailScreen> {
  final _service = SchemeService();

  @override
  void initState() {
    super.initState();
    _service.load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = widget.scheme;
    final profile = widget.profile;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF0A1628), const Color(0xFF0D1F3C)]
                : [const Color(0xFFEEF4FF), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        scheme.shortName,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                    ),
                    // Bookmark
                    IconButton(
                      icon: Icon(
                        _service.isBookmarked(scheme.id)
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: _service.isBookmarked(scheme.id)
                            ? const Color(0xFFF59E0B)
                            : null,
                      ),
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        await _service.toggleBookmark(scheme.id);
                        setState(() {});
                      },
                    ),
                    // Compare
                    IconButton(
                      icon: Icon(
                        _service.isComparing(scheme.id)
                            ? Icons.compare_arrows_rounded
                            : Icons.compare_arrows_outlined,
                        color: _service.isComparing(scheme.id)
                            ? const Color(0xFF7C3AED)
                            : null,
                      ),
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        await _service.toggleCompare(scheme.id);
                        setState(() {});
                      },
                    ),
                    // Share
                    IconButton(
                      icon: const Icon(Icons.share_rounded),
                      onPressed: () => _shareScheme(scheme),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        scheme.level == SchemeLevel.central ? 'Central' : 'State',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2563EB)),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF2563EB).withValues(alpha: 0.08),
                              const Color(0xFF7C3AED).withValues(alpha: 0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${scheme.category.emoji} ${scheme.name}',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            Text(scheme.ministry,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Plain Language Summary
                      _buildSection(
                        context,
                        icon: Icons.lightbulb_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        title: 'What This Means For You',
                        child: Text(
                          scheme.plainLanguageSummary,
                          style: const TextStyle(
                              fontSize: 14, height: 1.6, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Benefits
                      if (scheme.benefits.isNotEmpty)
                        _buildSection(
                          context,
                          icon: Icons.check_circle_rounded,
                          iconColor: const Color(0xFF16A34A),
                          title: 'Benefits',
                          child: Column(
                            children: scheme.benefits.map((b) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.check_rounded,
                                      color: Color(0xFF16A34A), size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(b,
                                        style: const TextStyle(fontSize: 13, height: 1.4)),
                                  ),
                                ],
                              ),
                            )).toList(),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Eligibility
                      _buildSection(
                        context,
                        icon: Icons.person_search_rounded,
                        iconColor: const Color(0xFF2563EB),
                        title: 'Who Can Apply',
                        child: Text(
                          scheme.eligibility.description ?? 'Open to all eligible citizens.',
                          style: const TextStyle(fontSize: 13, height: 1.5),
                        ),
                      ),

                      // Personalized Eligibility Check
                      if (profile.hasProfile) ...[
                        const SizedBox(height: 12),
                        _buildPersonalizedCheck(context),
                      ],
                      const SizedBox(height: 16),

                      // Documents Required
                      if (scheme.documentsRequired.isNotEmpty)
                        _buildSection(
                          context,
                          icon: Icons.description_rounded,
                          iconColor: const Color(0xFF7C3AED),
                          title: 'Documents Required',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: scheme.documentsRequired.map((doc) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: const Color(0xFF7C3AED).withValues(alpha: 0.2)),
                              ),
                              child: Text(doc,
                                  style: const TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w600)),
                            )).toList(),
                          ),
                        ),
                      const SizedBox(height: 24),

                      // Apply Options Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showApplyOptionsSheet(context, scheme),
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: const Text('Apply Now (Official Channels)',
                              style:
                                  TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Direct myScheme Unified Portal Button (Always 100% active)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await UrlLauncherUtil.openUrl(context, scheme.mySchemeUrl);
                          },
                          icon: const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF16A34A)),
                          label: const Text('Open on myScheme.gov.in (National Portal)',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Color(0xFF16A34A))),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF16A34A), width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),

                      if (scheme.helpline.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final uri = Uri(scheme: 'tel', path: scheme.helpline.replaceAll(RegExp(r'[^0-9]'), ''));
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            },
                            icon: const Icon(Icons.phone_rounded, size: 18),
                            label: Text('Helpline: ${scheme.helpline}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF16A34A),
                              side: const BorderSide(
                                  color: Color(0xFF16A34A), width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalizedCheck(BuildContext context) {
    final result = SchemeMatcher.scoreScheme(widget.scheme, widget.profile);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isEligible = result.score > 0;
    final color = isEligible ? const Color(0xFF16A34A) : const Color(0xFFEF4444);
    final bgColor = color.withValues(alpha: 0.08);
    final borderColor = color.withValues(alpha: 0.25);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isEligible ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isEligible
                    ? 'You may be eligible (${result.matchPercent.round()}% match)'
                    : 'You may not be eligible',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...result.reasons.map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  r.startsWith('Minimum age') || r.startsWith('Maximum age') ||
                  r.startsWith('Available for') || r.startsWith('Restricted') ||
                  r.startsWith('Requires') || r.startsWith('Available only')
                      ? Icons.info_outline_rounded
                      : Icons.check_rounded,
                  size: 14,
                  color: color.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    r,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  void _shareScheme(GovernmentScheme scheme) {
    final text = '''
${scheme.name}
${scheme.ministry}

${scheme.plainLanguageSummary}

Benefits:
${scheme.benefits.map((b) => '  • $b').join('\n')}

Documents Required:
${scheme.documentsRequired.join(', ')}

Apply: ${scheme.applyUrl}
Helpline: ${scheme.helpline}

Shared from ScanSure - Government Schemes Finder
''';

    // Copy to clipboard as share alternative
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scheme details copied to clipboard!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showApplyOptionsSheet(BuildContext context, GovernmentScheme scheme) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('🇮🇳', style: TextStyle(fontSize: 26)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Official Application Channels',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            scheme.shortName.isNotEmpty ? scheme.shortName : scheme.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.textTheme.bodySmall?.color,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Option 1: Ministry Official Portal
                _buildApplyOptionTile(
                  context: context,
                  isDark: isDark,
                  icon: Icons.account_balance_rounded,
                  iconColor: const Color(0xFF2563EB),
                  title: 'Ministry Official Portal',
                  subtitle: scheme.effectiveApplyUrl,
                  badge: 'Direct',
                  badgeColor: const Color(0xFF2563EB),
                  onTap: () {
                    Navigator.pop(ctx);
                    UrlLauncherUtil.openUrl(context, scheme.effectiveApplyUrl);
                  },
                ),
                const SizedBox(height: 10),
                // Option 2: National myScheme Central Portal
                _buildApplyOptionTile(
                  context: context,
                  isDark: isDark,
                  icon: Icons.verified_rounded,
                  iconColor: const Color(0xFF16A34A),
                  title: 'myScheme.gov.in (National Portal)',
                  subtitle: 'Government of India unified citizen portal — 100% active',
                  badge: 'Recommended',
                  badgeColor: const Color(0xFF16A34A),
                  onTap: () {
                    Navigator.pop(ctx);
                    UrlLauncherUtil.openUrl(context, scheme.mySchemeUrl);
                  },
                ),
                const SizedBox(height: 10),
                // Option 3: Search Verified Government Mirror
                _buildApplyOptionTile(
                  context: context,
                  isDark: isDark,
                  icon: Icons.travel_explore_rounded,
                  iconColor: const Color(0xFF7C3AED),
                  title: 'Find Mirrors on India.gov.in',
                  subtitle: 'Search official state & national .gov.in portals',
                  badge: 'Gov Search',
                  badgeColor: const Color(0xFF7C3AED),
                  onTap: () {
                    Navigator.pop(ctx);
                    final query = '${scheme.name} official apply portal site:gov.in';
                    UrlLauncherUtil.searchWeb(context, query);
                  },
                ),
                const SizedBox(height: 10),
                // Option 4: Copy Link
                _buildApplyOptionTile(
                  context: context,
                  isDark: isDark,
                  icon: Icons.copy_rounded,
                  iconColor: Colors.grey,
                  title: 'Copy Portal URL',
                  subtitle: 'Copy official address to open on desktop or laptop',
                  badge: 'Copy',
                  badgeColor: Colors.grey,
                  onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: scheme.effectiveApplyUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Official application link copied to clipboard!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildApplyOptionTile({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: isDark ? const Color(0xFF1E0C2B) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF381552) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: badgeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}
