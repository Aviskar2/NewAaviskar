import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/government_scheme_model.dart';
import '../../services/scheme_service.dart';
import '../../services/scheme_database.dart';
import 'scheme_detail_screen.dart';

class SchemeTrackerScreen extends StatefulWidget {
  const SchemeTrackerScreen({Key? key}) : super(key: key);

  @override
  State<SchemeTrackerScreen> createState() => _SchemeTrackerScreenState();
}

class _SchemeTrackerScreenState extends State<SchemeTrackerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _service = SchemeService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schemes'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Saved (${_service.bookmarks.length})'),
            Tab(text: 'Applied (${_service.appliedCount})'),
            Tab(text: 'In Progress (${_service.pendingCount})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBookmarksTab(),
          _buildAppliedTab(),
          _buildInProgressTab(),
        ],
      ),
    );
  }

  Widget _buildBookmarksTab() {
    final schemes = _service.bookmarkedSchemes;
    if (schemes.isEmpty) {
      return _buildEmpty('No saved schemes', 'Bookmark schemes to view them here later');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: schemes.length,
      itemBuilder: (ctx, i) => _buildSchemeTile(schemes[i], showBookmark: true),
    );
  }

  Widget _buildAppliedTab() {
    final records = _service.applications.where((a) => a.status == ApplicationStatus.applied).toList();
    if (records.isEmpty) {
      return _buildEmpty('No applications yet', 'Mark schemes as applied to track them');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: records.length,
      itemBuilder: (ctx, i) => _buildApplicationTile(records[i]),
    );
  }

  Widget _buildInProgressTab() {
    final records = _service.applications.where((a) =>
      a.status == ApplicationStatus.inProgress || a.status == ApplicationStatus.notApplied
    ).toList();
    if (records.isEmpty) {
      return _buildEmpty('Nothing in progress', 'Start applying to schemes to track progress');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: records.length,
      itemBuilder: (ctx, i) => _buildApplicationTile(records[i]),
    );
  }

  Widget _buildEmpty(String title, String subtitle) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_border_rounded,
              size: 48, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(title,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6))),
        ],
      ),
    );
  }

  Widget _buildSchemeTile(GovernmentScheme scheme, {bool showBookmark = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final status = _service.getApplicationStatus(scheme.id);

    return Dismissible(
      key: Key(scheme.id),
      onDismissed: (_) async {
        if (showBookmark) await _service.toggleBookmark(scheme.id);
        setState(() {});
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => SchemeDetailScreen(scheme: scheme, profile: const CitizenProfile()),
          ));
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB),
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
                child: Text(scheme.category.emoji, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(scheme.shortName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(scheme.ministry,
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              _buildStatusChip(status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApplicationTile(ApplicationRecord record) {
    final scheme = SchemeDatabase.schemes.firstWhere(
      (s) => s.id == record.schemeId,
      orElse: () => SchemeDatabase.schemes.first,
    );
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _showStatusDialog(record),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(scheme.category.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(scheme.shortName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (record.appliedAt != null)
                        Text('Applied: ${_formatDate(record.appliedAt!)}',
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6))),
                    ],
                  ),
                ),
                _buildStatusChip(record.status),
              ],
            ),
            if (record.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(record.notes,
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            if (record.deadline != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 14, color: _deadlineColor(record.deadline!)),
                  const SizedBox(width: 4),
                  Text('Deadline: ${_formatDate(record.deadline!)}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _deadlineColor(record.deadline!))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(ApplicationStatus status) {
    Color color;
    String label;
    switch (status) {
      case ApplicationStatus.notApplied:
        color = Colors.grey;
        label = 'Not Applied';
        break;
      case ApplicationStatus.inProgress:
        color = const Color(0xFFF59E0B);
        label = 'In Progress';
        break;
      case ApplicationStatus.applied:
        color = const Color(0xFF2563EB);
        label = 'Applied';
        break;
      case ApplicationStatus.received:
        color = const Color(0xFF16A34A);
        label = 'Received';
        break;
      case ApplicationStatus.rejected:
        color = const Color(0xFFEF4444);
        label = 'Rejected';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

  void _showStatusDialog(ApplicationRecord record) {
    final statuses = ApplicationStatus.values;
    final labels = ['Not Applied', 'In Progress', 'Applied', 'Received', 'Rejected'];

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Update Application Status',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            ...List.generate(statuses.length, (i) => ListTile(
              leading: _buildStatusChip(statuses[i]),
              title: Text(labels[i]),
              onTap: () async {
                await _service.setApplicationStatus(record.schemeId, statuses[i]);
                Navigator.pop(ctx);
                setState(() {});
              },
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Color _deadlineColor(DateTime deadline) {
    final days = deadline.difference(DateTime.now()).inDays;
    if (days < 0) return const Color(0xFFEF4444);
    if (days < 7) return const Color(0xFFF59E0B);
    return const Color(0xFF16A34A);
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
