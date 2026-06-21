import 'package:airo_app/features/coins/domain/services/quick_add_expense_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuickAddExpenseParser', () {
    test('parses a food split command into an expense draft', () {
      const parser = QuickAddExpenseParser();

      final draft = parser.parse('Pizza 420 split with Alex');

      expect(draft, isNotNull);
      expect(draft!.description, 'Pizza');
      expect(draft.amountCents, 42000);
      expect(draft.categoryId, 'food');
      expect(draft.budgetTag, 'Food');
      expect(draft.isSplit, isTrue);
      expect(draft.participants, ['Alex']);
    });

    test('detects recurring entertainment subscriptions', () {
      const parser = QuickAddExpenseParser();

      final draft = parser.parse('Netflix 649 recurring');

      expect(draft, isNotNull);
      expect(draft!.description, 'Netflix');
      expect(draft.amountCents, 64900);
      expect(draft.categoryId, 'shopping');
      expect(draft.budgetTag, 'Entertainment');
      expect(draft.isRecurring, isTrue);
    });

    test('returns null when no amount can be found', () {
      const parser = QuickAddExpenseParser();

      expect(parser.parse('Pizza with Alex'), isNull);
    });
  });
}
