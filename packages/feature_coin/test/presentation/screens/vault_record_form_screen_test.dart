// ignore_for_file: depend_on_referenced_packages

import 'package:feature_coin/feature_coin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows inline error for invalid IFSC and does not save', (
    tester,
  ) async {
    var saved = false;
    await tester.pumpWidget(
      MaterialApp(
        home: VaultRecordFormScreen(
          type: VaultRecordType.bankAccount,
          onSaved: () => saved = true,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('vault_nickname_field')),
      'HDFC Salary',
    );
    await tester.enterText(
      find.byKey(const ValueKey('vault_bankName_field')),
      'HDFC Bank',
    );
    await tester.enterText(
      find.byKey(const ValueKey('vault_accountHolderName_field')),
      'Jane Doe',
    );
    await tester.enterText(
      find.byKey(const ValueKey('vault_accountNumber_field')),
      '123456789012',
    );
    await tester.enterText(
      find.byKey(const ValueKey('vault_ifscCode_field')),
      'BADIFSC',
    );
    await tester.enterText(
      find.byKey(const ValueKey('vault_accountType_field')),
      'savings',
    );

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('vault_save_record_button')));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pump();

    expect(find.text('Not a valid IFSC code'), findsOneWidget);
    expect(saved, isFalse);
  });
}
