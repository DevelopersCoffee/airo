import '../../domain/entities/budget.dart';
import '../../domain/repositories/budget_repository.dart';
import '../datasources/coins_local_datasource.dart';
import '../mappers/budget_mapper.dart';

/// Implementation of BudgetRepository
///
/// Phase: 1 (Foundation)
/// See: docs/features/coins/PROJECT_STRUCTURE.md
class BudgetRepositoryImpl implements BudgetRepository {
  final CoinsLocalDatasource _localDatasource;
  final BudgetMapper _mapper;

  BudgetRepositoryImpl(this._localDatasource, this._mapper);

  @override
  Future<Result<Budget>> findById(String id) async {
    try {
      final entity = await _localDatasource.getBudgetById(id);
      if (entity == null) {
        return (data: null, error: 'Budget not found');
      }
      return (data: _mapper.toDomain(entity), error: null);
    } catch (e) {
      return (data: null, error: 'Failed to fetch budget: $e');
    }
  }

  @override
  Future<Result<Budget?>> findByCategory(String categoryId) async {
    try {
      final entity = await _localDatasource.getBudgetByCategory(categoryId);
      return (data: entity != null ? _mapper.toDomain(entity) : null, error: null);
    } catch (e) {
      return (data: null, error: 'Failed to fetch budget: $e');
    }
  }

  @override
  Future<Result<List<Budget>>> findActive() async {
    try {
      final entities = await _localDatasource.getActiveBudgets();
      return (data: entities.map(_mapper.toDomain).toList(), error: null);
    } catch (e) {
      return (data: null, error: 'Failed to fetch budgets: $e');
    }
  }

  @override
  Future<Result<List<Budget>>> findAll() async {
    try {
      final entities = await _localDatasource.getAllBudgets();
      return (data: entities.map(_mapper.toDomain).toList(), error: null);
    } catch (e) {
      return (data: null, error: 'Failed to fetch budgets: $e');
    }
  }

  @override
  Future<Result<Budget>> create(Budget budget) async {
    try {
      final entity = _mapper.toEntity(budget);
      await _localDatasource.insertBudget(entity);
      return (data: budget, error: null);
    } catch (e) {
      return (data: null, error: 'Failed to create budget: $e');
    }
  }

  @override
  Future<Result<Budget>> update(Budget budget) async {
    try {
      final entity = _mapper.toEntity(budget);
      await _localDatasource.updateBudget(entity);
      return (data: budget, error: null);
    } catch (e) {
      return (data: null, error: 'Failed to update budget: $e');
    }
  }

  @override
  Future<Result<void>> deactivate(String id) async {
    try {
      await _localDatasource.deactivateBudget(id);
      return (data: null, error: null);
    } catch (e) {
      return (data: null, error: 'Failed to deactivate budget: $e');
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      await _localDatasource.deleteBudget(id);
      return (data: null, error: null);
    } catch (e) {
      return (data: null, error: 'Failed to delete budget: $e');
    }
  }

  @override
  Stream<List<Budget>> watchActive() {
    return _localDatasource
        .watchActiveBudgets()
        .map((entities) => entities.map(_mapper.toDomain).toList());
  }

  @override
  Stream<Budget?> watchById(String id) {
    return _localDatasource
        .watchBudgetById(id)
        .map((entity) => entity != null ? _mapper.toDomain(entity) : null);
  }

  @override
  Future<Result<bool>> hasBudget(String categoryId) async {
    try {
      final entity = await _localDatasource.getBudgetByCategory(categoryId);
      return (data: entity != null, error: null);
    } catch (e) {
      return (data: null, error: 'Failed to check budget: $e');
    }
  }
}

