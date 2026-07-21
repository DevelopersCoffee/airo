import 'package:core_domain/core_domain.dart';
import 'package:sqflite/sqflite.dart';

import '../crypto/field_cipher.dart';
import '../domain/entities/bank_account_record.dart';
import '../domain/entities/vault_entry_summary.dart';
import 'vault_database.dart';

/// Repository for [BankAccountRecord]. Encrypts [BankAccountRecord.accountNumber]
/// and [BankAccountRecord.notes] before persisting; decrypts them on read.
class BankAccountRepository {
  BankAccountRepository({
    required VaultDatabase database,
    required FieldCipher fieldCipher,
  }) : _database = database,
       _fieldCipher = fieldCipher;

  final VaultDatabase _database;
  final FieldCipher _fieldCipher;

  Future<Result<int>> create(
    BankAccountRecord record,
    List<int> keyBytes,
  ) async {
    try {
      final accountNumberEnc = await _fieldCipher.encryptField(
        record.accountNumber,
        keyBytes,
      );
      final notesEnc = record.notes == null
          ? null
          : await _fieldCipher.encryptField(record.notes!, keyBytes);

      final id = await _database.db.insert(VaultTables.bankAccounts, {
        'nickname': record.nickname,
        'bank_name': record.bankName,
        'account_holder_name': record.accountHolderName,
        'account_number_enc': accountNumberEnc,
        'ifsc_code': record.ifscCode,
        'account_type': record.accountType,
        'branch_name': record.branchName,
        'micr_code': record.micrCode,
        'swift_iban': record.swiftIban,
        'customer_id': record.customerId,
        'upi_ids': record.upiIds,
        'linked_mobile': record.linkedMobile,
        'linked_email': record.linkedEmail,
        'nominee_name': record.nomineeName,
        'debit_card_last4': record.debitCardLast4,
        'debit_card_expiry': record.debitCardExpiry,
        'notes_enc': notesEnc,
        'created_at': record.createdAt.millisecondsSinceEpoch,
      });
      return Success(id);
    } on DatabaseException catch (e) {
      return Failure(
        ValidationFailure(
          message:
              'An account with nickname "${record.nickname}" already exists',
          field: 'nickname',
          cause: e,
        ),
      );
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to create bank account', cause: e),
      );
    }
  }

  Future<Result<BankAccountRecord?>> getByNickname(
    String nickname,
    List<int> keyBytes,
  ) async {
    try {
      final rows = await _database.db.query(
        VaultTables.bankAccounts,
        where: 'nickname = ?',
        whereArgs: [nickname],
        limit: 1,
      );
      if (rows.isEmpty) return const Success(null);

      final row = rows.single;
      final accountNumber = await _fieldCipher.decryptField(
        row['account_number_enc'] as String,
        keyBytes,
      );
      final notesEnc = row['notes_enc'] as String?;
      final notes = notesEnc == null
          ? null
          : await _fieldCipher.decryptField(notesEnc, keyBytes);

      return Success(
        BankAccountRecord(
          id: row['id'] as int,
          nickname: row['nickname'] as String,
          bankName: row['bank_name'] as String,
          accountHolderName: row['account_holder_name'] as String,
          accountNumber: accountNumber,
          ifscCode: row['ifsc_code'] as String,
          accountType: row['account_type'] as String,
          branchName: row['branch_name'] as String?,
          micrCode: row['micr_code'] as String?,
          swiftIban: row['swift_iban'] as String?,
          customerId: row['customer_id'] as String?,
          upiIds: row['upi_ids'] as String?,
          linkedMobile: row['linked_mobile'] as String?,
          linkedEmail: row['linked_email'] as String?,
          nomineeName: row['nominee_name'] as String?,
          debitCardLast4: row['debit_card_last4'] as String?,
          debitCardExpiry: row['debit_card_expiry'] as String?,
          notes: notes,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            row['created_at'] as int,
          ),
        ),
      );
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to read bank account', cause: e),
      );
    }
  }

  /// Lists all accounts as key-free summaries (unencrypted columns only).
  Future<Result<List<BankAccountSummary>>> listAllSummaries() async {
    try {
      final rows = await _database.db.query(
        VaultTables.bankAccounts,
        columns: const [
          'nickname',
          'bank_name',
          'account_holder_name',
          'ifsc_code',
          'account_type',
        ],
        orderBy: 'nickname ASC',
      );
      return Success([
        for (final row in rows)
          BankAccountSummary(
            nickname: row['nickname'] as String,
            bankName: row['bank_name'] as String,
            accountHolderName: row['account_holder_name'] as String,
            ifscCode: row['ifsc_code'] as String,
            accountType: row['account_type'] as String,
          ),
      ]);
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to list bank accounts', cause: e),
      );
    }
  }

  /// Re-encrypts sensitive fields and updates the row identified by
  /// [BankAccountRecord.nickname]. `created_at` is left untouched.
  Future<Result<void>> update(
    BankAccountRecord record,
    List<int> keyBytes,
  ) async {
    try {
      final accountNumberEnc = await _fieldCipher.encryptField(
        record.accountNumber,
        keyBytes,
      );
      final notesEnc = record.notes == null
          ? null
          : await _fieldCipher.encryptField(record.notes!, keyBytes);

      final count = await _database.db.update(
        VaultTables.bankAccounts,
        {
          'bank_name': record.bankName,
          'account_holder_name': record.accountHolderName,
          'account_number_enc': accountNumberEnc,
          'ifsc_code': record.ifscCode,
          'account_type': record.accountType,
          'branch_name': record.branchName,
          'micr_code': record.micrCode,
          'swift_iban': record.swiftIban,
          'customer_id': record.customerId,
          'upi_ids': record.upiIds,
          'linked_mobile': record.linkedMobile,
          'linked_email': record.linkedEmail,
          'nominee_name': record.nomineeName,
          'debit_card_last4': record.debitCardLast4,
          'debit_card_expiry': record.debitCardExpiry,
          'notes_enc': notesEnc,
        },
        where: 'nickname = ?',
        whereArgs: [record.nickname],
      );
      if (count == 0) {
        return Failure(
          NotFoundFailure(
            message: 'No bank account with nickname "${record.nickname}"',
            resourceType: 'BankAccountRecord',
            resourceId: record.nickname,
          ),
        );
      }
      return const Success<void>(null);
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to update bank account', cause: e),
      );
    }
  }

  Future<Result<void>> deleteByNickname(String nickname) async {
    try {
      final count = await _database.db.delete(
        VaultTables.bankAccounts,
        where: 'nickname = ?',
        whereArgs: [nickname],
      );
      if (count == 0) {
        return Failure(
          NotFoundFailure(
            message: 'No bank account with nickname "$nickname"',
            resourceType: 'BankAccountRecord',
            resourceId: nickname,
          ),
        );
      }
      return const Success<void>(null);
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to delete bank account', cause: e),
      );
    }
  }
}
