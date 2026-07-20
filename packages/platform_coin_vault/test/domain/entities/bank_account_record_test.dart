import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/src/domain/entities/bank_account_record.dart';

void main() {
  group('BankAccountRecord', () {
    test('constructs with a valid IFSC code', () {
      final record = BankAccountRecord(
        id: null,
        nickname: 'HDFC Salary',
        bankName: 'HDFC Bank',
        accountHolderName: 'Jane Doe',
        accountNumber: '1234567890',
        ifscCode: 'HDFC0001234',
        accountType: 'savings',
      );

      expect(record.ifscCode, 'HDFC0001234');
    });

    test('throws ArgumentError for an invalid IFSC code', () {
      expect(
        () => BankAccountRecord(
          id: null,
          nickname: 'Bad IFSC',
          bankName: 'HDFC Bank',
          accountHolderName: 'Jane Doe',
          accountNumber: '1234567890',
          ifscCode: 'not-an-ifsc',
          accountType: 'savings',
        ),
        throwsArgumentError,
      );
    });

    test('two records with identical fields are equal', () {
      final a = BankAccountRecord(
        id: 1,
        nickname: 'HDFC Salary',
        bankName: 'HDFC Bank',
        accountHolderName: 'Jane Doe',
        accountNumber: '1234567890',
        ifscCode: 'HDFC0001234',
        accountType: 'savings',
        createdAt: DateTime(2026, 7, 19),
      );
      final b = BankAccountRecord(
        id: 1,
        nickname: 'HDFC Salary',
        bankName: 'HDFC Bank',
        accountHolderName: 'Jane Doe',
        accountNumber: '1234567890',
        ifscCode: 'HDFC0001234',
        accountType: 'savings',
        createdAt: DateTime(2026, 7, 19),
      );

      expect(a, equals(b));
    });
  });
}
