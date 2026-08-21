/// Parses raw OCR text from ALL types of Indian bills into a StructuredBill.
/// Supports: Supermarket receipts, Restaurant bills, Pharmacy invoices,
///           GST tax invoices, E-commerce receipts, Fuel slips, Hotel bills.
/// Uses multi-strategy regex + heuristics. Deterministic — no LLM.

import '../models/bill_model.dart';

class BillParserService {
  /// Parse raw OCR text into a StructuredBill.
  StructuredBill parse(String rawText, {BillType? forcedType}) {
    // Normalize: trim, collapse multiple spaces inside lines, keep structure
    final normalized = _normalizeText(rawText);
    final lines = normalized
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final billType = forcedType ?? _detectType(normalized, lines);
    final gstin = _extractGstin(normalized);
    final sellerName = _extractSellerName(lines, normalized);
    final invoiceNumber = _extractInvoiceNumber(normalized);
    final invoiceDate = _extractDate(normalized);
    final grandTotal = _extractGrandTotal(normalized, lines);
    final taxes = _extractTaxSection(normalized, lines);
    final items = _extractItems(lines, normalized, billType);
    final charges = _extractCharges(lines, normalized);
    final confidence = _computeConfidence(gstin, sellerName, grandTotal, items, taxes);

    return StructuredBill(
      rawText: rawText,
      billType: billType,
      sellerName: sellerName,
      gstin: gstin,
      invoiceNumber: invoiceNumber,
      invoiceDate: invoiceDate,
      items: items,
      taxes: taxes,
      charges: charges,
      grandTotal: grandTotal,
      confidence: confidence,
    );
  }

  // ─── Text normalization ────────────────────────────────────────────────────

  String _normalizeText(String raw) {
    // Collapse multiple spaces to single space within each line (but keep newlines)
    final lines = raw.split('\n');
    return lines.map((l) => l.replaceAll(RegExp(r' {2,}'), ' ').trim()).join('\n');
  }

  // ─── Type detection ────────────────────────────────────────────────────────

  BillType _detectType(String raw, List<String> lines) {
    final lower = raw.toLowerCase();

    // Restaurants & food — check FIRST before generic checks
    if (_hasAny(lower, [
      'restaurant', 'cafe', 'dhaba', 'food bill', 'swiggy', 'zomato',
      'table no', 'table number', 'cover charge', 'dine in', 'dine-in',
      'food court', 'bar &', 'pub ', 'bistro', 'eatery', 'barbeque',
    ])) {
      return BillType.restaurant;
    }

    // Hotel / accommodation — check before generic
    if (_hasAny(lower, [
      'hotel ', 'resort', 'check-in', 'check-out', 'room no', 'room number',
      'accommodation', 'room tariff', 'checkout date', 'check in date',
    ])) {
      return BillType.hotel;
    }

    // Pharmacy / medical
    if (_hasAny(lower, [
      'pharmacy', 'chemist', 'medical store', 'drug store', 'medicineis',
      'medicines', 'rx ', 'tablet', 'capsule', 'syrup', 'apollo pharmacy',
      'medplus', 'netmeds', 'prescription',
    ])) {
      return BillType.pharmacy;
    }

    // Fuel / petrol
    if (_hasAny(lower, [
      'petrol', 'diesel', 'fuel', 'litre', 'liter', 'pump station',
      'filling station', 'cng', 'bharat petroleum', 'indian oil',
      'hindustan petroleum', 'hp petro', 'shell ', 'iocl', 'hpcl', 'bpcl',
    ])) {
      return BillType.fuel;
    }

    // Supermarket / hypermarket — check BEFORE electronics
    if (_hasAny(lower, [
      'supermarket', 'hypermarket', 'hypercity', 'big bazaar', 'bigbasket',
      'reliance fresh', 'reliance smart', 'd-mart', 'dmart', 'more supermarket',
      'star market', 'nature\'s basket', 'spar ', 'trent', 'westside grocery',
      'grocery', 'grocer', 'general store', 'departmental store',
      'invoice-cum-bill of supply', 'invoice cum bill',
      'total savings', 'total qty', 'no. of items',
    ])) {
      return BillType.supermarket;
    }

    // E-commerce / online order
    if (_hasAny(lower, [
      'amazon', 'flipkart', 'myntra', 'nykaa', 'meesho', 'snapdeal',
      'order id', 'order #', 'shipment', 'tracking', 'courier',
      'delivery address', 'sold by:', 'fulfilled by',
    ])) {
      return BillType.ecommerce;
    }

    // Electronics — after supermarket check
    if (_hasAny(lower, [
      'mobile phone', 'laptop', 'computer', 'television', 'headphone',
      'charger', 'electronics store', 'gadget', 'home appliance',
      'croma', 'vijay sales', 'reliance digital', 'samsung store',
      'apple store', 'mi store',
    ])) {
      return BillType.electronics;
    }

    // Shopping / fashion
    if (_hasAny(lower, [
      'fashion', 'clothing', 'apparel', 'garment', 'lifestyle store',
      'westside', 'shoppers stop', 'pantaloons', 'max fashion',
      'h&m', 'zara ', 'uniqlo',
    ])) {
      return BillType.shopping;
    }

    // Service
    if (_hasAny(lower, [
      'service charge', 'repair service', 'maintenance service',
      'subscription', 'labour charge', 'labor charge', 'amc ',
      'annual maintenance', 'plumber', 'electrician', 'carpenter',
    ])) {
      return BillType.service;
    }

    // Generic GST invoice — if GSTIN / HSN / SAC keywords present
    if (_hasAny(lower, ['gstin', 'hsn', 'sac code', 'tax invoice', 'igst', 'cgst', 'sgst'])) {
      return BillType.gstInvoice;
    }

    return BillType.unknown;
  }

