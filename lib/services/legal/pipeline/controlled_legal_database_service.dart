import '../../../core/legal/constants/indian_acts_database.dart';
import '../../../core/legal/models/legal_clause.dart';
import '../../../core/legal/models/legal_finding.dart';

/// Step 7 & 45 of Document Analysis Pipeline: Controlled Indian Legal Law Verification.
///
/// Prevents AI hallucination of laws, non-existent sections, or fabricated case citations.
/// Every legal citation presented in the UI is checked against our verified, curated
/// Indian statutory repository. If unverified, it is explicitly flagged.
class ControlledLegalDatabaseService {
  /// Aliases and shorthand terms mapped to official canonical Indian Act titles.
  static final Map<String, String> _actAliases = {
    'bns': 'Bharatiya Nyaya Sanhita, 2023 (BNS)',
    'bharatiya nyaya sanhita': 'Bharatiya Nyaya Sanhita, 2023 (BNS)',
    'ipc': 'Bharatiya Nyaya Sanhita, 2023 (BNS)', // Replaces IPC
    'bsa': 'Bharatiya Sakshya Adhiniyam, 2023 (BSA)',
    'bharatiya sakshya adhiniyam': 'Bharatiya Sakshya Adhiniyam, 2023 (BSA)',
    'evidence act': 'Bharatiya Sakshya Adhiniyam, 2023 (BSA)',
    'contract act': 'Indian Contract Act, 1872',
    'indian contract act': 'Indian Contract Act, 1872',
    'consumer protection act': 'Consumer Protection Act, 2019',
    'cpa': 'Consumer Protection Act, 2019',
    'model tenancy act': 'Model Tenancy Act, 2021',
    'mta': 'Model Tenancy Act, 2021',
    'rera': 'Real Estate (Regulation and Development) Act, 2016 (RERA)',
    'real estate act': 'Real Estate (Regulation and Development) Act, 2016 (RERA)',
    'msmed': 'Micro, Small and Medium Enterprises Development Act, 2006 (MSMED)',
    'msme act': 'Micro, Small and Medium Enterprises Development Act, 2006 (MSMED)',
    'arbitration act': 'Arbitration and Conciliation Act, 1996',
    'usurious loans act': 'Usurious Loans Act, 1918',
    'dpdp': 'Digital Personal Data Protection Act, 2023 (DPDP Act)',
    'data protection act': 'Digital Personal Data Protection Act, 2023 (DPDP Act)',
    'competition act': 'Competition Act, 2002',
    'transfer of property': 'Transfer of Property Act, 1882 & Registration Act, 1908',
  };

  /// Verifies a statutory reference against the controlled Indian database.
  ///
  /// If the statute & section are authentic, returns the verified provision with its
  /// official India Code URL.
  /// If unverified or hallucinated by an AI, returns a flagged citation with:
  /// "Legal reference requires verification."
  StatutoryCitation verifyOrFlag({
    required String rawActName,
    required String rawSection,
    String? providedTitle,
    String? relevanceExplanation,
  }) {
    final cleanAct = rawActName.trim().toLowerCase();
    final cleanSec = _cleanSectionString(rawSection);

    // Look for canonical match in IndianActsDatabase.allProvisions
    for (final provision in IndianActsDatabase.allProvisions) {
      final dbActLower = provision.actName.toLowerCase();
      final dbSecClean = _cleanSectionString(provision.section);

      final actMatches = dbActLower.contains(cleanAct) ||
          cleanAct.contains(dbActLower) ||
          _matchesAlias(cleanAct, dbActLower);

      final secMatches = cleanSec.isNotEmpty &&
          (dbSecClean == cleanSec ||
              dbSecClean.contains(cleanSec) ||
              cleanSec.contains(dbSecClean));

      if (actMatches && secMatches) {
        // Authentic verified law in force
        return StatutoryCitation(
          actName: provision.actName,
          section: provision.section,
          title: provision.title,
          description: relevanceExplanation != null && relevanceExplanation.isNotEmpty
              ? relevanceExplanation
              : provision.description,
          officialSourceUrl: provision.officialSourceUrl,
          isEnforceableInIndia: provision.isEnforceableInIndia,
        );
      }
    }

    // Secondary check: Did act match, but section is slightly different?
    for (final provision in IndianActsDatabase.allProvisions) {
      final dbActLower = provision.actName.toLowerCase();
      if (dbActLower.contains(cleanAct) || _matchesAlias(cleanAct, dbActLower)) {
        if (cleanSec.isNotEmpty && provision.section.toLowerCase().contains(cleanSec)) {
          return StatutoryCitation(
            actName: provision.actName,
            section: provision.section,
            title: provision.title,
            description: relevanceExplanation ?? provision.description,
            officialSourceUrl: provision.officialSourceUrl,
            isEnforceableInIndia: provision.isEnforceableInIndia,
          );
        }
      }
    }

    // Unverified Reference: Mark explicitly as unverified (Section 45)
    return StatutoryCitation(
      actName: rawActName.isNotEmpty ? rawActName : 'Unknown Statute',
      section: rawSection.isNotEmpty ? rawSection : 'Section Unverified',
      title: providedTitle != null && providedTitle.isNotEmpty
          ? '$providedTitle (Requires Verification)'
          : 'Legal reference requires verification',
      description: 'Legal reference requires verification. This provision could not be cross-referenced with the official Indian legislative registry.',
      officialSourceUrl: null,
      isEnforceableInIndia: false,
    );
  }

  /// Retrieves guaranteed verified provisions for a given clause type.
  List<StatutoryCitation> getProvisionsForClause(LegalClauseType clauseType) {
    return IndianActsDatabase.getProvisionsForClause(clauseType);
  }

  /// Searches the controlled database for provisions relevant to a topic or category.
  List<StatutoryCitation> searchCandidateProvisions(String query) {
    if (query.trim().isEmpty) return [];
    final lower = query.toLowerCase();

    return IndianActsDatabase.allProvisions.where((p) {
      return p.actName.toLowerCase().contains(lower) ||
          p.section.toLowerCase().contains(lower) ||
          p.title.toLowerCase().contains(lower) ||
          p.description.toLowerCase().contains(lower);
    }).toList();
  }

  String _cleanSectionString(String sec) {
    return sec
        .toLowerCase()
        .replaceAll('section', '')
        .replaceAll('sec', '')
        .replaceAll('§', '')
        .replaceAll('.', '')
        .replaceAll(' ', '')
        .trim();
  }

  bool _matchesAlias(String rawAct, String dbAct) {
    for (final entry in _actAliases.entries) {
      if (rawAct.contains(entry.key) && dbAct.contains(entry.value.toLowerCase())) {
        return true;
      }
    }
    return false;
  }
}
