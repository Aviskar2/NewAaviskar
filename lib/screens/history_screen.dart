import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/scan_history_service.dart';
import 'scanner/scan_history_screen.dart';

class HistoryScreen extends StatefulWidget {
  final List<Map<String, dynamic>> historyItems;
  final ValueChanged<Map<String, dynamic>> onLoadChat;
  final ScanHistoryService? scanHistoryService;

  const HistoryScreen({
    Key? key,
    required this.historyItems,
    required this.onLoadChat,
    this.scanHistoryService,
  }) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Filter items based on search query and category selector
    final filteredItems = widget.historyItems.where((item) {
      final matchesSearch = item['title'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item['description'].toLowerCase().contains(_searchQuery.toLowerCase());
      
      final matchesCategory = _selectedCategory == 'All' || item['category'] == _selectedCategory;
      
      return matchesSearch && matchesCategory;
    }).toList();

    // Group filtered items by dateGroup
    final Map<String, List<Map<String, dynamic>>> groupedItems = {
      'TODAY': [],
      'YESTERDAY': [],
      'LAST WEEK': [],
    };

    for (var item in filteredItems) {
      final group = item['dateGroup'] ?? 'TODAY';
      if (groupedItems.containsKey(group)) {
        groupedItems[group]!.add(item);
      } else {
        groupedItems[group] = [item];
      }
    }

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
          if (widget.scanHistoryService != null)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded),
              tooltip: 'Scan History',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ScanHistoryScreen(
                      historyService: widget.scanHistoryService!,
                    ),
                  ),
                );
              },
            ),
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
              // Header
              Text(
                'History',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Review your past sessions, scans, and insights.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),

              // Search & Filter Row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(24.0),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                          width: 1.0,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val;
                                });
                              },
                              decoration: InputDecoration(
                                hintText: 'Search...',
                                hintStyle: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                ),
                                border: InputBorder.none,
                              ),
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _showFilterDialog,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                          width: 1.0,
                        ),
                      ),
                      child: Icon(
                        Icons.filter_list,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // History list
              Expanded(
                child: filteredItems.isEmpty
                    ? const Center(
                        child: Text(
                          'No history sessions found.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView(
                        children: [
                          if (groupedItems['TODAY']!.isNotEmpty) ...[
                            _buildSectionHeader('TODAY'),
                            ...groupedItems['TODAY']!.map((item) => _buildHistoryCard(item)),
                          ],
                          if (groupedItems['YESTERDAY']!.isNotEmpty) ...[
                            _buildSectionHeader('YESTERDAY'),
                            ...groupedItems['YESTERDAY']!.map((item) => _buildHistoryCard(item)),
                          ],
                          if (groupedItems['LAST WEEK']!.isNotEmpty) ...[
                            _buildSectionHeader('LAST WEEK'),
                            ...groupedItems['LAST WEEK']!.map((item) => _buildHistoryCard(item)),
                          ],
                          const SizedBox(height: 24),
                          Align(
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: 200,
                              child: OutlinedButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Simulated loading older history...')),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: theme.colorScheme.primary),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: Text(
                                  'Load More History',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
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

  Widget _buildSectionHeader(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;
    final List<dynamic> tags = item['tags'] ?? [];
    final Color accentColor = item['color'] ?? theme.colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
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
        child: InkWell(
          onTap: () => widget.onLoadChat(item),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stripe indicator
              Container(
                height: 3,
                width: double.infinity,
                color: accentColor,
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item['title'],
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          item['time'],
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item['description'],
                      style: theme.textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: tags.map<Widget>((tag) {
                        return Container(
                          margin: const EdgeInsets.only(right: 8.0),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter History',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  _buildFilterChoice('All'),
                  _buildFilterChoice('Finance'),
                  _buildFilterChoice('OCR'),
                  _buildFilterChoice('Translate'),
                  _buildFilterChoice('Code'),
                  _buildFilterChoice('Ideas'),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Apply Filter', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChoice(String category) {
    final isSelected = _selectedCategory == category;
    final theme = Theme.of(context);

    return ChoiceChip(
      label: Text(category),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedCategory = category;
        });
        (context as Element).markNeedsBuild(); // Force redraw sheet
      },
      selectedColor: theme.colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
