/// Bill history analyzer — tracks past bill patterns per vendor to detect
/// progressive fraud, amount inflation, and duplicate vendor identities.
/// Uses SharedPreferences for lightweight local persistence.
library;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bill_model.dart';
import '../models/analysis_result.dart';
import 'government_source_service.dart';

/// Compact bill record stored for historical analysis.
class BillHistoryRecord {
  final String vendorName;
  final String? gstin;
  final double grandTotal;
  final double? subtotal;
  final int itemCount;
  final DateTime date;
  final String billType;

  const BillHistoryRecord({
    required this.vendorName,
    this.gstin,
    required this.grandTotal,
    this.subtotal,
    required this.itemCount,
    required this.date,
    required this.billType,
  });

  Map<String, dynamic> toJson() => {
        'v': vendorName,
        'g': gstin,
        't': grandTotal,
        's': subtotal,
        'n': itemCount,
        'd': date.millisecondsSinceEpoch,
        'b': billType,
      };

  factory BillHistoryRecord.fromJson(Map<String, dynamic> json) =>
      BillHistoryRecord(
        vendorName: json['v'] as String,
        gstin: json['g'] as String?,
        grandTotal: (json['t'] as num).toDouble(),
        subtotal: (json['s'] as num?)?.toDouble(),
        itemCount: json['n'] as int,
        date: DateTime.fromMillisecondsSinceEpoch(json['d'] as int),
        billType: json['b'] as String,
      );
}

class BillHistoryAnalyzer {
  final GovernmentSourceService _govService;
  static const String _key = 'bill_history_v1';
  static const int _maxRecords = 500;

  List<BillHistoryRecord> _records = [];
  bool _loaded = false;

