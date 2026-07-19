import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/src/crypto/field_cipher.dart';
import 'package:platform_coin_vault/src/data/bank_account_repository.dart';
import 'package:platform_coin_vault/src/data/credit_card_repository.dart';
import 'package:platform_coin_vault/src/data/pan_card_repository.dart';
import 'package:platform_coin_vault/src/data/secure_document_repository.dart';
import 'package:platform_coin_vault/src/data/vault_database.dart';
import 'package:platform_coin_vault/src/domain/entities/bank_account_record.dart';
import 'package:platform_coin_vault/src/domain/entities/credit_card_record.dart';
import 'package:platform_coin_vault/src/domain/entities/pan_card_record.dart';
import 'package:platform_coin_vault/src/domain/entities/secure_document_record.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late VaultDatabase vaultDb;
  late List<int> keyBytes;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    vaultDb = VaultDatabase(databaseFactory: databaseFactoryFfi);
    await vaultDb.open(path: inMemoryDatabasePath);
    keyBytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
  });

  tearDown(() async {
    await vaultDb.close();
  });

  test('all four repositories operate against one VaultDatabase instance without schema drift', () async {
    final fieldCipher = FieldCipher();
    final bankAccounts = BankAccountRepository(database: vaultDb, fieldCipher: fieldCipher);
    final panCards = PanCardRepository(database: vaultDb, fieldCipher: fieldCipher);
    final creditCards = CreditCardRepository(database: vaultDb);
    final secureDocuments = SecureDocumentRepository(database: vaultDb, fieldCipher: fieldCipher);

    final bankResult = await bankAccounts.create(
      BankAccountRecord(
        id: null,
        nickname: 'HDFC Salary',
        bankName: 'HDFC Bank',
        accountHolderName: 'Jane Doe',
        accountNumber: '1234567890',
        ifscCode: 'HDFC0001234',
        accountType: 'savings',
      ),
      keyBytes,
    );
    final panResult = await panCards.create(
      PanCardRecord(id: null, panNumber: 'ABCDE1234F', nameOnCard: 'Jane Doe'),
      keyBytes,
    );
    final creditResult = await creditCards.create(
      CreditCardRecord(
        id: null,
        nickname: 'HDFC Regalia',
        cardNetwork: CardNetwork.visa,
        last4: '4242',
        expiryMonth: 12,
        expiryYear: 2028,
        issuingBank: 'HDFC Bank',
        createdAt: DateTime(2026, 7, 19),
      ),
    );
    final documentResult = await secureDocuments.create(
      SecureDocumentRecord(
        id: null,
        nickname: 'Form 16 FY24-25',
        category: DocumentCategory.incomeProof,
        linkedAccountNickname: 'HDFC Salary',
        createdAt: DateTime(2026, 7, 19),
      ),
      keyBytes,
    );

    expect(bankResult.isSuccess, isTrue);
    expect(panResult.isSuccess, isTrue);
    expect(creditResult.isSuccess, isTrue);
    expect(documentResult.isSuccess, isTrue);

    final fetchedBank = await bankAccounts.getByNickname('HDFC Salary', keyBytes);
    final fetchedPan = await panCards.getById(panResult.value, keyBytes);
    final fetchedCredit = await creditCards.getByNickname('HDFC Regalia');
    final fetchedDocument = await secureDocuments.getByNickname('Form 16 FY24-25', keyBytes);

    expect(fetchedBank.value?.accountNumber, '1234567890');
    expect(fetchedPan.value?.panNumber, 'ABCDE1234F');
    expect(fetchedCredit.value?.last4, '4242');
    expect(fetchedDocument.value?.linkedAccountNickname, fetchedBank.value?.nickname);
  });
}
