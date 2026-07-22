import 'package:airo_app/features/home/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('coins home card points users to vault-enabled money tools', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.text('Coins'), findsOneWidget);
    expect(find.text('Expenses, budgets & secure vault'), findsOneWidget);
  });
}
