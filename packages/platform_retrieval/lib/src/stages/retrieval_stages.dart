
class RetrievedChunk {
  final String chunkId;
  final String content;
  final double score;
  RetrievedChunk({required this.chunkId, required this.content, required this.score});
}

class RetrievedDocument {
  final String documentId;
  final List<RetrievedChunk> chunks;
  RetrievedDocument({required this.documentId, required this.chunks});
}

class RetrievalResult {
  final List<RetrievedDocument> documents;
  RetrievalResult(this.documents);
}

abstract class CandidateGenerator {
  Future<RetrievalResult> generateCandidates(String query);
}

abstract class Reranker {
  Future<RetrievalResult> rerank(String query, RetrievalResult candidates);
}
