
import 'package:platform_content/platform_content.dart';

abstract class CandidateGenerator {
  Future<List<ContentDocument>> generateCandidates(String query);
}

abstract class Reranker {
  Future<List<ContentDocument>> rerank(String query, List<ContentDocument> candidates);
}
