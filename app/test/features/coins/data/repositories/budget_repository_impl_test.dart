import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:airo_app/features/coins/data/datasources/coins_local_datasource.dart';
import 'package:airo_app/features/coins/data/mappers/budget_mapper.dart';
import 'package:airo_app/features/coins/data/repositories/budget_repository_impl.dart';
import 'package:airo_app/features/coins/domain/entities/budget.dart';

class MockCoinsLocalDatasource extends Mock implements CoinsLocalDatasource {}

class MockBudgetMapper extends Mock implements BudgetMapper {}

void main() {
  late MockCoinsLocalDatasource mockDatasource;
  late MockBudgetMapper mockMapper;
  late BudgetRepositoryImpl repository;

  setUp(() {
    mockDatasource = MockCoinsLocalDatasource();
    mockMapper = MockBudgetMapper();
    repository = BudgetRepositoryImpl(mockDatasource, mockMapper);
  });

  setUpAll(() {
    registerFallbackValue(_createBudgetEntity());
    registerFallbackValue(_createBudget());
  });

  group('BudgetRepositoryImpl', () {
    group('findById', () {
      test('should return budget when found', () async {
        final entity = _createBudgetEntity();
        final budget = _createBudget();

        when(
          () => mockDatasource.getBudgetById('budget1'),
        ).thenAnswer((_) async => entity);
        when(() => mockMapper.toDomain(entity)).thenReturn(budget);

        final result = await repository.findById('budget1');

        expect(result.data, isNotNull);
        expect(result.error, isNull);
        expect(result.data!.id, 'budget1');
      });

      test('should return error when not found', () async {
        when(
          () => mockDatasource.getBudgetById('nonexistent'),
        ).thenAnswer((_) async => null);

        final result = await repository.findById('nonexistent');

        expect(result.data, isNull);
        expect(result.error, 'Budget not found');
      });

      test('should return error on exception', () async {
        when(
          () => mockDatasource.getBudgetById(any()),
        ).thenThrow(Exception('Database error'));

        final result = await repository.findById('budget1');

        expect(result.data, isNull);
        expect(result.error, contains('Failed to fetch budget'));
      });
    });

    group('findByCategory', () {
      test('should return budget when found for category', () async {
        final entity = _createBudgetEntity();
        final budget = _createBudget();

        when(
          () => mockDatasource.getBudgetByCategory('food'),
        ).thenAnswer((_) async => entity);
        when(() => mockMapper.toDomain(entity)).thenReturn(budget);

        final result = await repository.findByCategory('food');

        expect(result.data, isNotNull);
        expect(result.error, isNull);
      });

      test('should return null when no budget for category', () async {
        when(
          () => mockDatasource.getBudgetByCategory('nonexistent'),
        ).thenAnswer((_) async => null);

        final result = await repository.findByCategory('nonexistent');

        expect(result.data, isNull);
        expect(result.error, isNull);
      });
    });

    group('findActive', () {
      test('should return active budgets', () async {
        final entities = [_createBudgetEntity()];
        final budget = _createBudget();

        when(
          () => mockDatasource.getActiveBudgets(),
        ).thenAnswer((_) async => entities);
        when(() => mockMapper.toDomain(any())).thenReturn(budget);

        final result = await repository.findActive();

        expect(result.data, isNotNull);
        expect(result.data!.length, 1);
        expect(result.error, isNull);
      });

      test('should return empty list when no active budgets', () async {
        when(
          () => mockDatasource.getActiveBudgets(),
        ).thenAnswer((_) async => []);

        final result = await repository.findActive();

        expect(result.data, isEmpty);
        expect(result.error, isNull);
      });
    });

    group('findAll', () {
      test('should return all budgets', () async {
        final entities = [
          _createBudgetEntity(),
          _createBudgetEntity(id: 'budget2'),
        ];
        final budget = _createBudget();

        when(
          () => mockDatasource.getAllBudgets(),
        ).thenAnswer((_) async => entities);
        when(() => mockMapper.toDomain(any())).thenReturn(budget);

        final result = await repository.findAll();

        expect(result.data, isNotNull);
        expect(result.data!.length, 2);
      });
    });

    group('create', () {
      test('should create budget successfully', () async {
        final budget = _createBudget();
        final entity = _createBudgetEntity();

        when(() => mockMapper.toEntity(budget)).thenReturn(entity);
        when(() => mockDatasource.insertBudget(any())).thenAnswer((_) async {});

        final result = await repository.create(budget);

        expect(result.data, isNotNull);
        expect(result.error, isNull);
        verify(() => mockDatasource.insertBudget(entity)).called(1);
      });

      test('should return error on create failure', () async {
        final budget = _createBudget();

        when(
          () => mockMapper.toEntity(any()),
        ).thenReturn(_createBudgetEntity());
        when(
          () => mockDatasource.insertBudget(any()),
        ).thenThrow(Exception('Insert failed'));

        final result = await repository.create(budget);

        expect(result.data, isNull);
        expect(result.error, contains('Failed to create budget'));
      });
    });

    group('update', () {
      test('should update budget successfully', () async {
        final budget = _createBudget();
        final entity = _createBudgetEntity();

        when(() => mockMapper.toEntity(budget)).thenReturn(entity);
        when(() => mockDatasource.updateBudget(any())).thenAnswer((_) async {});

        final result = await repository.update(budget);

        expect(result.data, isNotNull);
        expect(result.error, isNull);
      });

      test('should return error on update failure', () async {
        final budget = _createBudget();

        when(
          () => mockMapper.toEntity(any()),
        ).thenReturn(_createBudgetEntity());
        when(
          () => mockDatasource.updateBudget(any()),
        ).thenThrow(Exception('Update failed'));

        final result = await repository.update(budget);

        expect(result.data, isNull);
        expect(result.error, contains('Failed to update budget'));
      });
    });

    group('deactivate', () {
      test('should deactivate budget successfully', () async {
        when(
          () => mockDatasource.deactivateBudget('budget1'),
        ).thenAnswer((_) async {});

        final result = await repository.deactivate('budget1');

        expect(result.error, isNull);
        verify(() => mockDatasource.deactivateBudget('budget1')).called(1);
      });

      test('should return error on deactivate failure', () async {
        when(
          () => mockDatasource.deactivateBudget(any()),
        ).thenThrow(Exception('Deactivate failed'));

        final result = await repository.deactivate('budget1');

        expect(result.error, contains('Failed to deactivate budget'));
      });
    });

    group('delete', () {
      test('should delete budget successfully', () async {
        when(
          () => mockDatasource.deleteBudget('budget1'),
        ).thenAnswer((_) async {});

        final result = await repository.delete('budget1');

        expect(result.error, isNull);
        verify(() => mockDatasource.deleteBudget('budget1')).called(1);
      });

      test('should return error on delete failure', () async {
        when(
          () => mockDatasource.deleteBudget(any()),
        ).thenThrow(Exception('Delete failed'));

        final result = await repository.delete('budget1');

        expect(result.error, contains('Failed to delete budget'));
      });
    });

    group('hasBudget', () {
      test('should return true when budget exists for category', () async {
        when(
          () => mockDatasource.getBudgetByCategory('food'),
        ).thenAnswer((_) async => _createBudgetEntity());

        final result = await repository.hasBudget('food');

        expect(result.data, true);
        expect(result.error, isNull);
      });

      test('should return false when no budget for category', () async {
        when(
          () => mockDatasource.getBudgetByCategory('nonexistent'),
        ).thenAnswer((_) async => null);

        final result = await repository.hasBudget('nonexistent');

        expect(result.data, false);
        expect(result.error, isNull);
      });

      test('should return error on exception', () async {
        when(
          () => mockDatasource.getBudgetByCategory(any()),
        ).thenThrow(Exception('Database error'));

        final result = await repository.hasBudget('food');

        expect(result.data, isNull);
        expect(result.error, contains('Failed to check budget'));
      });
    });

    group('watchActive', () {
      test('should stream active budgets', () async {
        final entities = [_createBudgetEntity()];
        final budget = _createBudget();

        when(
          () => mockDatasource.watchActiveBudgets(),
        ).thenAnswer((_) => Stream.value(entities));
        when(() => mockMapper.toDomain(any())).thenReturn(budget);

        final budgets = await repository.watchActive().first;

        expect(budgets.length, 1);
      });
    });

    group('watchById', () {
      test('should stream budget by id', () async {
        final entity = _createBudgetEntity();
        final budget = _createBudget();

        when(
          () => mockDatasource.watchBudgetById('budget1'),
        ).thenAnswer((_) => Stream.value(entity));
        when(() => mockMapper.toDomain(entity)).thenReturn(budget);

        final result = await repository.watchById('budget1').first;

        expect(result, isNotNull);
        expect(result!.id, 'budget1');
      });

      test('should stream null when budget not found', () async {
        when(
          () => mockDatasource.watchBudgetById('nonexistent'),
        ).thenAnswer((_) => Stream.value(null));

        final result = await repository.watchById('nonexistent').first;

        expect(result, isNull);
      });
    });
  });
}

// Helper functions

BudgetEntity _createBudgetEntity({
  String id = 'budget1',
  String name = 'Food Budget',
  String categoryId = 'food',
  int limitCents = 50000,
  String period = 'monthly',
}) {
  return BudgetEntity(
    id: id,
    name: name,
    categoryId: categoryId,
    limitCents: limitCents,
    period: period,
    alertThresholdPercent: 80,
    isActive: true,
    currencyCode: 'INR',
    startDate: DateTime(2024, 1, 1),
    createdAt: DateTime(2024, 1, 1),
  );
}

Budget _createBudget({
  String id = 'budget1',
  String categoryId = 'food',
  int limitCents = 50000,
}) {
  return Budget(
    id: id,
    categoryId: categoryId,
    limitCents: limitCents,
    period: BudgetPeriod.monthly,
    alertThresholdPercent: 80,
    isActive: true,
    startDate: DateTime(2024, 1, 1),
    createdAt: DateTime(2024, 1, 1),
  );
}
