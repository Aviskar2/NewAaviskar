/// Synthetic bill generator for testing fraud detection.
/// Creates test bills with known fraud patterns to verify each detection rule.
library;

import 'package:scan_sure/models/bill_model.dart';

enum FraudPattern {
  cgstSgstMismatch,
  igstMismatch,
  grandTotalMismatch,
  duplicateItem,
  excessivePackaging,
  serviceChargeWithGst,
  roundAmountSuspicious,
  thresholdManipulation,
  phantomItemZeroQty,
  missingHsnSac,
  futureDate,
  excessiveDiscount,
  chargesWithoutItems,
  excessiveChargeRatio,
  duplicateConvenienceFee,
  duplicateDelivery,
  itemTotalMismatch,
  qrGstinMismatch,
  qrTotalMismatch,
  invalidGstin,
  normalBill,
}

class SyntheticBillGenerator {
  /// Generate a StructuredBill with a specific fraud pattern embedded.
  static StructuredBill generate(FraudPattern pattern) {
    switch (pattern) {
      case FraudPattern.cgstSgstMismatch:
        return _cgstSgstMismatch();
      case FraudPattern.igstMismatch:
        return _igstMismatch();
      case FraudPattern.grandTotalMismatch:
        return _grandTotalMismatch();
      case FraudPattern.duplicateItem:
        return _duplicateItem();
      case FraudPattern.excessivePackaging:
        return _excessivePackaging();
      case FraudPattern.serviceChargeWithGst:
        return _serviceChargeWithGst();
      case FraudPattern.roundAmountSuspicious:
        return _roundAmountSuspicious();
      case FraudPattern.thresholdManipulation:
        return _thresholdManipulation();
      case FraudPattern.phantomItemZeroQty:
        return _phantomItemZeroQty();
      case FraudPattern.missingHsnSac:
        return _missingHsnSac();
      case FraudPattern.futureDate:
        return _futureDate();
      case FraudPattern.excessiveDiscount:
        return _excessiveDiscount();
      case FraudPattern.chargesWithoutItems:
        return _chargesWithoutItems();
      case FraudPattern.excessiveChargeRatio:
        return _excessiveChargeRatio();
      case FraudPattern.duplicateConvenienceFee:
        return _duplicateConvenienceFee();
      case FraudPattern.duplicateDelivery:
        return _duplicateDelivery();
      case FraudPattern.itemTotalMismatch:
        return _itemTotalMismatch();
      case FraudPattern.qrGstinMismatch:
        return _qrGstinMismatch();
      case FraudPattern.qrTotalMismatch:
        return _qrTotalMismatch();
      case FraudPattern.invalidGstin:
        return _invalidGstin();
      case FraudPattern.normalBill:
        return _normalBill();
    }
  }

  // ─── Clean Bills ─────────────────────────────────────────────────────────

  static StructuredBill _normalBill() {
    return StructuredBill(
      rawText: '_NORMAL BILL',
      billType: BillType.restaurant,
      sellerName: 'Green Leaf Restaurant',
      gstin: '27AAPFU0939F1ZV',
      invoiceNumber: 'INV-001',
      invoiceDate: DateTime(2026, 3, 15),
      items: [
        const BillItem(name: 'Paneer Tikka', quantity: 1, unitPrice: 280, lineTotal: 280, gstRate: 5, cgstRate: 2.5, sgstRate: 2.5),
        const BillItem(name: 'Naan', quantity: 2, unitPrice: 40, lineTotal: 80, gstRate: 5, cgstRate: 2.5, sgstRate: 2.5),
        const BillItem(name: 'Jeera Rice', quantity: 1, unitPrice: 120, lineTotal: 120, gstRate: 5, cgstRate: 2.5, sgstRate: 2.5),
      ],
      taxes: const BillTaxSection(subtotal: 480, cgstAmount: 12, sgstAmount: 12, cgstRate: 2.5, sgstRate: 2.5),
      charges: const [],
      grandTotal: 504,
      confidence: 0.95,
    );
  }

  // ─── GST Fraud Bills ─────────────────────────────────────────────────────

