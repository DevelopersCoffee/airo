// ignore_for_file: depend_on_referenced_packages

import 'package:feature_coin/feature_coin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

class FakeVaultRecordReader implements VaultRecordReader {
  var bankAccountNumberRevealCount = 0;

  @override
  Future<String?> revealBankAccountNumber(String nickname) async {
    bankAccountNumberRevealCount++;
    return '123456789012';
  }

  @override
  Future<String?> revealBankNotes(String nickname) async => 'Payroll account';

  @override
  Future<String?> revealDocumentNotes(String nickname) async => null;

  @override
  Future<String?> revealPanNumber(int id) async => null;
}

void main() {
  testWidgets('masks account number until reveal and delegates copy', (
    tester,
  ) async {
    final reader = FakeVaultRecordReader();
    String? copied;
    final clipboard = ClipboardService(
      setData: (data) async => copied = data.text,
      getData: () async => ClipboardData(text: copied ?? ''),
    );
    addTearDown(clipboard.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultRecordReaderProvider.overrideWithValue(reader),
          clipboardServiceProvider.overrideWithValue(clipboard),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: RecordDetailSheet(
              recordRef: VaultRecordRef.bankAccount('HDFC Salary'),
              summary: BankAccountSummary(
                nickname: 'HDFC Salary',
                bankName: 'HDFC Bank',
                accountHolderName: 'Jane Doe',
                ifscCode: 'HDFC0001234',
                accountType: 'savings',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('••••••••'), findsOneWidget);
    expect(find.text('123456789012'), findsNothing);

    await tester.tap(find.byIcon(Icons.visibility).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('123456789012'), findsOneWidget);
    expect(reader.bankAccountNumberRevealCount, 1);

    await tester.tap(find.byIcon(Icons.copy_outlined).first);
    await tester.pump();

    expect(copied, '123456789012');
    clipboard.dispose();
  });
}
