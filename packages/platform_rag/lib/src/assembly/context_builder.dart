
import 'package:platform_retrieval/platform_retrieval.dart';

class RagContext {
  final String augmentedPrompt;
  final List<String> citations;
  RagContext(this.augmentedPrompt, this.citations);
}

abstract class ContextBuilder {
  Future<RagContext> buildContext(String userPrompt, List<dynamic> retrievedItems);
}
