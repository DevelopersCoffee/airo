import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:airo_app/features/coins/data/datasources/coins_local_datasource.dart';
import 'package:airo_app/features/coins/data/mappers/settlement_mapper.dart';
import 'package:airo_app/features/coins/data/repositories/settlement_repository_impl.dart';
import 'package:airo_app/features/coins/domain/entities/settlement.dart';

class MockCoinsLocalDatasource extends Mock implements CoinsLocalDatasource {}

class MockSettlementMapper extends Mock implements SettlementMapper {}

void main() {
  late MockCoinsLocalDatasource mockDatasource;
  late MockSettlementMapper mockMapper;
  late SettlementRepositoryImpl repository;

  setUp(() {
    mockDatasource = MockCoinsLocalDatasource();
    mockMapper = MockSettlementMapper();
    repository = SettlementRepositoryImpl(mockDatasource, mockMapper);
  });

  setUpAll(() {
    registerFallbackValue(_createSettlementEntity());
    registerFallbackValue(_createSettlement());
  });

  group('SettlementRepositoryImpl', () {
    group('findById', () {
      test('should return settlement when found', () async {
        final entity = _createSettlementEntity();
        final settlement = _createSettlement();

        when(
          () => mockDatasource.getSettlementById('stl1'),
        ).thenAnswer((_) async => entity);
        when(() => mockMapper.toDomain(entity)).thenReturn(settlement);

        final result = await repository.findById('stl1');

        expect(result.data, isNotNull);
        expect(result.error, isNull);
        expect(result.data!.id, 'stl1');
        verify(() => mockDatasource.getSettlementById('stl1')).called(1);
      });

      test('should return error when not found', () async {
        when(
          () => mockDatasource.getSettlementById('nonexistent'),
        ).thenAnswer((_) async => null);

        final result = await repository.findById('nonexistent');

        expect(result.data, isNull);
        expect(result.error, 'Settlement not found');
      });

      test('should return error on exception', () async {
        when(
          () => mockDatasource.getSettlementById(any()),
        ).thenThrow(Exception('Database error'));

        final result = await repository.findById('stl1');

        expect(result.data, isNull);
        expect(result.error, contains('Failed to fetch settlement'));
      });
    });

    group('findByGroup', () {
      test('should return settlements for group', () async {
        final entities = [_createSettlementEntity()];
        final settlement = _createSettlement();

        when(
          () => mockDatasource.getSettlementsByGroup('grp1'),
        ).thenAnswer((_) async => entities);
        when(() => mockMapper.toDomain(any())).thenReturn(settlement);

        final result = await repository.findByGroup('grp1');

        expect(result.data, isNotNull);
        expect(result.data!.length, 1);
        expect(result.error, isNull);
      });

      test('should return empty list when no settlements', () async {
        when(
          () => mockDatasource.getSettlementsByGroup('grp1'),
        ).thenAnswer((_) async => []);

        final result = await repository.findByGroup('grp1');

        expect(result.data, isNotNull);
        expect(result.data, isEmpty);
        expect(result.error, isNull);
      });
    });

    group('findBetweenUsers', () {
      test('should return settlements between two users', () async {
        final entities = [_createSettlementEntity()];
        final settlement = _createSettlement();

        when(
          () => mockDatasource.getSettlementsBetweenUsers(
            'grp1',
            'user1',
            'user2',
          ),
        ).thenAnswer((_) async => entities);
        when(() => mockMapper.toDomain(any())).thenReturn(settlement);

        final result = await repository.findBetweenUsers(
          'grp1',
          'user1',
          'user2',
        );

        expect(result.data, isNotNull);
        expect(result.data!.length, 1);
        expect(result.error, isNull);
      });
    });

    group('findByStatus', () {
      test('should return settlements with given status', () async {
        final entities = [_createSettlementEntity()];
        final settlement = _createSettlement();

        when(
          () => mockDatasource.getSettlementsByStatus('grp1', 'pending'),
        ).thenAnswer((_) async => entities);
        when(() => mockMapper.toDomain(any())).thenReturn(settlement);

        final result = await repository.findByStatus(
          'grp1',
          SettlementStatus.pending,
        );

        expect(result.data, isNotNull);
        expect(result.data!.length, 1);
        expect(result.error, isNull);
      });
    });

    group('findPendingForUser', () {
      test('should return pending settlements for user', () async {
        final entities = [_createSettlementEntity()];
        final settlement = _createSettlement();

        when(
          () => mockDatasource.getPendingSettlementsForUser('user1'),
        ).thenAnswer((_) async => entities);
        when(() => mockMapper.toDomain(any())).thenReturn(settlement);

        final result = await repository.findPendingForUser('user1');

        expect(result.data, isNotNull);
        expect(result.data!.length, 1);
        expect(result.error, isNull);
      });
    });

    group('create', () {
      test('should create settlement successfully', () async {
        final settlement = _createSettlement();
        final entity = _createSettlementEntity();

        when(() => mockMapper.toEntity(settlement)).thenReturn(entity);
        when(
          () => mockDatasource.insertSettlement(any()),
        ).thenAnswer((_) async {});

        final result = await repository.create(settlement);

        expect(result.data, isNotNull);
        expect(result.error, isNull);
        verify(() => mockDatasource.insertSettlement(entity)).called(1);
      });

      test('should return error on create failure', () async {
        final settlement = _createSettlement();

        when(
          () => mockMapper.toEntity(any()),
        ).thenReturn(_createSettlementEntity());
        when(
          () => mockDatasource.insertSettlement(any()),
        ).thenThrow(Exception('Insert failed'));

        final result = await repository.create(settlement);

        expect(result.data, isNull);
        expect(result.error, contains('Failed to create settlement'));
      });
    });

    group('update', () {
      test('should update settlement successfully', () async {
        final settlement = _createSettlement();
        final entity = _createSettlementEntity();

        when(() => mockMapper.toEntity(settlement)).thenReturn(entity);
        when(
          () => mockDatasource.updateSettlement(any()),
        ).thenAnswer((_) async {});

        final result = await repository.update(settlement);

        expect(result.data, isNotNull);
        expect(result.error, isNull);
      });
    });

    group('complete', () {
      test(
        'should complete settlement and return updated settlement',
        () async {
          final entity = _createSettlementEntity(status: 'completed');
          final settlement = _createSettlement(
            status: SettlementStatus.completed,
          );

          when(
            () => mockDatasource.completeSettlement('stl1'),
          ).thenAnswer((_) async {});
          when(
            () => mockDatasource.getSettlementById('stl1'),
          ).thenAnswer((_) async => entity);
          when(() => mockMapper.toDomain(entity)).thenReturn(settlement);

          final result = await repository.complete('stl1');

          expect(result.data, isNotNull);
          expect(result.data!.status, SettlementStatus.completed);
          expect(result.error, isNull);
        },
      );

      test(
        'should return error when settlement not found after completion',
        () async {
          when(
            () => mockDatasource.completeSettlement('stl1'),
          ).thenAnswer((_) async {});
          when(
            () => mockDatasource.getSettlementById('stl1'),
          ).thenAnswer((_) async => null);

          final result = await repository.complete('stl1');

          expect(result.data, isNull);
          expect(
            result.error,
            contains('Settlement not found after completion'),
          );
        },
      );
    });

    group('cancel', () {
      test('should cancel settlement and return updated settlement', () async {
        final entity = _createSettlementEntity(status: 'cancelled');
        final settlement = _createSettlement(
          status: SettlementStatus.cancelled,
        );

        when(
          () => mockDatasource.cancelSettlement('stl1'),
        ).thenAnswer((_) async {});
        when(
          () => mockDatasource.getSettlementById('stl1'),
        ).thenAnswer((_) async => entity);
        when(() => mockMapper.toDomain(entity)).thenReturn(settlement);

        final result = await repository.cancel('stl1');

        expect(result.data, isNotNull);
        expect(result.data!.status, SettlementStatus.cancelled);
        expect(result.error, isNull);
      });

      test(
        'should return error when settlement not found after cancellation',
        () async {
          when(
            () => mockDatasource.cancelSettlement('stl1'),
          ).thenAnswer((_) async {});
          when(
            () => mockDatasource.getSettlementById('stl1'),
          ).thenAnswer((_) async => null);

          final result = await repository.cancel('stl1');

          expect(result.data, isNull);
          expect(
            result.error,
            contains('Settlement not found after cancellation'),
          );
        },
      );
    });

    group('delete', () {
      test('should delete settlement successfully', () async {
        when(
          () => mockDatasource.deleteSettlement('stl1'),
        ).thenAnswer((_) async {});

        final result = await repository.delete('stl1');

        expect(result.error, isNull);
        verify(() => mockDatasource.deleteSettlement('stl1')).called(1);
      });

      test('should return error on delete failure', () async {
        when(
          () => mockDatasource.deleteSettlement(any()),
        ).thenThrow(Exception('Delete failed'));

        final result = await repository.delete('stl1');

        expect(result.error, contains('Failed to delete settlement'));
      });
    });

    group('watchByGroup', () {
      test('should stream settlements for group', () async {
        final entities = [_createSettlementEntity()];
        final settlement = _createSettlement();

        when(
          () => mockDatasource.watchSettlementsByGroup('grp1'),
        ).thenAnswer((_) => Stream.value(entities));
        when(() => mockMapper.toDomain(any())).thenReturn(settlement);

        final settlements = await repository.watchByGroup('grp1').first;

        expect(settlements.length, 1);
      });
    });

    group('watchPendingForUser', () {
      test('should stream pending settlements for user', () async {
        final entities = [_createSettlementEntity()];
        final settlement = _createSettlement();

        when(
          () => mockDatasource.watchPendingSettlementsForUser('user1'),
        ).thenAnswer((_) => Stream.value(entities));
        when(() => mockMapper.toDomain(any())).thenReturn(settlement);

        final settlements = await repository.watchPendingForUser('user1').first;

        expect(settlements.length, 1);
      });
    });

    group('getTotalSettled', () {
      test('should return total settled amount', () async {
        when(
          () => mockDatasource.getTotalSettled('grp1'),
        ).thenAnswer((_) async => 150000);

        final result = await repository.getTotalSettled('grp1');

        expect(result.data, 150000);
        expect(result.error, isNull);
      });

      test('should return error on failure', () async {
        when(
          () => mockDatasource.getTotalSettled(any()),
        ).thenThrow(Exception('Database error'));

        final result = await repository.getTotalSettled('grp1');

        expect(result.data, isNull);
        expect(result.error, contains('Failed to calculate total'));
      });
    });

    group('getHistory', () {
      test('should return settlement history between users', () async {
        final entities = [_createSettlementEntity()];
        final settlement = _createSettlement();

        when(
          () => mockDatasource.getSettlementHistory('user1', 'user2', 20),
        ).thenAnswer((_) async => entities);
        when(() => mockMapper.toDomain(any())).thenReturn(settlement);

        final result = await repository.getHistory('user1', 'user2');

        expect(result.data, isNotNull);
        expect(result.data!.length, 1);
        expect(result.error, isNull);
      });

      test('should return error on failure', () async {
        when(
          () => mockDatasource.getSettlementHistory(any(), any(), any()),
        ).thenThrow(Exception('Database error'));

        final result = await repository.getHistory('user1', 'user2');

        expect(result.data, isNull);
        expect(result.error, contains('Failed to fetch history'));
      });
    });
  });
}

// Helper functions
SettlementEntity _createSettlementEntity({
  String id = 'stl1',
  String groupId = 'grp1',
  String status = 'pending',
}) {
  return SettlementEntity(
    id: id,
    groupId: groupId,
    fromUserId: 'user1',
    toUserId: 'user2',
    amountCents: 50000,
    currencyCode: 'INR',
    status: status,
    paymentMethod: 'cash',
    createdAt: DateTime(2024, 1, 1),
  );
}

Settlement _createSettlement({
  String id = 'stl1',
  String groupId = 'grp1',
  SettlementStatus status = SettlementStatus.pending,
}) {
  return Settlement(
    id: id,
    groupId: groupId,
    fromUserId: 'user1',
    toUserId: 'user2',
    amountCents: 50000,
    currencyCode: 'INR',
    status: status,
    paymentMethod: PaymentMethod.cash,
    settlementDate: DateTime(2024, 1, 1),
    createdAt: DateTime(2024, 1, 1),
  );
}
