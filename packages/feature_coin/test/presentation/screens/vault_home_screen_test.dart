// ignore_for_file: depend_on_referenced_packages

import 'package:feature_coin/feature_coin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

void main() {
  testWidgets('renders grouped summaries without an unlocked session', (
    tester,
  ) async {
    const summaries = VaultSummaries(
      bankAccounts: [
        BankAccountSummary(
          nickname: 'HDFC Salary',
          bankName: 'HDFC Bank',
          accountHolderName: 'Jane Doe',
          ifscCode: 'HDFC0001234',
          accountType: 'savings',
        ),
      ],
      panCards: [PanCardSummary(id: 7, nameOnCard: 'JANE DOE')],
      creditCards: [
        CreditCardSummary(
          nickname: 'ICICI Amazon Pay',
          cardNetwork: CardNetwork.visa,
          last4: '4321',
          expiryMonth: 8,
          expiryYear: 2029,
          issuingBank: 'ICICI Bank',
        ),
      ],
      secureDocuments: [
        SecureDocumentSummary(
          nickname: 'Form 16 FY25',
          category: DocumentCategory.incomeProof,
          hasAttachment: false,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultSummariesProvider.overrideWith((ref) async => summaries),
        ],
        child: const MaterialApp(home: VaultHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bank accounts'), findsOneWidget);
    expect(find.text('PAN cards'), findsOneWidget);
    expect(find.text('Cards'), findsOneWidget);
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('HDFC Salary'), findsOneWidget);
    expect(find.text('JANE DOE'), findsOneWidget);
    expect(find.text('ICICI Amazon Pay'), findsOneWidget);
    expect(find.text('Form 16 FY25'), findsOneWidget);
    expect(find.textContaining('Summaries only'), findsOneWidget);
  });
}
