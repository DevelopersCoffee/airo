/// Token-stream completion. Callers buffer until the stream completes.
abstract class CompletionClient {
  bool get isAvailable;

  Stream<String> generate({
    required String prompt,
    String? grammar,
    int maxTokens = 512,
  });

  Future<void> stop();
}
