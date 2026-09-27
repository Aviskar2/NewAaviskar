import '../models/government_scheme_model.dart';
import 'scheme_database.dart';

/// Matches citizen profile against government schemes using ALL profile fields.
class SchemeMatcher {
  static List<SchemeMatchResult> matchAll(CitizenProfile profile) {
    if (!profile.hasProfile) {
      // Return ALL schemes when no profile exists — user can browse and filter
      return SchemeDatabase.schemes.map((s) => SchemeMatchResult(
        scheme: s,
        score: 0.3,
        reasons: ['Set up your profile for personalized matching.'],
      )).toList();
    }

    final results = <SchemeMatchResult>[];
    for (final scheme in SchemeDatabase.schemes) {
      final result = _scoreScheme(scheme, profile);
      results.add(result);
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  static List<SchemeMatchResult> topMatches(CitizenProfile profile, {int limit = 10}) {
    return matchAll(profile).take(limit).toList();
  }

  static List<SchemeMatchResult> byCategory(CitizenProfile profile, SchemeCategory category) {
    return matchAll(profile).where((r) => r.scheme.category == category).toList();
  }

  /// Public scoring method for external use (e.g., detail screen eligibility check).
  static SchemeMatchResult scoreScheme(GovernmentScheme scheme, CitizenProfile profile) {
    return _scoreScheme(scheme, profile);
  }

  static SchemeMatchResult _scoreScheme(GovernmentScheme scheme, CitizenProfile profile) {
    double score = 0;
    final reasons = <String>[];
    final elig = scheme.eligibility;

    // ── HARD FILTERS (return 0 immediately if not met) ──

    // Age check
    if (elig.minAge != null && profile.age < elig.minAge!) {
      return SchemeMatchResult(scheme: scheme, score: 0, reasons: ['Minimum age: ${elig.minAge} years']);
    }
    if (elig.maxAge != null && profile.age > elig.maxAge!) {
      return SchemeMatchResult(scheme: scheme, score: 0, reasons: ['Maximum age: ${elig.maxAge} years']);
    }

    // Gender check
    if (elig.gender == EligibilityGender.female && profile.gender != 'Female') {
      return SchemeMatchResult(scheme: scheme, score: 0, reasons: ['Available for women only']);
    }
    if (elig.gender == EligibilityGender.male && profile.gender != 'Male') {
      return SchemeMatchResult(scheme: scheme, score: 0, reasons: ['Available for men only']);
    }

    // SC/ST required — hard filter
    if (elig.isSCSTRequired && !profile.isSCST) {
      return SchemeMatchResult(scheme: scheme, score: 0, reasons: ['Restricted to SC/ST candidates']);
    }

    // State check — hard filter for state-specific schemes
    if (elig.eligibleStates.isNotEmpty) {
      if (elig.eligibleStates.contains(profile.state)) {
        score += 0.15;
        reasons.add('Available in ${profile.state}');
      } else {
        return SchemeMatchResult(scheme: scheme, score: 0, reasons: ['Available only in: ${elig.eligibleStates.join(", ")}']);
      }
    }

    // BPL required — hard filter
    if (elig.isBPLRequired && !profile.isBPL) {
      return SchemeMatchResult(scheme: scheme, score: 0, reasons: ['Requires BPL certificate']);
    }

    // Farmer required — hard filter
    if (elig.isFarmerRequired && !profile.isFarmer && !(profile.occupation?.toLowerCase().contains('farmer') ?? false)) {
      return SchemeMatchResult(scheme: scheme, score: 0, reasons: ['Restricted to farmers']);
    }

    // Student required — hard filter
    if (elig.isStudentRequired && !profile.isStudent) {
      return SchemeMatchResult(scheme: scheme, score: 0, reasons: ['Restricted to students']);
    }

    // Disability required — hard filter
    if (elig.isDisabledRequired && !profile.isDisabled) {
      return SchemeMatchResult(scheme: scheme, score: 0, reasons: ['Restricted to persons with disabilities']);
    }

    // Minority required — hard filter
    if (elig.isMinorityRequired && !profile.isMinority) {
      return SchemeMatchResult(scheme: scheme, score: 0, reasons: ['Restricted to minority communities']);
    }

    // Widow required — hard filter
    if (elig.isWidowRequired && !profile.isWidow) {
      return SchemeMatchResult(scheme: scheme, score: 0, reasons: ['Restricted to widows']);
    }

    // ── SCORING (soft matches that add points) ──

    // Income scoring
    if (elig.maxAnnualIncome != null) {
      if (profile.annualIncome <= elig.maxAnnualIncome!) {
        score += 0.2;
        reasons.add('Income within limit (Rs ${_formatIncome(elig.maxAnnualIncome!)})');
      } else {
        score -= 0.05;
        reasons.add('Income may exceed limit (Rs ${_formatIncome(elig.maxAnnualIncome!)})');
      }
    }

    // BPL bonus
    if (elig.isBPLRequired && profile.isBPL) {
      score += 0.1;
    }

    // SC/ST bonus
    if (elig.isSCSTRequired && profile.isSCST) {
      score += 0.1;
    }

    // Occupation matching
    if (elig.occupationRequired != null || elig.occupations.isNotEmpty) {
      final userOcc = profile.occupation?.toLowerCase() ?? '';
      bool matched = false;

      // Check occupationRequired
      if (elig.occupationRequired != null) {
        final occ = elig.occupationRequired!.toLowerCase();
        matched = _matchOccupation(occ, userOcc, profile);
      }

      // Check occupations array
      if (!matched && elig.occupations.isNotEmpty) {
        for (final occ in elig.occupations) {
          if (_matchOccupation(occ.toLowerCase(), userOcc, profile)) {
            matched = true;
            break;
          }
        }
      }

      if (matched) {
        score += 0.2;
        reasons.add('Occupation matches');
      } else if (userOcc.isNotEmpty) {
        reasons.add('Occupation requirement exists — check eligibility');
      }
    }

    // Category-specific bonuses
    if (profile.isFarmer && _textMatches(scheme, 'farmer|agriculture|kisan|crop|farming')) {
      score += 0.12;
      reasons.add('Relevant for farmers');
    }

    if (profile.isStudent && _textMatches(scheme, 'student|education|scholarship|fellowship|tuition|university|college|school')) {
      score += 0.12;
      reasons.add('Relevant for students');
    }

    if (profile.isSeniorCitizen && (scheme.category == SchemeCategory.seniorCitizen || _textMatches(scheme, 'senior|elderly|old age|pension|geriatric'))) {
      score += 0.15;
      reasons.add('Senior citizen relevant');
    }

    if (profile.isDisabled && (scheme.category == SchemeCategory.disability || _textMatches(scheme, 'disab|divyang|differently.abled|udid'))) {
      score += 0.15;
      reasons.add('Disability welfare');
    }

    if (profile.isWoman && (scheme.category == SchemeCategory.womenChild || _textMatches(scheme, 'women|woman|girl|beti|ladi|matru|pregnant|maternity'))) {
      score += 0.12;
      reasons.add('Women welfare');
    }

    if (profile.isWidow && _textMatches(scheme, 'widow|vidhwa')) {
      score += 0.15;
      reasons.add('Widow scheme');
    }

    if (profile.isMinority && _textMatches(scheme, 'minority|muslim|christian|sikh|buddhist|jain|parsi')) {
      score += 0.12;
      reasons.add('Minority welfare');
    }

    // Category match bonus
    if (scheme.category == SchemeCategory.health && _textMatches(scheme, 'health|medical|hospital|insurance|ayushman')) {
      score += 0.05;
    }
    if (scheme.category == SchemeCategory.housing && _textMatches(scheme, 'house|housing|awas|flat|home')) {
      score += 0.05;
    }
    if (scheme.category == SchemeCategory.finance && _textMatches(scheme, 'loan|credit|bank|finance|mudra')) {
      score += 0.05;
    }
    if (scheme.category == SchemeCategory.employment && _textMatches(scheme, 'employ|job|work|rozgar|mgnrega|skill')) {
      score += 0.05;
    }
    if (scheme.category == SchemeCategory.food && _textMatches(scheme, 'food|ration|grain|midday|poshan')) {
      score += 0.05;
    }
    if (scheme.category == SchemeCategory.pension && _textMatches(scheme, 'pension|maandhan|vaya')) {
      score += 0.05;
    }
    if (scheme.category == SchemeCategory.insurance && _textMatches(scheme, 'insur|bima|suraksha')) {
      score += 0.05;
    }

    // Base relevance
    score += 0.05;
    if (reasons.isEmpty) {
      reasons.add('General eligibility — check details');
    }

    return SchemeMatchResult(
      scheme: scheme,
      score: score.clamp(0.0, 1.0),
      reasons: reasons,
    );
  }

  static bool _matchOccupation(String required, String userOcc, CitizenProfile profile) {
    if (required.isEmpty) return false;

    // Unorganised worker — broad match
    if (required == 'unorganised worker') {
      const keywords = [
        'street vendor', 'rickshaw', 'auto', 'domestic', 'construction',
        'factory', 'daily wage', 'labourer', 'driver', 'tailor', 'mechanic',
        'artisan', 'transport', 'fisherman', 'vendor', 'helper', 'cleaner',
        'welder', 'carpenter', 'mason', 'sweeper', 'gardener', 'peon',
        'watchman', 'security', 'delivery', 'soberwala', ' ironwala',
      ];
      return keywords.any((k) => userOcc.contains(k)) || profile.isFarmer;
    }

    // Farmer
    if (required == 'farmer') {
      return profile.isFarmer || userOcc.contains('farmer') || userOcc.contains('kisan');
    }

    // Street vendor
    if (required == 'street vendor') {
      return userOcc.contains('vendor') || userOcc.contains('rehri') || userOcc.contains('thela');
    }

    // Direct match
    if (userOcc.contains(required) || required.contains(userOcc)) return true;

    // Common occupation mappings
    const mappings = {
      'domestic worker': ['domestic', 'housekeep', 'maid', 'servant'],
      'construction worker': ['construction', 'building', 'mason'],
      'factory worker': ['factory', 'industrial', 'plant'],
      'driver': ['driver', 'chauffeur', 'auto', 'taxi', 'truck'],
      'rickshaw puller': ['rickshaw', 'cycle rickshaw'],
      'tailor': ['tailor', 'darzi'],
      'mechanic': ['mechanic', 'repair'],
      'artisan': ['artisan', 'craft', 'karigar'],
      'fisherman': ['fisher', 'machhli', 'boat'],
      'weaver': ['weav', 'loom', 'bunkar'],
      'barber': ['barber', 'nai'],
      'washerman': ['washerman', 'dhobi'],
      'blacksmith': ['blacksmith', 'lohar'],
      'goldsmith': ['goldsmith', 'sonar'],
      'potter': ['potter', 'kumhar'],
      'cobbler': ['cobbler', 'mochi'],
    };

    for (final entry in mappings.entries) {
      if (required == entry.key || entry.value.any((k) => required.contains(k))) {
        if (entry.value.any((k) => userOcc.contains(k))) return true;
      }
    }

    return false;
  }

  static bool _textMatches(GovernmentScheme scheme, String pattern) {
    final text = '${scheme.name} ${scheme.shortName} ${scheme.description} ${scheme.plainLanguageSummary}'.toLowerCase();
    final keywords = pattern.split('|');
    return keywords.any((k) => text.contains(k.trim()));
  }

  static String _formatIncome(double income) {
    if (income >= 100000) {
      return '${(income / 100000).toStringAsFixed(1)} Lakh';
    }
    return income.toStringAsFixed(0);
  }
}

class SchemeMatchResult {
  final GovernmentScheme scheme;
  final double score;
  final List<String> reasons;

  const SchemeMatchResult({
    required this.scheme,
    required this.score,
    required this.reasons,
  });

  String get matchLabel {
    if (score >= 0.8) return 'Excellent Match';
    if (score >= 0.6) return 'Strong Match';
    if (score >= 0.4) return 'Good Match';
    if (score >= 0.2) return 'Possible Match';
    return 'Check Eligibility';
  }

  double get matchPercent => (score * 100).clamp(0, 100);
}
