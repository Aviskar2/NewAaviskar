import '../../models/product_safety_model.dart';

/// Automated parsing of Manufacturing Date, Expiry Date, Best Before & Shelf-life.
class ExpiryExtractorService {
  /// Analyzes text to extract dates and calculate shelf-life status.
  ExpiryAnalysis extract(String rawText, {DateTime? referenceDate}) {
    final now = referenceDate ?? DateTime.now();
    final normalized = rawText.toUpperCase().replaceAll(RegExp(r'[ \t]+'), ' ');

    DateTime? mfgDate = _extractMfgDate(normalized);
    DateTime? expDate = _extractDirectExpDate(normalized);
    String? bestBeforePhrase = _extractBestBeforePhrase(normalized);

    // If direct EXP not found but Best Before X months exists with Mfg date
    if (expDate == null && mfgDate != null && bestBeforePhrase != null) {
      final months = _extractMonthsFromPhrase(bestBeforePhrase);
      final days = _extractDaysFromPhrase(bestBeforePhrase);
      if (months != null && months > 0) {
        expDate = DateTime(mfgDate.year, mfgDate.month + months, mfgDate.day);
      } else if (days != null && days > 0) {
        expDate = mfgDate.add(Duration(days: days));
      }
    }

    // Determine status & remaining days
    int? daysRemaining;
    ExpiryStatus status = ExpiryStatus.unknown;
    double shelfLifePercent = 0.0;

    if (expDate != null) {
      daysRemaining = expDate.difference(now).inDays;
      if (daysRemaining < 0) {
        status = ExpiryStatus.expired;
      } else if (daysRemaining <= 30) {
        status = ExpiryStatus.expiringSoon;
      } else {
        status = ExpiryStatus.fresh;
      }

      if (mfgDate != null && expDate.isAfter(mfgDate)) {
        final totalShelfLifeDays = expDate.difference(mfgDate).inDays;
        final elapsedDays = now.difference(mfgDate).inDays;
        if (totalShelfLifeDays > 0) {
          shelfLifePercent = (elapsedDays / totalShelfLifeDays).clamp(0.0, 1.0);
        }
      }
    }

    final excerpt = _buildExcerpt(mfgDate, expDate, bestBeforePhrase);

    return ExpiryAnalysis(
      manufacturingDate: mfgDate,
      expiryDate: expDate,
      bestBeforePhrase: bestBeforePhrase,
      daysRemaining: daysRemaining,
      status: status,
      rawTextExcerpt: excerpt,
      shelfLifeConsumedPercentage: shelfLifePercent,
    );
  }

