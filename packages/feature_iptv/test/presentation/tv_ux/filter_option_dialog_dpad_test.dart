import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// Not exported from feature_iptv.dart — dialogs are internal to the shell.
import 'package:feature_iptv/presentation/tv_ux/sections/filter_dialogs.dart';

void main() {
  testWidgets('D-pad down visits every option in order — no skipped rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FilterOptionDialog(
            title: 'Category',
            options: const ['Alpha', 'Bravo', 'Charlie', 'Delta', 'Echo'],
            selectedValue: null,
            onSelected: (_) {},
            onClear: () {},
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    const order = [
      'All',
      'Alpha',
      'Bravo',
      'Charlie',
      'Delta',
      'Echo',
    ];

    // Which option row holds focus now? A row is "focused" when the focus
    // ancestor of its Text widget has primary focus.
    String? currentFocused() {
      for (final option in order) {
        final finder = find.text(option);
        if (finder.evaluate().isEmpty) continue;
        final element = finder.evaluate().first;
        final focus = Focus.maybeOf(element, scopeOk: true);
        if (focus != null && focus.hasPrimaryFocus) return option;
      }
      return null;
    }

    final visited = <String>[];
    for (var i = 0; i < order.length; i++) {
      final label = currentFocused();
      if (label != null && (visited.isEmpty || visited.last != label)) {
        visited.add(label);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }

    // Every consecutive pair must be adjacent rows — a gap of 2+ means the
    // D-pad skipped an option (reported on Fire TV Stick: category dialog
    // skips alternate choices).
    expect(visited.length, greaterThanOrEqualTo(3), reason: 'sanity: $visited');
    for (var i = 1; i < visited.length; i++) {
      final from = order.indexOf(visited[i - 1]);
      final to = order.indexOf(visited[i]);
      expect(
        to - from,
        1,
        reason:
            'focus jumped ${visited[i - 1]} → ${visited[i]} '
            '(visited: $visited)',
      );
    }
  });
}
