import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/ocr_service.dart';
import '../../services/scan_history_service.dart';
import 'qr_scanner_screen.dart';
import '../medicine_safety/medicine_entry_screen.dart';
import '../product_safety/product_safety_entry_screen.dart';

/// Unified Scanner & Safety Hub with 3 comprehensive modes:
/// 1. 🏷️ QR & Barcode Scanner
/// 2. 💊 Medicine Safety & Jan Aushadhi Generic Savings
/// 3. 🥗 Food & Product Safety (FSSAI, Expiry & Nutrition)
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
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
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
        title: const Text(
          'Universal Scanner & Safety Hub',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
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
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 12),
              tabs: const [
                Tab(
                  icon: Icon(Icons.qr_code_scanner_rounded, size: 20),
                  text: 'QR / Barcode',
                ),
                Tab(
                  icon: Icon(Icons.medication_rounded, size: 20),
                  text: 'Medicine',
                ),
                Tab(
                  icon: Icon(Icons.health_and_safety_rounded, size: 20),
                  text: 'Food Safety',
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
          MedicineEntryScreen(
            ocrService: widget.ocrService,
            historyService: widget.historyService,
          ),
          ProductSafetyEntryScreen(
            ocrService: widget.ocrService,
            historyService: widget.historyService,
          ),
        ],
      ),
    );
  }
}
