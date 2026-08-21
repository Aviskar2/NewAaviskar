/// Deterministic GST calculation engine.
/// Recalculates expected taxes independently and compares with printed values.
/// NO LLM. NO assumptions about fixed rates.
/// Key principle: only flag a REAL problem when ALL required data is confidently available.
/// Missing data → skip check silently, never flag as suspicious.

import '../models/bill_model.dart';
import '../models/analysis_result.dart';
import 'government_source_service.dart';

class GstRuleEngine {
  final GovernmentSourceService _govService;

  GstRuleEngine(this._govService);

  /// Validate the bill's GST arithmetic deterministically.
  /// Returns a list of findings.
  List<AnalysisFinding> analyze(StructuredBill bill) {
    final findings = <AnalysisFinding>[];

    _checkCgstSgstMismatch(bill, findings);
    _checkIgstMismatch(bill, findings);
    _checkTotalMismatch(bill, findings);
    _checkCgstSgstEquality(bill, findings);
    _checkDuplicateTax(bill, findings);
    _checkServiceChargeTax(bill, findings);
    _checkRounding(bill, findings);
    _checkSubtotalMatch(bill, findings);
    _checkCessValidation(bill, findings);
    _checkReverseCharge(bill, findings);
    _checkMultiSlabConsistency(bill, findings);

    // If no findings at all yet, add a general positive finding
    if (findings.isEmpty && bill.grandTotal != null) {
      findings.add(AnalysisFinding(
        id: 'general_ok',
        severity: FindingSeverity.ok,
        title: 'Bill parsed successfully',
        explanation: 'The bill was parsed and no arithmetic issues were detected.',
        category: 'Arithmetic',
      ));
    }

    return findings;
  }

  // ─── Subtotal check ────────────────────────────────────────────────────────
  // Only check if we have BOTH printed subtotal AND reliably extracted items

  void _checkSubtotalMatch(StructuredBill bill, List<AnalysisFinding> findings) {
    final printedSubtotal = bill.taxes.subtotal;
    final computedSubtotal = bill.computedSubtotal;

    // Skip if we don't have a printed subtotal OR no items were extracted
    if (printedSubtotal == null || computedSubtotal == 0) return;

    // Skip if item confidence is generally low (many items with default qty/price)
    final highConfItems = bill.items.where((i) => i.confidence >= 0.75).length;
    if (highConfItems < bill.items.length * 0.6) return;

    final diff = (printedSubtotal - computedSubtotal).abs();
    // Use a wider tolerance for multi-format bills (₹5 tolerance)
    if (diff > 5.0) {
      findings.add(AnalysisFinding(
        id: 'subtotal_mismatch',
        severity: FindingSeverity.verify,
        title: 'Subtotal may not match items',
        explanation: 'The taxable amount printed on the bill does not match the sum of extracted item prices. '
            'This may be due to OCR extraction limitations.',
        whatFound: '₹${printedSubtotal.toStringAsFixed(2)} (printed)',
        whatExpected: '₹${computedSubtotal.toStringAsFixed(2)} (estimated from items)',
        difference: diff,
        recommendation: 'Manually verify each item price adds up correctly.',
        category: 'Arithmetic',
        source: _govService.arithmeticSource,
      ));
    } else if (diff <= 5.0 && highConfItems == bill.items.length) {
      findings.add(AnalysisFinding(
        id: 'subtotal_ok',
        severity: FindingSeverity.ok,
        title: 'Subtotal matches item sum',
        explanation: 'The taxable amount matches the sum of individual items.',
        category: 'Arithmetic',
      ));
    }
  }

  // ─── CGST/SGST mismatch ────────────────────────────────────────────────────
  // Only check if we have BOTH amounts AND the rate — otherwise skip