  static StructuredBill _cgstSgstMismatch() {
    return StructuredBill(
      rawText: 'CGST/SGST MISMATCH BILL',
      billType: BillType.restaurant,
      sellerName: 'Spice Garden',
      gstin: '27AAPFU0939F1ZV',
      invoiceNumber: 'INV-101',
      invoiceDate: DateTime(2026, 4, 10),
      items: [
        const BillItem(name: 'Biryani', quantity: 1, unitPrice: 350, lineTotal: 350, gstRate: 5, cgstRate: 2.5, sgstRate: 2.5),
        const BillItem(name: 'Raita', quantity: 1, unitPrice: 60, lineTotal: 60, gstRate: 5, cgstRate: 2.5, sgstRate: 2.5),
      ],
      // CGST=10.25 but SGST=14 — mismatch at same rate
      taxes: const BillTaxSection(subtotal: 410, cgstAmount: 10.25, sgstAmount: 14, cgstRate: 2.5, sgstRate: 2.5),
      charges: const [],
      grandTotal: 434.25,
      confidence: 0.9,
    );
  }

  static StructuredBill _igstMismatch() {
    return StructuredBill(
      rawText: 'IGST MISMATCH BILL',
      billType: BillType.gstInvoice,
      sellerName: 'Mumbai Electronics',
      gstin: '27AAPFU0939F1ZV',
      invoiceNumber: 'INV-201',
      invoiceDate: DateTime(2026, 5, 1),
      items: [
        const BillItem(name: 'Laptop', quantity: 1, unitPrice: 55000, lineTotal: 55000, igstRate: 18),
        const BillItem(name: 'Mouse', quantity: 1, unitPrice: 800, lineTotal: 800, igstRate: 18),
      ],
      // IGST should be 10044 but printed as 8000
      taxes: const BillTaxSection(subtotal: 55800, igstAmount: 8000, igstRate: 18),
      charges: const [],
      grandTotal: 63800,
      confidence: 0.9,
    );
  }

  static StructuredBill _grandTotalMismatch() {
    return StructuredBill(
      rawText: 'TOTAL MISMATCH BILL',
      billType: BillType.shopping,
      sellerName: 'Fashion Hub',
      gstin: '27AAPFU0939F1ZV',
      invoiceNumber: 'INV-301',
      invoiceDate: DateTime(2026, 6, 15),
      items: [
        const BillItem(name: 'Shirt', quantity: 2, unitPrice: 800, lineTotal: 1600, gstRate: 5, cgstRate: 2.5, sgstRate: 2.5),
        const BillItem(name: 'Trousers', quantity: 1, unitPrice: 1200, lineTotal: 1200, gstRate: 5, cgstRate: 2.5, sgstRate: 2.5),
      ],
      taxes: const BillTaxSection(subtotal: 2800, cgstAmount: 70, sgstAmount: 70, cgstRate: 2.5, sgstRate: 2.5),
      charges: const [],
      // Correct total should be 2940, but printed as 3200
      grandTotal: 3200,
      confidence: 0.9,
    );
  }

  // ─── Item Fraud Bills ────────────────────────────────────────────────────

  static StructuredBill _duplicateItem() {
    return StructuredBill(
      rawText: 'DUPLICATE ITEM BILL',
      billType: BillType.supermarket,
      sellerName: 'Quick Mart',
      gstin: '27AABCU9603R1ZM',
      invoiceNumber: 'INV-401',
      invoiceDate: DateTime(2026, 7, 1),
      items: [
        const BillItem(name: 'Milk 1L', quantity: 2, unitPrice: 56, lineTotal: 112),
        const BillItem(name: 'Bread', quantity: 1, unitPrice: 40, lineTotal: 40),
        const BillItem(name: 'Milk 1L', quantity: 2, unitPrice: 56, lineTotal: 112), // Duplicate!
      ],
      taxes: const BillTaxSection(subtotal: 264, cgstAmount: 3.96, sgstAmount: 3.96, cgstRate: 1.5, sgstRate: 1.5),
      charges: const [],
      grandTotal: 271.92,
      confidence: 0.85,
    );
  }

  static StructuredBill _excessivePackaging() {
    return StructuredBill(
      rawText: 'EXCESSIVE PACKAGING BILL',
      billType: BillType.ecommerce,
      sellerName: 'Online Bazaar',
      gstin: '29AACCM1234F1Z5',
      invoiceNumber: 'INV-501',
      invoiceDate: DateTime(2026, 8, 10),
      items: [
        const BillItem(name: 'T-Shirt', quantity: 1, unitPrice: 500, lineTotal: 500, gstRate: 5),
      ],
      taxes: const BillTaxSection(subtotal: 500, cgstAmount: 12.5, sgstAmount: 12.5, cgstRate: 2.5, sgstRate: 2.5),
      charges: [
        const BillCharge(label: 'Packaging Fee', amount: 150, taxApplied: true), // Excessive!
      ],
      grandTotal: 675,
      confidence: 0.9,
    );
  }

