import 'dart:io';

import 'package:airo_app/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('AppDatabase reliability', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('airo-db-reliability-');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('applies expected sqlite pragmas on open', () async {
      final db = AppDatabase(databasePath: _dbPath(tempDir, 'pragmas.db'));
      addTearDown(db.close);

      final foreignKeys = await db.customSelect('PRAGMA foreign_keys;').get();
      final journalMode = await db.customSelect('PRAGMA journal_mode;').get();

      expect(foreignKeys.single.data.values.single, 1);
      expect(
        journalMode.single.data.values.single.toString().toLowerCase(),
        'wal',
      );
    });

    test('exports and restores a populated database', () async {
      final sourcePath = _dbPath(tempDir, 'source.db');
      final restoredPath = _dbPath(tempDir, 'restored.db');
      final source = AppDatabase(databasePath: sourcePath);
      await _seedTransactions(source, count: 3);
      final sourceCount = await _transactionCount(source);

      final backup = await source.exportDatabase();
      await source.close();

      await AppDatabase.restoreBackup(backup, databasePath: restoredPath);
      final restored = AppDatabase(databasePath: restoredPath);
      addTearDown(restored.close);

      expect(await _transactionCount(restored), sourceCount);
      final restoredRows = await restored
          .select(restored.transactionEntries)
          .get();
      expect(restoredRows.last.description, 'Transaction 2');
    });

    test(
      'recreates a usable schema when the database file is malformed',
      () async {
        final path = _dbPath(tempDir, 'corrupted.db');
        await File(path).writeAsBytes('not-a-sqlite-database'.codeUnits);

        final db = AppDatabase(databasePath: path);
        addTearDown(db.close);

        final tables = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'transaction_entries';",
            )
            .get();

        expect(tables, hasLength(1));
        expect(await _transactionCount(db), 0);
      },
    );

    test('restores larger local histories without dropping rows', () async {
      final sourcePath = _dbPath(tempDir, 'history-source.db');
      final restoredPath = _dbPath(tempDir, 'history-restored.db');
      final source = AppDatabase(databasePath: sourcePath);
      await _seedTransactions(source, count: 250);

      final backup = await source.exportDatabase();
      await source.close();

      await AppDatabase.restoreBackup(backup, databasePath: restoredPath);
      final restored = AppDatabase(databasePath: restoredPath);
      addTearDown(restored.close);

      expect(await _transactionCount(restored), 250);
      final sample = await (restored.select(
        restored.transactionEntries,
      )..where((tbl) => tbl.uuid.equals('txn-249'))).getSingle();
      expect(sample.description, 'Transaction 249');
    });
  });
}

String _dbPath(Directory dir, String name) => p.join(dir.path, name);

Future<void> _seedTransactions(AppDatabase db, {required int count}) async {
  for (var i = 0; i < count; i++) {
    await db
        .into(db.transactionEntries)
        .insert(
          TransactionEntriesCompanion.insert(
            uuid: 'txn-$i',
            accountId: 'account-1',
            timestamp: DateTime.utc(2026, 6, 29, 12, i % 60),
            amountCents: -1000 - i,
            description: 'Transaction $i',
            category: 'meeting',
          ),
        );
  }
}

Future<int> _transactionCount(AppDatabase db) async {
  final countRow = await db
      .customSelect('SELECT COUNT(*) AS count FROM transaction_entries;')
      .getSingle();
  return countRow.read<int>('count');
}
