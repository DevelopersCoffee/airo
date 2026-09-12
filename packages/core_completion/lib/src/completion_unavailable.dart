/// Thrown when no GGUF (or other) backend can run [CompletionClient.generate].
class CompletionUnavailable implements Exception {
  const CompletionUnavailable(this.code);

  /// Stable code, e.g. `gguf_model_not_loaded`, `gguf_backend_unavailable`.
  final String code;

  @override
  String toString() => 'CompletionUnavailable($code)';
}