  DateTime? _extractMfgDate(String text) {
    final mfgPatterns = [
      RegExp(r'(?:MFG|MFD|PKD|PACKED|PACKAGING|MANUFACTURED|DATE OF MFG|DATE OF PACKING|DATE OF MANUFACTURE)\s*(?:DT\.?|DATE)?[:\s\.\-]+(\d{1,2}[\/\.\-]\d{1,2}[\/\.\-]\d{2,4})'),
      RegExp(r'(?:MFG|MFD|PKD)\s*(?:DT\.?|DATE)?[:\s\.\-]+([A-Z]{3,9}[\s\/\.\-]\d{2,4})'),
      RegExp(r'(?:MFG|MFD|PKD)\s*(?:DT\.?|DATE)?[:\s\.\-]+(\d{1,2}[\s\/\.\-][A-Z]{3,9}[\s\/\.\-]\d{2,4})'),
      RegExp(r'\b(?:MFG|MFD|PKD)\s*(?:DT\.?|DATE)?[:\s]+(\d{2}\/\d{2,4})\b'),
    ];

    for (final pattern in mfgPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final dateStr = match.group(1);
        if (dateStr != null) {
          final parsed = _parseDateString(dateStr);
          if (parsed != null) return parsed;
        }
      }
    }
    return null;
  }

  DateTime? _extractDirectExpDate(String text) {
    final expPatterns = [
      RegExp(r'(?:EXP|EXPIRY|USE BY|USE BEFORE|VALID UPTO|DATE OF EXPIRY)\s*(?:DT\.?|DATE)?[:\s\.\-]+(\d{1,2}[\/\.\-]\d{1,2}[\/\.\-]\d{2,4})'),
      RegExp(r'(?:EXP|EXPIRY)\s*(?:DT\.?|DATE)?[:\s\.\-]+([A-Z]{3,9}[\s\/\.\-]\d{2,4})'),
      RegExp(r'(?:EXP|EXPIRY)\s*(?:DT\.?|DATE)?[:\s\.\-]+(\d{1,2}[\s\/\.\-][A-Z]{3,9}[\s\/\.\-]\d{2,4})'),
      RegExp(r'\b(?:EXP|EXPIRY|USE BY)\s*(?:DT\.?|DATE)?[:\s]+(\d{2}\/\d{2,4})\b'),
    ];

    for (final pattern in expPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final dateStr = match.group(1);
        if (dateStr != null) {
          final parsed = _parseDateString(dateStr);
          if (parsed != null) return parsed;
        }
      }
    }
    return null;
  }

  String? _extractBestBeforePhrase(String text) {
    final bbRegex = RegExp(r'(BEST BEFORE\s+\d+\s*(?:MONTHS?|DAYS?|WEEKS?|YEARS?)(?:\s+FROM\s+(?:MFG|PKD|PACKAGING|MANUFACTURE))?)');
    final match = bbRegex.firstMatch(text);
    if (match != null) return match.group(1);

    final simpleBb = RegExp(r'(BEST BEFORE\s+[A-Z0-9\s\/\.\-]+)');
    final simpleMatch = simpleBb.firstMatch(text);
    if (simpleMatch != null) return simpleMatch.group(1);

    return null;
  }

  int? _extractMonthsFromPhrase(String phrase) {
    final mMatch = RegExp(r'(\d+)\s*MONTHS?').firstMatch(phrase);
    if (mMatch != null) return int.tryParse(mMatch.group(1)!);
    final yMatch = RegExp(r'(\d+)\s*YEARS?').firstMatch(phrase);
    if (yMatch != null) {
      final y = int.tryParse(yMatch.group(1)!);
      if (y != null) return y * 12;
    }
    return null;
  }

  int? _extractDaysFromPhrase(String phrase) {
    final dMatch = RegExp(r'(\d+)\s*DAYS?').firstMatch(phrase);
    if (dMatch != null) return int.tryParse(dMatch.group(1)!);
    final wMatch = RegExp(r'(\d+)\s*WEEKS?').firstMatch(phrase);
    if (wMatch != null) {
      final w = int.tryParse(wMatch.group(1)!);
      if (w != null) return w * 7;
    }
    return null;
  }

  DateTime? _parseDateString(String str) {
    final clean = str.trim().replaceAll('.', '/').replaceAll('-', '/');
    final parts = clean.split('/');

    // Formats: DD/MM/YYYY or DD/MM/YY
    if (parts.length == 3) {
      int? d = int.tryParse(parts[0]);
      int? m = int.tryParse(parts[1]);
      int? y = int.tryParse(parts[2]);

      // If month is alphabetical e.g. 15/AUG/2024
      m ??= _monthNameToNum(parts[1]);

      if (d != null && m != null && y != null) {
        if (y < 100) y += 2000;
        if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
          try {
            return DateTime(y, m, d);
          } catch (_) {}
        }
      }
    }

    // Formats: MM/YYYY or MM/YY
    if (parts.length == 2) {
      int? m = int.tryParse(parts[0]);
      int? y = int.tryParse(parts[1]);
      m ??= _monthNameToNum(parts[0]);

      if (m != null && y != null) {
        if (y < 100) y += 2000;
        if (m >= 1 && m <= 12) {
          // Last day of that month for expiry
          final daysInMonth = DateTime(y, m + 1, 0).day;
          return DateTime(y, m, daysInMonth);
        }
      }
    }

    return null;
  }

  int? _monthNameToNum(String monthName) {
    final m = monthName.toUpperCase();
    const months = {
      'JAN': 1, 'JANUARY': 1,
      'FEB': 2, 'FEBRUARY': 2,
      'MAR': 3, 'MARCH': 3,
      'APR': 4, 'APRIL': 4,
      'MAY': 5,
      'JUN': 6, 'JUNE': 6,
      'JUL': 7, 'JULY': 7,
      'AUG': 8, 'AUGUST': 8,
      'SEP': 9, 'SEPTEMBER': 9,
      'OCT': 10, 'OCTOBER': 10,
      'NOV': 11, 'NOVEMBER': 11,
      'DEC': 12, 'DECEMBER': 12,
    };
    return months[m];
  }

  String _buildExcerpt(DateTime? mfg, DateTime? exp, String? bb) {
    final parts = <String>[];
    if (mfg != null) parts.add('Mfg: ${mfg.day}/${mfg.month}/${mfg.year}');
    if (exp != null) parts.add('Exp: ${exp.day}/${exp.month}/${exp.year}');
    if (bb != null) parts.add('Note: $bb');
    return parts.isEmpty ? 'No explicit expiry text detected' : parts.join(' | ');
  }
}
