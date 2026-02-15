import '../../domain/entities/settlement.dart';
import '../../domain/repositories/settlement_repository.dart';
import '../datasources/coins_local_datasource.dart';
import '../mappers/settlement_mapper.dart';

/// Implementation of SettlementRepository
///
/// Phase: 2 (Split Engine)
/// See: docs/features/coins/PROJECT_STRUCTURE.md
class SettlementRepositoryImpl implements SettlementRepository {
  final CoinsLocalDatasource _localDatasource;
  final SettlementMapper _mapper;

  SettlementRepositoryImpl(this._localDatasource, this._mapper);

  @override
  Future<Result<Settlement>> findById(String id) async {
    try {
      final entity = await _localDatasource.getSettlementById(id);
      if (entity == null) {
        return (data: null, error: 'Settlement not found');
      }
      return (data: _mapper.toDomain(entity), error: null);
    } catch (e) {
      return (data: null, error: 'Failed to fetch settlement: $e');
    }
  }

  @override
  Future<Result<List<Settlement>>> findByGroup(String groupId) async {
    try {
      final entities = await _localDatasource.getSettlementsByGroup(groupId);
      return (data: entities.map(_mapper.toDomain).toList(), error: null);
    } catch (e) {
      return (data: null, error: 'Failed to fetch settlements: $e');
    }
  }

  @override
  Future<Result<List<Settlement>>> findBetweenUsers(
    String groupId,
    String userId1,
    String userId2,
  ) async {
    try {
      final entities = await _localDatasource.getSettlementsBetweenUsers(
        groupId,
        userId1,
        userId2,
      );
      return (data: entities.map(_mapper.toDomain).toList(), error: null);
    } catch (e) {
      return (data: null, error: 'Failed to fetch settlements: $e');
    }
  }

  @override
  Future<Result<List<Settlement>>> findByStatus(
    String groupId,
    SettlementStatus status,
  ) async {
    try {
      final entities = await _localDatasource.getSettlementsByStatus(
        groupId,
        status.name,
      );
      return (data: entities.map(_mapper.toDomain).toList(), error: null);
    } catch (e) {
      return (data: null, error: 'Failed to fetch settlements: $e');
    }
  }

  @override
  Future<Result<List<Settlement>>> findPendingForUser(String userId) async {
    try {
      final entities =
          await _localDatasource.getPendingSettlementsForUser(userId);
      return (data: entities.map(_mapper.toDomain).toList(), error: null);
    } catch (e) {
      return (data: null, error: 'Failed to fetch settlements: $e');
    }
  }

  @override
  Future<Result<Settlement>> create(Settlement settlement) async {
    try {
      final entity = _mapper.toEntity(settlement);
      await _localDatasource.insertSettlement(entity);
      return (data: settlement, error: null);
    } catch (e) {
      return (data: null, error: 'Failed to create settlement: $e');
    }
  }

  @override
  Future<Result<Settlement>> update(Settlement settlement) async {
    try {
      final entity = _mapper.toEntity(settlement);
      await _localDatasource.updateSettlement(entity);
      return (data: settlement, error: null);
    } catch (e) {
      return (data: null, error: 'Failed to update settlement: $e');
    }
  }

  @override
  Future<Result<Settlement>> complete(String id) async {
    try {
      await _localDatasource.completeSettlement(id);
      final entity = await _localDatasource.getSettlementById(id);
      if (entity == null) {
        return (data: null, error: 'Settlement not found after completion');
      }
      return (data: _mapper.toDomain(entity), error: null);
    } catch (e) {
      return (data: null, error: 'Failed to complete settlement: $e');
    }
  }

  @override
  Future<Result<Settlement>> cancel(String id) async {
    try {
      await _localDatasource.cancelSettlement(id);
      final entity = await _localDatasource.getSettlementById(id);
      if (entity == null) {
        return (data: null, error: 'Settlement not found after cancellation');
      }
      return (data: _mapper.toDomain(entity), error: null);
    } catch (e) {
      return (data: null, error: 'Failed to cancel settlement: $e');
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      await _localDatasource.deleteSettlement(id);
      return (data: null, error: null);
    } catch (e) {
      return (data: null, error: 'Failed to delete settlement: $e');
    }
  }

  @override
  Stream<List<Settlement>> watchByGroup(String groupId) {
    return _localDatasource
        .watchSettlementsByGroup(groupId)
        .map((entities) => entities.map(_mapper.toDomain).toList());
  }

  @override
  Stream<List<Settlement>> watchPendingForUser(String userId) {
    return _localDatasource
        .watchPendingSettlementsForUser(userId)
        .map((entities) => entities.map(_mapper.toDomain).toList());
  }

  @override
  Future<Result<int>> getTotalSettled(String groupId) async {
    try {
      final total = await _localDatasource.getTotalSettled(groupId);
      return (data: total, error: null);
    } catch (e) {
      return (data: null, error: 'Failed to calculate total: $e');
    }
  }

  @override
  Future<Result<List<Settlement>>> getHistory(
    String userId1,
    String userId2, {
    int limit = 20,
  }) async {
    try {
      final entities = await _localDatasource.getSettlementHistory(
        userId1,
        userId2,
        limit,
      );
      return (data: entities.map(_mapper.toDomain).toList(), error: null);
    } catch (e) {
      return (data: null, error: 'Failed to fetch history: $e');
    }
  }
}

