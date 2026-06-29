import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import '../contracts/storage_service.dart';
import '../contracts/repository_factory.dart';
import '../contracts/transaction_manager.dart';
import '../drift/app_database.dart';
import '../api/drift_storage_service.dart';
import '../repositories/default_repository_factory.dart';
import '../transactions/drift_transaction_manager.dart';

// In tests we can override this to use NativeDatabase.memory()
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final storageServiceProvider = Provider<StorageService>((ref) {
  return DriftStorageService(ref.watch(appDatabaseProvider));
});

final repositoryFactoryProvider = Provider<RepositoryFactory>((ref) {
  return DefaultRepositoryFactory();
});

final transactionProvider = Provider<TransactionManager>((ref) {
  return DriftTransactionManager(ref.watch(appDatabaseProvider));
});
