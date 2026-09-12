import 'completion_client.dart';

/// Scripted [CompletionClient] for tests. Never loads a model file.
class FakeCompletionClient implements CompletionClient {
  FakeCompletionClient({
    this.tokens = const [],
    this.error,
    this.available = true,
  });

  final List<String> tokens;
  final Object? error;
  final bool available;

  String? lastPrompt;
  String? lastGrammar;
  int? lastMaxTokens;

  @override
  bool get isAvailable => available;

  @override
  Stream<String> generate({
    required String prompt,
    String? grammar,
    int maxTokens = 512,
  }) {
    lastPrompt = prompt;
    lastGrammar = grammar;
    lastMaxTokens = maxTokens;
    if (error != null) return Stream<String>.error(error!);
    return Stream<String>.fromIterable(tokens);
  }

  @override
  Future<void> stop() async {}
}
