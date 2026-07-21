import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/src/domain/entities/credit_card_record.dart';
import 'package:platform_coin_vault/src/domain/entities/secure_document_record.dart';
import 'package:platform_coin_vault/src/domain/entities/vault_entry_summary.dart';

void main() {
  group('VaultEntrySummary types', () {
    test('BankAccountSummary equality is value-based', () {
      const a = BankAccountSummary(
        nickname: 'HDFC Salary',
        bankName: 'HDFC Bank',
        accountHolderName: 'Jane Doe',
        ifscCode: 'HDFC0001234',
        accountType: 'savings',
      );
      const b = BankAccountSummary(
        nickname: 'HDFC Salary',
        bankName: 'HDFC Bank',
        accountHolderName: 'Jane Doe',
        ifscCode: 'HDFC0001234',
        accountType: 'savings',
      );
      expect(a, equals(b));
    });

    test('PanCardSummary is keyed by row id', () {
      const summary = PanCardSummary(id: 7, nameOnCard: 'JANE DOE');
      expect(summary.id, 7);
      expect(summary.fathersName, isNull);
    });

    test('CreditCardSummary carries only masked-only fields', () {
      const summary = CreditCardSummary(
        nickname: 'ICICI Amazon Pay',
        cardNetwork: CardNetwork.visa,
        last4: '4321',
        expiryMonth: 8,
        expiryYear: 2029,
        issuingBank: 'ICICI Bank',
      );
      expect(summary.last4, '4321');
      expect(summary.cardNetwork, CardNetwork.visa);
    });

    test('SecureDocumentSummary exposes hasAttachment without decrypting', () {
      const summary = SecureDocumentSummary(
        nickname: 'Form 16 FY25',
        category: DocumentCategory.incomeProof,
        linkedAccountNickname: 'HDFC Salary',
        hasAttachment: false,
      );
      expect(summary.category, DocumentCategory.incomeProof);
      expect(summary.hasAttachment, isFalse);
    });
  });
}
