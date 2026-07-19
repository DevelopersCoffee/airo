import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/src/crypto/field_cipher.dart';
import 'package:platform_coin_vault/src/data/secure_document_repository.dart';
import 'package:platform_coin_vault/src/data/vault_database.dart';
import 'package:platform_coin_vault/src/domain/entities/secure_document_record.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late VaultDatabase vaultDb;
  late SecureDocumentRepository repository;
  late List<int> keyBytes;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    vaultDb = VaultDatabase(databaseFactory: databaseFactoryFfi);
    await vaultDb.open(path: inMemoryDatabasePath);
    repository = SecureDocumentRepository(database: vaultDb, fieldCipher: FieldCipher());
    keyBytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
  });

  tearDown(() async {
    await vaultDb.close();
  });

  test('create then getByNickname roundtrips category and linked account', () async {
    final record = SecureDocumentRecord(
      id: null,
      nickname: 'Form 16 FY24-25',
      category: DocumentCategory.incomeProof,
      linkedAccountNickname: 'HDFC Salary',
      notes: 'Employer TDS certificate',
      createdAt: DateTime(2026, 7, 19),
    );

    final createResult = await repository.create(record, keyBytes);
    expect(createResult.isSuccess, isTrue);

    final fetched = await repository.getByNickname('Form 16 FY24-25', keyBytes);

    expect(fetched.value?.category, DocumentCategory.incomeProof);
    expect(fetched.value?.linkedAccountNickname, 'HDFC Salary');
    expect(fetched.value?.notes, 'Employer TDS certificate');
  });

  test('stored notes_enc column is never plaintext', () async {
    final record = SecureDocumentRecord(
      id: null,
      nickname: 'AIS FY24-25',
      category: DocumentCategory.taxCredit,
      notes: 'Downloaded from e-filing portal',
      createdAt: DateTime(2026, 7, 19),
    );

    await repository.create(record, keyBytes);

    final rows = await vaultDb.db.query(VaultTables.secureDocuments);
    expect(rows.single['notes_enc'], isNot('Downloaded from e-filing portal'));
  });

  test('custom fields roundtrip through encryption', () async {
    final record = SecureDocumentRecord(
      id: null,
      nickname: '80C Receipt',
      category: DocumentCategory.investmentProof,
      customFields: {'insurer': 'LIC', 'premium': '25000'},
      createdAt: DateTime(2026, 7, 19),
    );

    await repository.create(record, keyBytes);
    final fetched = await repository.getByNickname('80C Receipt', keyBytes);

    expect(fetched.value?.customFields, {'insurer': 'LIC', 'premium': '25000'});
  });
}