  BillHistoryAnalyzer(this._govService);

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    _records = raw
        .map((s) {
          try {
            return BillHistoryRecord.fromJson(
                jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<BillHistoryRecord>()
        .toList();
    _loaded = true;
  }

  /// Store a new bill record for future analysis.
  Future<void> recordBill(StructuredBill bill) async {
    await load();
    _records.insert(0, BillHistoryRecord(
      vendorName: bill.sellerName ?? 'Unknown',
      gstin: bill.gstin,
      grandTotal: bill.grandTotal ?? 0,
      subtotal: bill.taxes.subtotal,
      itemCount: bill.items.length,
      date: bill.invoiceDate ?? DateTime.now(),
      billType: bill.billType.displayName,
    ));
    if (_records.length > _maxRecords) {
      _records = _records.sublist(0, _maxRecords);
    }
    await _persist();
  }

  /// Analyze a new bill against historical data for fraud patterns.
  List<AnalysisFinding> analyze(StructuredBill bill) {
    final findings = <AnalysisFinding>[];

    _checkVendorInflation(bill, findings);
    _checkVendorFrequency(bill, findings);
    _checkDuplicateVendorGstin(bill, findings);
    _checkAmountAnomalyVsHistory(bill, findings);

    return findings;
  }

  // ─── Vendor Amount Inflation ─────────────────────────────────────────────
  // Detect progressive increase in bills from the same vendor.

  void _checkVendorInflation(StructuredBill bill, List<AnalysisFinding> findings) {
    if (bill.sellerName == null || bill.grandTotal == null) return;

    final vendorBills = _records
        .where((r) => r.vendorName.toLowerCase() == bill.sellerName!.toLowerCase())
        .toList();

    if (vendorBills.length < 3) return; // Need history

    // Sort by date ascending
    vendorBills.sort((a, b) => a.date.compareTo(b.date));

    // Check if amounts are consistently increasing
    int increaseCount = 0;
    for (int i = 1; i < vendorBills.length; i++) {
      if (vendorBills[i].grandTotal > vendorBills[i - 1].grandTotal) {
        increaseCount++;
      }
    }

    final increaseRatio = increaseCount / (vendorBills.length - 1);
    if (increaseRatio > 0.7 && vendorBills.length >= 4) {
      final firstAmount = vendorBills.first.grandTotal;
      final lastAmount = vendorBills.last.grandTotal;
      final pctIncrease = ((lastAmount - firstAmount) / firstAmount * 100);

      findings.add(AnalysisFinding(
        id: 'vendor_inflation_${bill.sellerName}',
        severity: pctIncrease > 50 ? FindingSeverity.suspicious : FindingSeverity.verify,
        title: 'Progressive amount increase from "${bill.sellerName}"',
        explanation:
            'Bills from this vendor have been increasing over time. '
            '${(increaseRatio * 100).toStringAsFixed(0)}% of historical bills show increases. '
            'Total increase: ${pctIncrease.toStringAsFixed(0)}% '
            '(₹${firstAmount.toStringAsFixed(0)} → ₹${lastAmount.toStringAsFixed(0)}).',
        whatFound: '${pctIncrease.toStringAsFixed(0)}% increase over ${vendorBills.length} bills',
        recommendation:
            'Monitor this vendor — progressive price increases without '
            'corresponding service changes may indicate overcharging.',
        category: 'History',
        source: _govService.consumerProtectionSource,
      ));
    }
  }

  // ─── Vendor Frequency Analysis ───────────────────────────────────────────
  // Detect unusually frequent invoicing from the same vendor.

  void _checkVendorFrequency(StructuredBill bill, List<AnalysisFinding> findings) {
    if (bill.sellerName == null) return;

    final vendorBills = _records
        .where((r) => r.vendorName.toLowerCase() == bill.sellerName!.toLowerCase())
        .toList();

    if (vendorBills.length < 5) return;

    // Count bills in last 30 days
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final recentBills = vendorBills
        .where((r) => r.date.isAfter(thirtyDaysAgo))
        .length;

    if (recentBills >= 10) {
      findings.add(AnalysisFinding(
        id: 'vendor_frequency_${bill.sellerName}',
        severity: FindingSeverity.suspicious,
        title: 'High invoice frequency from "${bill.sellerName}"',
        explanation:
            '$recentBills invoices were received from this vendor in the last 30 days. '
            'This frequency may indicate split billing or phantom invoicing.',
        whatFound: '$recentBills bills in 30 days',
        recommendation:
            'Verify each invoice represents a genuine, separate transaction. '
            'High-frequency low-value invoicing may be used to avoid approval thresholds.',
        category: 'History',
      ));
    } else if (recentBills >= 6) {
      findings.add(AnalysisFinding(
        id: 'vendor_frequency_mild_${bill.sellerName}',
        severity: FindingSeverity.verify,
        title: 'Elevated invoice frequency from "${bill.sellerName}"',
        explanation:
            '$recentBills invoices were received from this vendor in the last 30 days. '
            'This is above average but may be normal for active vendors.',
        whatFound: '$recentBills bills in 30 days',
        category: 'History',
      ));
    }
  }

  // ─── Duplicate Vendor GSTIN Detection ────────────────────────────────────
  // Multiple GSTINs with the same vendor name may indicate shell companies.

  void _checkDuplicateVendorGstin(StructuredBill bill, List<AnalysisFinding> findings) {
    if (bill.sellerName == null || bill.gstin == null) return;

    final vendorRecords = _records
        .where((r) => r.vendorName.toLowerCase() == bill.sellerName!.toLowerCase() && r.gstin != null)
        .toList();

    final uniqueGstins = vendorRecords.map((r) => r.gstin).toSet();
    uniqueGstins.add(bill.gstin); // Include current

    if (uniqueGstins.length > 1) {
      findings.add(AnalysisFinding(
        id: 'duplicate_vendor_gstin_${bill.sellerName}',
        severity: FindingSeverity.suspicious,
        title: 'Multiple GSTINs for same vendor name',
        explanation:
            '"${bill.sellerName}" has been associated with ${uniqueGstins.length} different GSTINs '
            'across historical bills. Multiple GSTINs for the same vendor name may indicate '
            'shell companies or identity manipulation.',
        whatFound: 'GSTINs: ${uniqueGstins.join(", ")}',
        recommendation:
            'Verify the vendor\'s identity. Different GSTINs for the same business '
            'name is a significant fraud indicator.',
        category: 'History',
      ));
    }
  }

  // ─── Amount Anomaly vs Historical Average ────────────────────────────────
  // Flag if current bill is significantly different from vendor's history.

  void _checkAmountAnomalyVsHistory(StructuredBill bill, List<AnalysisFinding> findings) {
    if (bill.sellerName == null || bill.grandTotal == null) return;

    final vendorBills = _records
        .where((r) => r.vendorName.toLowerCase() == bill.sellerName!.toLowerCase())
        .toList();

    if (vendorBills.length < 3) return;

    final amounts = vendorBills.map((r) => r.grandTotal).toList();
    final mean = amounts.reduce((a, b) => a + b) / amounts.length;
    final variance = amounts.fold(0.0, (s, a) => s + (a - mean) * (a - mean)) / amounts.length;
    final double stddev = mean > 0 ? (variance > 0 ? _sqrt(variance) : 0.0) : 0.0;

    if (stddev == 0 || mean == 0) return;

    final zScore = (bill.grandTotal! - mean) / stddev;

    if (zScore.abs() > 2.0) {
      final direction = zScore > 0 ? 'significantly higher' : 'significantly lower';
      findings.add(AnalysisFinding(
        id: 'amount_anomaly_vs_history_${bill.sellerName}',
        severity: zScore.abs() > 3.0 ? FindingSeverity.suspicious : FindingSeverity.verify,
        title: 'Bill amount is $direction than average',
        explanation:
            'This bill (₹${bill.grandTotal!.toStringAsFixed(2)}) is $direction than the '
            'average for "${bill.sellerName}" (₹${mean.toStringAsFixed(2)} ± ₹${stddev.toStringAsFixed(2)}). '
            'Z-score: ${zScore.toStringAsFixed(2)}.',
        whatFound: '₹${bill.grandTotal!.toStringAsFixed(2)} (Z-score: ${zScore.toStringAsFixed(2)})',
        whatExpected: '₹${mean.toStringAsFixed(2)} ± ₹${stddev.toStringAsFixed(2)}',
        recommendation:
            'Verify this bill — a significant deviation from the vendor\'s pattern '
            'may indicate an error or fraudulent charge.',
        category: 'History',
      ));
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  double _sqrt(double x) {
    if (x <= 0) return 0.0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _records.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(_key, raw);
  }
}
