import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/ocr_service.dart';
import '../../services/scan_history_service.dart';
import 'qr_scanner_screen.dart';
import 'universal_product_entry_screen.dart';

/// Unified Scanner Hub with 2 high-impact modes:
/// 1. 🏷️ Live QR & Barcode Scanner
/// 2. 🛡️ Universal Product & Safety Scanner (Food, Medicine, Cosmetics, FMCG)
class ScannerHubScreen extends StatefulWidget {
  final OcrService ocrService;
  final ScanHistoryService historyService;
  final int initialTab;

  const ScannerHubScreen({
    Key? key,
    required this.ocrService,
    required this.historyService,
    this.initialTab = 0,
  }) : super(key: key);

  @override
  State<ScannerHubScreen> createState() => _ScannerHubScreenState();
}

class _ScannerHubScreenState extends State<ScannerHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Universal Scanner Hub'),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: false,
              onTap: (_) => HapticFeedback.selectionClick(),
              indicatorColor: const Color(0xFF2563EB),
              labelColor: const Color(0xFF2563EB),
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(
                  icon: Icon(Icons.qr_code_scanner_rounded, size: 20),
                  text: 'QR & Barcode',
                ),
                Tab(
                  icon: Icon(Icons.verified_user_rounded, size: 20),
                  text: 'Product & Safety',
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          QrScannerScreen(
            historyService: widget.historyService,
          ),
          UniversalProductEntryScreen(
            ocrService: widget.ocrService,
            historyService: widget.historyService,
          ),
        ],
      ),
    );
  }
}
