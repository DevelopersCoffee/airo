import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:airo_app/features/coins/data/datasources/coins_local_datasource.dart';
import 'package:airo_app/features/coins/data/mappers/account_mapper.dart';
import 'package:airo_app/features/coins/data/repositories/account_repository_impl.dart';
import 'package:airo_app/features/coins/domain/entities/account.dart';

class MockCoinsLocalDatasource extends Mock implements CoinsLocalDatasource {}

class MockAccountMapper extends Mock implements AccountMapper {}

void main() {
  late MockCoinsLocalDatasource mockDatasource;
  late MockAccountMapper mockMapper;
  late AccountRepositoryImpl repository;

  setUp(() {
    mockDatasource = MockCoinsLocalDatasource();
    mockMapper = MockAccountMapper();
    repository = AccountRepositoryImpl(mockDatasource, mockMapper);
  });

  setUpAll(() {
    registerFallbackValue(_createAccountEntity());
    registerFallbackValue(_createAccount());
  });

  group('AccountRepositoryImpl', () {
    group('findById', () {
      test('should return account when found', () async {
        final entity = _createAccountEntity();
        final account = _createAccount();

        when(
          () => mockDatasource.getAccountById('acc1'),
        ).thenAnswer((_) async => entity);
        when(() => mockMapper.toDomain(entity)).thenReturn(account);

        final result = await repository.findById('acc1');

        expect(result.data, isNotNull);
        expect(result.error, isNull);
        expect(result.data!.id, 'acc1');
      });

      test('should return error when not found', () async {
        when(
          () => mockDatasource.getAccountById('nonexistent'),
        ).thenAnswer((_) async => null);

        final result = await repository.findById('nonexistent');

        expect(result.data, isNull);
        expect(result.error, 'Account not found');
      });

      test('should return error on exception', () async {
        when(
          () => mockDatasource.getAccountById(any()),
        ).thenThrow(Exception('Database error'));

        final result = await repository.findById('acc1');

        expect(result.data, isNull);
        expect(result.error, contains('Failed to fetch account'));
      });
    });

    group('findActive', () {
      test('should return active accounts', () async {
        final entities = [_createAccountEntity()];
        final account = _createAccount();

        when(
          () => mockDatasource.getActiveAccounts(),
        ).thenAnswer((_) async => entities);
        when(() => mockMapper.toDomain(any())).thenReturn(account);

        final result = await repository.findActive();

        expect(result.data, isNotNull);
        expect(result.data!.length, 1);
        expect(result.error, isNull);
      });

      test('should return empty list when no active accounts', () async {
        when(
          () => mockDatasource.getActiveAccounts(),
        ).thenAnswer((_) async => []);

        final result = await repository.findActive();

        expect(result.data, isEmpty);
        expect(result.error, isNull);
      });
    });

    group('findAll', () {
      test('should return all accounts', () async {
        final entities = [
          _createAccountEntity(),
          _createAccountEntity(id: 'acc2'),
        ];
        final account = _createAccount();

        when(
          () => mockDatasource.getAllAccounts(),
        ).thenAnswer((_) async => entities);
        when(() => mockMapper.toDomain(any())).thenReturn(account);

        final result = await repository.findAll();

        expect(result.data, isNotNull);
        expect(result.data!.length, 2);
      });
    });

    group('findDefault', () {
      test('should return default account when exists', () async {
        final entity = _createAccountEntity(isDefault: true);
        final account = _createAccount(isDefault: true);

        when(
          () => mockDatasource.getDefaultAccount(),
        ).thenAnswer((_) async => entity);
        when(() => mockMapper.toDomain(entity)).thenReturn(account);

        final result = await repository.findDefault();

        expect(result.data, isNotNull);
        expect(result.data!.isDefault, true);
        expect(result.error, isNull);
      });

      test('should return null when no default account', () async {
        when(
          () => mockDatasource.getDefaultAccount(),
        ).thenAnswer((_) async => null);

        final result = await repository.findDefault();

        expect(result.data, isNull);
        expect(result.error, isNull);
      });
    });

    group('create', () {
      test('should create account successfully', () async {
        final account = _createAccount();
        final entity = _createAccountEntity();

        when(() => mockMapper.toEntity(account)).thenReturn(entity);
        when(
          () => mockDatasource.insertAccount(any()),
        ).thenAnswer((_) async {});

        final result = await repository.create(account);

        expect(result.data, isNotNull);
        expect(result.error, isNull);
        verify(() => mockDatasource.insertAccount(entity)).called(1);
      });

      test('should return error on create failure', () async {
        final account = _createAccount();

        when(
          () => mockMapper.toEntity(any()),
        ).thenReturn(_createAccountEntity());
        when(
          () => mockDatasource.insertAccount(any()),
        ).thenThrow(Exception('Insert failed'));

        final result = await repository.create(account);

        expect(result.data, isNull);
        expect(result.error, contains('Failed to create account'));
      });
    });

    group('update', () {
      test('should update account successfully', () async {
        final account = _createAccount();
        final entity = _createAccountEntity();

        when(() => mockMapper.toEntity(account)).thenReturn(entity);
        when(
          () => mockDatasource.updateAccount(any()),
        ).thenAnswer((_) async {});

        final result = await repository.update(account);

        expect(result.data, isNotNull);
        expect(result.error, isNull);
      });
    });

    group('updateBalance', () {
      test('should update balance and return updated account', () async {
        final entity = _createAccountEntity(balanceCents: 75000);
        final account = _createAccount(balanceCents: 75000);

        when(
          () => mockDatasource.updateAccountBalance('acc1', 75000),
        ).thenAnswer((_) async {});
        when(
          () => mockDatasource.getAccountById('acc1'),
        ).thenAnswer((_) async => entity);
        when(() => mockMapper.toDomain(entity)).thenReturn(account);

        final result = await repository.updateBalance('acc1', 75000);

        expect(result.data, isNotNull);
        expect(result.data!.balanceCents, 75000);
      });

      test('should return error when account not found after update', () async {
        when(
          () => mockDatasource.updateAccountBalance('acc1', 75000),
        ).thenAnswer((_) async {});
        when(
          () => mockDatasource.getAccountById('acc1'),
        ).thenAnswer((_) async => null);

        final result = await repository.updateBalance('acc1', 75000);

        expect(result.data, isNull);
        expect(result.error, contains('Account not found after update'));
      });
    });

    group('setDefault', () {
      test('should set default account successfully', () async {
        when(
          () => mockDatasource.setDefaultAccount('acc1'),
        ).thenAnswer((_) async {});

        final result = await repository.setDefault('acc1');

        expect(result.error, isNull);
        verify(() => mockDatasource.setDefaultAccount('acc1')).called(1);
      });
    });

    group('archive', () {
      test('should archive account successfully', () async {
        when(
          () => mockDatasource.archiveAccount('acc1'),
        ).thenAnswer((_) async {});

        final result = await repository.archive('acc1');

        expect(result.error, isNull);
        verify(() => mockDatasource.archiveAccount('acc1')).called(1);
      });
    });

    group('restore', () {
      test('should restore account successfully', () async {
        when(
          () => mockDatasource.restoreAccount('acc1'),
        ).thenAnswer((_) async {});

        final result = await repository.restore('acc1');

        expect(result.error, isNull);
        verify(() => mockDatasource.restoreAccount('acc1')).called(1);
      });
    });

    group('delete', () {
      test('should delete account successfully', () async {
        when(
          () => mockDatasource.deleteAccount('acc1'),
        ).thenAnswer((_) async {});

        final result = await repository.delete('acc1');

        expect(result.error, isNull);
        verify(() => mockDatasource.deleteAccount('acc1')).called(1);
      });
    });

    group('getTotalBalance', () {
      test('should return total balance', () async {
        when(
          () => mockDatasource.getTotalBalance(),
        ).thenAnswer((_) async => 150000);

        final result = await repository.getTotalBalance();

        expect(result.data, 150000);
        expect(result.error, isNull);
      });
    });

    group('watchActive', () {
      test('should stream active accounts', () async {
        final entities = [_createAccountEntity()];
        final account = _createAccount();

        when(
          () => mockDatasource.watchActiveAccounts(),
        ).thenAnswer((_) => Stream.value(entities));
        when(() => mockMapper.toDomain(any())).thenReturn(account);

        final accounts = await repository.watchActive().first;

        expect(accounts.length, 1);
      });
    });

    group('watchTotalBalance', () {
      test('should stream total balance', () async {
        when(
          () => mockDatasource.watchTotalBalance(),
        ).thenAnswer((_) => Stream.value(150000));

        final balance = await repository.watchTotalBalance().first;

        expect(balance, 150000);
      });
    });
  });
}

// Helper functions

AccountEntity _createAccountEntity({
  String id = 'acc1',
  String name = 'Cash Wallet',
  String type = 'cash',
  int balanceCents = 50000,
  bool isDefault = false,
}) {
  return AccountEntity(
    id: id,
    name: name,
    type: type,
    balanceCents: balanceCents,
    currencyCode: 'INR',
    isDefault: isDefault,
    isArchived: false,
    createdAt: DateTime(2024, 1, 1),
  );
}

Account _createAccount({
  String id = 'acc1',
  String name = 'Cash Wallet',
  int balanceCents = 50000,
  bool isDefault = false,
}) {
  return Account(
    id: id,
    name: name,
    type: AccountType.cash,
    balanceCents: balanceCents,
    currencyCode: 'INR',
    isDefault: isDefault,
    isArchived: false,
    createdAt: DateTime(2024, 1, 1),
  );
}