  static StructuredBill _serviceChargeWithGst() {
    return StructuredBill(
      rawText: 'SERVICE CHARGE + GST BILL',
      billType: BillType.restaurant,
      sellerName: 'Grand Dining',
      gstin: '07AABCU9603R1ZM',
      invoiceNumber: 'INV-601',
      invoiceDate: DateTime(2026, 9, 5),
      items: [
        const BillItem(name: 'Dosa', quantity: 2, unitPrice: 120, lineTotal: 240, gstRate: 5),
        const BillItem(name: 'Coffee', quantity: 2, unitPrice: 60, lineTotal: 120, gstRate: 5),
      ],
      taxes: const BillTaxSection(subtotal: 360, cgstAmount: 9, sgstAmount: 9, cgstRate: 2.5, sgstRate: 2.5),
      charges: [
        const BillCharge(label: 'Service Charge', amount: 36, taxApplied: true), // GST on service charge!
      ],
      grandTotal: 414,
      confidence: 0.9,
    );
  }

  // ─── Pattern Fraud Bills ─────────────────────────────────────────────────

  static StructuredBill _roundAmountSuspicious() {
    return StructuredBill(
      rawText: 'ROUND AMOUNT BILL',
      billType: BillType.shopping,
      sellerName: 'Luxe Boutique',
      gstin: '27AAPFU0939F1ZV',
      invoiceNumber: 'INV-701',
      invoiceDate: DateTime(2026, 10, 20),
      items: [
        const BillItem(name: 'Watch', quantity: 1, unitPrice: 3200, lineTotal: 3200, gstRate: 18),
        const BillItem(name: 'Chain', quantity: 1, unitPrice: 1800, lineTotal: 1800, gstRate: 3),
      ],
      taxes: const BillTaxSection(subtotal: 5000, cgstAmount: 300, sgstAmount: 300, cgstRate: 3, sgstRate: 3),
      charges: const [],
      // Suspiciously round ₹5000 total
      grandTotal: 5000,
      confidence: 0.9,
    );
  }

  static StructuredBill _thresholdManipulation() {
    return StructuredBill(
      rawText: 'THRESHOLD MANIPULATION BILL',
      billType: BillType.service,
      sellerName: 'Tech Solutions',
      gstin: '29AACCM1234F1Z5',
      invoiceNumber: 'INV-801',
      invoiceDate: DateTime(2026, 11, 1),
      items: [
        const BillItem(name: 'Consulting', quantity: 1, unitPrice: 4200, lineTotal: 4200, gstRate: 18),
        const BillItem(name: 'Support', quantity: 1, unitPrice: 500, lineTotal: 500, gstRate: 18),
      ],
      taxes: const BillTaxSection(subtotal: 4700, cgstAmount: 423, sgstAmount: 423, cgstRate: 9, sgstRate: 9),
      charges: const [BillCharge(label: 'Processing Fee', amount: 100)],
      // Just below ₹5000 threshold
      grandTotal: 4999,
      confidence: 0.9,
    );
  }

  static StructuredBill _phantomItemZeroQty() {
    return StructuredBill(
      rawText: 'PHANTOM ITEM BILL',
      billType: BillType.supermarket,
      sellerName: 'Fresh Grocery',
      gstin: '27AABCU9603R1ZM',
      invoiceNumber: 'INV-901',
      invoiceDate: DateTime(2026, 12, 1),
      items: [
        const BillItem(name: 'Rice 5kg', quantity: 1, unitPrice: 350, lineTotal: 350),
        const BillItem(name: 'Sugar 1kg', quantity: 0, unitPrice: 80, lineTotal: 0), // Zero qty!
        const BillItem(name: 'Oil 1L', quantity: 1, unitPrice: 180, lineTotal: 180),
      ],
      taxes: const BillTaxSection(subtotal: 530, cgstAmount: 5.3, sgstAmount: 5.3, cgstRate: 1, sgstRate: 1),
      charges: const [],
      grandTotal: 540.6,
      confidence: 0.85,
    );
  }

  static StructuredBill _missingHsnSac() {
    return StructuredBill(
      rawText: 'MISSING HSN BILL',
      billType: BillType.gstInvoice,
      sellerName: 'Wholesale Trading Co',
      gstin: '07AABCU9603R1ZM',
      invoiceNumber: 'INV-1001',
      invoiceDate: DateTime(2026, 2, 14),
      items: [
        const BillItem(name: 'Widget A', quantity: 10, unitPrice: 150, lineTotal: 1500, gstRate: 18),
        const BillItem(name: 'Widget B', quantity: 5, unitPrice: 300, lineTotal: 1500, gstRate: 18),
        const BillItem(name: 'Service X', quantity: 1, unitPrice: 2000, lineTotal: 2000, gstRate: 18),
      ],
      taxes: const BillTaxSection(subtotal: 5000, cgstAmount: 450, sgstAmount: 450, cgstRate: 9, sgstRate: 9),
      charges: const [],
      grandTotal: 5900,
      confidence: 0.9,
    );
  }