  void _checkCgstSgstMismatch(StructuredBill bill, List<AnalysisFinding> findings) {
    final taxes = bill.taxes;

    // Need: cgstAmount, sgstAmount, and AT LEAST ONE rate
    if (taxes.cgstAmount == null || taxes.sgstAmount == null) return;
    if (taxes.cgstRate == null || taxes.sgstRate == null) {
      // We have amounts but no rate — can only verify equality, not calculation
      return;
    }

    final base = taxes.subtotal ?? bill.computedSubtotal;
    // Need a valid base amount to verify
    if (base <= 0) return;

    // Sanity check: the base should be > tax (tax can't be more than 50% of base)
    if (taxes.cgstAmount! > base * 0.5) return;

    final expectedCgst = _round2(base * taxes.cgstRate! / 100.0);
    final expectedSgst = _round2(base * taxes.sgstRate! / 100.0);
    final cgstDiff = (taxes.cgstAmount! - expectedCgst).abs();
    final sgstDiff = (taxes.sgstAmount! - expectedSgst).abs();

    // Use ₹2 tolerance to account for multi-slab rounding
    if (cgstDiff > 2.0) {
      findings.add(AnalysisFinding(
        id: 'cgst_mismatch',
        severity: FindingSeverity.error,
        title: 'CGST amount does not match the rate',
        explanation: 'The CGST amount printed does not equal the taxable amount × CGST rate.',
        whatFound: '₹${taxes.cgstAmount!.toStringAsFixed(2)} printed',
        whatExpected: '₹${expectedCgst.toStringAsFixed(2)} (${taxes.cgstRate}% of ₹${base.toStringAsFixed(2)})',
        difference: cgstDiff,
        recommendation: 'Verify CGST calculation with the establishment.',
        category: 'GST',
        source: _govService.cgstSource,
      ));
    }

    if (sgstDiff > 2.0) {
      findings.add(AnalysisFinding(
        id: 'sgst_mismatch',
        severity: FindingSeverity.error,
        title: 'SGST amount does not match the rate',
        explanation: 'The SGST amount printed does not equal the taxable amount × SGST rate.',
        whatFound: '₹${taxes.sgstAmount!.toStringAsFixed(2)} printed',
        whatExpected: '₹${expectedSgst.toStringAsFixed(2)} (${taxes.sgstRate}% of ₹${base.toStringAsFixed(2)})',
        difference: sgstDiff,
        recommendation: 'Verify SGST calculation with the establishment.',
        category: 'GST',
        source: _govService.sgstSource,
      ));
    }

    if (cgstDiff <= 2.0 && sgstDiff <= 2.0) {
      findings.add(AnalysisFinding(
        id: 'cgst_sgst_ok',
        severity: FindingSeverity.ok,
        title: 'CGST and SGST calculations are correct',
        explanation: 'CGST (${taxes.cgstRate}%) and SGST (${taxes.sgstRate}%) match the printed rates.',
        category: 'GST',
        source: _govService.cgstSource,
      ));
    }
  }

  // ─── IGST mismatch ─────────────────────────────────────────────────────────

  void _checkIgstMismatch(StructuredBill bill, List<AnalysisFinding> findings) {
    final taxes = bill.taxes;
    if (taxes.igstAmount == null || taxes.igstRate == null) return;

    final base = taxes.subtotal ?? bill.computedSubtotal;
    if (base <= 0) return;
    if (taxes.igstAmount! > base * 0.5) return; // sanity check

    final expectedIgst = _round2(base * taxes.igstRate! / 100.0);
    final diff = (taxes.igstAmount! - expectedIgst).abs();

    if (diff > 2.0) {
      findings.add(AnalysisFinding(
        id: 'igst_mismatch',
        severity: FindingSeverity.error,
        title: 'IGST amount does not match the rate',
        explanation: 'The IGST amount printed does not equal the taxable amount × IGST rate.',
        whatFound: '₹${taxes.igstAmount!.toStringAsFixed(2)} printed',
        whatExpected: '₹${expectedIgst.toStringAsFixed(2)} (${taxes.igstRate}% of ₹${base.toStringAsFixed(2)})',
        difference: diff,
        recommendation: 'Verify IGST calculation with the establishment.',
        category: 'GST',
        source: _govService.igstSource,
      ));
    } else {
      findings.add(AnalysisFinding(
        id: 'igst_ok',
        severity: FindingSeverity.ok,
        title: 'IGST calculation is correct',
        explanation: 'IGST (${taxes.igstRate}%) matches the printed amount.',
        category: 'GST',
        source: _govService.igstSource,
      ));
    }
  }

