import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_mind/src/runtime/mind_global_shortcut.dart';

void main() {
  testWidgets('MindInAppGlobalShortcut fires on Cmd+K', (tester) async {
    final shortcut = MindInAppGlobalShortcut();
    var triggerCount = 0;
    shortcut.register(() => triggerCount++);
    addTearDown(shortcut.dispose);

    // A focusable widget so key events reach the engine's key handling.
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TextField(autofocus: true))),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
    await tester.pump();

    expect(triggerCount, 1);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  });

  testWidgets('does not fire on K alone', (tester) async {
    final shortcut = MindInAppGlobalShortcut();
    var triggerCount = 0;
    shortcut.register(() => triggerCount++);
    addTearDown(shortcut.dispose);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TextField(autofocus: true))),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
    await tester.pump();

    expect(triggerCount, 0);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
  });

  testWidgets(
    'registering twice replaces the previous callback rather than stacking it',
    (tester) async {
      final shortcut = MindInAppGlobalShortcut();
      var firstCalls = 0;
      var secondCalls = 0;
      shortcut.register(() => firstCalls++);
      shortcut.register(() => secondCalls++);
      addTearDown(shortcut.dispose);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TextField(autofocus: true))),
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
      await tester.pump();

      expect(firstCalls, 0);
      expect(secondCalls, 1);

      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    },
  );

  testWidgets('dispose stops the shortcut from firing', (tester) async {
    final shortcut = MindInAppGlobalShortcut();
    var triggerCount = 0;
    shortcut.register(() => triggerCount++);
    shortcut.dispose();

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TextField(autofocus: true))),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
    await tester.pump();

    expect(triggerCount, 0);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  });
}
