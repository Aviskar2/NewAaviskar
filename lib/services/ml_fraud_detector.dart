/// ML-inspired fraud detector using statistical anomaly scoring.
/// Implements lightweight anomaly detection using Z-score, Isolation Score,
/// and pattern deviation — all computed locally with dart:math.
/// No external ML dependencies required.

import 'dart:math';
import '../models/bill_model.dart';
import '../models/analysis_result.dart';
import 'government_source_service.dart';

class MlFraudDetector {
  final GovernmentSourceService _govService;
  final Random _rng = Random(42); // Deterministic seed for reproducibility

  MlFraudDetector(this._govService);

  /// Analyze bill and return anomaly findings with confidence scores.
  List<AnalysisFinding> analyze(StructuredBill bill) {
    final findings = <AnalysisFinding>[];

    _checkItemPriceAnomalies(bill, findings);
    _checkTotalAnomalyScore(bill, findings);
    _checkVendorRiskSignals(bill, findings);
    _checkIsolationScore(bill, findings);

    return findings;
  }

  // ─── Item Price Anomaly Detection (Z-Score) ──────────────────────────────
  // Flags individual items whose prices deviate significantly from the
  // bill's overall price distribution.

  void _checkItemPriceAnomalies(StructuredBill bill, List<AnalysisFinding> findings) {
    final prices = bill.items
        .where((i) => i.unitPrice != null && i.unitPrice! > 0)
        .map((i) => i.unitPrice!)
        .toList();

    if (prices.length < 3) return; // Need enough data for statistical analysis

    final mean = prices.reduce((a, b) => a + b) / prices.length;
    final variance = prices.fold(0.0, (s, p) => s + (p - mean) * (p - mean)) / prices.length;
    final stddev = sqrt(variance);

    if (stddev == 0) return; // All prices identical — no anomalies possible

    for (final item in bill.items) {
      if (item.unitPrice == null || item.unitPrice! <= 0) continue;

      final zScore = (item.unitPrice! - mean) / stddev;

      // Z-score > 2.5 indicates significant outlier
      if (zScore.abs() > 2.5) {
        final direction = zScore > 0 ? 'unusually high' : 'unusually low';
        findings.add(AnalysisFinding(
          id: 'price_anomaly_${item.name}',
          severity: zScore.abs() > 3.5 ? FindingSeverity.suspicious : FindingSeverity.verify,
          title: 'Price anomaly on "${item.name}"',
          explanation:
              '"${item.name}" at ₹${item.unitPrice!.toStringAsFixed(2)} is $direction '
              'compared to other items on this bill (Z-score: ${zScore.toStringAsFixed(2)}). '
              'Mean price: ₹${mean.toStringAsFixed(2)}, StdDev: ₹${stddev.toStringAsFixed(2)}.',
          whatFound: '₹${item.unitPrice!.toStringAsFixed(2)} (Z-score: ${zScore.toStringAsFixed(2)})',
          whatExpected: '₹${mean.toStringAsFixed(2)} ± ₹${stddev.toStringAsFixed(2)}',
          recommendation: 'Verify this item\'s price — it deviates significantly from the bill pattern.',
          category: 'ML',
          relatedItemName: item.name,
        ));
      }
    }
  }

  // ─── Total Amount Anomaly Score ──────────────────────────────────────────
  // Heuristic scoring based on multiple bill characteristics.

  void _checkTotalAnomalyScore(StructuredBill bill, List<AnalysisFinding> findings) {
    if (bill.grandTotal == null || bill.grandTotal! <= 0) return;

    double score = 0.0;
    final signals = <String>[];

    // Signal 1: High charge-to-item ratio
    if (bill.items.isNotEmpty && bill.totalCharges > 0) {
      final chargeRatio = bill.totalCharges / bill.itemsGrossTotal;
      if (chargeRatio > 0.3) {
        score += 0.3;
        signals.add('charges are ${(chargeRatio * 100).toStringAsFixed(0)}% of item total');
      }
    }

    // Signal 2: Many items with low confidence parsing
    if (bill.items.isNotEmpty) {
      final lowConfCount = bill.items.where((i) => i.confidence < 0.5).length;
      final lowConfRatio = lowConfCount / bill.items.length;
      if (lowConfRatio > 0.4) {
        score += 0.2;
        signals.add('${(lowConfRatio * 100).toStringAsFixed(0)}% of items have low parse confidence');
      }
    }

    // Signal 3: Bill total is a prime number (unusual for natural billing)
    if (bill.grandTotal! > 100 && _isPrime(bill.grandTotal!.round())) {
      score += 0.1;
      signals.add('total is a prime number');
    }

    // Signal 4: Missing key fields
    int missingFields = 0;
    if (bill.sellerName == null) missingFields++;
    if (bill.gstin == null) missingFields++;
    if (bill.invoiceNumber == null) missingFields++;
    if (bill.invoiceDate == null) missingFields++;
    if (missingFields >= 3) {
      score += 0.25;
      signals.add('$missingFields key fields missing (seller, GSTIN, invoice#)');
    }

    // Signal 5: Unusual item count for bill type
    if (bill.billType == BillType.restaurant && bill.items.length > 30) {
      score += 0.15;
      signals.add('unusually many items (${bill.items.length}) for a restaurant bill');
    }

    if (score >= 0.4) {
      findings.add(AnalysisFinding(
        id: 'anomaly_score_high',
        severity: score >= 0.6 ? FindingSeverity.suspicious : FindingSeverity.verify,
        title: 'Bill anomaly score: ${(score * 100).toStringAsFixed(0)}%',
        explanation:
            'This bill has an anomaly score of ${(score * 100).toStringAsFixed(0)}% based on '
            'multiple risk signals. Detected signals: ${signals.join("; ")}.',
        whatFound: '${signals.length} risk signals detected',
        recommendation:
            'This bill warrants closer inspection. '
            'Review each signal and verify with the establishment.',
        category: 'ML',
      ));
    }
  }

