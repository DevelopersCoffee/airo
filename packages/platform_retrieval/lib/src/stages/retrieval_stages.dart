
class RetrievedChunk {
  RetrievedChunk({required this.chunkId, required this.content, required this.score});
  final String chunkId;
  final String content;
  final double score;
}

class RetrievedDocument {
  RetrievedDocument({required this.documentId, required this.chunks});
  final String documentId;
  final List<RetrievedChunk> chunks;
}

class RetrievalResult {
  RetrievalResult(this.documents);
  final List<RetrievedDocument> documents;
}

abstract class CandidateGenerator {
  Future<RetrievalResult> generateCandidates(String query);
}

abstract class Reranker {
  Future<RetrievalResult> rerank(String query, RetrievalResult candidates);
}
