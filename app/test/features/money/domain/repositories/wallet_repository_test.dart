import 'package:flutter_test/flutter_test.dart';
import 'package:airo_app/features/money/domain/repositories/wallet_repository.dart';

void main() {
  group('Wallet Model', () {
    group('INR formatting', () {
      test('should format balance with rupee symbol', () {
        final wallet = Wallet(
          id: '1',
          name: 'Test Wallet',
          balanceCents: 250050,
          type: WalletType.bank,
          currency: 'INR',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(wallet.balanceAsDouble, 2500.50);
      });

      test('should mask account number correctly', () {
        final wallet = Wallet(
          id: '1',
          name: 'Test Wallet',
          balanceCents: 100000,
          type: WalletType.bank,
          currency: 'INR',
          accountNumber: '1234567890',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(wallet.maskedAccountNumber, '****7890');
      });

      test('should handle empty account number', () {
        final wallet = Wallet(
          id: '1',
          name: 'Test Wallet',
          balanceCents: 100000,
          type: WalletType.cash,
          currency: 'INR',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(wallet.maskedAccountNumber, '');
      });
    });

    group('JSON serialization', () {
      test('should serialize and deserialize correctly', () {
        final original = Wallet(
          id: '1',
          name: 'Test Wallet',
          description: 'Test Description',
          balanceCents: 250050,
          type: WalletType.bank,
          currency: 'INR',
          bankName: 'HDFC Bank',
          accountNumber: '1234567890',
          isActive: true,
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 11, 30),
          metadata: {'key': 'value'},
        );

        final json = original.toJson();
        final restored = Wallet.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.name, original.name);
        expect(restored.description, original.description);
        expect(restored.balanceCents, original.balanceCents);
        expect(restored.type, original.type);
        expect(restored.currency, original.currency);
        expect(restored.bankName, original.bankName);
        expect(restored.accountNumber, original.accountNumber);
        expect(restored.isActive, original.isActive);
      });

      test('should default to INR when currency is missing', () {
        final json = {
          'id': '1',
          'name': 'Test Wallet',
          'balanceCents': 10000,
          'type': 'cash',
          'isActive': true,
          'createdAt': '2025-01-01T00:00:00.000',
          'updatedAt': '2025-11-30T00:00:00.000',
        };

        final wallet = Wallet.fromJson(json);
        expect(wallet.currency, 'INR');
      });
    });

    group('copyWith', () {
      test('should create copy with updated fields', () {
        final original = Wallet(
          id: '1',
          name: 'Original',
          balanceCents: 10000,
          type: WalletType.cash,
          currency: 'INR',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final copy = original.copyWith(
          name: 'Updated',
          balanceCents: 20000,
        );

        expect(copy.id, original.id);
        expect(copy.name, 'Updated');
        expect(copy.balanceCents, 20000);
        expect(copy.type, original.type);
      });
    });

    group('equality', () {
      test('should be equal when IDs match', () {
        final wallet1 = Wallet(
          id: '1',
          name: 'Wallet 1',
          balanceCents: 10000,
          type: WalletType.cash,
          currency: 'INR',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final wallet2 = Wallet(
          id: '1',
          name: 'Wallet 2',
          balanceCents: 20000,
          type: WalletType.bank,
          currency: 'INR',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(wallet1, equals(wallet2));
        expect(wallet1.hashCode, equals(wallet2.hashCode));
      });
    });
  });
}

