import 'package:core_product_shell/core_product_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets("every registry entry's icon asset loads without error", (
    tester,
  ) async {
    for (final app in siblingApps) {
      await tester.pumpWidget(
        MaterialApp(home: Image.asset(app.iconAsset)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    }
  });
}
