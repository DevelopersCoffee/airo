/// Timing and token counts from the native llama.cpp runtime.
class GgufRuntimeStats {
  const GgufRuntimeStats({
    required this.prefillMs,
    required this.prefillTokens,
    required this.generationMs,
    required this.generatedTokens,
    required this.tokensPerSecond,
  });

  final int prefillMs;
  final int prefillTokens;
  final int generationMs;
  final int generatedTokens;
  final double tokensPerSecond;

  bool get hasTokenCounts => prefillTokens > 0 || generatedTokens > 0;
}
