import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:platform_storage/platform_storage.dart';
import 'package:platform_storage/src/drift/app_database.dart';
import 'package:platform_storage/src/api/drift_storage_service.dart';
import 'package:platform_storage/src/transactions/drift_transaction_manager.dart';
import 'package:platform_storage/src/repositories/default_repository_factory.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MockRepository {
  final String name = 'Mock';
}

void main() {
  group('DriftStorageService', () {
    late AppDatabase db;
    late DriftStorageService service;

    setUp(() {
      // Use in-memory SQLite for tests
      db = AppDatabase(NativeDatabase.memory());
      service = DriftStorageService(db);
    });

    tearDown(() async {
      await service.close();
    });

    test('Initializes and opens database correctly', () async {
      await service.initialize();
      // Should not throw
      expect(true, isTrue);
    });

    test('Health checker reports healthy status for fresh database', () async {
      await service.initialize();
      final health = await service.healthChecker.checkHealth();
      
      expect(health.integrityOk, isTrue);
      expect(health.schemaVersion, equals(1));
    });
  });

  group('DefaultRepositoryFactory', () {
    test('Allows registration and returns singletons', () {
      final factory = DefaultRepositoryFactory();
      factory.register<MockRepository>(() => MockRepository());
      
      final repo1 = factory.get<MockRepository>();
      final repo2 = factory.get<MockRepository>();
      
      expect(repo1, isNotNull);
      expect(repo1.name, 'Mock');
      expect(identical(repo1, repo2), isTrue); // Should return same instance
    });

    test('Throws StateError if accessing unregistered repository', () {
      final factory = DefaultRepositoryFactory();
      expect(() => factory.get<MockRepository>(), throwsStateError);
    });
  });

  group('DriftTransactionManager', () {
    late AppDatabase db;
    late DriftTransactionManager transactionManager;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      transactionManager = DriftTransactionManager(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Executes transaction block', () async {
      final result = await transactionManager.transaction(() async {
        return 'success';
      });
      
      expect(result, 'success');
    });

    test('Rolls back on exception', () async {
      expect(
        () async {
          await transactionManager.transaction(() async {
            throw Exception('Rollback!');
          });
        },
        throwsException,
      );
    });
  });
}
