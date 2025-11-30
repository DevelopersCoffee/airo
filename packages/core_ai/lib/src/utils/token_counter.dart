/// Utility for estimating token counts.
///
/// Note: This is an approximation. For accurate counts,
/// use the actual tokenizer from the model provider.
abstract final class TokenCounter {
  /// Approximate tokens per character for English text
  static const double _tokensPerChar = 0.25;

  /// Estimates token count for the given text.
  ///
  /// This uses a simple heuristic: ~4 characters per token for English.
  /// Actual counts may vary based on the specific tokenizer used.
  static int estimate(String text) => (text.length * _tokensPerChar).ceil();

  /// Estimates if text fits within a token limit
  static bool fitsInLimit(String text, int maxTokens) =>
      estimate(text) <= maxTokens;

  /// Truncates text to fit within token limit
  static String truncateToFit(String text, int maxTokens) {
    final estimatedTokens = estimate(text);
    if (estimatedTokens <= maxTokens) {
      return text;
    }

    // Calculate approximate character limit
    final maxChars = (maxTokens / _tokensPerChar).floor();
    if (maxChars >= text.length) {
      return text;
    }

    // Find a word boundary to truncate at
    var truncateAt = maxChars;
    while (truncateAt > 0 && text[truncateAt] != ' ') {
      truncateAt--;
    }

    if (truncateAt == 0) {
      truncateAt = maxChars; // No word boundary found, hard truncate
    }

    return '${text.substring(0, truncateAt)}...';
  }

  /// Gemini Nano token limits
  static const int geminiNanoMaxPromptTokens = 1024;
  static const int geminiNanoMaxContextTokens = 4096;

  /// Gemini API token limits (approximate)
  static const int geminiApiMaxContextTokens = 32768;
}