  static StructuredBill _futureDate() {
    return StructuredBill(
      rawText: 'FUTURE DATE BILL',
      billType: BillType.shopping,
      sellerName: 'Style Store',
      gstin: '27AAPFU0939F1ZV',
      invoiceNumber: 'INV-1101',
      invoiceDate: DateTime(2027, 12, 31), // Future date!
      items: [
        const BillItem(name: 'Jacket', quantity: 1, unitPrice: 2500, lineTotal: 2500, gstRate: 12),
      ],
      taxes: const BillTaxSection(subtotal: 2500, cgstAmount: 150, sgstAmount: 150, cgstRate: 6, sgstRate: 6),
      charges: const [],
      grandTotal: 2800,
      confidence: 0.9,
    );
  }

  static StructuredBill _excessiveDiscount() {
    return StructuredBill(
      rawText: 'EXCESSIVE DISCOUNT BILL',
      billType: BillType.electronics,
      sellerName: 'Gadget World',
      gstin: '29AACCM1234F1Z5',
      invoiceNumber: 'INV-1201',
      invoiceDate: DateTime(2026, 3, 20),
      items: [
        const BillItem(name: 'Headphones', quantity: 1, unitPrice: 2000, discount: 1800, lineTotal: 200, gstRate: 18),
        const BillItem(name: 'Case', quantity: 1, unitPrice: 500, discount: 0, lineTotal: 500, gstRate: 18),
      ],
      taxes: const BillTaxSection(subtotal: 700, cgstAmount: 63, sgstAmount: 63, cgstRate: 9, sgstRate: 9),
      charges: const [],
      grandTotal: 826,
      confidence: 0.9,
    );
  }

  static StructuredBill _chargesWithoutItems() {
    return StructuredBill(
      rawText: 'CHARGES ONLY BILL',
      billType: BillType.service,
      sellerName: 'Mystery Services',
      invoiceNumber: 'INV-1301',
      invoiceDate: DateTime(2026, 5, 10),
      items: const [],
      taxes: const BillTaxSection(),
      charges: [
        const BillCharge(label: 'Service Fee', amount: 500),
        const BillCharge(label: 'Processing', amount: 200),
        const BillCharge(label: 'Handling', amount: 150),
      ],
      grandTotal: 850,
      confidence: 0.7,
    );
  }

  static StructuredBill _excessiveChargeRatio() {
    return StructuredBill(
      rawText: 'EXCESSIVE CHARGES BILL',
      billType: BillType.ecommerce,
      sellerName: 'Express Delivery Co',
      gstin: '27AABCU9603R1ZM',
      invoiceNumber: 'INV-1401',
      invoiceDate: DateTime(2026, 6, 1),
      items: [
        const BillItem(name: 'Book', quantity: 1, unitPrice: 300, lineTotal: 300, gstRate: 0),
      ],
      taxes: const BillTaxSection(subtotal: 300),
      charges: [
        const BillCharge(label: 'Delivery', amount: 200),
        const BillCharge(label: 'Platform Fee', amount: 100),
        const BillCharge(label: 'Packaging', amount: 80),
        const BillCharge(label: 'Convenience', amount: 50),
      ],
      grandTotal: 730,
      confidence: 0.85,
    );
  }

  // ─── Charge Fraud Bills ──────────────────────────────────────────────────

  static StructuredBill _duplicateConvenienceFee() {
    return StructuredBill(
      rawText: 'DUPLICATE CONVENIENCE FEE BILL',
      billType: BillType.ecommerce,
      sellerName: 'Food Express',
      gstin: '27AABCU9603R1ZM',
      invoiceNumber: 'INV-1501',
      invoiceDate: DateTime(2026, 7, 15),
      items: [
        const BillItem(name: 'Pizza', quantity: 1, unitPrice: 400, lineTotal: 400, gstRate: 5),
      ],
      taxes: const BillTaxSection(subtotal: 400, cgstAmount: 10, sgstAmount: 10, cgstRate: 2.5, sgstRate: 2.5),
      charges: [
        const BillCharge(label: 'Platform Fee', amount: 30),
        const BillCharge(label: 'Convenience Charge', amount: 25), // Duplicate!
      ],
      grandTotal: 475,
      confidence: 0.9,
    );
  }

