import 'package:core_domain/core_domain.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/entities/credit_card_record.dart';
import '../domain/entities/vault_entry_summary.dart';
import 'vault_database.dart';

/// Repository for [CreditCardRecord]. No field is encrypted here — the
/// record is masked-only (network, last4, expiry, issuing bank), none of
/// which requires AES-GCM protection.
class CreditCardRepository {
  CreditCardRepository({required VaultDatabase database})
    : _database = database;

  final VaultDatabase _database;

  Future<Result<int>> create(CreditCardRecord record) async {
    try {
      final id = await _database.db.insert(VaultTables.creditCards, {
        'nickname': record.nickname,
        'card_network': record.cardNetwork.name,
        'last4': record.last4,
        'expiry_month': record.expiryMonth,
        'expiry_year': record.expiryYear,
        'issuing_bank': record.issuingBank,
        'created_at': record.createdAt.millisecondsSinceEpoch,
      });
      return Success(id);
    } on DatabaseException catch (e) {
      return Failure(
        ValidationFailure(
          message: 'A card with nickname "${record.nickname}" already exists',
          field: 'nickname',
          cause: e,
        ),
      );
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to create credit card', cause: e),
      );
    }
  }

  Future<Result<CreditCardRecord?>> getByNickname(String nickname) async {
    try {
      final rows = await _database.db.query(
        VaultTables.creditCards,
        where: 'nickname = ?',
        whereArgs: [nickname],
        limit: 1,
      );
      if (rows.isEmpty) return const Success(null);

      final row = rows.single;
      return Success(
        CreditCardRecord(
          id: row['id'] as int,
          nickname: row['nickname'] as String,
          cardNetwork: CardNetwork.values.byName(row['card_network'] as String),
          last4: row['last4'] as String,
          expiryMonth: row['expiry_month'] as int,
          expiryYear: row['expiry_year'] as int,
          issuingBank: row['issuing_bank'] as String,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            row['created_at'] as int,
          ),
        ),
      );
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to read credit card', cause: e),
      );
    }
  }

  /// Lists all cards as masked-only summaries (nothing here is encrypted).
  Future<Result<List<CreditCardSummary>>> listAllSummaries() async {
    try {
      final rows = await _database.db.query(
        VaultTables.creditCards,
        columns: const [
          'nickname',
          'card_network',
          'last4',
          'expiry_month',
          'expiry_year',
          'issuing_bank',
        ],
        orderBy: 'nickname ASC',
      );
      return Success([
        for (final row in rows)
          CreditCardSummary(
            nickname: row['nickname'] as String,
            cardNetwork: CardNetwork.values.byName(
              row['card_network'] as String,
            ),
            last4: row['last4'] as String,
            expiryMonth: row['expiry_month'] as int,
            expiryYear: row['expiry_year'] as int,
            issuingBank: row['issuing_bank'] as String,
          ),
      ]);
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to list credit cards', cause: e),
      );
    }
  }

  /// Updates the row identified by [CreditCardRecord.nickname].
  /// `created_at` is left untouched.
  Future<Result<void>> update(CreditCardRecord record) async {
    try {
      final count = await _database.db.update(
        VaultTables.creditCards,
        {
          'card_network': record.cardNetwork.name,
          'last4': record.last4,
          'expiry_month': record.expiryMonth,
          'expiry_year': record.expiryYear,
          'issuing_bank': record.issuingBank,
        },
        where: 'nickname = ?',
        whereArgs: [record.nickname],
      );
      if (count == 0) {
        return Failure(
          NotFoundFailure(
            message: 'No credit card with nickname "${record.nickname}"',
            resourceType: 'CreditCardRecord',
            resourceId: record.nickname,
          ),
        );
      }
      return const Success<void>(null);
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to update credit card', cause: e),
      );
    }
  }

  Future<Result<void>> deleteByNickname(String nickname) async {
    try {
      final count = await _database.db.delete(
        VaultTables.creditCards,
        where: 'nickname = ?',
        whereArgs: [nickname],
      );
      if (count == 0) {
        return Failure(
          NotFoundFailure(
            message: 'No credit card with nickname "$nickname"',
            resourceType: 'CreditCardRecord',
            resourceId: nickname,
          ),
        );
      }
      return const Success<void>(null);
    } catch (e) {
      return Failure(
        DatabaseFailure(message: 'Failed to delete credit card', cause: e),
      );
    }
  }
}
