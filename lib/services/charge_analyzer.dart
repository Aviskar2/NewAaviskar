/// Charge analyzer — detects suspicious charges beyond GST arithmetic.

import '../models/bill_model.dart';
import '../models/analysis_result.dart';
import 'government_source_service.dart';

class ChargeAnalyzer {
  final GovernmentSourceService _govService;

  ChargeAnalyzer(this._govService);

  List<AnalysisFinding> analyze(StructuredBill bill) {
    final findings = <AnalysisFinding>[];

    _checkDuplicateItems(bill, findings);
    _checkExcessivePackaging(bill, findings);
    _checkConvenienceFee(bill, findings);
    _checkDeliveryCharge(bill, findings);
    _checkItemTotals(bill, findings);
    _checkQrMismatch(bill, findings);
    _checkHiddenCharges(bill, findings);
    _checkChargeProportion(bill, findings);
    _checkGstOnDiscount(bill, findings);

    return findings;
  }

  // ─── Duplicate items ──────────────────────────────────────────────────────

  void _checkDuplicateItems(StructuredBill bill, List<AnalysisFinding> findings) {
    final seen = <String>{};
    for (final item in bill.items) {
      final key = item.name.toLowerCase().trim();
      if (seen.contains(key)) {
        findings.add(AnalysisFinding(
          id: 'duplicate_item_$key',
          severity: FindingSeverity.verify,
          title: 'Duplicate item detected',
          explanation:
              '"${item.name}" appears more than once in the bill. '
              'This may be intentional (multiple orders) or an error.',
          whatFound: '"${item.name}" listed multiple times',
          recommendation: 'Verify that you actually ordered this item more than once.',
          category: 'Item',
          relatedItemName: item.name,
        ));
      } else {
        seen.add(key);
      }
    }
  }

  // ─── Excessive packaging fee ──────────────────────────────────────────────

  void _checkExcessivePackaging(StructuredBill bill, List<AnalysisFinding> findings) {
    for (final charge in bill.charges) {
      if (charge.isPackaging && charge.amount > 50) {
        findings.add(AnalysisFinding(
          id: 'excessive_packaging',
          severity: FindingSeverity.verify,
          title: 'Packaging charge seems high',
          explanation:
              'A packaging charge of ₹${charge.amount.toStringAsFixed(2)} was added. '
              'While packaging charges are generally permitted, they should be reasonable.',
          whatFound: '${charge.label}: ₹${charge.amount.toStringAsFixed(2)}',
          recommendation:
              'Verify this charge was disclosed before ordering.',
          category: 'Item',
          source: _govService.consumerProtectionSource,
        ));
      }
    }
  }

  // ─── Convenience fee ──────────────────────────────────────────────────────

  void _checkConvenienceFee(StructuredBill bill, List<AnalysisFinding> findings) {
    final convFees = bill.charges.where((c) => c.isConvenienceFee).toList();
    if (convFees.length > 1) {
      findings.add(AnalysisFinding(
        id: 'duplicate_convenience_fee',
        severity: FindingSeverity.suspicious,
        title: 'Multiple convenience/platform fees detected',
        explanation: 'More than one convenience or platform fee appears on the bill.',
        whatFound: convFees.map((c) => '${c.label}: ₹${c.amount.toStringAsFixed(2)}').join(', '),
        recommendation: 'Verify with the platform/establishment which fees apply.',
        category: 'Item',
        source: _govService.consumerProtectionSource,
      ));
    }
  }

  // ─── Delivery charge ──────────────────────────────────────────────────────

  void _checkDeliveryCharge(StructuredBill bill, List<AnalysisFinding> findings) {
    final deliveryCharges = bill.charges.where((c) => c.isDelivery).toList();
    if (deliveryCharges.length > 1) {
      findings.add(AnalysisFinding(
        id: 'duplicate_delivery',
        severity: FindingSeverity.suspicious,
        title: 'Multiple delivery charges detected',
        explanation: 'More than one delivery charge appears on the bill.',
        whatFound: deliveryCharges
            .map((c) => '${c.label}: ₹${c.amount.toStringAsFixed(2)}')
            .join(', '),
        recommendation: 'Only one delivery charge should apply.',
        category: 'Item',
        source: _govService.consumerProtectionSource,
      ));
    }
  }

  // ─── Item total cross-check ───────────────────────────────────────────────

  void _checkItemTotals(StructuredBill bill, List<AnalysisFinding> findings) {
    for (final item in bill.items) {
      if (item.quantity != null && item.unitPrice != null && item.lineTotal != null) {
        final expected = item.quantity! * item.unitPrice!;
        final diff = (item.lineTotal! - expected).abs();
        if (diff > 1.0) {
          findings.add(AnalysisFinding(
            id: 'item_total_mismatch_${item.name}',
            severity: FindingSeverity.verify,
            title: 'Item total may be incorrect',
            explanation:
                'For "${item.name}": qty ${item.quantity} × ₹${item.unitPrice!.toStringAsFixed(2)} = '
                '₹${expected.toStringAsFixed(2)}, but ₹${item.lineTotal!.toStringAsFixed(2)} is printed.',
            whatFound: '₹${item.lineTotal!.toStringAsFixed(2)}',
            whatExpected: '₹${expected.toStringAsFixed(2)}',
            difference: diff,
            recommendation: 'Verify the price and quantity for this item.',
            category: 'Item',
            relatedItemName: item.name,
          ));
        }
      }
    }
  }

  // ─── QR vs printed data mismatch ──────────────────────────────────────────

