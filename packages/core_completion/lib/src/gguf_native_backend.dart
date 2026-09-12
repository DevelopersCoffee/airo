/// Load-agnostic GGUF generate slot (FRB / desktop). Grammar is forwarded.
abstract class GgufNativeBackend {
  bool get isReady;

  Stream<String> generate({
    required String prompt,
    required int maxTokens,
    String? grammar,
  });

  Future<void> stop();
}
