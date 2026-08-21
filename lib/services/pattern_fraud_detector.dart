/// Pattern-based fraud detector — identifies suspicious billing patterns
/// beyond GST arithmetic and charge analysis.
/// Covers: round amounts, threshold abuse, phantom items, impossible dates,
/// missing HSN/SAC, excessive discounts, and charge ratios.

import '../models/bill_model.dart';
import '../models/analysis_result.dart';
import 'government_source_service.dart';

class PatternFraudDetector {
  final GovernmentSourceService _govService;

  PatternFraudDetector(this._govService);

  List<AnalysisFinding> analyze(StructuredBill bill) {
    final findings = <AnalysisFinding>[];

    _checkRoundAmount(bill, findings);
    _checkThresholdManipulation(bill, findings);
    _checkPhantomItems(bill, findings);
    _checkMissingHsnSac(bill, findings);
    _checkImpossibleDates(bill, findings);
    _checkRoundPricePattern(bill, findings);
    _checkTaxRateAnomaly(bill, findings);
    _checkExcessiveDiscount(bill, findings);
    _checkChargesWithoutItems(bill, findings);
    _checkChargeProportion(bill, findings);

    return findings;
  }

  // ─── Round Amount Abuse ──────────────────────────────────────────────────
  // Suspiciously round totals (₹500, ₹1000, ₹5000) may indicate estimated/fake bills

  void _checkRoundAmount(StructuredBill bill, List<AnalysisFinding> findings) {
    if (bill.grandTotal == null) return;
    final total = bill.grandTotal!;

    // Check if total is a "suspiciously round" number
    final isRound = total > 100 && total % 100 == 0;
    final isVeryRound = total > 500 && total % 500 == 0;

    if (isVeryRound && bill.items.length > 1) {
      findings.add(AnalysisFinding(
        id: 'round_amount_very_suspicious',
        severity: FindingSeverity.verify,
        title: 'Suspiciously round total amount',
        explanation:
            'The grand total of ₹${total.toStringAsFixed(0)} is a round number '
            '(multiple of ₹500). While possible, round totals on bills with '
            'multiple items may indicate estimated or fabricated billing.',
        whatFound: '₹${total.toStringAsFixed(2)}',
        recommendation:
            'Verify each item price — round totals with multiple line items are unusual.',
        category: 'Pattern',
      ));
    } else if (isRound && bill.items.length > 3) {
      findings.add(AnalysisFinding(
        id: 'round_amount_mild',
        severity: FindingSeverity.ok,
        title: 'Total is a round amount',
        explanation:
            'The grand total of ₹${total.toStringAsFixed(0)} is a round number. '
            'This is common for single-item bills but less typical for multi-item bills.',
        whatFound: '₹${total.toStringAsFixed(2)}',
        category: 'Pattern',
      ));
    }
  }

  // ─── Threshold Manipulation ──────────────────────────────────────────────
  // Invoices just below approval limits (e.g., ₹4999 when limit is ₹5000)

  void _checkThresholdManipulation(StructuredBill bill, List<AnalysisFinding> findings) {
    if (bill.grandTotal == null) return;
    final total = bill.grandTotal!;

    // Common Indian approval thresholds
    final thresholds = [1000, 2000, 5000, 10000, 20000, 50000, 100000];

    for (final threshold in thresholds) {
      final diff = threshold - total;
      // Flag if within 2% below threshold
      if (diff > 0 && diff <= threshold * 0.02) {
        findings.add(AnalysisFinding(
          id: 'threshold_manipulation_$threshold',
          severity: FindingSeverity.suspicious,
          title: 'Amount just below ₹$threshold threshold',
          explanation:
              'The total ₹${total.toStringAsFixed(2)} is just ₹${diff.toStringAsFixed(2)} below '
              'the ₹$threshold threshold. This pattern may indicate deliberate structuring '
              'to avoid higher-level approval requirements.',
          whatFound: '₹${total.toStringAsFixed(2)} (₹${diff.toStringAsFixed(2)} below ₹$threshold)',
          recommendation:
              'Check if this bill should have been routed through higher approval. '
              'Multiple consecutive bills just below a threshold are a strong fraud indicator.',
          category: 'Pattern',
        ));
        break; // Only flag the closest threshold
      }
    }
  }

