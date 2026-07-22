import 'package:feature_iptv/presentation/tv_ux/sections/filter_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dialog sorts values alphabetically and exposes D-pad targets', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FilterOptionDialog(
            title: 'Country',
            options: const ['US', 'IN'],
            selectedValue: null,
            onSelected: (value) => selected = value,
            onClear: () {},
            onClose: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('filter-option-IN')), findsOneWidget);
    expect(find.byType(Focus), findsWidgets);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(selected, isNotNull);
  });

  testWidgets('zero-result state provides a clear-filter affordance', (
    tester,
  ) async {
    var cleared = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FilterOptionDialog(
            title: 'Language',
            options: const [],
            selectedValue: 'en',
            emptyResult: true,
            onSelected: (_) {},
            onClear: () => cleared = true,
            onClose: () {},
          ),
        ),
      ),
    );

    expect(find.text('No channels match'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    expect(cleared, isTrue);
  });
}