  // ─── Vendor Risk Signals ─────────────────────────────────────────────────
  // Check for characteristics associated with higher fraud risk vendors.

  void _checkVendorRiskSignals(StructuredBill bill, List<AnalysisFinding> findings) {
    int riskScore = 0;
    final risks = <String>[];

    // Missing seller name
    if (bill.sellerName == null || bill.sellerName!.isEmpty) {
      riskScore += 2;
      risks.add('no seller name');
    }

    // GSTIN state code mismatch with address
    if (bill.gstin != null && bill.sellerAddress != null) {
      final gstinState = bill.gstin!.substring(0, 2);
      // Basic check: if address mentions a state and GSTIN state code doesn't match common patterns
      final addressLower = bill.sellerAddress!.toLowerCase();
      if (addressLower.contains('delhi') && gstinState != '07' && gstinState != '01') {
        riskScore += 1;
        risks.add('GSTIN state code may not match address');
      }
    }

    // No invoice number
    if (bill.invoiceNumber == null || bill.invoiceNumber!.isEmpty) {
      riskScore += 1;
      risks.add('no invoice number');
    }

    // Very short raw text (may indicate incomplete/fake bill)
    if (bill.rawText.length < 50) {
      riskScore += 2;
      risks.add('very short bill text (${bill.rawText.length} chars)');
    }

    // Items with no names (just amounts)
    final unnamedItems = bill.items.where((i) => i.name.length < 2).length;
    if (unnamedItems > 0) {
      riskScore += 1;
      risks.add('$unnamedItems items with no descriptive name');
    }

    if (riskScore >= 3) {
      findings.add(AnalysisFinding(
        id: 'vendor_risk_signals',
        severity: riskScore >= 5 ? FindingSeverity.suspicious : FindingSeverity.verify,
        title: 'Vendor risk signals detected',
        explanation:
            'This bill has $riskScore vendor risk signal(s): ${risks.join("; ")}. '
            'These characteristics are commonly associated with higher fraud risk.',
        whatFound: '$riskScore risk signals',
        recommendation: 'Verify vendor identity and bill authenticity before payment.',
        category: 'ML',
      ));
    }
  }

  // ─── Isolation Score (Simplified) ────────────────────────────────────────
  // A lightweight isolation forest concept: bills that are "easily isolated"
  // (different from normal bills on multiple dimensions) get higher scores.

  void _checkIsolationScore(StructuredBill bill, List<AnalysisFinding> findings) {
    if (bill.grandTotal == null || bill.items.isEmpty) return;

    double isolationScore = 0.0;
    int dimensions = 0;

    // Dimension 1: Item count deviation
    final avgItemsPerBill = 8.0; // Typical bill has ~8 items
    final itemDeviation = (bill.items.length - avgItemsPerBill).abs() / avgItemsPerBill;
    if (itemDeviation > 1.0) isolationScore += 1.0;
    dimensions++;

    // Dimension 2: Average item price
    final avgItemPrice = bill.itemsGrossTotal / bill.items.length;
    if (avgItemPrice > 5000) isolationScore += 1.0; // Very high avg item price
    dimensions++;

    // Dimension 3: Tax rate consistency
    final taxRates = bill.items
        .where((i) => i.gstRate != null)
        .map((i) => i.gstRate!)
        .toSet();
    if (taxRates.length > 3) isolationScore += 1.0; // Too many different tax rates
    dimensions++;

    // Dimension 4: Charge diversity
    final chargeLabels = bill.charges.map((c) => c.label.toLowerCase()).toSet();
    if (chargeLabels.length > 4) isolationScore += 0.5; // Many different charge types
    dimensions++;

    // Dimension 5: Total as percentage of max item price
    if (bill.items.isNotEmpty) {
      final maxItemPrice = bill.items
          .where((i) => i.lineTotal != null)
          .map((i) => i.lineTotal!)
          .fold(0.0, (a, b) => max(a, b));
      if (maxItemPrice > 0 && bill.grandTotal! / maxItemPrice < 1.1) {
        isolationScore += 0.5; // Total barely exceeds max single item — unusual
      }
    }
    dimensions++;

    final normalizedScore = isolationScore / dimensions;

    if (normalizedScore > 0.5) {
      findings.add(AnalysisFinding(
        id: 'isolation_score',
        severity: normalizedScore > 0.7 ? FindingSeverity.suspicious : FindingSeverity.verify,
        title: 'Bill deviates from typical patterns',
        explanation:
            'This bill scores ${(normalizedScore * 100).toStringAsFixed(0)}% on the isolation index, '
            'meaning it differs from typical bills on multiple dimensions simultaneously. '
            'This does not confirm fraud but warrants attention.',
        whatFound: 'Isolation score: ${(normalizedScore * 100).toStringAsFixed(0)}%',
        recommendation: 'Cross-reference with the vendor\'s typical billing patterns.',
        category: 'ML',
      ));
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  bool _isPrime(int n) {
    if (n < 2) return false;
    if (n < 4) return true;
    if (n % 2 == 0 || n % 3 == 0) return false;
    for (int i = 5; i * i <= n; i += 6) {
      if (n % i == 0 || n % (i + 2) == 0) return false;
    }
    return true;
  }
}
