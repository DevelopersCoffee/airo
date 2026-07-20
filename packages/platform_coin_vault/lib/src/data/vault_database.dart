import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite/sqflite.dart' hide databaseFactory;

/// Table name constants for the Airo Coin vault schema.
abstract final class VaultTables {
  static const bankAccounts = 'bank_accounts';
  static const panCards = 'pan_cards';
  static const creditCards = 'credit_cards';
  static const secureDocuments = 'secure_documents';
}

/// Opens and owns the vault's sqflite database. Holds no encryption logic
/// itself — sensitive columns already arrive pre-encrypted from the
/// repositories (see `FieldCipher`); this class only owns table DDL and the
/// open `Database` handle.
class VaultDatabase {
  VaultDatabase({DatabaseFactory? databaseFactory})
    : _databaseFactory = databaseFactory ?? sqflite.databaseFactory;

  final DatabaseFactory _databaseFactory;
  Database? _db;

  Database get db {
    final database = _db;
    if (database == null) {
      throw StateError('VaultDatabase.open() must be called before use');
    }
    return database;
  }

  Future<void> open({required String path}) async {
    _db = await _databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE ${VaultTables.bankAccounts} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nickname TEXT NOT NULL UNIQUE,
              bank_name TEXT NOT NULL,
              account_holder_name TEXT NOT NULL,
              account_number_enc TEXT NOT NULL,
              ifsc_code TEXT NOT NULL,
              account_type TEXT NOT NULL,
              branch_name TEXT,
              micr_code TEXT,
              swift_iban TEXT,
              customer_id TEXT,
              upi_ids TEXT,
              linked_mobile TEXT,
              linked_email TEXT,
              nominee_name TEXT,
              debit_card_last4 TEXT,
              debit_card_expiry TEXT,
              notes_enc TEXT,
              created_at INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE ${VaultTables.panCards} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              pan_number_enc TEXT NOT NULL,
              name_on_card TEXT NOT NULL,
              fathers_name TEXT,
              date_of_birth TEXT,
              card_image_blob_enc TEXT,
              created_at INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE ${VaultTables.creditCards} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nickname TEXT NOT NULL UNIQUE,
              card_network TEXT NOT NULL,
              last4 TEXT NOT NULL,
              expiry_month INTEGER NOT NULL,
              expiry_year INTEGER NOT NULL,
              issuing_bank TEXT NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE ${VaultTables.secureDocuments} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nickname TEXT NOT NULL UNIQUE,
              category TEXT NOT NULL,
              linked_account_nickname TEXT,
              custom_fields_enc TEXT,
              attachment_blob_enc TEXT,
              notes_enc TEXT,
              created_at INTEGER NOT NULL
            )
          ''');
        },
      ),
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
