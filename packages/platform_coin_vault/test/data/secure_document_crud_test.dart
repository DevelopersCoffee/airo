import 'dart:convert';
import 'dart:math';

import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/src/crypto/field_cipher.dart';
import 'package:platform_coin_vault/src/data/secure_document_repository.dart';
import 'package:platform_coin_vault/src/data/vault_database.dart';
import 'package:platform_coin_vault/src/domain/entities/secure_document_record.dart';
import 'package:platform_coin_vault/src/domain/entities/vault_entry_summary.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late VaultDatabase vaultDb;
  late SecureDocumentRepository repository;
  late List<int> keyBytes;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    vaultDb = VaultDatabase(databaseFactory: databaseFactoryFfi);
    await vaultDb.open(path: inMemoryDatabasePath);
    repository = SecureDocumentRepository(
      database: vaultDb,
      fieldCipher: FieldCipher(),
    );
    keyBytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
  });

  tearDown(() => vaultDb.close());

  SecureDocumentRecord record(
    String nickname, {
    DocumentCategory category = DocumentCategory.incomeProof,
    String? linked,
    Map<String, String> customFields = const {'employer': 'Acme'},
    String? notes,
    List<int>? attachment,
    DateTime? createdAt,
  }) => SecureDocumentRecord(
    id: null,
    nickname: nickname,
    category: category,
    createdAt: createdAt ?? DateTime(2026, 7, 20),
    linkedAccountNickname: linked,
    customFields: customFields,
    attachmentBlob: attachment,
    notes: notes,
  );

  group('listAllSummaries', () {
    test(
      'lists summaries with hasAttachment flag, no keyBytes needed',
      () async {
        await repository.create(
          record('Form 16', linked: 'HDFC Salary', attachment: [1, 2, 3]),
          keyBytes,
        );
        await repository.create(
          record(
            '26AS',
            category: DocumentCategory.taxCredit,
            customFields: const {},
          ),
          keyBytes,
        );

        final result = await repository.listAllSummaries();

        expect(result.isSuccess, isTrue);
        expect(result.value, [
          const SecureDocumentSummary(
            nickname: '26AS',
            category: DocumentCategory.taxCredit,
            hasAttachment: false,
          ),
          const SecureDocumentSummary(
            nickname: 'Form 16',
            category: DocumentCategory.incomeProof,
            linkedAccountNickname: 'HDFC Salary',
            hasAttachment: true,
          ),
        ]);
      },
    );
  });

  group('update', () {
    test('re-encrypts custom fields and notes, updates plain fields', () async {
      await repository.create(record('Form 16'), keyBytes);

      final updateResult = await repository.update(
        record(
          'Form 16',
          category: DocumentCategory.taxCredit,
          linked: 'HDFC Salary',
          customFields: const {'employer': 'NewCorp', 'fy': '2025-26'},
          notes: 'verified',
        ),
        keyBytes,
      );

      expect(updateResult.isSuccess, isTrue);
      final rows = await vaultDb.db.query(
        VaultTables.secureDocuments,
        columns: const ['custom_fields_enc', 'notes_enc'],
        where: 'nickname = ?',
        whereArgs: ['Form 16'],
        limit: 1,
      );
      final row = rows.single;
      expect(row['custom_fields_enc'], isNotNull);
      expect(
        row['custom_fields_enc'],
        isNot(jsonEncode({'employer': 'NewCorp', 'fy': '2025-26'})),
      );
      expect(row['notes_enc'], isNotNull);
      expect(row['notes_enc'], isNot('verified'));

      final fetched = await repository.getByNickname('Form 16', keyBytes);
      expect(fetched.value?.category, DocumentCategory.taxCredit);
      expect(fetched.value?.linkedAccountNickname, 'HDFC Salary');
      expect(fetched.value?.customFields, {
        'employer': 'NewCorp',
        'fy': '2025-26',
      });
      expect(fetched.value?.notes, 'verified');
    });

    test('preserves the attachment blob on update', () async {
      await repository.create(
        record('Form 16', attachment: [9, 8, 7]),
        keyBytes,
      );
      final beforeRows = await vaultDb.db.query(
        VaultTables.secureDocuments,
        columns: const ['attachment_blob_enc'],
        where: 'nickname = ?',
        whereArgs: ['Form 16'],
        limit: 1,
      );
      final attachmentBlobEnc = beforeRows.single['attachment_blob_enc'];

      await repository.update(record('Form 16', notes: 'n'), keyBytes);

      final afterRows = await vaultDb.db.query(
        VaultTables.secureDocuments,
        columns: const ['attachment_blob_enc'],
        where: 'nickname = ?',
        whereArgs: ['Form 16'],
        limit: 1,
      );
      expect(attachmentBlobEnc, isNotNull);
      expect(afterRows.single['attachment_blob_enc'], attachmentBlobEnc);

      final fetched = await repository.getByNickname('Form 16', keyBytes);
      expect(fetched.value?.attachmentBlob, [9, 8, 7]);
    });

    test('preserves createdAt on update', () async {
      final createdAt = DateTime(2026, 7, 20, 9, 30);
      final updatedCreatedAt = DateTime(2026, 8, 21, 18, 45);
      await repository.create(
        record('Form 16', createdAt: createdAt),
        keyBytes,
      );

      await repository.update(
        record('Form 16', notes: 'n', createdAt: updatedCreatedAt),
        keyBytes,
      );

      final rows = await vaultDb.db.query(
        VaultTables.secureDocuments,
        columns: const ['created_at'],
        where: 'nickname = ?',
        whereArgs: ['Form 16'],
        limit: 1,
      );
      final fetched = await repository.getByNickname('Form 16', keyBytes);

      expect(rows.single['created_at'], createdAt.millisecondsSinceEpoch);
      expect(fetched.value?.createdAt, createdAt);
    });

    test('fails with NotFoundFailure for an unknown nickname', () async {
      final result = await repository.update(record('Ghost'), keyBytes);

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<NotFoundFailure>());
    });
  });

  group('deleteByNickname', () {
    test('removes the record; unknown nickname fails', () async {
      await repository.create(record('Form 16'), keyBytes);

      expect((await repository.deleteByNickname('Form 16')).isSuccess, isTrue);
      expect(
        (await repository.getByNickname('Form 16', keyBytes)).value,
        isNull,
      );

      final missing = await repository.deleteByNickname('Form 16');
      expect(missing.isFailure, isTrue);
      expect(missing.failure, isA<NotFoundFailure>());
    });
  });
}
