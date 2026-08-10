import 'package:airo_app/features/home/screens/home_screen.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('living console home remains usable across target widths', (
    tester,
  ) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.devicePixelRatio = 1;

    for (final width in [320.0, 375.0, 600.0, 768.0, 1024.0, 1440.0, 1920.0]) {
      tester.view.physicalSize = Size(width, 1000);
      await tester.pumpWidget(
        MaterialApp(
          theme: AiroTheme.defaultDark,
          home: const AiroDomainTheme(
            domain: AiroDomain.airo,
            child: Scaffold(body: HomeScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your day, in one place'), findsOneWidget);
      expect(find.text('Coins'), findsOneWidget);
      expect(find.text('Expenses, budgets & secure vault.'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });
}
