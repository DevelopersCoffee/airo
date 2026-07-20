import 'package:core_domain/core_domain.dart';
import 'package:sqflite/sqflite.dart';

import '../crypto/field_cipher.dart';
import '../crypto/vault_key_manager.dart';
import 'vault_database.dart';

/// Column names that carry [FieldCipher]-encrypted values, keyed by table.
/// `credit_cards` is intentionally absent — it has no encrypted columns.
const Map<String, List<String>> _encryptedColumnsByTable = {
  VaultTables.bankAccounts: ['account_number_enc', 'notes_enc'],
  VaultTables.panCards: ['pan_number_enc', 'card_image_blob_enc'],
  VaultTables.secureDocuments: ['custom_fields_enc', 'attachment_blob_enc', 'notes_enc'],
};

/// Safely rotates the vault's DEK by re-encrypting every field-encrypted
/// column, across every table, under the new key before the new key ever
/// becomes active. If re-encryption fails partway through, the whole
/// operation rolls back inside one sqflite transaction and the old DEK
/// remains active — there is no partially-rotated state.
///
/// This is the only supported way to rotate the vault's DEK.
/// `VaultKeyManager.rotateKey()` is a raw, destructive primitive that exists
/// only to satisfy `EncryptionKeyManager`'s interface contract — it must
/// never be called directly on a vault containing data.
class VaultKeyRotationService {
  VaultKeyRotationService({
    required VaultDatabase database,
    required VaultKeyManager keyManager,
    required FieldCipher fieldCipher,
  }) : _database = database,
       _keyManager = keyManager,
       _fieldCipher = fieldCipher;

  final VaultDatabase _database;
  final VaultKeyManager _keyManager;
  final FieldCipher _fieldCipher;

  Future<Result<void>> rotateKeyWithReencryption() async {
    final oldKeyResult = await _keyManager.getDatabaseKey();
    if (oldKeyResult.isFailure) {
      return Failure(oldKeyResult.failure);
    }
    final oldKey = oldKeyResult.value;
    final newKey = _keyManager.generateCandidateKey();

    try {
      await _database.db.transaction((txn) async {
        for (final entry in _encryptedColumnsByTable.entries) {
          await _reencryptTable(txn, entry.key, entry.value, oldKey, newKey);
        }
      });
    } catch (e) {
      return Failure(DatabaseFailure(
        message: 'Re-encryption failed; the vault DEK was not rotated',
        cause: e,
      ));
    }

    return _keyManager.commitRotatedKey(newKey);
  }

  Future<void> _reencryptTable(
    Transaction txn,
    String table,
    List<String> encryptedColumns,
    List<int> oldKey,
    List<int> newKey,
  ) async {
    final rows = await txn.query(table);
    for (final row in rows) {
      final id = row['id'] as int;
      final updates = <String, Object?>{};
      for (final column in encryptedColumns) {
        final value = row[column] as String?;
        if (value == null) continue;
        final plaintext = await _fieldCipher.decryptField(
          value,
          oldKey,
          context: '$table:$column:$id',
        );
        updates[column] = await _fieldCipher.encryptField(
          plaintext,
          newKey,
          context: '$table:$column:$id',
        );
      }
      if (updates.isNotEmpty) {
        await txn.update(table, updates, where: 'id = ?', whereArgs: [id]);
      }
    }
  }
}