  // ─── Grand total mismatch ──────────────────────────────────────────────────
  // Only run if we have a printed total AND a usable base amount

  void _checkTotalMismatch(StructuredBill bill, List<AnalysisFinding> findings) {
    if (bill.grandTotal == null) return;

    final taxes = bill.taxes;
    final base = taxes.subtotal ?? bill.computedSubtotal;
    final totalTax = taxes.totalPrintedTax;
    final charges = bill.totalCharges;
    final roundOff = taxes.roundOff ?? 0;

    // If we have neither a printed subtotal nor extracted items, skip this check
    // to avoid false positives from incomplete parsing
    if (base <= 0 && totalTax <= 0) return;

    // If base is 0 but we have taxes and grand total — something is missing
    if (base <= 0) return;

    final computedTotal = _round2(base + totalTax + charges + roundOff);
    final diff = (bill.grandTotal! - computedTotal).abs();

    // Use a wider tolerance: ₹10 for multi-slab GST bills where parsing may miss slabs
    // Only flag as suspicious if the difference is large AND we have high-quality data
    final hasPrintedSubtotal = taxes.subtotal != null;
    final hasTaxAmounts = totalTax > 0;

    if (hasPrintedSubtotal && hasTaxAmounts && diff > 10.0) {
      findings.add(AnalysisFinding(
        id: 'total_mismatch',
        severity: FindingSeverity.suspicious,
        title: 'Bill total does not match the calculated amount',
        explanation: 'The grand total printed differs from: taxable amount + taxes + charges.',
        whatFound: '₹${bill.grandTotal!.toStringAsFixed(2)} (printed)',
        whatExpected:
            '₹${computedTotal.toStringAsFixed(2)} (calculated: ₹${base.toStringAsFixed(2)} base + ₹${totalTax.toStringAsFixed(2)} tax + ₹${charges.toStringAsFixed(2)} charges)',
        difference: diff,
        recommendation: 'Ask the establishment to explain the difference of ₹${diff.toStringAsFixed(2)}.',
        category: 'Arithmetic',
        source: _govService.arithmeticSource,
      ));
    } else if (hasPrintedSubtotal && hasTaxAmounts && diff <= 10.0) {
      findings.add(AnalysisFinding(
        id: 'total_ok',
        severity: FindingSeverity.ok,
        title: 'Grand total is correct',
        explanation: 'The printed grand total matches the calculated sum (within rounding tolerance).',
        category: 'Arithmetic',
      ));
    }
    // If data is incomplete — silently skip, no false alarms
  }

  // ─── CGST ≠ SGST check ─────────────────────────────────────────────────────
  // On multi-slab bills, CGST ≠ SGST is perfectly normal (different slabs sum differently)
  // Only flag if we have single-rate and the amounts differ significantly

