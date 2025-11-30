/// Utility class for sanitizing user input
class Sanitizer {
  Sanitizer._();

  /// Maximum length for description fields
  static const int maxDescriptionLength = 500;
  
  /// Maximum length for category/tag fields
  static const int maxCategoryLength = 50;

  /// Sanitize text input by removing potentially dangerous characters
  /// and trimming whitespace
  static String sanitizeText(String input, {int? maxLength}) {
    if (input.isEmpty) return input;

    // Remove null bytes and other control characters
    var sanitized = input.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
    
    // Remove HTML/script tags
    sanitized = _stripHtml(sanitized);
    
    // Normalize whitespace (multiple spaces to single space)
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');
    
    // Trim leading/trailing whitespace
    sanitized = sanitized.trim();
    
    // Enforce max length
    final limit = maxLength ?? maxDescriptionLength;
    if (sanitized.length > limit) {
      sanitized = sanitized.substring(0, limit);
    }
    
    return sanitized;
  }

  /// Sanitize a description field
  static String sanitizeDescription(String input) {
    return sanitizeText(input, maxLength: maxDescriptionLength);
  }

  /// Sanitize a category/tag field
  static String sanitizeCategory(String input) {
    return sanitizeText(input, maxLength: maxCategoryLength);
  }

  /// Sanitize amount input - ensure it's a valid positive number
  static double? sanitizeAmount(String input) {
    if (input.isEmpty) return null;
    
    // Remove currency symbols and commas
    var cleaned = input.replaceAll(RegExp(r'[^\d.]'), '');
    
    // Handle multiple decimal points
    final parts = cleaned.split('.');
    if (parts.length > 2) {
      cleaned = '${parts[0]}.${parts.sublist(1).join('')}';
    }
    
    final amount = double.tryParse(cleaned);
    if (amount == null || amount < 0) return null;
    
    // Round to 2 decimal places
    return (amount * 100).round() / 100;
  }

  /// Strip HTML tags from text
  static String _stripHtml(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'&[a-zA-Z]+;'), ' ')
        .replaceAll(RegExp(r'&#\d+;'), ' ');
  }

  /// Check if text contains potentially malicious content
  static bool containsSuspiciousContent(String input) {
    final patterns = [
      RegExp(r'<script', caseSensitive: false),
      RegExp(r'javascript:', caseSensitive: false),
      RegExp(r'on\w+\s*=', caseSensitive: false), // onclick, onerror, etc.
      RegExp(r'data:', caseSensitive: false),
      RegExp(r'vbscript:', caseSensitive: false),
    ];
    
    return patterns.any((pattern) => pattern.hasMatch(input));
  }

  /// Validate and sanitize email address
  static String? sanitizeEmail(String input) {
    final trimmed = input.trim().toLowerCase();
    
    // Basic email validation
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    if (!emailRegex.hasMatch(trimmed)) return null;
    
    return trimmed;
  }

  /// Sanitize a list of tags
  static List<String> sanitizeTags(List<String> tags) {
    return tags
        .map((tag) => sanitizeCategory(tag))
        .where((tag) => tag.isNotEmpty)
        .toSet() // Remove duplicates
        .toList();
  }

  /// Convert cents to formatted currency string
  static String formatCurrency(int cents, {String symbol = '\$'}) {
    final isNegative = cents < 0;
    final absCents = cents.abs();
    final dollars = absCents ~/ 100;
    final remainingCents = absCents % 100;
    final formatted = '$symbol$dollars.${remainingCents.toString().padLeft(2, '0')}';
    return isNegative ? '-$formatted' : formatted;
  }

  /// Parse currency string to cents
  static int? parseCurrencyToCents(String input) {
    final amount = sanitizeAmount(input);
    if (amount == null) return null;
    return (amount * 100).round();
  }
}

