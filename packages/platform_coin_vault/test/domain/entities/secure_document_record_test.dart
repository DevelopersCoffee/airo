import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/src/domain/entities/secure_document_record.dart';

void main() {
  test('all ITR-driven categories are available', () {
    expect(DocumentCategory.values, containsAll(<DocumentCategory>[
      DocumentCategory.personalId,
      DocumentCategory.incomeProof,
      DocumentCategory.taxCredit,
      DocumentCategory.investmentProof,
      DocumentCategory.hra,
      DocumentCategory.capitalGains,
      DocumentCategory.homeLoan,
      DocumentCategory.other,
    ]));
  });

  test('linkedAccountNickname is optional', () {
    final record = SecureDocumentRecord(
      id: null,
      nickname: 'Form 16 FY24-25',
      category: DocumentCategory.incomeProof,
      createdAt: DateTime(2026, 7, 19),
    );

    expect(record.linkedAccountNickname, isNull);
  });
}
