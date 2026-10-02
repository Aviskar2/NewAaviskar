/// Confidence level for document risk analysis (Section 35 Step 9 & Section 40).
enum DocumentAnalysisConfidence {
  high,
  medium,
  low,
  insufficientEvidence,
}

extension DocumentAnalysisConfidenceExt on DocumentAnalysisConfidence {
  String get displayName {
    switch (this) {
      case DocumentAnalysisConfidence.high:
        return 'High';
      case DocumentAnalysisConfidence.medium:
        return 'Medium';
      case DocumentAnalysisConfidence.low:
        return 'Low';
      case DocumentAnalysisConfidence.insufficientEvidence:
        return 'Insufficient evidence';
    }
  }

  String get badgeText => 'Confidence: $displayName';
}

/// Comprehensive outcome status for document risk analysis (Section 41 & 47).
enum DocumentAnalysisStatus {
  completed,
  noMaterialRisk,
  lowConfidence,
  insufficientEvidence,
  unsupportedDocument,
  poorOcrQuality,
  analysisUnavailable,
}

extension DocumentAnalysisStatusExt on DocumentAnalysisStatus {
  String get userMessage {
    switch (this) {
      case DocumentAnalysisStatus.completed:
        return 'Analysis complete.';
      case DocumentAnalysisStatus.noMaterialRisk:
        return 'No significant risk indicators detected.';
      case DocumentAnalysisStatus.lowConfidence:
        return 'Analysis completed, but confidence is low due to limited document context.';
      case DocumentAnalysisStatus.insufficientEvidence:
        return 'Document could not be analyzed adequately. Insufficient text or evidence.';
      case DocumentAnalysisStatus.unsupportedDocument:
        return 'Unsupported document type. General legal safety review applied.';
      case DocumentAnalysisStatus.poorOcrQuality:
        return 'Analysis incomplete. The document text quality was insufficient for reliable analysis.';
      case DocumentAnalysisStatus.analysisUnavailable:
        return 'Analysis unavailable. Please check connection and try again.';
    }
  }

  bool get isSuccessful =>
      this == DocumentAnalysisStatus.completed ||
      this == DocumentAnalysisStatus.noMaterialRisk ||
      this == DocumentAnalysisStatus.lowConfidence;

  bool get requiresRetry => this == DocumentAnalysisStatus.analysisUnavailable;
}

/// Structural and factual consistency checks (Section 38 & 51).
class DocumentConsistencyChecks {
  final String partyConsistency; // pass, warning, fail
  final String dateConsistency;  // pass, warning, fail
  final String structure;        // pass, warning, fail
  final String? notes;

  const DocumentConsistencyChecks({
    this.partyConsistency = 'pass',
    this.dateConsistency = 'pass',
    this.structure = 'pass',
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'partyConsistency': {'status': partyConsistency},
    'dateConsistency': {'status': dateConsistency},
    'structure': {'status': structure},
    if (notes != null) 'notes': notes,
  };

  factory DocumentConsistencyChecks.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const DocumentConsistencyChecks();

    String extractStatus(dynamic field) {
      if (field is Map) {
        return field['status']?.toString() ?? 'pass';
      }
      return field?.toString() ?? 'pass';
    }

    return DocumentConsistencyChecks(
      partyConsistency: extractStatus(json['partyConsistency']),
      dateConsistency: extractStatus(json['dateConsistency']),
      structure: extractStatus(json['structure']),
      notes: json['notes']?.toString(),
    );
  }
}