  static StructuredBill _duplicateDelivery() {
    return StructuredBill(
      rawText: 'DUPLICATE DELIVERY BILL',
      billType: BillType.ecommerce,
      sellerName: 'Swift Logistics',
      gstin: '29AACCM1234F1Z5',
      invoiceNumber: 'INV-1601',
      invoiceDate: DateTime(2026, 8, 20),
      items: [
        const BillItem(name: 'Keyboard', quantity: 1, unitPrice: 1500, lineTotal: 1500, gstRate: 18),
      ],
      taxes: const BillTaxSection(subtotal: 1500, cgstAmount: 135, sgstAmount: 135, cgstRate: 9, sgstRate: 9),
      charges: [
        const BillCharge(label: 'Delivery Charge', amount: 50),
        const BillCharge(label: 'Shipping Fee', amount: 40), // Duplicate!
      ],
      grandTotal: 1860,
      confidence: 0.9,
    );
  }

  static StructuredBill _itemTotalMismatch() {
    return StructuredBill(
      rawText: 'ITEM TOTAL MISMATCH BILL',
      billType: BillType.supermarket,
      sellerName: 'Daily Needs',
      gstin: '07AABCU9603R1ZM',
      invoiceNumber: 'INV-1701',
      invoiceDate: DateTime(2026, 9, 10),
      items: [
        // 3 × 120 = 360, but printed as 500
        const BillItem(name: 'Mangoes', quantity: 3, unitPrice: 120, lineTotal: 500),
        const BillItem(name: 'Bananas', quantity: 2, unitPrice: 40, lineTotal: 80),
      ],
      taxes: const BillTaxSection(subtotal: 580, cgstAmount: 5.8, sgstAmount: 5.8, cgstRate: 1, sgstRate: 1),
      charges: const [],
      grandTotal: 591.6,
      confidence: 0.85,
    );
  }

  // ─── QR Mismatch Bills ───────────────────────────────────────────────────

  static StructuredBill _qrGstinMismatch() {
    return StructuredBill(
      rawText: 'QR GSTIN MISMATCH BILL',
      billType: BillType.shopping,
      sellerName: 'City Mall',
      gstin: '27AAPFU0939F1ZV',
      invoiceNumber: 'INV-1801',
      invoiceDate: DateTime(2026, 10, 5),
      items: [
        const BillItem(name: 'Shoes', quantity: 1, unitPrice: 3000, lineTotal: 3000, gstRate: 18),
      ],
      taxes: const BillTaxSection(subtotal: 3000, cgstAmount: 270, sgstAmount: 270, cgstRate: 9, sgstRate: 9),
      charges: const [],
      grandTotal: 3540,
      qrData: const {'gstin': '29AACCM1234F1Z5', 'total': '3540'}, // Different GSTIN!
      confidence: 0.9,
    );
  }

  static StructuredBill _qrTotalMismatch() {
    return StructuredBill(
      rawText: 'QR TOTAL MISMATCH BILL',
      billType: BillType.restaurant,
      sellerName: 'Tasty Bites',
      gstin: '27AABCU9603R1ZM',
      invoiceNumber: 'INV-1901',
      invoiceDate: DateTime(2026, 11, 15),
      items: [
        const BillItem(name: 'Thali', quantity: 2, unitPrice: 200, lineTotal: 400, gstRate: 5),
      ],
      taxes: const BillTaxSection(subtotal: 400, cgstAmount: 10, sgstAmount: 10, cgstRate: 2.5, sgstRate: 2.5),
      charges: const [],
      grandTotal: 420,
      qrData: const {'gstin': '27AABCU9603R1ZM', 'total': '500'}, // QR says ₹500!
      confidence: 0.9,
    );
  }

  static StructuredBill _invalidGstin() {
    return StructuredBill(
      rawText: 'INVALID GSTIN BILL',
      billType: BillType.gstInvoice,
      sellerName: 'Fake Traders',
      gstin: '12AAAAA0000A1Z5', // Invalid checksum
      invoiceNumber: 'INV-2001',
      invoiceDate: DateTime(2026, 1, 10),
      items: [
        const BillItem(name: 'Widget', quantity: 10, unitPrice: 100, lineTotal: 1000, gstRate: 18),
      ],
      taxes: const BillTaxSection(subtotal: 1000, cgstAmount: 90, sgstAmount: 90, cgstRate: 9, sgstRate: 9),
      charges: const [],
      grandTotal: 1180,
      confidence: 0.85,
    );
  }
}
