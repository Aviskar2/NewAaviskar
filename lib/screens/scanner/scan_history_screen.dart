import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/scan_result_model.dart';
import '../../services/scan_history_service.dart';
import 'ocr_result_screen.dart';
import 'translation_screen.dart';
import '../../widgets/scan_result_dialog.dart';

/// Dedicated scan history screen showing all persisted OCR, QR, barcode, and
/// translation results with filter tabs, swipe-to-delete, and detail navigation.
class ScanHistoryScreen extends StatefulWidget {
  final ScanHistoryService historyService;

  const ScanHistoryScreen({Key? key, required this.historyService})
      : super(key: key);

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _loading = true;

  static const _tabs = ['All', 'OCR', 'QR Code', 'Barcode', 'Translation'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    await widget.historyService.load();
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<ScanHistoryItem> _itemsForTab(int index) {
    final items = widget.historyService.items;
    switch (index) {
      case 1:
        return items.where((i) => i.type == ScanType.ocr).toList();
      case 2:
        return items.where((i) => i.type == ScanType.qrCode).toList();
      case 3:
        return items.where((i) => i.type == ScanType.barcode).toList();
      case 4:
        return items.where((i) => i.type == ScanType.translation).toList();
      default:
        return items;
    }
  }

  Future<void> _deleteItem(ScanHistoryItem item) async {
    await widget.historyService.delete(item.id);
    if (mounted) setState(() {});
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All History?'),
        content: const Text(
            'All scan history will be permanently deleted. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.historyService.clearAll();
      if (mounted) setState(() {});
    }
  }

  void _openDetail(ScanHistoryItem item) {
    switch (item.type) {
      case ScanType.ocr:
        if (item.ocrText != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OcrResultScreen(
                result: OcrResult(
                  fullText: item.ocrText!,
                  blocks: [
                    OcrBlock(
                        text: item.ocrText!,
                        lines: item.ocrText!.split('\n'))
                  ],
                  imagePath: item.imagePath ?? '',
                  timestamp: item.timestamp,
                ),
                historyService: widget.historyService,
              ),
            ),
          );
        }
        break;
      case ScanType.translation:
        if (item.ocrText != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TranslationScreen(
                initialText: item.ocrText!,
                historyService: widget.historyService,
              ),
            ),
          );
        }
        break;
      case ScanType.qrCode:
      case ScanType.barcode:
        // Show a simple detail sheet for barcode results
        if (item.barcodeValue != null) {
          _showBarcodeDetail(item);
        }
        break;
    }
  }

  void _showBarcodeDetail(ScanHistoryItem item) {
    final barcodeVal = item.barcodeValue ?? '';
    final dummyBarcode = BarcodeResult(
      rawValue: barcodeVal,
      format: item.barcodeFormat ?? (item.type == ScanType.qrCode ? 'QR Code' : 'Barcode'),
      displayType: item.title,
      timestamp: item.timestamp,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScanResultDialog(
        result: dummyBarcode,
        onSaveToHistory: () {}, // Already in history
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan History'),
        centerTitle: true,
        actions: [
          if (widget.historyService.items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear all history',
              onPressed: _clearAll,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
          onTap: (_) => setState(() {}),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: List.generate(
                _tabs.length,
                (i) => _HistoryList(
                  items: _itemsForTab(i),
                  onDelete: _deleteItem,
                  onTap: _openDetail,
                  theme: theme,
                  isDark: isDark,
                ),
              ),
            ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final List<ScanHistoryItem> items;
  final ValueChanged<ScanHistoryItem> onDelete;
  final ValueChanged<ScanHistoryItem> onTap;
  final ThemeData theme;
  final bool isDark;

  const _HistoryList({
    required this.items,
    required this.onDelete,
    required this.onTap,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded,
                size: 56, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text('No scans yet',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Your scan history will appear here',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final item = items[i];
        return Dismissible(
          key: Key(item.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete_rounded, color: Colors.red),
          ),
          confirmDismiss: (_) async {
            HapticFeedback.mediumImpact();
            return true;
          },
          onDismissed: (_) => onDelete(item),
          child: _HistoryTile(
            item: item,
            onTap: () => onTap(item),
            theme: theme,
            isDark: isDark,
          ),
        );
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final ScanHistoryItem item;
  final VoidCallback onTap;
  final ThemeData theme;
  final bool isDark;

  const _HistoryTile({
    required this.item,
    required this.onTap,
    required this.theme,
    required this.isDark,
  });

  Color _accentColor() {
    switch (item.type) {
      case ScanType.ocr:
        return const Color(0xFF9D00FF);
      case ScanType.qrCode:
        return const Color(0xFF00BFA5);
      case ScanType.barcode:
        return const Color(0xFF2563EB);
      case ScanType.translation:
        return const Color(0xFFFF6E84);
    }
  }

  IconData _icon() {
    switch (item.type) {
      case ScanType.ocr:
        return Icons.document_scanner_rounded;
      case ScanType.qrCode:
        return Icons.qr_code_2_rounded;
      case ScanType.barcode:
        return Icons.barcode_reader;
      case ScanType.translation:
        return Icons.translate_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF22062C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF32113D) : const Color(0xFFE5EEFF),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon(), color: accent, size: 22),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.typeLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatDate(item.timestamp),
                        style: theme.textTheme.labelMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.summary,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                color: theme.colorScheme.outlineVariant),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('d MMM yyyy').format(dt);
}
