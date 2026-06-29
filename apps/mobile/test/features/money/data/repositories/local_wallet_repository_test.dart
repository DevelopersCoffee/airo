import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:airo_app/features/money/domain/repositories/wallet_repository.dart';
import 'package:airo_app/features/money/data/repositories/local_wallet_repository.dart';

void main() {
  late LocalWalletRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = LocalWalletRepository();
  });

  group('LocalWalletRepository', () {
    group('create wallet', () {
      test('should create wallet with correct data', () async {
        final result = await repository.create(
          name: 'Test Wallet',
          description: 'Test Description',
          balanceCents: 100000,
          type: WalletType.bank,
          currency: 'INR',
          bankName: 'HDFC Bank',
          accountNumber: '1234567890',
        );

        expect(result.isOk, true);
        final wallet = result.getOrNull();
        expect(wallet, isNotNull);
        expect(wallet!.name, 'Test Wallet');
        expect(wallet.description, 'Test Description');
        expect(wallet.balanceCents, 100000);
        expect(wallet.type, WalletType.bank);
        expect(wallet.currency, 'INR');
        expect(wallet.bankName, 'HDFC Bank');
        expect(wallet.accountNumber, '1234567890');
        expect(wallet.isActive, true);
      });

      test('should generate unique ID for each wallet', () async {
        final result1 = await repository.create(
          name: 'Wallet 1',
          balanceCents: 1000,
          type: WalletType.cash,
          currency: 'INR',
        );
        final result2 = await repository.create(
          name: 'Wallet 2',
          balanceCents: 2000,
          type: WalletType.cash,
          currency: 'INR',
        );

        expect(result1.getOrNull()!.id, isNot(result2.getOrNull()!.id));
      });
    });

    group('fetchAll', () {
      test('should return empty list when no wallets exist', () async {
        final result = await repository.fetchAll();
        expect(result.isOk, true);
        expect(result.getOrNull(), isEmpty);
      });

      test('should return all active wallets', () async {
        await repository.create(
          name: 'Wallet 1',
          balanceCents: 1000,
          type: WalletType.cash,
          currency: 'INR',
        );
        await repository.create(
          name: 'Wallet 2',
          balanceCents: 2000,
          type: WalletType.bank,
          currency: 'INR',
        );

        final result = await repository.fetchAll();
        expect(result.isOk, true);
        expect(result.getOrNull()!.length, 2);
      });
    });

    group('fetchById', () {
      test('should return wallet when exists', () async {
        final createResult = await repository.create(
          name: 'Test Wallet',
          balanceCents: 5000,
          type: WalletType.cash,
          currency: 'INR',
        );
        final walletId = createResult.getOrNull()!.id;

        final result = await repository.fetchById(walletId);
        expect(result.isOk, true);
        expect(result.getOrNull()!.name, 'Test Wallet');
      });

      test('should return error when wallet not found', () async {
        final result = await repository.fetchById('non-existent-id');
        expect(result.isErr, true);
      });
    });

    group('updateBalance', () {
      test('should update balance correctly', () async {
        final createResult = await repository.create(
          name: 'Test Wallet',
          balanceCents: 10000,
          type: WalletType.cash,
          currency: 'INR',
        );
        final walletId = createResult.getOrNull()!.id;

        final result = await repository.updateBalance(walletId, 25000);
        expect(result.isOk, true);
        expect(result.getOrNull()!.balanceCents, 25000);
      });

      test('should handle negative balance (for credit cards)', () async {
        final createResult = await repository.create(
          name: 'Credit Card',
          balanceCents: 0,
          type: WalletType.credit,
          currency: 'INR',
        );
        final walletId = createResult.getOrNull()!.id;

        final result = await repository.updateBalance(walletId, -50000);
        expect(result.isOk, true);
        expect(result.getOrNull()!.balanceCents, -50000);
      });
    });

    group('getTotalBalanceCents', () {
      test('should return sum of all active wallet balances', () async {
        await repository.create(
          name: 'Wallet 1',
          balanceCents: 10000,
          type: WalletType.cash,
          currency: 'INR',
        );
        await repository.create(
          name: 'Wallet 2',
          balanceCents: 20000,
          type: WalletType.bank,
          currency: 'INR',
        );

        final result = await repository.getTotalBalanceCents();
        expect(result.isOk, true);
        expect(result.getOrNull(), 30000);
      });
    });
  });
}