  void _checkQrMismatch(StructuredBill bill, List<AnalysisFinding> findings) {
    final qr = bill.qrData;
    if (qr == null) return;

    // GSTIN mismatch
    final qrGstin = qr['gstin']?.toString();
    if (qrGstin != null && bill.gstin != null && qrGstin != bill.gstin) {
      findings.add(AnalysisFinding(
        id: 'qr_gstin_mismatch',
        severity: FindingSeverity.suspicious,
        title: 'QR GSTIN does not match printed GSTIN',
        explanation: 'The GSTIN in the QR code differs from what is printed on the bill. '
            'This could indicate a tampered or incorrect bill. Please verify.',
        whatFound: 'QR GSTIN: $qrGstin',
        whatExpected: 'Printed GSTIN: ${bill.gstin}',
        recommendation: 'Do NOT assume fraud — verify with the establishment first.',
        category: 'QR',
        source: _govService.gstinSource,
      ));
    }

    // Total mismatch
    final qrTotal = double.tryParse(qr['total']?.toString() ?? '');
    if (qrTotal != null && bill.grandTotal != null) {
      final diff = (qrTotal - bill.grandTotal!).abs();
      if (diff > 2.0) {
        findings.add(AnalysisFinding(
          id: 'qr_total_mismatch',
          severity: FindingSeverity.suspicious,
          title: 'QR total does not match printed total',
          explanation: 'The total amount in the QR code differs from the printed grand total. '
              'Mismatch detected — please verify with the establishment.',
          whatFound: 'QR total: ₹${qrTotal.toStringAsFixed(2)}',
          whatExpected: 'Printed total: ₹${bill.grandTotal!.toStringAsFixed(2)}',
          difference: diff,
          recommendation: 'This is a potential mismatch — verify before paying.',
          category: 'QR',
          source: _govService.gstinSource,
        ));
      }
    }
  }

  // ─── Hidden / Unrecognised Charges ────────────────────────────────────────
  // Charges that don't match any known category may be disguised fees.

  void _checkHiddenCharges(StructuredBill bill, List<AnalysisFinding> findings) {
    for (final charge in bill.charges) {
      final isKnown = charge.isServiceCharge ||
          charge.isPackaging ||
          charge.isDelivery ||
          charge.isConvenienceFee;
      if (!isKnown && charge.amount > 0) {
        findings.add(AnalysisFinding(
          id: 'hidden_charge_${charge.label}',
          severity: FindingSeverity.verify,
          title: 'Unrecognised charge: "${charge.label}"',
          explanation:
              'A charge of ₹${charge.amount.toStringAsFixed(2)} labelled "${charge.label}" '
              'does not match common charge categories (service, packaging, delivery, convenience). '
              'It may be a legitimate fee or a disguised surcharge.',
          whatFound: '${charge.label}: ₹${charge.amount.toStringAsFixed(2)}',
          recommendation:
              'Ask the establishment to explain this charge. '
              'Unexplained charges can be challenged under consumer protection law.',
          category: 'Item',
          source: _govService.consumerProtectionSource,
        ));
      }
    }
  }

  // ─── Charge Proportion Check ─────────────────────────────────────────────
  // Total extra charges > 20% of subtotal indicates excessive fees.

  void _checkChargeProportion(StructuredBill bill, List<AnalysisFinding> findings) {
    final subtotal = bill.taxes.subtotal ?? bill.computedSubtotal;
    if (subtotal <= 0 || bill.totalCharges <= 0) return;

    final ratio = (bill.totalCharges / subtotal) * 100;
    if (ratio > 20) {
      findings.add(AnalysisFinding(
        id: 'excessive_charge_ratio',
        severity: FindingSeverity.verify,
        title: 'Extra charges are high relative to subtotal',
        explanation:
            'Total extra charges (₹${bill.totalCharges.toStringAsFixed(2)}) represent '
            '${ratio.toStringAsFixed(0)}% of the taxable subtotal (₹${subtotal.toStringAsFixed(2)}). '
            'Charges above 20% of the subtotal are considered excessive.',
        whatFound: '${ratio.toStringAsFixed(0)}% of subtotal',
        whatExpected: '< 20% of subtotal',
        recommendation: 'Review each charge — excessive fees may be challenged.',
        category: 'Item',
        source: _govService.consumerProtectionSource,
      ));
    }
  }

  // ─── GST on Discount ─────────────────────────────────────────────────────
  // GST should be calculated on the discounted price, not the original price.

  void _checkGstOnDiscount(StructuredBill bill, List<AnalysisFinding> findings) {
    if (bill.discountTotal == null || bill.discountTotal! <= 0) return;
    if (bill.taxes.subtotal == null || bill.taxes.subtotal! <= 0) return;

    final itemsGrossTotal = bill.itemsGrossTotal;
    if (itemsGrossTotal <= 0) return;

    final expectedSubtotal = itemsGrossTotal - bill.discountTotal!;
    final diff = (bill.taxes.subtotal! - expectedSubtotal).abs();

    if (diff > 5.0 && bill.taxes.subtotal! > expectedSubtotal) {
      findings.add(AnalysisFinding(
        id: 'gst_on_pre_discount',
        severity: FindingSeverity.suspicious,
        title: 'GST may be charged on pre-discount amount',
        explanation:
            'A discount of ₹${bill.discountTotal!.toStringAsFixed(2)} was applied, but the '
            'taxable subtotal (₹${bill.taxes.subtotal!.toStringAsFixed(2)}) appears to be calculated '
            'on the original price. GST should be charged on the discounted price.',
        whatFound: 'Subtotal: ₹${bill.taxes.subtotal!.toStringAsFixed(2)}',
        whatExpected: '≈ ₹${expectedSubtotal.toStringAsFixed(2)} (after ₹${bill.discountTotal!.toStringAsFixed(2)} discount)',
        difference: diff,
        recommendation: 'Ask the establishment to recalculate GST on the discounted amount.',
        category: 'GST',
        source: _govService.gstinSource,
      ));
    }
  }
}
