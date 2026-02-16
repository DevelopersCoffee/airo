import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:airo_app/features/coins/data/datasources/coins_local_datasource.dart';
import 'package:airo_app/features/coins/data/mappers/transaction_mapper.dart';
import 'package:airo_app/features/coins/data/repositories/transaction_repository_impl.dart';
import 'package:airo_app/features/coins/domain/entities/transaction.dart';

class MockCoinsLocalDatasource extends Mock implements CoinsLocalDatasource {}

class MockTransactionMapper extends Mock implements TransactionMapper {}

void main() {
  late MockCoinsLocalDatasource mockDatasource;
  late MockTransactionMapper mockMapper;
  late TransactionRepositoryImpl repository;

  setUp(() {
    mockDatasource = MockCoinsLocalDatasource();
    mockMapper = MockTransactionMapper();
    repository = TransactionRepositoryImpl(mockDatasource, mockMapper);
  });

  setUpAll(() {
    registerFallbackValue(_createTransactionEntity());
    registerFallbackValue(_createTransaction());
  });

  group('TransactionRepositoryImpl', () {
    group('findById', () {
      test('should return transaction when found', () async {
        final entity = _createTransactionEntity();
        final transaction = _createTransaction();

        when(
          () => mockDatasource.getTransactionById('tx1'),
        ).thenAnswer((_) async => entity);
        when(() => mockMapper.toDomain(entity)).thenReturn(transaction);

        final result = await repository.findById('tx1');

        expect(result.data, isNotNull);
        expect(result.error, isNull);
        expect(result.data!.id, 'tx1');
        verify(() => mockDatasource.getTransactionById('tx1')).called(1);
      });

      test('should return error when not found', () async {
        when(
          () => mockDatasource.getTransactionById('nonexistent'),
        ).thenAnswer((_) async => null);

        final result = await repository.findById('nonexistent');

        expect(result.data, isNull);
        expect(result.error, 'Transaction not found');
      });

      test('should return error on exception', () async {
        when(
          () => mockDatasource.getTransactionById(any()),
        ).thenThrow(Exception('Database error'));

        final result = await repository.findById('tx1');

        expect(result.data, isNull);
        expect(result.error, contains('Failed to fetch transaction'));
      });
    });

    group('findByDateRange', () {
      test('should return transactions in date range', () async {
        final start = DateTime(2024, 1, 1);
        final end = DateTime(2024, 1, 31);
        final entities = [_createTransactionEntity()];
        final transaction = _createTransaction();

        when(
          () => mockDatasource.getTransactionsByDateRange(start, end),
        ).thenAnswer((_) async => entities);
        when(() => mockMapper.toDomain(any())).thenReturn(transaction);

        final result = await repository.findByDateRange(start, end);

        expect(result.data, isNotNull);
        expect(result.data!.length, 1);
        expect(result.error, isNull);
      });

      test('should return empty list when no transactions in range', () async {
        final start = DateTime(2024, 1, 1);
        final end = DateTime(2024, 1, 31);

        when(
          () => mockDatasource.getTransactionsByDateRange(start, end),
        ).thenAnswer((_) async => []);

        final result = await repository.findByDateRange(start, end);

        expect(result.data, isNotNull);
        expect(result.data, isEmpty);
      });

      test('should return error on exception', () async {
        when(
          () => mockDatasource.getTransactionsByDateRange(any(), any()),
        ).thenThrow(Exception('Database error'));

        final result = await repository.findByDateRange(
          DateTime(2024, 1, 1),
          DateTime(2024, 1, 31),
        );

        expect(result.data, isNull);
        expect(result.error, contains('Failed to fetch transactions'));
      });
    });

    group('create', () {
      test('should create transaction successfully', () async {
        final transaction = _createTransaction();
        final entity = _createTransactionEntity();

        when(() => mockMapper.toEntity(transaction)).thenReturn(entity);
        when(
          () => mockDatasource.insertTransaction(any()),
        ).thenAnswer((_) async {});

        final result = await repository.create(transaction);

        expect(result.data, isNotNull);
        expect(result.error, isNull);
        verify(() => mockDatasource.insertTransaction(entity)).called(1);
      });

      test('should return error on insert failure', () async {
        final transaction = _createTransaction();

        when(
          () => mockMapper.toEntity(any()),
        ).thenReturn(_createTransactionEntity());
        when(
          () => mockDatasource.insertTransaction(any()),
        ).thenThrow(Exception('Insert failed'));

        final result = await repository.create(transaction);

        expect(result.data, isNull);
        expect(result.error, contains('Failed to create transaction'));
      });
    });

    group('update', () {
      test('should update transaction successfully', () async {
        final transaction = _createTransaction();
        final entity = _createTransactionEntity();

        when(() => mockMapper.toEntity(transaction)).thenReturn(entity);
        when(
          () => mockDatasource.updateTransaction(any()),
        ).thenAnswer((_) async {});

        final result = await repository.update(transaction);

        expect(result.data, isNotNull);
        expect(result.error, isNull);
      });

      test('should return error on update failure', () async {
        final transaction = _createTransaction();

        when(
          () => mockMapper.toEntity(any()),
        ).thenReturn(_createTransactionEntity());
        when(
          () => mockDatasource.updateTransaction(any()),
        ).thenThrow(Exception('Update failed'));

        final result = await repository.update(transaction);

        expect(result.data, isNull);
        expect(result.error, contains('Failed to update transaction'));
      });
    });

    group('delete', () {
      test('should soft delete transaction successfully', () async {
        when(
          () => mockDatasource.softDeleteTransaction('tx1'),
        ).thenAnswer((_) async {});

        final result = await repository.delete('tx1');

        expect(result.error, isNull);
        verify(() => mockDatasource.softDeleteTransaction('tx1')).called(1);
      });

      test('should return error on delete failure', () async {
        when(
          () => mockDatasource.softDeleteTransaction(any()),
        ).thenThrow(Exception('Delete failed'));

        final result = await repository.delete('tx1');

        expect(result.error, contains('Failed to delete transaction'));
      });
    });

    group('hardDelete', () {
      test('should hard delete transaction successfully', () async {
        when(
          () => mockDatasource.hardDeleteTransaction('tx1'),
        ).thenAnswer((_) async {});

        final result = await repository.hardDelete('tx1');

        expect(result.error, isNull);
        verify(() => mockDatasource.hardDeleteTransaction('tx1')).called(1);
      });
    });

    group('restore', () {
      test('should restore transaction successfully', () async {
        final entity = _createTransactionEntity();
        final transaction = _createTransaction();

        when(
          () => mockDatasource.restoreTransaction('tx1'),
        ).thenAnswer((_) async {});
        when(
          () => mockDatasource.getTransactionById('tx1'),
        ).thenAnswer((_) async => entity);
        when(() => mockMapper.toDomain(entity)).thenReturn(transaction);

        final result = await repository.restore('tx1');

        expect(result.data, isNotNull);
        expect(result.error, isNull);
      });

      test(
        'should return error when transaction not found after restore',
        () async {
          when(
            () => mockDatasource.restoreTransaction('tx1'),
          ).thenAnswer((_) async {});
          when(
            () => mockDatasource.getTransactionById('tx1'),
          ).thenAnswer((_) async => null);

          final result = await repository.restore('tx1');

          expect(result.data, isNull);
          expect(result.error, contains('not found after restore'));
        },
      );
    });

    group('findByCategory', () {
      test('should return transactions for category', () async {
        final entities = [_createTransactionEntity()];
        final transaction = _createTransaction();

        when(
          () => mockDatasource.getTransactionsByCategory('food'),
        ).thenAnswer((_) async => entities);
        when(() => mockMapper.toDomain(any())).thenReturn(transaction);

        final result = await repository.findByCategory('food');

        expect(result.data, isNotNull);
        expect(result.data!.length, 1);
      });
    });

    group('findByAccount', () {
      test('should return transactions for account', () async {
        final entities = [_createTransactionEntity()];
        final transaction = _createTransaction();

        when(
          () => mockDatasource.getTransactionsByAccount('acc1'),
        ).thenAnswer((_) async => entities);
        when(() => mockMapper.toDomain(any())).thenReturn(transaction);

        final result = await repository.findByAccount('acc1');

        expect(result.data, isNotNull);
        expect(result.data!.length, 1);
      });
    });

    group('findRecent', () {
      test('should return recent transactions with default limit', () async {
        final entities = List.generate(10, (_) => _createTransactionEntity());
        final transaction = _createTransaction();

        when(
          () => mockDatasource.getRecentTransactions(10),
        ).thenAnswer((_) async => entities);
        when(() => mockMapper.toDomain(any())).thenReturn(transaction);

        final result = await repository.findRecent();

        expect(result.data, isNotNull);
        expect(result.data!.length, 10);
      });

      test('should respect custom limit', () async {
        final entities = List.generate(5, (_) => _createTransactionEntity());
        final transaction = _createTransaction();

        when(
          () => mockDatasource.getRecentTransactions(5),
        ).thenAnswer((_) async => entities);
        when(() => mockMapper.toDomain(any())).thenReturn(transaction);

        final result = await repository.findRecent(limit: 5);

        expect(result.data!.length, 5);
        verify(() => mockDatasource.getRecentTransactions(5)).called(1);
      });
    });

    group('getTotalSpent', () {
      test('should return total spent amount', () async {
        final start = DateTime(2024, 1, 1);
        final end = DateTime(2024, 1, 31);

        when(
          () => mockDatasource.getTotalSpent(start, end),
        ).thenAnswer((_) async => 50000);

        final result = await repository.getTotalSpent(start, end);

        expect(result.data, 50000);
        expect(result.error, isNull);
      });
    });

    group('getSpentByCategory', () {
      test('should return spending by category', () async {
        final start = DateTime(2024, 1, 1);
        final end = DateTime(2024, 1, 31);
        final categoryTotals = {'food': 25000, 'transport': 15000};

        when(
          () => mockDatasource.getSpentByCategory(start, end),
        ).thenAnswer((_) async => categoryTotals);

        final result = await repository.getSpentByCategory(start, end);

        expect(result.data, isNotNull);
        expect(result.data!['food'], 25000);
        expect(result.data!['transport'], 15000);
      });
    });

    group('search', () {
      test('should return matching transactions', () async {
        final entities = [_createTransactionEntity()];
        final transaction = _createTransaction();

        when(
          () => mockDatasource.searchTransactions('coffee'),
        ).thenAnswer((_) async => entities);
        when(() => mockMapper.toDomain(any())).thenReturn(transaction);

        final result = await repository.search('coffee');

        expect(result.data, isNotNull);
        expect(result.data!.length, 1);
      });

      test('should return empty list for no matches', () async {
        when(
          () => mockDatasource.searchTransactions('nonexistent'),
        ).thenAnswer((_) async => []);

        final result = await repository.search('nonexistent');

        expect(result.data, isEmpty);
      });
    });
  });
}

// Helper functions

TransactionEntity _createTransactionEntity({
  String id = 'tx1',
  String description = 'Test transaction',
  int amountCents = -1500,
  String type = 'expense',
  String categoryId = 'food',
  String accountId = 'acc1',
}) {
  return TransactionEntity(
    id: id,
    description: description,
    amountCents: amountCents,
    type: type,
    categoryId: categoryId,
    accountId: accountId,
    transactionDate: DateTime(2024, 3, 15),
    createdAt: DateTime(2024, 3, 15),
    isDeleted: false,
  );
}

Transaction _createTransaction({
  String id = 'tx1',
  String description = 'Test transaction',
  int amountCents = -1500,
  String categoryId = 'food',
  String accountId = 'acc1',
}) {
  return Transaction(
    id: id,
    description: description,
    amountCents: amountCents,
    type: TransactionType.expense,
    categoryId: categoryId,
    accountId: accountId,
    transactionDate: DateTime(2024, 3, 15),
    createdAt: DateTime(2024, 3, 15),
  );
}
