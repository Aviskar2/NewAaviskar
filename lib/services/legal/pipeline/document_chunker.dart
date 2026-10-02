import 'clause_segmentation_service.dart';

/// A logical chunk of segmented clauses for processing long documents without context overflow.
class DocumentChunk {
  final int chunkIndex;
  final int totalChunks;
  final List<SegmentedClause> clauses;
  final String combinedText;

  const DocumentChunk({
    required this.chunkIndex,
    required this.totalChunks,
    required this.clauses,
    required this.combinedText,
  });
}

/// Step 44 of Document Analysis Pipeline: Multi-Stage Document Chunking.
///
/// Prevents large documents from overwhelming AI context windows or causing timeouts
/// by partitioning clauses into manageable chunks with overlap.
class DocumentChunker {
  final int maxClausesPerChunk;
  final int maxCharsPerChunk;
  final int overlapClauses;

  const DocumentChunker({
    this.maxClausesPerChunk = 8,
    this.maxCharsPerChunk = 4500,
    this.overlapClauses = 1,
  });

  /// Chunks a list of [SegmentedClause]s into processing batches.
  List<DocumentChunk> createChunks(List<SegmentedClause> clauses) {
    if (clauses.isEmpty) return [];

    final totalChars = clauses.fold<int>(0, (sum, c) => sum + c.text.length);

    // If small enough, single chunk
    if (clauses.length <= maxClausesPerChunk && totalChars <= maxCharsPerChunk) {
      return [
        DocumentChunk(
          chunkIndex: 0,
          totalChunks: 1,
          clauses: clauses,
          combinedText: clauses.map((c) => '[${c.id}] ${c.text}').join('\n\n'),
        )
      ];
    }

    final chunks = <DocumentChunk>[];
    int startIdx = 0;

    while (startIdx < clauses.length) {
      final currentBatch = <SegmentedClause>[];
      int currentChars = 0;

      for (int i = startIdx; i < clauses.length; i++) {
        final clause = clauses[i];
        if (currentBatch.length >= maxClausesPerChunk ||
            (currentChars + clause.text.length > maxCharsPerChunk && currentBatch.isNotEmpty)) {
          break;
        }
        currentBatch.add(clause);
        currentChars += clause.text.length;
      }

      final combined = currentBatch.map((c) => '[${c.id}] ${c.text}').join('\n\n');
      chunks.add(DocumentChunk(
        chunkIndex: chunks.length,
        totalChunks: 0, // updated below
        clauses: currentBatch,
        combinedText: combined,
      ));

      // Advance with overlap
      final advance = (currentBatch.length - overlapClauses).clamp(1, currentBatch.length);
      startIdx += advance;
    }

    // Set correct total chunks count
    return chunks
        .map((c) => DocumentChunk(
              chunkIndex: c.chunkIndex,
              totalChunks: chunks.length,
              clauses: c.clauses,
              combinedText: c.combinedText,
            ))
        .toList();
  }
}
