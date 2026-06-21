import 'package:airo_app/features/coins/domain/entities/transaction.dart';
import 'package:airo_app/features/coins/domain/services/finance_message_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FinanceMessageParser', () {
    test('parses credit card spend SMS into an expense', () {
      final parser = FinanceMessageParser(now: () => DateTime(2026, 6, 20));

      final parsed = parser.parse(
        'INR 450.00 spent on your HDFC Bank Credit Card xx1234 at Swiggy '
        'on 20-06-26. Avl limit INR 10000.',
      );

      expect(parsed, isNotNull);
      expect(parsed!.amountCents, 45000);
      expect(parsed.type, TransactionType.expense);
      expect(parsed.description, 'Swiggy');
      expect(parsed.categoryId, 'food');
      expect(parsed.transactionDate, DateTime(2026, 6, 20));
      expect(parsed.sourceTag, startsWith('source:chat_sms:'));
      expect(parsed.isHighConfidence, isTrue);
    });

    test('parses credited SMS into income', () {
      final parser = FinanceMessageParser(now: () => DateTime(2026, 6, 20));

      final parsed = parser.parse(
        'Rs. 50000 credited to your A/c XX1111 on 19/06/2026 from Payroll.',
      );

      expect(parsed, isNotNull);
      expect(parsed!.amountCents, 5000000);
      expect(parsed.type, TransactionType.income);
      expect(parsed.description, 'Payroll');
      expect(parsed.categoryId, 'salary');
    });

    test('ignores non-financial chat messages', () {
      const parser = FinanceMessageParser();

      expect(parser.parse('Can you summarize this note?'), isNull);
    });
  });
}