  void _checkCgstSgstEquality(StructuredBill bill, List<AnalysisFinding> findings) {
    final taxes = bill.taxes;
    if (taxes.cgstAmount == null || taxes.sgstAmount == null) return;

    // If rates are known and equal, expect equal amounts
    final ratesEqual = taxes.cgstRate != null &&
        taxes.sgstRate != null &&
        (taxes.cgstRate! - taxes.sgstRate!).abs() < 0.01;

    if (!ratesEqual) return; // Multi-slab or unknown rates — don't check

    final diff = (taxes.cgstAmount! - taxes.sgstAmount!).abs();
    // Very strict: only flag if difference > ₹2 and rates are definitively equal
    if (diff > 2.0) {
      findings.add(AnalysisFinding(
        id: 'cgst_sgst_inequality',
        severity: FindingSeverity.verify,
        title: 'CGST and SGST amounts differ',
        explanation:
            'For intra-state supplies at the same rate, CGST and SGST should be equal.',
        whatFound: 'CGST=₹${taxes.cgstAmount!.toStringAsFixed(2)}, SGST=₹${taxes.sgstAmount!.toStringAsFixed(2)}',
        whatExpected: 'CGST = SGST',
        difference: diff,
        recommendation: 'Verify with the seller that the GST split is correct.',
        category: 'GST',
        source: _govService.cgstSource,
      ));
    }
  }

  // ─── Duplicate tax check ───────────────────────────────────────────────────

  void _checkDuplicateTax(StructuredBill bill, List<AnalysisFinding> findings) {
    final taxes = bill.taxes;
    if (taxes.igstAmount != null &&
        (taxes.cgstAmount != null || taxes.sgstAmount != null)) {
      findings.add(AnalysisFinding(
        id: 'duplicate_tax',
        severity: FindingSeverity.suspicious,
        title: 'Both IGST and CGST/SGST appear on the same bill',
        explanation:
            'A bill should have either IGST (inter-state) OR CGST+SGST (intra-state), not both. '
            'This may indicate a tax error.',
        recommendation: 'Ask the seller to clarify — both cannot apply simultaneously.',
        category: 'GST',
        source: _govService.cgstSource,
      ));
    }
  }

  // ─── Service charge on top of GST ─────────────────────────────────────────

  void _checkServiceChargeTax(StructuredBill bill, List<AnalysisFinding> findings) {
    if (bill.billType != BillType.restaurant && bill.billType != BillType.hotel) return;
    for (final charge in bill.charges) {
      if (charge.isServiceCharge) {
        findings.add(AnalysisFinding(
          id: 'service_charge_found_${charge.label}',
          severity: FindingSeverity.verify,
          title: 'Service charge detected',
          explanation:
              'A service charge of ₹${charge.amount.toStringAsFixed(2)} was found. '
              'According to CCPA guidelines, service charge should not be automatically added '
              'and customers are not obligated to pay it. You may request it to be removed.',
          whatFound: '${charge.label}: ₹${charge.amount.toStringAsFixed(2)}',
          recommendation:
              'If this was added automatically (not disclosed before ordering), '
              'you may request the establishment to remove it.',
          category: 'Service Charge',
          source: _govService.ccpaServiceChargeSource,
        ));

        if (charge.taxApplied) {
          findings.add(AnalysisFinding(
            id: 'gst_on_service_charge_${charge.label}',
            severity: FindingSeverity.suspicious,
            title: 'GST applied on top of service charge',
            explanation:
                'GST appears to have been charged on the service charge amount. '
                'If the service charge itself is considered a voluntary tip, applying GST on it may be questionable.',
            recommendation: 'Ask the establishment to clarify the GST basis.',
            category: 'Service Charge',
            source: _govService.ccpaServiceChargeSource,
          ));
        }
      }
    }
  }

  // ─── Rounding check ────────────────────────────────────────────────────────

