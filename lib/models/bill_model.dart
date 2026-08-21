/// Structured bill data model.
/// Populated by BillParserService from raw OCR text.

enum BillType {
  restaurant,
  hotel,
  shopping,
  supermarket,
  pharmacy,
  fuel,
  electronics,
  service,
  gstInvoice,
  ecommerce,
  unknown,
}

extension BillTypeLabel on BillType {
  String get displayName {
    switch (this) {
      case BillType.restaurant: return 'Restaurant';
      case BillType.hotel: return 'Hotel';
      case BillType.shopping: return 'Shopping';
      case BillType.supermarket: return 'Supermarket';
      case BillType.pharmacy: return 'Pharmacy / Medical';
      case BillType.fuel: return 'Fuel / Petrol';
      case BillType.electronics: return 'Electronics';
      case BillType.service: return 'Service';
      case BillType.gstInvoice: return 'GST Invoice';
      case BillType.ecommerce: return 'E-Commerce';
      case BillType.unknown: return 'Unknown';
    }
  }

  String get emoji {
    switch (this) {
      case BillType.restaurant: return '🍽️';
      case BillType.hotel: return '🏨';
      case BillType.shopping: return '🛍️';
      case BillType.supermarket: return '🛒';
      case BillType.pharmacy: return '💊';
      case BillType.fuel: return '⛽';
      case BillType.electronics: return '📱';
      case BillType.service: return '🔧';
      case BillType.gstInvoice: return '🧾';
      case BillType.ecommerce: return '📦';
      case BillType.unknown: return '📄';
    }
  }
}

/// A single line item on the bill.
class BillItem {
  final String name;
  final double? quantity;
  final String? unit;
  final double? unitPrice;
  final double? discount;
  final double? taxableValue;
  final double? gstRate;   // total GST % (e.g. 5, 12, 18, 28)
  final double? cgstRate;
  final double? sgstRate;
  final double? igstRate;
  final double? cgstAmount;
  final double? sgstAmount;
  final double? igstAmount;
  final double? cessAmount;
  final double? lineTotal;
  final String? hsnSac;
  /// Confidence 0.0–1.0 that the parsed values are correct.
  final double confidence;

  const BillItem({
    required this.name,
    this.quantity,
    this.unit,
    this.unitPrice,
    this.discount,
    this.taxableValue,
    this.gstRate,
    this.cgstRate,
    this.sgstRate,
    this.igstRate,
    this.cgstAmount,
    this.sgstAmount,
    this.igstAmount,
    this.cessAmount,
    this.lineTotal,
    this.hsnSac,
    this.confidence = 1.0,
  });

  /// Recompute taxable value from qty × unitPrice − discount.
  double? get computedTaxable {
    if (unitPrice == null) return taxableValue;
    final qty = quantity ?? 1.0;
    final disc = discount ?? 0.0;
    return (unitPrice! * qty) - disc;
  }

  /// Expected total tax for this item based on printed rates.
  double? get expectedTax {
    final base = computedTaxable ?? taxableValue;
    if (base == null) return null;
    if (cgstRate != null && sgstRate != null) {
      return base * (cgstRate! + sgstRate!) / 100.0;
    }
    if (igstRate != null) return base * igstRate! / 100.0;
    if (gstRate != null) return base * gstRate! / 100.0;
    return null;
  }

  double? get printedTax {
    double t = 0;
    if (cgstAmount != null) t += cgstAmount!;
    if (sgstAmount != null) t += sgstAmount!;
    if (igstAmount != null) t += igstAmount!;
    if (t > 0) return t;
    return null;
  }
}

/// Tax totals section of the bill.
class BillTaxSection {
  final double? subtotal;       // taxable amount
  final double? cgstAmount;
  final double? sgstAmount;
  final double? igstAmount;
  final double? cgstRate;
  final double? sgstRate;
  final double? igstRate;
  final double? cessAmount;
  final double? roundOff;

  const BillTaxSection({
    this.subtotal,
    this.cgstAmount,
    this.sgstAmount,
    this.igstAmount,
    this.cgstRate,
    this.sgstRate,
    this.igstRate,
    this.cessAmount,
    this.roundOff,
  });

  double get totalPrintedTax {
    double t = 0;
    if (cgstAmount != null) t += cgstAmount!;
    if (sgstAmount != null) t += sgstAmount!;
    if (igstAmount != null) t += igstAmount!;
    if (cessAmount != null) t += cessAmount!;
    return t;
  }

