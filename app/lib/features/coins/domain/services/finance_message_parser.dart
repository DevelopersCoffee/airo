import '../entities/transaction.dart';

/// Structured transaction candidate extracted from a pasted bank/card/UPI alert.
class ParsedFinanceMessage {
  final String description;
  final int amountCents;
  final TransactionType type;
  final String categoryId;
  final DateTime transactionDate;
  final String sourceHash;
  final double confidence;

  const ParsedFinanceMessage({
    required this.description,
    required this.amountCents,
    required this.type,
    required this.categoryId,
    required this.transactionDate,
    required this.sourceHash,
    required this.confidence,
  });

  String get sourceTag => 'source:chat_sms:$sourceHash';

  bool get isHighConfidence => confidence >= 0.70;
}

/// Deterministic parser for finance SMS/notification text pasted into chat.
///
/// Keep this rules-first. Local LLMs can explain or review uncertain results,
/// but ledger math should come from deterministic extraction.
class FinanceMessageParser {
  const FinanceMessageParser({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  ParsedFinanceMessage? parse(String rawText) {
    final normalized = _normalize(rawText);
    if (!_looksFinancial(normalized)) return null;

    final amountCents = _extractAmountCents(normalized);
    if (amountCents == null || amountCents <= 0) return null;

    final type = _detectType(normalized);
    if (type == null) return null;

    final merchant = _extractMerchant(normalized);
    final categoryId = _categorize(normalized, merchant);
    final date = _extractDate(normalized) ?? _now();
    final description = _buildDescription(merchant, normalized, type);
    final confidence = _confidence(normalized, merchant, type);

    return ParsedFinanceMessage(
      description: description,
      amountCents: amountCents,
      type: type,
      categoryId: categoryId,
      transactionDate: DateTime(date.year, date.month, date.day),
      sourceHash: _stableHash(normalized),
      confidence: confidence,
    );
  }

  bool _looksFinancial(String text) {
    final hasAmount = RegExp(
      r'(?:inr|rs\.?|₹)\s*[0-9]',
      caseSensitive: false,
    ).hasMatch(text);
    final hasTransactionWord = RegExp(
      r'\b(debit|debited|spent|paid|purchase|withdrawn|credited|credit|received|upi|a/c|account|card)\b',
      caseSensitive: false,
    ).hasMatch(text);
    return hasAmount && hasTransactionWord;
  }

  int? _extractAmountCents(String text) {
    final match = RegExp(
      r'(?:inr|rs\.?|₹)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;

    final rawAmount = match.group(1)?.replaceAll(',', '');
    if (rawAmount == null) return null;

    final amount = double.tryParse(rawAmount);
    if (amount == null) return null;
    return (amount * 100).round();
  }

  TransactionType? _detectType(String text) {
    final lower = text.toLowerCase();
    if (RegExp(
      r'\b(credited|received|refund|cashback|salary)\b',
    ).hasMatch(lower)) {
      return TransactionType.income;
    }
    if (RegExp(
      r'\b(debited|debit|spent|paid|purchase|withdrawn|sent)\b',
    ).hasMatch(lower)) {
      return TransactionType.expense;
    }
    return null;
  }

  String _extractMerchant(String text) {
    final patterns = [
      RegExp(
        r'\bat\s+([a-z0-9 &._-]{2,40}?)(?:\s+on\b|\.|,|$)',
        caseSensitive: false,
      ),
      RegExp(
        r'\bto\s+([a-z0-9 &._-]{2,40}?)(?:\s+on\b|\.|,|$)',
        caseSensitive: false,
      ),
      RegExp(
        r'\bfrom\s+([a-z0-9 &._-]{2,40}?)(?:\s+on\b|\.|,|$)',
        caseSensitive: false,
      ),
      RegExp(
        r'\binfo:\s*([a-z0-9 /&._-]{2,40}?)(?:\.|,|$)',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      final candidate = match?.group(1)?.trim();
      if (candidate != null && candidate.isNotEmpty) {
        return _titleCase(_cleanMerchant(candidate));
      }
    }
    return 'Unknown merchant';
  }

  DateTime? _extractDate(String text) {
    final match = RegExp(
      r'\b([0-3]?\d)[-/]([01]?\d)[-/](\d{2,4})\b',
    ).firstMatch(text);
    if (match == null) return null;

    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    var year = int.tryParse(match.group(3)!);
    if (day == null || month == null || year == null) return null;
    if (year < 100) year += 2000;

    try {
      return DateTime(year, month, day);
    } on ArgumentError {
      return null;
    }
  }

  String _categorize(String text, String merchant) {
    final haystack = '$text ${merchant.toLowerCase()}';
    if (RegExp(
      r'\b(swiggy|zomato|restaurant|cafe|coffee|food|dining|blinkit|zepto|instamart|grocery)\b',
    ).hasMatch(haystack)) {
      return 'food';
    }
    if (RegExp(
      r'\b(uber|ola|rapido|metro|fuel|petrol|diesel|irctc|parking|toll)\b',
    ).hasMatch(haystack)) {
      return 'transport';
    }
    if (RegExp(
      r'\b(amazon|flipkart|myntra|ajio|shopping|store|mall|retail)\b',
    ).hasMatch(haystack)) {
      return 'shopping';
    }
    if (RegExp(
      r'\b(salary|payroll|credited by employer)\b',
    ).hasMatch(haystack)) {
      return 'salary';
    }
    return 'shopping';
  }

  String _buildDescription(String merchant, String text, TransactionType type) {
    if (merchant != 'Unknown merchant') return merchant;
    if (type == TransactionType.income) return 'Money received';
    if (text.toLowerCase().contains('upi')) return 'UPI payment';
    if (text.toLowerCase().contains('card')) return 'Card payment';
    return 'Finance SMS transaction';
  }

  double _confidence(String text, String merchant, TransactionType type) {
    var score = 0.55;
    if (merchant != 'Unknown merchant') score += 0.20;
    if (_extractDate(text) != null) score += 0.10;
    if (text.toLowerCase().contains('upi') ||
        text.toLowerCase().contains('card') ||
        text.toLowerCase().contains('a/c')) {
      score += 0.10;
    }
    if (type == TransactionType.income) score += 0.03;
    return score.clamp(0, 1);
  }

  String _normalize(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _cleanMerchant(String value) {
    return value
        .replaceAll(
          RegExp(r'\b(ref|upi|txn|transaction|id)\b.*$', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _titleCase(String value) {
    return value
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) {
          if (part.length == 1) return part.toUpperCase();
          return '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}';
        })
        .join(' ');
  }

  String _stableHash(String text) {
    var hash = 0x811c9dc5;
    for (final unit in text.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
