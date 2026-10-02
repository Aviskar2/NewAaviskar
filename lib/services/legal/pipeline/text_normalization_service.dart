/// Result of text cleaning and normalization.
class NormalizedTextResult {
  final String text;
  final double ocrQualityScore; // 0.0 to 1.0
  final bool isPoorQuality;
  final int originalLength;
  final int cleanedLength;
  final List<String> transformations;

  const NormalizedTextResult({
    required this.text,
    required this.ocrQualityScore,
    required this.isPoorQuality,
    required this.originalLength,
    required this.cleanedLength,
    this.transformations = const [],
  });
}

/// Step 3 of the Document Analysis Pipeline: Text Cleaning and Normalization.
///
/// Strips HTML entities, repairs common encoding glitches, removes duplicate spaces,
/// fixes broken OCR line wraps, and evaluates overall OCR readability.
class TextNormalizationService {
  static final Map<String, String> _htmlEntities = {
    '&quot;': '"',
    '&apos;': "'",
    '&#39;': "'",
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&nbsp;': ' ',
    '&copy;': '©',
    '&reg;': '®',
    '&trade;': '™',
    '&ndash;': '–',
    '&mdash;': '—',
    '&bull;': '•',
    '&#8377;': '₹',
    '&inr;': '₹',
    '&pound;': '£',
    '&euro;': '€',
  };

  static final Map<String, String> _encodingFixes = {
    'Â©': '©',
    'Â®': '®',
    'â': "'",
    'â': "'",
    'â': '"',
    'â': '"',
    'â': '–',
    'â': '—',
    'â¹': '₹',
    'â¢': '•',
    'Â': '',
    '\u00A0': ' ', // Non-breaking space
    '\u200B': '',  // Zero-width space
    '\u200C': '',  // Zero-width non-joiner
    '\u200D': '',  // Zero-width joiner
    '\uFEFF': '',  // Byte order mark
  };

  NormalizedTextResult normalize(String rawText) {
    if (rawText.trim().isEmpty) {
      return const NormalizedTextResult(
        text: '',
        ocrQualityScore: 0.0,
        isPoorQuality: true,
        originalLength: 0,
        cleanedLength: 0,
        transformations: ['empty_text'],
      );
    }

    final transformations = <String>[];
    String current = rawText;

    // 1. Fix HTML entities
    for (final entry in _htmlEntities.entries) {
      if (current.contains(entry.key)) {
        current = current.replaceAll(entry.key, entry.value);
        transformations.add('decoded_entity_${entry.key}');
      }
    }

    // Also match numeric character references (e.g., &#160;, &#x20;)
    if (current.contains('&#')) {
      current = current.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
        final code = int.tryParse(match.group(1) ?? '');
        if (code != null && code > 0 && code < 65536) {
          transformations.add('decoded_numeric_entity');
          return String.fromCharCode(code);
        }
        return match.group(0)!;
      });
    }

    // 2. Fix broken UTF-8 encoding corruptions
    for (final entry in _encodingFixes.entries) {
      if (current.contains(entry.key)) {
        current = current.replaceAll(entry.key, entry.value);
        transformations.add('fixed_encoding_${entry.key}');
      }
    }

    // 3. Unify line endings: CRLF -> LF, CR -> LF
    current = current.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // 4. Fix hyphenated broken words across lines (e.g. "termina-\ntion" -> "termination")
    final hyphenWordRegex = RegExp(r'([A-Za-z]{3,})-\n([a-z]{3,})');
    if (hyphenWordRegex.hasMatch(current)) {
      current = current.replaceAllMapped(hyphenWordRegex, (m) => '${m[1]}${m[2]}');
      transformations.add('merged_hyphen_breaks');
    }

    // 5. Clean horizontal whitespace per line (keep single space, preserve newlines)
    final lines = current.split('\n');
    final cleanedLines = <String>[];

    for (final line in lines) {
      // Collapse tabs and multiple spaces to a single space
      final collapsed = line.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
      cleanedLines.add(collapsed);
    }

    // 6. Collapse excessive consecutive blank lines (max 2 consecutive newlines)
    var joined = cleanedLines.join('\n');
    joined = joined.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

    // 7. Evaluate OCR quality score
    final qualityScore = _evaluateOcrQuality(joined);
    final isPoorQuality = qualityScore < 0.50 || (joined.length < 25 && rawText.length < 25);

    return NormalizedTextResult(
      text: joined,
      ocrQualityScore: qualityScore,
      isPoorQuality: isPoorQuality,
      originalLength: rawText.length,
      cleanedLength: joined.length,
      transformations: transformations,
    );
  }

  /// Calculates an OCR quality score between 0.0 and 1.0 based on:
  /// - Ratio of readable alphanumeric characters to total characters
  /// - Ratio of recognized word patterns vs random symbol noise
  /// - Absence of high garbage character frequency
  double _evaluateOcrQuality(String text) {
    if (text.trim().isEmpty) return 0.0;

    int totalChars = text.length;
    int garbageSymbols = 0;
    int lettersAndDigits = 0;

    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      // Newlines and tabs are valid whitespace
      if (code == 10 || code == 9 || code == 32) {
        continue;
      }
      // Standard alphanumeric or Indian language scripts (Devanagari 0x0900..0x097F)
      if ((code >= 65 && code <= 90) ||
          (code >= 97 && code <= 122) ||
          (code >= 48 && code <= 57) ||
          (code >= 0x0900 && code <= 0x097F)) {
        lettersAndDigits++;
      } else if (code >= 33 && code <= 126) {
        // Count suspicious repeated non-standard OCR artifacts: ~ ` ^ | \ _
        if (code == 126 || code == 96 || code == 94 || code == 124) {
          garbageSymbols++;
        }
      } else {
        // Non-printable or unexpected control bytes
        garbageSymbols++;
      }
    }

    if (totalChars == 0) return 0.0;

    final letterRatio = lettersAndDigits / totalChars;
    final garbageRatio = garbageSymbols / totalChars;

    // Word length check: detects random noise like "kjhsf 98327 ksjdfh !@#"
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 0.0;

    int validWordLikeCount = 0;
    for (final w in words) {
      if (RegExp(r'^[A-Za-z0-9\u0900-\u097F.,₹()/:%-]+$').hasMatch(w) && w.length >= 2) {
        validWordLikeCount++;
      }
    }
    final validWordRatio = validWordLikeCount / words.length;

    double score = (letterRatio * 0.45) + (validWordRatio * 0.45) - (garbageRatio * 0.50);
    return score.clamp(0.0, 1.0);
  }
}
