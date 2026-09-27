import '../../core/legal/constants/indian_acts_database.dart';
import '../../core/legal/models/legal_clause.dart';
import '../../core/legal/models/legal_finding.dart';

class IndianLawRagService {
  /// Retrieves relevant Indian statutory provisions based on the query or clause type.
  List<StatutoryCitation> retrieveProvisions(String query, {LegalClauseType? clauseType}) {
    if (clauseType != null) {
      return IndianActsDatabase.getProvisionsForClause(clauseType);
    }

    final lower = query.toLowerCase();
    final results = <StatutoryCitation>[];

    for (final provision in IndianActsDatabase.allProvisions) {
      if (provision.title.toLowerCase().contains(lower) ||
          provision.actName.toLowerCase().contains(lower) ||
          provision.section.toLowerCase().contains(lower) ||
          provision.description.toLowerCase().contains(lower)) {
        results.add(provision);
      }
    }

    if (results.isEmpty) {
      // Return default statutory provisions
      return IndianActsDatabase.allProvisions.take(2).toList();
    }

    return results;
  }
}
