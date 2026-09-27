import 'package:flutter/material.dart';
import '../../models/government_scheme_model.dart';
import '../../services/scheme_service.dart';
import '../../services/scheme_database.dart';
import '../../services/scheme_matcher.dart';

class SchemeAnalyticsScreen extends StatefulWidget {
  final CitizenProfile profile;
  const SchemeAnalyticsScreen({Key? key, required this.profile}) : super(key: key);

  @override
  State<SchemeAnalyticsScreen> createState() => _SchemeAnalyticsScreenState();
}

class _SchemeAnalyticsScreenState extends State<SchemeAnalyticsScreen> {
  final _service = SchemeService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final totalEligible = _service.totalEligibleSchemes(widget.profile);
    final strongMatches = _service.totalStrongMatches(widget.profile);
    final totalSchemes = SchemeDatabase.schemes.length;
    final centralCount = SchemeDatabase.schemes.where((s) => s.level == SchemeLevel.central).length;
    final stateCount = SchemeDatabase.schemes.where((s) => s.level == SchemeLevel.state).length;
    final categoryStats = _service.eligibilityByCategory(widget.profile);

    return Scaffold(
      appBar: AppBar(title: const Text('Scheme Analytics')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overview Cards
            Row(
              children: [
                _buildStatCard('Total Schemes', '$totalSchemes', Icons.account_balance_rounded, const Color(0xFF2563EB), isDark),
                const SizedBox(width: 12),
                _buildStatCard('Eligible', '$totalEligible', Icons.check_circle_rounded, const Color(0xFF16A34A), isDark),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatCard('Strong Match', '$strongMatches', Icons.auto_awesome, const Color(0xFF7C3AED), isDark),
                const SizedBox(width: 12),
                _buildStatCard('Saved', '${_service.bookmarks.length}', Icons.bookmark_rounded, const Color(0xFFF59E0B), isDark),
              ],
            ),
            const SizedBox(height: 24),

            // Eligibility Progress
            Text('Your Eligibility Score',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 12),
            _buildEligibilityBar(totalEligible, totalSchemes, isDark),
            const SizedBox(height: 24),

            // Central vs State
            Text('Central vs State Schemes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildLevelCard('Central', centralCount, const Color(0xFF2563EB), isDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildLevelCard('State', stateCount, const Color(0xFF7C3AED), isDark),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Category Breakdown
            Text('Schemes You Qualify For',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 12),
            if (categoryStats.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text('Set up your profile to see personalized analytics',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              )
            else
              ...categoryStats.entries.map((e) => _buildCategoryBar(e.key, e.value, totalSchemes, isDark)),
            const SizedBox(height: 24),

            // State Coverage
            Text('State Scheme Coverage',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 12),
            _buildStateCoverage(widget.profile.state, isDark),
            const SizedBox(height: 24),

            // Documents Needed
            Text('Documents You May Need',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 12),
            _buildDocumentChecklist(widget.profile),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(value,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildEligibilityBar(int eligible, int total, bool isDark) {
    final percent = total > 0 ? eligible / total : 0.0;
    final color = percent > 0.5 ? const Color(0xFF16A34A) : percent > 0.25 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$eligible of $total schemes',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text('${(percent * 100).round()}%',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelCard(String label, int count, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(count.toString(),
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildCategoryBar(SchemeCategory category, int count, int total, bool isDark) {
    final percent = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 32, child: Text(category.emoji, style: const TextStyle(fontSize: 16))),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(category.label,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    Text('$count schemes',
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF2563EB)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateCoverage(String userState, bool isDark) {
    final stateCounts = _service.stateSchemeCount();
    final sorted = stateCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sorted.take(5).toList();
    final userStateCount = stateCounts[userState] ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (userState.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF2563EB)),
                const SizedBox(width: 6),
                Text('$userState: $userStateCount state schemes',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
              ],
            ),
            const Divider(height: 20),
          ],
          ...top5.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12))),
                Text('${e.value} schemes',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildDocumentChecklist(CitizenProfile profile) {
    final docs = <String, bool>{};
    final schemes = SchemeDatabase.schemes.where((s) =>
      SchemeMatcher.scoreScheme(s, profile).score > 0.2
    ).toList();

    for (final s in schemes) {
      for (final doc in s.documentsRequired) {
        docs[doc] = false;
      }
    }

    final sortedDocs = docs.keys.toList()..sort();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('You may need ${sortedDocs.length} different documents',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ...sortedDocs.take(15).map((doc) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(Icons.description_rounded, size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                const SizedBox(width: 8),
                Expanded(child: Text(doc, style: const TextStyle(fontSize: 12))),
              ],
            ),
          )),
          if (sortedDocs.length > 15)
            Text('+ ${sortedDocs.length - 15} more documents',
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6))),
        ],
      ),
    );
  }
}
