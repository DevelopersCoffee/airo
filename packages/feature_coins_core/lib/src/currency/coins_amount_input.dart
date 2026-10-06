import '../models/currency.dart';

/// Locale-tolerant parsing for quick-capture amount fields.
abstract final class CoinsAmountInput {
  /// Digits and common decimal/group separators — not currency symbols.
  static final RegExp allowedInputCharacters = RegExp(r'[0-9.,\s\u00A0]');

  static int? parseToCents(String raw) {
    var normalized = raw.trim();
    if (normalized.isEmpty) return null;

    for (final code in CurrencyCode.values) {
      normalized = normalized.replaceAll(code.symbol, '');
    }
    normalized = normalized.replaceAll(RegExp(r'[\s\u00A0]'), '');
    if (normalized.isEmpty) return null;

    normalized = _normalizeDecimalSeparators(normalized);
    final value = double.tryParse(normalized);
    if (value == null || value <= 0) return null;
    return (value * 100).round();
  }

  static String _normalizeDecimalSeparators(String value) {
    final lastComma = value.lastIndexOf(',');
    final lastDot = value.lastIndexOf('.');
    if (lastComma > lastDot) {
      return value.replaceAll('.', '').replaceAll(',', '.');
    }
    return value.replaceAll(',', '');
  }
}