  // ─── Phantom Items ───────────────────────────────────────────────────────
  // Items with ₹0 price or zero quantity

  void _checkPhantomItems(StructuredBill bill, List<AnalysisFinding> findings) {
    for (final item in bill.items) {
      if (item.quantity != null && item.quantity! <= 0) {
        findings.add(AnalysisFinding(
          id: 'phantom_item_zero_qty_${item.name}',
          severity: FindingSeverity.suspicious,
          title: 'Item has zero or negative quantity',
          explanation:
              '"${item.name}" has a quantity of ${item.quantity}. '
              'A zero or negative quantity item on a bill is suspicious.',
          whatFound: 'Quantity: ${item.quantity}',
          recommendation: 'This item should not appear on the bill — verify with the seller.',
          category: 'Pattern',
          relatedItemName: item.name,
        ));
      }

      if (item.unitPrice != null && item.unitPrice! <= 0 && item.lineTotal != null && item.lineTotal! > 0) {
        findings.add(AnalysisFinding(
          id: 'phantom_item_zero_price_${item.name}',
          severity: FindingSeverity.suspicious,
          title: 'Item has zero unit price but non-zero total',
          explanation:
              '"${item.name}" shows ₹0 unit price but a line total of ₹${item.lineTotal!.toStringAsFixed(2)}. '
              'This inconsistency may indicate data manipulation.',
          whatFound: 'Unit price: ₹0, Line total: ₹${item.lineTotal!.toStringAsFixed(2)}',
          recommendation: 'Verify the pricing for this item.',
          category: 'Pattern',
          relatedItemName: item.name,
        ));
      }
    }
  }

  // ─── Missing HSN/SAC on GST Invoice ──────────────────────────────────────

  void _checkMissingHsnSac(StructuredBill bill, List<AnalysisFinding> findings) {
    if (bill.billType != BillType.gstInvoice &&
        bill.billType != BillType.ecommerce &&
        bill.gstin == null) {
      return; // Only check GST-registered invoices
    }

    final missingHsn = bill.items.where((i) => i.hsnSac == null || i.hsnSac!.isEmpty).length;
    if (missingHsn > 0 && missingHsn == bill.items.length) {
      findings.add(AnalysisFinding(
        id: 'missing_hsn_all_items',
        severity: FindingSeverity.verify,
        title: 'HSN/SAC codes missing on all items',
        explanation:
            'None of the $missingHsn items have HSN/SAC codes. '
            'Under GST rules, HSN/SAC codes are required on tax invoices. '
            'Their absence may indicate a non-compliant or fake invoice.',
        recommendation: 'Ask the seller for HSN/SAC codes — required for GST input credit.',
        category: 'Pattern',
        source: _govService.gstinSource,
      ));
    } else if (missingHsn > 0) {
      findings.add(AnalysisFinding(
        id: 'missing_hsn_some_items',
        severity: FindingSeverity.ok,
        title: '$missingHsn items missing HSN/SAC codes',
        explanation:
            '$missingHsn out of ${bill.items.length} items do not have HSN/SAC codes. '
            'While not critical, complete HSN/SAC coverage is expected on GST invoices.',
        category: 'Pattern',
      ));
    }
  }

  // ─── Impossible Dates ────────────────────────────────────────────────────

