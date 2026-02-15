import '../../domain/entities/account.dart';
import '../../domain/repositories/account_repository.dart';
import '../datasources/coins_local_datasource.dart';
import '../mappers/account_mapper.dart';

/// Implementation of AccountRepository
///
/// Phase: 1 (Foundation)
/// See: docs/features/coins/PROJECT_STRUCTURE.md
class AccountRepositoryImpl implements AccountRepository {
  final CoinsLocalDatasource _localDatasource;
  final AccountMapper _mapper;

  AccountRepositoryImpl(this._localDatasource, this._mapper);

  @override
  Future<Result<Account>> findById(String id) async {
    try {
      final entity = await _localDatasource.getAccountById(id);
      if (entity == null) {
        return (data: null, error: 'Account not found');
      }
      return (data: _mapper.toDomain(entity), error: null);
    } catch (e) {
      return (data: null, error: 'Failed to fetch account: $e');
    }
  }

  @override
  Future<Result<List<Account>>> findActive() async {
    try {
      final entities = await _localDatasource.getActiveAccounts();
      return (data: entities.map(_mapper.toDomain).toList(), error: null);
    } catch (e) {
      return (data: null, error: 'Failed to fetch accounts: $e');
    }
  }

  @override
  Future<Result<List<Account>>> findAll() async {
    try {
      final entities = await _localDatasource.getAllAccounts();
      return (data: entities.map(_mapper.toDomain).toList(), error: null);
    } catch (e) {
      return (data: null, error: 'Failed to fetch accounts: $e');
    }
  }

  @override
  Future<Result<Account?>> findDefault() async {
    try {
      final entity = await _localDatasource.getDefaultAccount();
      return (data: entity != null ? _mapper.toDomain(entity) : null, error: null);
    } catch (e) {
      return (data: null, error: 'Failed to fetch default account: $e');
    }
  }

  @override
  Future<Result<Account>> create(Account account) async {
    try {
      final entity = _mapper.toEntity(account);
      await _localDatasource.insertAccount(entity);
      return (data: account, error: null);
    } catch (e) {
      return (data: null, error: 'Failed to create account: $e');
    }
  }

  @override
  Future<Result<Account>> update(Account account) async {
    try {
      final entity = _mapper.toEntity(account);
      await _localDatasource.updateAccount(entity);
      return (data: account, error: null);
    } catch (e) {
      return (data: null, error: 'Failed to update account: $e');
    }
  }

  @override
  Future<Result<Account>> updateBalance(String id, int balanceCents) async {
    try {
      await _localDatasource.updateAccountBalance(id, balanceCents);
      final entity = await _localDatasource.getAccountById(id);
      if (entity == null) {
        return (data: null, error: 'Account not found after update');
      }
      return (data: _mapper.toDomain(entity), error: null);
    } catch (e) {
      return (data: null, error: 'Failed to update balance: $e');
    }
  }

  @override
  Future<Result<void>> setDefault(String id) async {
    try {
      await _localDatasource.setDefaultAccount(id);
      return (data: null, error: null);
    } catch (e) {
      return (data: null, error: 'Failed to set default account: $e');
    }
  }

  @override
  Future<Result<void>> archive(String id) async {
    try {
      await _localDatasource.archiveAccount(id);
      return (data: null, error: null);
    } catch (e) {
      return (data: null, error: 'Failed to archive account: $e');
    }
  }

  @override
  Future<Result<void>> restore(String id) async {
    try {
      await _localDatasource.restoreAccount(id);
      return (data: null, error: null);
    } catch (e) {
      return (data: null, error: 'Failed to restore account: $e');
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      await _localDatasource.deleteAccount(id);
      return (data: null, error: null);
    } catch (e) {
      return (data: null, error: 'Failed to delete account: $e');
    }
  }

  @override
  Stream<List<Account>> watchActive() {
    return _localDatasource
        .watchActiveAccounts()
        .map((entities) => entities.map(_mapper.toDomain).toList());
  }

  @override
  Stream<int> watchTotalBalance() {
    return _localDatasource.watchTotalBalance();
  }

  @override
  Future<Result<int>> getTotalBalance() async {
    try {
      final total = await _localDatasource.getTotalBalance();
      return (data: total, error: null);
    } catch (e) {
      return (data: null, error: 'Failed to get total balance: $e');
    }
  }
}