  /// Calculates effective GST percentage against taxable subtotal.
  double? get effectiveGstRate {
    if (subtotal != null && subtotal! > 0 && totalPrintedTax > 0) {
      return (totalPrintedTax / subtotal!) * 100.0;
    }
    if (cgstRate != null && sgstRate != null) {
      return cgstRate! + sgstRate!;
    }
    if (igstRate != null) {
      return igstRate!;
    }
    return null;
  }
}

/// Extra charge on the bill (service charge, packaging, delivery, etc.)
class BillCharge {
  final String label;
  final double amount;
  final bool taxApplied;  // was GST applied on top of this charge?

  const BillCharge({
    required this.label,
    required this.amount,
    this.taxApplied = false,
  });

  bool get isServiceCharge {
    final l = label.toLowerCase();
    return l.contains('service charge') ||
        l.contains('service fee') ||
        l.contains('hospitality') ||
        l.contains('staff charge');
  }

  bool get isPackaging {
    final l = label.toLowerCase();
    return l.contains('pack') || l.contains('bag') || l.contains('carry');
  }

  bool get isDelivery {
    final l = label.toLowerCase();
    return l.contains('delivery') || l.contains('shipping') || l.contains('logistic');
  }

  bool get isConvenienceFee {
    final l = label.toLowerCase();
    return l.contains('convenience') || l.contains('platform') || l.contains('processing');
  }
}

/// Fully structured bill extracted from OCR.
class StructuredBill {
  final String rawText;
  final BillType billType;

  // Seller
  final String? sellerName;
  final String? gstin;
  final String? sellerAddress;

  // Customer
  final String? customerName;
  final String? customerGstin;

  // Invoice meta
  final String? invoiceNumber;
  final DateTime? invoiceDate;

  // Items
  final List<BillItem> items;

  // Tax section
  final BillTaxSection taxes;

  // Extra charges
  final List<BillCharge> charges;

  // Totals
  final double? grandTotal;
  final double? discountTotal;

  // QR data (if available from QR scanner)
  final Map<String, dynamic>? qrData;

  /// Overall confidence 0.0–1.0 in the parsed data.
  final double confidence;

  // AI Enhancement
  final bool isAiEnhanced;
  final String? aiNotes;
  final String? aiModelUsed;

  const StructuredBill({
    required this.rawText,
    required this.billType,
    this.sellerName,
    this.gstin,
    this.sellerAddress,
    this.customerName,
    this.customerGstin,
    this.invoiceNumber,
    this.invoiceDate,
    required this.items,
    required this.taxes,
    required this.charges,
    this.grandTotal,
    this.discountTotal,
    this.qrData,
    required this.confidence,
    this.isAiEnhanced = false,
    this.aiNotes,
    this.aiModelUsed,
  });

  /// Sum of all item taxable values.
  double get computedSubtotal =>
      items.fold(0.0, (s, i) => s + (i.computedTaxable ?? i.taxableValue ?? 0.0));

  /// Sum of gross items amount before bill-level discounts.
  double get itemsGrossTotal => items.fold(
        0.0,
        (s, i) => s + (i.lineTotal ?? ((i.unitPrice ?? 0.0) * (i.quantity ?? 1.0))),
      );

  /// Total discount across bill and individual item discounts.
  double get totalDiscountAmount =>
      (discountTotal ?? 0.0) +
      items.fold(0.0, (s, i) => s + (i.discount ?? 0.0));

  /// Sum of extra charges.
  double get totalCharges =>
      charges.fold(0.0, (s, c) => s + c.amount);

  /// Is this an intra-state bill (CGST + SGST)?
  bool get isIntraState =>
      taxes.cgstAmount != null || taxes.cgstRate != null || (taxes.sgstAmount != null);

  /// Is this an inter-state bill (IGST)?
  bool get isInterState =>
      taxes.igstAmount != null || taxes.igstRate != null;

  /// Mathematically calculated net total based on parsed components.
  double? get calculatedNetTotal {
    final base = taxes.subtotal ?? (computedSubtotal > 0 ? computedSubtotal : null);
    if (base != null && base > 0) {
      return base + taxes.totalPrintedTax + totalCharges + (taxes.roundOff ?? 0.0);
    }
    if (itemsGrossTotal > 0) {
      final netItems = itemsGrossTotal - totalDiscountAmount;
      return netItems + taxes.totalPrintedTax + totalCharges + (taxes.roundOff ?? 0.0);
    }
    return grandTotal;
  }
}