  void _checkImpossibleDates(StructuredBill bill, List<AnalysisFinding> findings) {
    if (bill.invoiceDate == null) return;
    final date = bill.invoiceDate!;
    final now = DateTime.now();

    // Future date check (more than 1 day ahead to account for timezone)
    if (date.isAfter(now.add(const Duration(days: 1)))) {
      findings.add(AnalysisFinding(
        id: 'future_date',
        severity: FindingSeverity.error,
        title: 'Invoice date is in the future',
        explanation:
            'The invoice date ${_formatDate(date)} is after today\'s date (${_formatDate(now)}). '
            'A future-dated invoice is invalid and may indicate fraud.',
        whatFound: '${_formatDate(date)}',
        whatExpected: 'Date on or before ${_formatDate(now)}',
        recommendation: 'This invoice is not valid — do not pay until the date is corrected.',
        category: 'Pattern',
      ));
    }

    // Very old date check (> 1 year old)
    if (date.isBefore(now.subtract(const Duration(days: 365)))) {
      findings.add(AnalysisFinding(
        id: 'very_old_date',
        severity: FindingSeverity.verify,
        title: 'Invoice is more than 1 year old',
        explanation:
            'The invoice date ${_formatDate(date)} is over a year old. '
            'Old invoices may be recycled or reused fraudulently.',
        whatFound: '${_formatDate(date)}',
        recommendation: 'Verify this is a current invoice, not a recycled old one.',
        category: 'Pattern',
      ));
    }
  }

  // ─── Round Price Pattern ─────────────────────────────────────────────────
  // Multiple items all at round prices may indicate estimated billing

  void _checkRoundPricePattern(StructuredBill bill, List<AnalysisFinding> findings) {
    if (bill.items.length < 3) return;

    int roundCount = 0;
    for (final item in bill.items) {
      if (item.unitPrice != null && item.unitPrice! >= 10) {
        if (item.unitPrice! % 10 == 0) roundCount++;
      }
    }

    final ratio = roundCount / bill.items.length;
    if (ratio > 0.7 && roundCount >= 3) {
      findings.add(AnalysisFinding(
        id: 'round_price_pattern',
        severity: FindingSeverity.verify,
        title: 'Multiple items have round-number prices',
        explanation:
            '$roundCount out of ${bill.items.length} items (${(ratio * 100).toStringAsFixed(0)}%) '
            'have prices that are multiples of ₹10. While common in some retail, '
            'this pattern on a detailed invoice may indicate estimated rather than actual pricing.',
        whatFound: '$roundCount items with round prices',
        recommendation: 'Cross-check individual item prices against market rates.',
        category: 'Pattern',
      ));
    }
  }

  // ─── Tax Rate Anomaly ────────────────────────────────────────────────────
  // Unusual GST rates for item categories

  void _checkTaxRateAnomaly(StructuredBill bill, List<AnalysisFinding> findings) {
    // Standard GST rates in India: 0%, 5%, 12%, 18%, 28%
    final validRates = {0.0, 5.0, 12.0, 18.0, 28.0};

    for (final item in bill.items) {
      final rate = item.gstRate ?? item.cgstRate;
      if (rate == null) continue;

      // Check if rate is a standard GST rate
      final totalRate = item.gstRate ?? ((item.cgstRate ?? 0) + (item.sgstRate ?? 0));
      if (totalRate > 0 && !validRates.contains(totalRate)) {
        findings.add(AnalysisFinding(
          id: 'unusual_tax_rate_${item.name}',
          severity: FindingSeverity.verify,
          title: 'Unusual GST rate on "${item.name}"',
          explanation:
              'A GST rate of ${totalRate.toStringAsFixed(1)}% was found on "${item.name}". '
              'Standard GST rates are 0%, 5%, 12%, 18%, and 28%. '
              'Non-standard rates may indicate an error or manipulation.',
          whatFound: '${totalRate.toStringAsFixed(1)}%',
          recommendation: 'Verify the GST rate with the seller or check the HSN code.',
          category: 'Pattern',
          relatedItemName: item.name,
        ));
      }
    }
  }

  // ─── Excessive Discount ──────────────────────────────────────────────────
  // Discounts > 50% or negative discounts (surcharges disguised as discounts)