  void _checkRounding(StructuredBill bill, List<AnalysisFinding> findings) {
    if (bill.grandTotal == null) return;
    final roundOff = bill.taxes.roundOff;
    if (roundOff != null && roundOff.abs() > 5.0) {
      findings.add(AnalysisFinding(
        id: 'excessive_rounding',
        severity: FindingSeverity.verify,
        title: 'Unusual rounding amount',
        explanation:
            'The round-off adjustment of ₹${roundOff.abs().toStringAsFixed(2)} seems large. '
            'Normal rounding should be less than ₹1.',
        difference: roundOff.abs(),
        recommendation: 'Verify the final total calculation with the establishment.',
        category: 'Arithmetic',
      ));
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  double _round2(double v) => double.parse(v.toStringAsFixed(2));

  // ─── CESS Validation ─────────────────────────────────────────────────────
  // Cess amount should not exceed a reasonable percentage of taxable value.

  void _checkCessValidation(StructuredBill bill, List<AnalysisFinding> findings) {
    final taxes = bill.taxes;
    if (taxes.cessAmount == null || taxes.cessAmount! <= 0) return;

    final base = taxes.subtotal ?? bill.computedSubtotal;
    if (base <= 0) return;

    final cessPct = (taxes.cessAmount! / base) * 100;
    if (cessPct > 40) {
      findings.add(AnalysisFinding(
        id: 'excessive_cess',
        severity: FindingSeverity.suspicious,
        title: 'CESS amount seems unusually high',
        explanation:
            'CESS of ₹${taxes.cessAmount!.toStringAsFixed(2)} (${cessPct.toStringAsFixed(1)}% of taxable value) '
            'was found. Standard CESS rates rarely exceed 36%. This may indicate a calculation error.',
        whatFound: '₹${taxes.cessAmount!.toStringAsFixed(2)} (${cessPct.toStringAsFixed(1)}%)',
        recommendation: 'Verify the CESS rate with the seller.',
        category: 'GST',
        source: _govService.cgstSource,
      ));
    }
  }

  // ─── Reverse Charge Indicator ────────────────────────────────────────────

  void _checkReverseCharge(StructuredBill bill, List<AnalysisFinding> findings) {
    if (bill.gstin == null) return;
    if (bill.grandTotal == null || bill.grandTotal! < 5000) return;

    final hasReverseCharge = bill.rawText.toLowerCase().contains('reverse charge') ||
        bill.rawText.toLowerCase().contains('rcm');

    if (!hasReverseCharge && bill.grandTotal! >= 50000) {
      findings.add(AnalysisFinding(
        id: 'missing_reverse_charge',
        severity: FindingSeverity.verify,
        title: 'No reverse charge indication on GST invoice',
        explanation:
            'This GST-registered invoice of ₹${bill.grandTotal!.toStringAsFixed(2)} does not mention '
            'reverse charge mechanism (RCM). For B2B transactions above ₹50,000, '
            'reverse charge applicability should be indicated.',
        recommendation:
            'Verify if reverse charge applies to this transaction.',
        category: 'GST',
        source: _govService.gstinSource,
      ));
    }
  }

  // ─── Multi-Slab Consistency ──────────────────────────────────────────────

  void _checkMultiSlabConsistency(StructuredBill bill, List<AnalysisFinding> findings) {
    final hsnRates = <String, Set<double>>{};
    for (final item in bill.items) {
      if (item.hsnSac == null || item.hsnSac!.isEmpty) continue;
      final rate = item.gstRate ?? ((item.cgstRate ?? 0) + (item.sgstRate ?? 0));
      if (rate <= 0) continue;

      hsnRates.putIfAbsent(item.hsnSac!, () => {}).add(rate);
    }

    for (final entry in hsnRates.entries) {
      if (entry.value.length > 1) {
        final rates = entry.value.map((r) => '${r.toStringAsFixed(1)}%').join(', ');
        findings.add(AnalysisFinding(
          id: 'hsn_rate_mismatch_${entry.key}',
          severity: FindingSeverity.suspicious,
          title: 'Same HSN code with different GST rates',
          explanation:
              'Items with HSN code ${entry.key} have different GST rates: $rates. '
              'The same HSN/SAC code should always have the same GST rate.',
          whatFound: 'HSN ${entry.key}: rates $rates',
          recommendation: 'Verify the correct GST rate for this HSN code.',
          category: 'GST',
          source: _govService.gstinSource,
        ));
      }
    }
  }
}
