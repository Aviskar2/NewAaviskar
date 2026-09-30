import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/government_scheme_model.dart';
import '../../services/scheme_service.dart';
import 'scheme_detail_screen.dart';

class SchemeTrackerScreen extends StatefulWidget {
  const SchemeTrackerScreen({super.key});

  @override
  State<SchemeTrackerScreen> createState() => _SchemeTrackerScreenState();
}

class _SchemeTrackerScreenState extends State<SchemeTrackerScreen> {
  final _service = SchemeService();

  @override
  void initState() {
    super.initState();
    _service.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final schemes = _service.bookmarkedSchemes;
    return Scaffold(
      appBar: AppBar(
        title: Text('Saved schemes (${schemes.length})'),
      ),
      body: schemes.isEmpty
          ? _buildEmpty()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: schemes.length,
              itemBuilder: (context, index) => _buildSchemeTile(schemes[index]),
            ),
    );
  }

  Widget _buildEmpty() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border_rounded,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35)),
            const SizedBox(height: 12),
            Text('No saved schemes yet',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text('Bookmark a scheme to keep it here for later.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }

  Widget _buildSchemeTile(GovernmentScheme scheme) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Dismissible(
      key: Key(scheme.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) async {
        await _service.toggleBookmark(scheme.id);
        if (mounted) setState(() {});
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => SchemeDetailScreen(
              scheme: scheme,
              profile: const CitizenProfile(),
            ),
          )).then((_) {
            if (mounted) setState(() {});
          });
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(scheme.category.emoji,
                    style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(scheme.shortName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(scheme.plainLanguageSummary,
                        style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
