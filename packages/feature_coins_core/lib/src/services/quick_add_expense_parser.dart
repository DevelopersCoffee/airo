class QuickExpenseDraft {
  final String description;
  final int amountCents;
  final String categoryId;
  final String budgetTag;
  final bool isRecurring;
  final bool isSplit;
  final List<String> participants;

  const QuickExpenseDraft({
    required this.description,
    required this.amountCents,
    required this.categoryId,
    required this.budgetTag,
    this.isRecurring = false,
    this.isSplit = false,
    this.participants = const [],
  });
}

class QuickAddExpenseParser {
  const QuickAddExpenseParser();

  QuickExpenseDraft? parse(String input) {
    final normalized = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return null;

    final amountMatch = RegExp(
      r'(?:₹|\$)?\s*(\d+(?:\.\d{1,2})?)',
    ).firstMatch(normalized);
    if (amountMatch == null) return null;

    final amount = double.tryParse(amountMatch.group(1)!);
    if (amount == null || amount <= 0) return null;

    final beforeAmount = normalized.substring(0, amountMatch.start).trim();
    final afterAmount = normalized.substring(amountMatch.end).trim();
    final commandText = '$beforeAmount $afterAmount'.trim();
    final lowerCommand = commandText.toLowerCase();
    final isRecurring =
        lowerCommand.contains('recurring') ||
        lowerCommand.contains('subscription') ||
        lowerCommand.contains('monthly');
    final isSplit =
        lowerCommand.contains('split with') || lowerCommand.contains('split ');
    final participants = _extractParticipants(commandText);
    final description = _cleanDescription(beforeAmount);
    final category = _categoryFor('$description $commandText');

    return QuickExpenseDraft(
      description: description.isEmpty ? 'Expense' : description,
      amountCents: (amount * 100).round(),
      categoryId: category.categoryId,
      budgetTag: category.budgetTag,
      isRecurring: isRecurring,
      isSplit: isSplit,
      participants: participants,
    );
  }

  String _cleanDescription(String text) {
    return text
        .replaceAll(
          RegExp(r'\b(split|with|recurring|monthly)\b', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _extractParticipants(String text) {
    final match = RegExp(
      r'\bsplit\s+with\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return const [];

    return match
        .group(1)!
        .replaceAll(
          RegExp(r'\b(recurring|monthly|subscription)\b', caseSensitive: false),
          '',
        )
        .split(RegExp(r',|\band\b|&'))
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .map((name) => name[0].toUpperCase() + name.substring(1))
        .toList(growable: false);
  }

  _QuickCategory _categoryFor(String text) {
    final lower = text.toLowerCase();
    if (_containsAny(lower, [
      'uber',
      'ola',
      'cab',
      'taxi',
      'metro',
      'flight',
    ])) {
      return const _QuickCategory('transport', 'Travel');
    }
    if (_containsAny(lower, [
      'netflix',
      'spotify',
      'movie',
      'cinema',
      'game',
    ])) {
      return const _QuickCategory('shopping', 'Entertainment');
    }
    if (_containsAny(lower, ['salary', 'bonus', 'income'])) {
      return const _QuickCategory('salary', 'Income');
    }
    if (_containsAny(lower, [
      'pizza',
      'dinner',
      'lunch',
      'coffee',
      'food',
      'restaurant',
      'swiggy',
      'zomato',
    ])) {
      return const _QuickCategory('food', 'Food');
    }
    return const _QuickCategory('shopping', 'Shopping');
  }

  bool _containsAny(String text, List<String> needles) {
    return needles.any(text.contains);
  }
}

class _QuickCategory {
  final String categoryId;
  final String budgetTag;

  const _QuickCategory(this.categoryId, this.budgetTag);
}