  bool _hasAny(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));

  // ─── GSTIN extraction ──────────────────────────────────────────────────────

  String? _extractGstin(String raw) {
    final regex = RegExp(
      r'\b\d{2}[A-Z]{5}\d{4}[A-Z]{1}[A-Z\d]{1}Z[A-Z\d]{1}\b',
    );
    final match = regex.firstMatch(raw.toUpperCase());
    return match?.group(0);
  }

  // ─── Seller name ───────────────────────────────────────────────────────────

  String? _extractSellerName(List<String> lines, String raw) {
    // Priority 1: Look for company/brand name indicators in first 10 lines
    final companyPatterns = [
      RegExp(r'([\w\s]+(?:pvt\.?\s*ltd\.?|private\s+limited|ltd\.?|llp|inc\.?|corp\.?))', caseSensitive: false),
    ];

    for (final line in lines.take(10)) {
      for (final p in companyPatterns) {
        final m = p.firstMatch(line);
        if (m != null) {
          final candidate = _cleanText(m.group(0) ?? '').trim();
          if (candidate.length > 4) return _toTitleCase(candidate);
        }
      }
    }

    // Priority 2: First non-numeric, non-address, meaningful line in first 6
    for (final line in lines.take(6)) {
      if (line.length > 4 &&
          !RegExp(r'^\d').hasMatch(line) &&
          !_isAddressLine(line) &&
          !_isTaxLine(line) &&
          !_isMetaLine(line)) {
        return _toTitleCase(_cleanText(line));
      }
    }
    return null;
  }

  bool _isAddressLine(String l) {
    final lower = l.toLowerCase();
    return _hasAny(lower, [
      'road', 'nagar', 'sector', 'plot', 'pin:', 'pincode', 'gst',
      'mob:', 'ph:', 'tel:', 'fax:', 'email:', '@', 'floor', 'wing',
      'tower', 'mall', 'complex', 'building', 'street', 'avenue',
      'maharashtra', 'delhi', 'mumbai', 'bangalore', 'hyderabad',
    ]);
  }

  bool _isTaxLine(String l) {
    final lower = l.toLowerCase();
    return _hasAny(lower, [
      'cgst', 'sgst', 'igst', 'cess', 'grand total', 'subtotal',
      'taxable amount', 'total amount', 'net amount',
    ]);
  }

  bool _isMetaLine(String l) {
    final lower = l.toLowerCase();
    return _hasAny(lower, [
      'invoice', 'invoice no', 'bill no', 'date:', 'time:', 'cashier',
      'counter', 'customer', 'gstin', 'cin:', 'fssai', 'registered',
    ]);
  }

  // ─── Invoice number ────────────────────────────────────────────────────────

  String? _extractInvoiceNumber(String raw) {
    final patterns = [
      RegExp(r'(?:invoice\s*no\.?|bill\s*no\.?|receipt\s*no\.?|inv\s*no\.?)\s*[:\-]?\s*([A-Z0-9\/\-]{3,30})', caseSensitive: false),
      RegExp(r'(?:invoice|bill|receipt)\s*[:\-#]\s*([A-Z0-9\/\-]{3,30})', caseSensitive: false),
      RegExp(r'(?:BT|INV|RCP|BL)\d{6,}', caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(raw);
      if (m != null) {
        final v = (m.groupCount >= 1 ? m.group(1) : m.group(0))?.trim();
        if (v != null && v.length >= 3 && v.length <= 30) return v;
      }
    }
    return null;
  }

  // ─── Date extraction ───────────────────────────────────────────────────────

  DateTime? _extractDate(String raw) {
    final patterns = [
      // DD/MM/YYYY or DD-MM-YYYY
      RegExp(r'(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})'),
      // YYYY/MM/DD or YYYY-MM-DD
      RegExp(r'(\d{4})[/\-](\d{1,2})[/\-](\d{1,2})'),
      // DD MMM YYYY (e.g. 14 Aug 2024)
      RegExp(r'(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(\d{4})', caseSensitive: false),
      // Date: 10/08/2026
      RegExp(r'date\s*[:\-]?\s*(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})', caseSensitive: false),
    ];

    final monthMap = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };

    for (final p in patterns) {
      final m = p.firstMatch(raw);
      if (m != null) {
        try {
          if (p.pattern.contains('Jan')) {
            final d = int.parse(m.group(1)!);
            final mo = monthMap[m.group(2)!.toLowerCase()] ?? 1;
            final y = int.parse(m.group(3)!);
            if (y >= 2000 && y <= 2100 && mo >= 1 && mo <= 12 && d >= 1 && d <= 31) {
              return DateTime(y, mo, d);
            }
          } else if (p.pattern.startsWith(r'(\d{4})')) {
            final y = int.parse(m.group(1)!);
            final mo = int.parse(m.group(2)!);
            final d = int.parse(m.group(3)!);
            if (y >= 2000 && y <= 2100) return DateTime(y, mo, d);
          } else {
            // Could be DD/MM/YYYY — group indices may shift for `date:` pattern
            final g1 = int.parse(m.group(m.groupCount >= 3 ? m.groupCount - 2 : 1)!);
            final g2 = int.parse(m.group(m.groupCount >= 3 ? m.groupCount - 1 : 2)!);
            final g3 = int.parse(m.group(m.groupCount)!);
            // g3 is YYYY if 4 digits
            if (g3 >= 2000) return DateTime(g3, g2, g1);
          }
        } catch (_) {}
      }
    }
    return null;
  }

  // ─── Grand total extraction ────────────────────────────────────────────────

  double? _extractGrandTotal(String raw, List<String> lines) {
    // Excluded keywords that represent subtotals, savings, quantities, or payments
    bool isExcludedLine(String line) {
      final lower = line.toLowerCase();
      return _hasAny(lower, [
        'saving', 'savings', 'discount', 'disc.', 'disc ',
        'subtotal', 'sub-total', 'sub total', 'taxable',
        'cgst', 'sgst', 'igst', 'cess', 'vat', 'total tax', 'tax total',
        'qty', 'quantity', 'item count', 'total items', 'total item', 'pcs',
        'cash tendered', 'tender cash', 'tendered', 'change due', 'change return',
        'balance return', 'refund', 'mrp total',
      ]);
    }

    // High Priority Patterns (Exact Net Payable / Invoice Total matches)
    final highPriorityPatterns = [
      RegExp(r'(?:total\s+invoice\s+amount|total\s+bill\s+amount)\s*[:\-]?\s*[₹Rs\.]*\s*([\d,]+\.?\d*)', caseSensitive: false),
      RegExp(r'(?:net\s+payable|net\s+amount|net\s+total|amount\s+payable|balance\s+payable)\s*[:\-]?\s*[₹Rs\.]*\s*([\d,]+\.?\d*)', caseSensitive: false),
      RegExp(r'(?:grand\s+total|final\s+total|bill\s+total)\s*[:\-]?\s*[₹Rs\.]*\s*([\d,]+\.?\d*)', caseSensitive: false),
      RegExp(r'(?:amount\s+due|total\s+payable)\s*[:\-]?\s*[₹Rs\.]*\s*([\d,]+\.?\d*)', caseSensitive: false),
      RegExp(r'(?:total\s+amount|total\s+amt)\s*[:\-]?\s*[₹Rs\.]*\s*([\d,]+\.?\d*)', caseSensitive: false),
    ];

    // Check high priority patterns first
    for (final p in highPriorityPatterns) {
      final matches = p.allMatches(raw).toList();
      for (final m in matches.reversed) {
        final fullMatchLine = m.input.substring(
          (m.start - 20).clamp(0, m.start),
          (m.end + 20).clamp(m.end, m.input.length),
        );
        if (!isExcludedLine(fullMatchLine)) {
          final v = _parseAmount(m.group(1));
          if (v != null && v > 0) return v;
        }
      }
    }

    // Strategy 2: Scan lines bottom-up for total lines (summary is always at bottom)
    for (int i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];
      if (isExcludedLine(line)) continue;

      final lower = line.toLowerCase();
      if (lower.contains('total') || lower.contains('payable') || lower.contains('net amt') || lower.contains('due')) {
        // Extract numbers formatted as amounts (e.g. 335.40 or 335)
        final matches = RegExp(r'[\d,]+\.\d{2}').allMatches(line).toList();
        if (matches.isNotEmpty) {
          final v = _parseAmount(matches.last.group(0));
          if (v != null && v > 0) return v;
        }

        // Single integer or float fallback
        final genericMatch = RegExp(r'[₹Rs\.]*\s*([\d,]+\.?\d*)\s*$').firstMatch(line);
        if (genericMatch != null) {
          final v = _parseAmount(genericMatch.group(1));
          if (v != null && v > 0) return v;
        }
      }
    }

    // Strategy 3: Generic last-resort regex
    final genericRegex = RegExp(r'(?:^|\n)\s*total\s*[:\-]?\s*[₹Rs\.]*\s*([\d,]+\.?\d*)', caseSensitive: false);
    for (final m in genericRegex.allMatches(raw).toList().reversed) {
      final v = _parseAmount(m.group(1));
      if (v != null && v > 0) return v;
    }

    return null;
  }

  // ─── Item extraction ───────────────────────────────────────────────────────

  List<BillItem> _extractItems(List<String> lines, String raw, BillType billType) {
    // Try specialized parsers first, then fall back to generic
    List<BillItem> items = [];

    // Supermarket / hypermarket tabular format (Trent, Big Bazaar, DMart, Star)
    if (billType == BillType.supermarket || billType == BillType.gstInvoice ||
        _hasAny(raw.toLowerCase(), ['hsn', 'sac', 'hsn-sac', 'hsn/sac'])) {
      items = _extractSupermarketItems(lines, raw);
    }

    // Restaurant format
    if (items.isEmpty && (billType == BillType.restaurant || billType == BillType.hotel)) {
      items = _extractRestaurantItems(lines);
    }

    // Pharmacy format
    if (items.isEmpty && billType == BillType.pharmacy) {
      items = _extractPharmacyItems(lines);
    }

    // Generic fallback for any format
    if (items.isEmpty) {
      items = _extractGenericItems(lines);
    }

    return items;
  }

  // ─── Supermarket item extraction (handles Indian hypermarket receipts) ──────

  List<BillItem> _extractSupermarketItems(List<String> lines, String raw) {
    final items = <BillItem>[];

    // Patterns for supermarket receipt lines:
    // Format A: "ProductName / HSN / TaxableValue"   followed by or on same line as price
    // Format B: "SKU    Qty  UnitPrice  LineTotal"
    // Format C: "ProductName  Qty  Rate  Amount"  (standard tabular)

    // The Trent/Star receipt format interleaves:
    //   Line 1: Header section "A) CGST@5.00, SGST@5.00" (GST slab header)
    //   Line 2: SKU_number
    //   Line 3: "ProductName / HSN / TaxableValue"  then:
    //            "  1 PC  UnitPrice  LineTotal"
    // OR the name and qty are on the SAME line:
    //   "ProductName / HSN / TaxableValue  1 PC  30.00  30.40"

    // Strategy: scan line by line, identify item lines by pattern
    final skipLine = _buildSkipPattern();

    // Pattern: Name followed by "/ HSN / amount"  (Trent format)
    // e.g. "Chupasoubte61.8 / 20041000 / 28.96"
    final trentItemPattern = RegExp(
      r'^(.+?)\s*/\s*(\d{4,8})\s*/\s*([\d,]+\.?\d*)$',
    );

    // Pattern: "Name  Qty  UnitPrice  Total" — all on one line
    // e.g. "Butter Chicken   1 x 350.00  350.00"
    final singleLinePattern = RegExp(
      r'^(.+?)\s+(\d+(?:\.\d+)?)\s*(?:x|×|X|pcs?|pc|nos?|kgs?|gms?|ltrs?|ml|units?|bags?)?\s+([\d,]+\.?\d+)\s+([\d,]+\.?\d+)$',
      caseSensitive: false,
    );

    // Note: simple "Name  LineTotal" matching is handled by the generic fallback

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();

      if (skipLine(lower)) continue;
      if (line.length < 4) continue;

      // Try Trent-style: "Name / HSN / taxableValue"
      final trentM = trentItemPattern.firstMatch(line);
      if (trentM != null) {
        final rawName = trentM.group(1) ?? '';
        final taxableStr = trentM.group(3) ?? '';
        final taxable = _parseAmount(taxableStr);
        if (taxable == null || taxable <= 0) continue;

        // Clean the name — remove leading SKU codes (pure digits > 6 chars)
        final name = _cleanItemName(rawName);
        if (name.length < 2) continue;

        // Look at next line for qty/unit/lineTotal info
        double? qty, unitPrice, lineTotal;
        String? unit;

        if (i + 1 < lines.length) {
          final nextLine = lines[i + 1];
          // Try to extract: qty unit unitPrice lineTotal
          final nextPattern = RegExp(
            r'(\d+(?:\.\d+)?)\s*(PC|PCS|KG|GM|GMS|LTR|ML|NOS?|UNIT|BAG|BOX|PKT|PACK)?\s+([\d,]+\.?\d*)\s+([\d,]+\.?\d*)$',
            caseSensitive: false,
          );
          final nm = nextPattern.firstMatch(nextLine);
          if (nm != null) {
            qty = double.tryParse(nm.group(1) ?? '');
            unit = nm.group(2)?.toUpperCase();
            unitPrice = _parseAmount(nm.group(3));
            lineTotal = _parseAmount(nm.group(4));
            i++; // consume next line
          } else {
            // Try simpler: just a number at end of next line
            final simplePriceM = RegExp(r'([\d,]+\.\d{2})\s*$').firstMatch(nextLine);
            if (simplePriceM != null && !skipLine(nextLine.toLowerCase())) {
              lineTotal = _parseAmount(simplePriceM.group(1));
              // Check if qty is in the next line
              final qtyM = RegExp(r'^(\d+(?:\.\d+)?)\s*(PC|PCS|KG|GM|NOS?|UNIT|BAG)?\s', caseSensitive: false).firstMatch(nextLine);
              if (qtyM != null) {
                final possibleQty = double.tryParse(qtyM.group(1) ?? '');
                // Only treat as qty if it's a small number (< 1000) — not a barcode
                if (possibleQty != null && possibleQty < 1000) {
                  qty = possibleQty;
                  unit = qtyM.group(2)?.toUpperCase();
                }
              }
              i++; // consume next line
            }
          }
        }

        // Use taxable as lineTotal if not found
        lineTotal ??= taxable;
        qty ??= 1.0;
        unitPrice ??= (qty > 0) ? lineTotal / qty : lineTotal;

        items.add(BillItem(
          name: name,
          quantity: qty,
          unit: unit,
          unitPrice: unitPrice,
          taxableValue: taxable,
          lineTotal: lineTotal,
          confidence: 0.80,
        ));
        continue;
      }

      // Try single-line with qty and price: "Name  qty  unitPrice  lineTotal"
      final slM = singleLinePattern.firstMatch(line);
      if (slM != null) {
        final rawName = slM.group(1) ?? '';
        final name = _cleanItemName(rawName);
        if (name.length < 2) continue;

        final qtyStr = slM.group(2);
        final possibleQty = double.tryParse(qtyStr ?? '');

        // Reject if qty looks like a barcode (> 6 digits before decimal)
        if (possibleQty != null && possibleQty >= 1000000) continue;

        final unitPrice = _parseAmount(slM.group(3));
        final lineTotal = _parseAmount(slM.group(4));
        if (lineTotal == null || lineTotal <= 0) continue;
        final qty = possibleQty ?? 1.0;

        items.add(BillItem(
          name: name,
          quantity: qty,
          unitPrice: unitPrice,
          lineTotal: lineTotal,
          taxableValue: lineTotal,
          confidence: 0.85,
        ));
        continue;
      }
    }

    // If nothing found with specialized patterns, fall back to generic
    if (items.isEmpty) {
      return _extractGenericItems(lines);
    }

    return items;
  }

  // ─── Restaurant item extraction ────────────────────────────────────────────

  List<BillItem> _extractRestaurantItems(List<String> lines) {
    final items = <BillItem>[];
    final skipLine = _buildSkipPattern();

    // Restaurant pattern: "Item Name  qty  price  total" OR "Item Name  total"
    final withQtyPrice = RegExp(
      r'^(.{2,40}?)\s+(\d+(?:\.\d+)?)\s*(?:x|×)?\s*([\d,]+\.?\d+)\s+([\d,]+\.?\d+)$',
    );
    final withTotal = RegExp(
      r'^(.{3,45}?)\s+([\d,]+\.\d{2})\s*$',
    );

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (skipLine(lower)) continue;
      if (line.length < 4) continue;

      // Try "Name qty × price  total"
      final m1 = withQtyPrice.firstMatch(line);
      if (m1 != null) {
        final name = _cleanItemName(m1.group(1) ?? '');
        if (name.length < 2) continue;
        final qty = double.tryParse(m1.group(2) ?? '') ?? 1.0;
        if (qty >= 1000000) continue; // barcode check
        final unitPrice = _parseAmount(m1.group(3));
        final lineTotal = _parseAmount(m1.group(4));
        if (lineTotal == null || lineTotal <= 0) continue;

        items.add(BillItem(
          name: name,
          quantity: qty,
          unitPrice: unitPrice,
          lineTotal: lineTotal,
          taxableValue: lineTotal,
          confidence: 0.85,
        ));
        continue;
      }

      // Try "Name  total"
      final m2 = withTotal.firstMatch(line);
      if (m2 != null) {
        final name = _cleanItemName(m2.group(1) ?? '');
        if (name.length < 2) continue;
        final lineTotal = _parseAmount(m2.group(2));
        if (lineTotal == null || lineTotal <= 0) continue;

        items.add(BillItem(
          name: name,
          quantity: 1.0,
          lineTotal: lineTotal,
          taxableValue: lineTotal,
          confidence: 0.70,
        ));
      }
    }
    return items;
  }

  // ─── Pharmacy item extraction ──────────────────────────────────────────────

  List<BillItem> _extractPharmacyItems(List<String> lines) {
    final items = <BillItem>[];
    final skipLine = _buildSkipPattern();

    // Pharmacy: "Medicine Name  qty  mrp  discount  amount"
    // or: "Medicine Name  qty x price  amount"
    final pharmaPattern = RegExp(
      r'^(.{3,45}?)\s+(?:(\d+(?:\.\d+)?)\s*(?:x|×|tab|cap|ml|gm|mg|strip|strips|nos?)?\s*)?([\d,]+\.?\d+)\s*$',
      caseSensitive: false,
    );

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (skipLine(lower)) continue;
      if (line.length < 4) continue;

      final m = pharmaPattern.firstMatch(line);
      if (m != null) {
        final name = _cleanItemName(m.group(1) ?? '');
        if (name.length < 2) continue;
        final possibleQty = double.tryParse(m.group(2) ?? '');
        if (possibleQty != null && possibleQty >= 1000000) continue;
        final lineTotal = _parseAmount(m.group(3));
        if (lineTotal == null || lineTotal <= 0) continue;
        final qty = possibleQty ?? 1.0;

        items.add(BillItem(
          name: name,
          quantity: qty,
          lineTotal: lineTotal,
          taxableValue: lineTotal,
          confidence: 0.75,
        ));
      }
    }
    return items;
  }

  // ─── Generic item extraction ───────────────────────────────────────────────

  List<BillItem> _extractGenericItems(List<String> lines) {
    final items = <BillItem>[];
    final skipLine = _buildSkipPattern();

    // Generic: handles most formats
    // "Name  [qty x unitPrice]  lineTotal"
    final genericWithQty = RegExp(
      r'^(.{2,50}?)\s+(\d+(?:\.\d+)?)\s*(?:x|×|X)?\s*([\d,]+\.?\d+)\s+([\d,]+\.?\d+)$',
    );
    final genericSimple = RegExp(
      r'^(.{3,50}?)\s+([\d,]+\.\d{2})\s*$',
    );

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (skipLine(lower)) continue;
      if (line.length < 5) continue;

      // Skip lines that are purely numeric (likely barcodes/SKUs)
      if (RegExp(r'^\d{5,}$').hasMatch(line.trim())) continue;

      // Try with qty
      final m1 = genericWithQty.firstMatch(line);
      if (m1 != null) {
        final name = _cleanItemName(m1.group(1) ?? '');
        if (name.length < 2) continue;
        final qty = double.tryParse(m1.group(2) ?? '') ?? 1.0;
        if (qty >= 1000000) continue;
        final unitPrice = _parseAmount(m1.group(3));
        final lineTotal = _parseAmount(m1.group(4));
        if (lineTotal == null || lineTotal <= 0) continue;

        items.add(BillItem(
          name: name,
          quantity: qty,
          unitPrice: unitPrice,
          lineTotal: lineTotal,
          taxableValue: lineTotal,
          confidence: 0.70,
        ));
        continue;
      }

      // Simple name + total
      final m2 = genericSimple.firstMatch(line);
      if (m2 != null) {
        final name = _cleanItemName(m2.group(1) ?? '');
        if (name.length < 2) continue;
        final lineTotal = _parseAmount(m2.group(2));
        if (lineTotal == null || lineTotal <= 0) continue;

        items.add(BillItem(
          name: name,
          quantity: 1.0,
          lineTotal: lineTotal,
          taxableValue: lineTotal,
          confidence: 0.60,
        ));
      }
    }
    return items;
  }

  // ─── Skip-line predicate (shared across all extraction methods) ─────────────

  bool Function(String) _buildSkipPattern() {
    const skipKeywords = [
      'total', 'subtotal', 'sub total', 'cgst', 'sgst', 'igst', 'cess',
      'tax', 'discount', 'service charge', 'gst', 'bill', 'invoice',
      'date', 'time', 'table', 'receipt', 'thank you', 'address', 'gstin',
      'amount', 'grand', 'round', 'cash', 'change due', 'tender',
      'payment', 'paid', 'balance', 'savings', 'mrp', 'max. retail',
      'description', 'particulars', 'hsn', 'sac', 'counter', 'cashier',
      'customer', 'cust', 'name:', 'phone', 'mobile', 'email', 'website',
      'store', 'branch', 'registered', 'cin :', 'cin:', 'fssai',
      'no. of items', 'total qty', 'qty', 'rate', 'unit', 'net amt',
      'taxable value', 'net amount', 'net value',
      '**', '---', '===', '...', '***',
    ];
    return (String lower) => skipKeywords.any((k) => lower.contains(k));
  }

  // ─── Item name cleaning ────────────────────────────────────────────────────

  String _cleanItemName(String raw) {
    String s = raw.trim();

    // Remove leading SKU/barcode numbers (pure digits, optionally followed by space)
    // e.g. "1328036 ProductName" → "ProductName"
    s = s.replaceAll(RegExp(r'^\d{5,}\s*'), '');

    // Remove trailing HSN/SAC code patterns: "/ 20041000" or "/ 8-digit-number"
    s = s.replaceAll(RegExp(r'\s*/\s*\d{4,}.*$'), '');

    // Remove trailing amount: "ProductName 28.96" (but only if digits + decimal at end)
    // Be careful not to remove "500mg" or "250ml" type suffixes
    s = s.replaceAll(RegExp(r'\s+\d{2,6}\.\d{2}\s*$'), '');

    // Remove OCR artifacts: stray punctuation at start
    s = s.replaceAll(RegExp(r'^[^a-zA-Z\d₹(]+'), '');

    // Normalize multiple spaces
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Remove purely numeric names (barcodes)
    if (RegExp(r'^\d+$').hasMatch(s)) return '';

    // Keep letters, digits, spaces, &, -, /, (, ), %, .
    s = s.replaceAll(RegExp(r'[^\w\s\-\.\/\&\(\)%+]'), '').trim();

    return s;
  }

  // ─── Tax section extraction ─────────────────────────────────────────────────

  BillTaxSection _extractTaxSection(String raw, List<String> lines) {
    // Strategy 1: Try to parse tabular GST summary (Trent/Star/DMart style)
    // These bills show:
    //   GST  Taxable  CGST  SGST  CESS  Total
    //   IND  Value
    //   A)   205.14   5.13  5.13  0.00  215.40
    //   B)   88.70   17.15 17.15  0.00  123.00
    //   Total  293.84  22.28  22.28  0.00  338.40
    final tabularResult = _extractTabularTax(lines);
    if (tabularResult != null) return tabularResult;

    // Strategy 2: Line-by-line keyword search (restaurant/standard format)
    return BillTaxSection(
      subtotal: _extractTaxValue(raw, ['subtotal', 'taxable amount', 'taxable value', 'taxable', 'base amount']),
      cgstAmount: _extractTaxValue(raw, ['cgst']),
      sgstAmount: _extractTaxValue(raw, ['sgst']),
      igstAmount: _extractTaxValue(raw, ['igst']),
      cessAmount: _extractTaxValue(raw, ['cess']),
      cgstRate: _extractTaxRate(raw, 'cgst'),
      sgstRate: _extractTaxRate(raw, 'sgst'),
      igstRate: _extractTaxRate(raw, 'igst'),
    );
  }

  BillTaxSection? _extractTabularTax(List<String> lines) {
    // Look for the GST summary table pattern
    // The table typically has rows like: "A)  205.14  5.13  5.13  0.00  215.40"
    // or "Total  293.84  22.28  22.28  0.00  338.40"

    double? totalTaxable;
    double? totalCgst;
    double? totalSgst;
    double? totalIgst;
    double? totalCess;

    bool inTaxTable = false;
    int taxTableRows = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();

      // Detect start of tax table
      if ((lower.contains('cgst') && lower.contains('sgst')) ||
          (lower.contains('gst') && lower.contains('taxable')) ||
          lower.contains('tax details')) {
        inTaxTable = true;
        continue;
      }

      if (!inTaxTable) continue;

      // Skip header lines
      if (lower.contains('ind') || lower.contains('value') || lower.contains('cess') ||
          lower.contains('total') || lower.contains('description') || lower.contains('gst')) {
        // But check if this "total" line has numbers — it might be the totals row
        if (lower.contains('total')) {
          final nums = _extractAllNumbers(line);
          if (nums.length >= 4) {
            // Last few numbers are: taxable, cgst, sgst, cess, total_tax
            // "Total  293.84  22.28  22.28  0.00  338.40"
            if (nums.length == 5) {
              totalTaxable = nums[0];
              totalCgst = nums[1];
              totalSgst = nums[2];
              totalCess = nums[3] > 0.01 ? nums[3] : null;
            } else if (nums.length >= 4) {
              totalTaxable = nums[0];
              totalCgst = nums[1];
              totalSgst = nums[2];
            }
            inTaxTable = false;
          }
        }
        continue;
      }

      // Try to parse a slab row: "A)  205.14  5.13  5.13  0.00  215.40"
      // or: "A)  88.70  17.15  17.15  0.00  123.00"
      if (RegExp(r'^[A-Za-z\)]+\s').hasMatch(line) || RegExp(r'^\s*[\d,]+\.\d').hasMatch(line)) {
        final nums = _extractAllNumbers(line);
        if (nums.length >= 4) {
          // Format: taxable  cgst  sgst  cess  lineTotal
          totalTaxable = (totalTaxable ?? 0) + nums[0];
          totalCgst = (totalCgst ?? 0) + nums[1];
          totalSgst = (totalSgst ?? 0) + nums[2];
          if (nums.length >= 5 && nums[3] > 0.01) {
            totalCess = (totalCess ?? 0) + nums[3];
          }
          taxTableRows++;
        }
      }

      // Stop if we've been in the table for too long without a match
      if (taxTableRows == 0 && i > 5) inTaxTable = false;

      // Stop after a blank-ish line after finding rows
      if (taxTableRows > 0 && line.trim().isEmpty) break;
    }

    // Also try to parse from raw text: "A) CGST@5.00, SGST@5.00" style
    // which tells us the rates for each slab
    // We'll skip rate extraction from slab headers for now (complex)

    if (totalCgst != null || totalSgst != null) {
      return BillTaxSection(
        subtotal: totalTaxable,
        cgstAmount: totalCgst,
        sgstAmount: totalSgst,
        igstAmount: totalIgst,
        cessAmount: totalCess,
      );
    }

    return null;
  }

  List<double> _extractAllNumbers(String line) {
    final matches = RegExp(r'[\d,]+\.\d+').allMatches(line);
    return matches
        .map((m) => _parseAmount(m.group(0)))
        .where((v) => v != null && v >= 0)
        .cast<double>()
        .toList();
  }

  double? _extractTaxValue(String raw, List<String> keywords) {
    for (final kw in keywords) {
      // Pattern: "CGST 2.5%: 11.75" or "CGST: 22.28" or "CGST@5% 10.25"
      final p = RegExp(
        r'(?:' + RegExp.escape(kw) + r')\s*(?:@?\s*[\d.]+\s*%\s*)?[:\-]?\s*[₹Rs\.]*\s*([\d,]+\.?\d+)',
        caseSensitive: false,
      );
      // Try to find the LAST match (most specific — at the bottom of the bill)
      final all = p.allMatches(raw).toList();
      if (all.isNotEmpty) {
        // Sum all matches for this keyword IF there are multiple slabs
        // (e.g., bill has CGST@5% and CGST@12% each with different amounts)
        if (all.length > 1) {
          double sum = 0;
          for (final m in all) {
            final v = _parseAmount(m.group(1));
            if (v != null && v > 0) sum += v;
          }
          // If the last value alone > sum of previous, it IS the total
          final lastV = _parseAmount(all.last.group(1));
          if (lastV != null && lastV >= sum * 0.8) return lastV;
          return sum > 0 ? sum : null;
        }
        final v = _parseAmount(all.last.group(1));
        if (v != null && v > 0) return v;
      }
    }
    return null;
  }

  double? _extractTaxRate(String raw, String taxType) {
    final p = RegExp(
      r'(?:' + RegExp.escape(taxType) + r')\s*@?\s*([\d.]+)\s*%',
      caseSensitive: false,
    );
    final all = p.allMatches(raw).toList();
    if (all.isEmpty) return null;
    // If multiple rates exist (multi-slab), return null (we don't know which applies)
    final rates = all.map((m) => double.tryParse(m.group(1) ?? '')).whereType<double>().toSet();
    if (rates.length == 1) return rates.first;
    return null; // Multiple rates — don't report a single rate
  }

  // ─── Charge extraction ─────────────────────────────────────────────────────

  List<BillCharge> _extractCharges(List<String> lines, String raw) {
    final charges = <BillCharge>[];
    final chargePatterns = {
      'service charge': ['service charge', 'service fee'],
      'hospitality charge': ['hospitality charge', 'staff charge'],
      'packaging charge': ['packaging', 'packing charge', 'carry bag', 'bag charge'],
      'delivery charge': ['delivery charge', 'delivery fee', 'shipping charge'],
      'convenience fee': ['convenience fee', 'platform fee', 'processing fee'],
    };

    for (final line in lines) {
      final lower = line.toLowerCase();
      for (final entry in chargePatterns.entries) {
        if (entry.value.any((kw) => lower.contains(kw))) {
          final amtMatch = RegExp(r'[₹Rs\.]*\s*([\d,]+\.?\d*)').firstMatch(line);
          if (amtMatch != null) {
            final amt = _parseAmount(amtMatch.group(1));
            if (amt != null && amt > 0 && amt < 10000) {
              // Avoid adding duplicates
              if (!charges.any((c) => c.label == entry.key)) {
                charges.add(BillCharge(label: entry.key, amount: amt));
              }
            }
          }
          break;
        }
      }
    }
    return charges;
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  double? _parseAmount(String? s) {
    if (s == null) return null;
    final cleaned = s.replaceAll(',', '').trim();
    return double.tryParse(cleaned);
  }

  String _cleanText(String s) =>
      s.replaceAll(RegExp(r'[^\w\s\-\.\/\&\(\)]'), '').trim();

  String _toTitleCase(String s) {
    return s.split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  double _computeConfidence(
    String? gstin,
    String? sellerName,
    double? grandTotal,
    List<BillItem> items,
    BillTaxSection taxes,
  ) {
    int score = 0;
    const total = 5;
    if (gstin != null) score++;
    if (sellerName != null) score++;
    if (grandTotal != null) score++;
    if (items.isNotEmpty) score++;
    if (taxes.cgstAmount != null || taxes.igstAmount != null || taxes.cessAmount != null) score++;
    return score / total;
  }
}
