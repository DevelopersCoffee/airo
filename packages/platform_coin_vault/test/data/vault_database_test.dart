import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/src/data/vault_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  test('open creates all four vault tables', () async {
    final vaultDb = VaultDatabase(databaseFactory: databaseFactoryFfi);
    await vaultDb.open(path: inMemoryDatabasePath);

    final tables = await vaultDb.db.query(
      'sqlite_master',
      columns: ['name'],
      where: "type = 'table'",
    );
    final tableNames = tables.map((row) => row['name']).toSet();

    expect(
      tableNames,
      containsAll(<String>[
        VaultTables.bankAccounts,
        VaultTables.panCards,
        VaultTables.creditCards,
        VaultTables.secureDocuments,
      ]),
    );

    await vaultDb.close();
  });

  test('bank_accounts enforces unique nickname', () async {
    final vaultDb = VaultDatabase(databaseFactory: databaseFactoryFfi);
    await vaultDb.open(path: inMemoryDatabasePath);

    await vaultDb.db.insert(VaultTables.bankAccounts, {
      'nickname': 'HDFC Salary',
      'bank_name': 'HDFC Bank',
      'account_holder_name': 'Jane Doe',
      'account_number_enc': 'enc1',
      'ifsc_code': 'HDFC0001234',
      'account_type': 'savings',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });

    expect(
      () => vaultDb.db.insert(VaultTables.bankAccounts, {
        'nickname': 'HDFC Salary',
        'bank_name': 'HDFC Bank',
        'account_holder_name': 'Jane Doe',
        'account_number_enc': 'enc2',
        'ifsc_code': 'HDFC0001234',
        'account_type': 'savings',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      }),
      throwsA(anything),
    );

    await vaultDb.close();
  });
}
