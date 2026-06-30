
import 'package:platform_retrieval/platform_retrieval.dart';

class RetrievedContext {
  RetrievedContext(this.result);
  final RetrievalResult result;
}

class CitationMap {
  CitationMap(this.citations);
  final Map<String, String> citations;
}

class GroundedPrompt {
  GroundedPrompt(this.text, this.citations);
  final String text;
  final CitationMap citations;
}

abstract class PromptBuilder {
  Future<GroundedPrompt> buildPrompt(String userPrompt, RetrievedContext context);
}