  void _checkExcessiveDiscount(StructuredBill bill, List<AnalysisFinding> findings) {
    for (final item in bill.items) {
      if (item.discount == null || item.discount! <= 0) continue;
      if (item.unitPrice == null || item.unitPrice! <= 0) continue;

      final discountPct = (item.discount! / (item.unitPrice! * (item.quantity ?? 1))) * 100;

      if (item.discount! < 0) {
        findings.add(AnalysisFinding(
          id: 'negative_discount_${item.name}',
          severity: FindingSeverity.suspicious,
          title: 'Negative discount (surcharge) on "${item.name}"',
          explanation:
              '"${item.name}" shows a negative discount of ₹${item.discount!.abs().toStringAsFixed(2)}, '
              'which is actually a surcharge. Surcharges disguised as discounts are deceptive.',
          whatFound: '₹${item.discount!.toStringAsFixed(2)} (negative)',
          recommendation: 'This is a surcharge, not a discount — verify legitimacy.',
          category: 'Pattern',
          relatedItemName: item.name,
        ));
      } else if (discountPct > 50) {
        findings.add(AnalysisFinding(
          id: 'excessive_discount_${item.name}',
          severity: FindingSeverity.verify,
          title: 'Excessive discount on "${item.name}"',
          explanation:
              '"${item.name}" has a discount of ${discountPct.toStringAsFixed(0)}% '
              '(₹${item.discount!.toStringAsFixed(2)} off ₹${(item.unitPrice! * (item.quantity ?? 1)).toStringAsFixed(2)}). '
              'Discounts above 50% are unusual and may indicate price manipulation.',
          whatFound: '${discountPct.toStringAsFixed(0)}% discount',
          recommendation: 'Verify the original price and discount legitimacy.',
          category: 'Pattern',
          relatedItemName: item.name,
        ));
      }
    }
  }

  // ─── Charges Without Items ───────────────────────────────────────────────

  void _checkChargesWithoutItems(StructuredBill bill, List<AnalysisFinding> findings) {
    if (bill.items.isEmpty && bill.charges.isNotEmpty && bill.grandTotal != null) {
      findings.add(AnalysisFinding(
        id: 'charges_without_items',
        severity: FindingSeverity.suspicious,
        title: 'Bill has charges but no line items',
        explanation:
            'The bill contains ${bill.charges.length} charge(s) totaling '
            '₹${bill.totalCharges.toStringAsFixed(2)} but no line items were extracted. '
            'A bill with only charges and no itemized products/services is suspicious.',
        whatFound: '${bill.charges.length} charges, 0 items',
        recommendation: 'Request an itemized breakdown of all charges.',
        category: 'Pattern',
      ));
    }
  }

  // ─── Charge Proportion ───────────────────────────────────────────────────
  // Total charges > 20% of subtotal indicates excessive fees

  void _checkChargeProportion(StructuredBill bill, List<AnalysisFinding> findings) {
    final subtotal = bill.taxes.subtotal ?? bill.computedSubtotal;
    if (subtotal <= 0 || bill.totalCharges <= 0) return;

    final chargeRatio = (bill.totalCharges / subtotal) * 100;
    if (chargeRatio > 20) {
      findings.add(AnalysisFinding(
        id: 'excessive_charges_ratio',
        severity: FindingSeverity.verify,
        title: 'Extra charges are high relative to subtotal',
        explanation:
            'Total extra charges (₹${bill.totalCharges.toStringAsFixed(2)}) represent '
            '${chargeRatio.toStringAsFixed(0)}% of the taxable subtotal (₹${subtotal.toStringAsFixed(2)}). '
            'Charges exceeding 20% of the subtotal are considered excessive.',
        whatFound: '${chargeRatio.toStringAsFixed(0)}% (${bill.charges.length} charges)',
        whatExpected: '< 20% of subtotal',
        recommendation: 'Review each charge — excessive fees may be challenged under consumer protection rules.',
        category: 'Pattern',
        source: _govService.consumerProtectionSource,
      ));
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
