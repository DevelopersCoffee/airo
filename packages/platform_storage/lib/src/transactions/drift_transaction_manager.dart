import '../contracts/transaction_manager.dart';
import '../drift/app_database.dart';

class DriftTransactionManager implements TransactionManager {
  final AppDatabase _db;

  DriftTransactionManager(this._db);

  @override
  Future<T> transaction<T>(Future<T> Function() action) async {
    return await _db.transaction(() async {
      return await action();
    });
  }
}
