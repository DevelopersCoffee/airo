
import 'package:platform_retrieval/platform_retrieval.dart';

class RetrievedContext {
  final RetrievalResult result;
  RetrievedContext(this.result);
}

class CitationMap {
  final Map<String, String> citations;
  CitationMap(this.citations);
}

class GroundedPrompt {
  final String text;
  final CitationMap citations;
  GroundedPrompt(this.text, this.citations);
}

abstract class PromptBuilder {
  Future<GroundedPrompt> buildPrompt(String userPrompt, RetrievedContext context);
}
