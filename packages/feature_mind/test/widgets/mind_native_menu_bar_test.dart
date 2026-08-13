import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_mind/src/runtime/fixture/fixture_mind_runtime.dart';
import 'package:feature_mind/src/widgets/mind_native_menu_bar.dart';

void main() {
  testWidgets('wraps its child without altering the tree beneath it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MindNativeMenuBar(
          runtime: FixtureMindRuntime(),
          onOpenEverythingBrowser: () {},
          child: const Scaffold(body: Text('mind surface')),
        ),
      ),
    );

    expect(find.text('mind surface'), findsOneWidget);
    expect(find.byType(PlatformMenuBar), findsOneWidget);
  });

  testWidgets('Search Everything and Everything Browser call the same action', (
    tester,
  ) async {
    var openCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MindNativeMenuBar(
          runtime: FixtureMindRuntime(),
          onOpenEverythingBrowser: () => openCount++,
          child: const Scaffold(body: SizedBox()),
        ),
      ),
    );

    final bar = tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar));
    final labels = <String, VoidCallback?>{};
    void collect(List<PlatformMenuItem> items) {
      for (final item in items) {
        if (item is PlatformMenu) {
          collect(item.menus.whereType<PlatformMenuItem>().toList());
          continue;
        }
        labels[item.label] = item.onSelected;
      }
    }

    collect(bar.menus);

    expect(labels.containsKey('Search Everything'), isTrue);
    expect(labels.containsKey('Everything Browser'), isTrue);

    labels['Search Everything']!();
    labels['Everything Browser']!();

    expect(openCount, 2);
  });

  testWidgets('File > New Note calls through to the runtime log', (
    tester,
  ) async {
    final runtime = FixtureMindRuntime();

    await tester.pumpWidget(
      MaterialApp(
        home: MindNativeMenuBar(
          runtime: runtime,
          onOpenEverythingBrowser: () {},
          child: const Scaffold(body: SizedBox()),
        ),
      ),
    );

    final before = await runtime.log.count();

    final bar = tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar));
    final fileMenu = bar.menus.whereType<PlatformMenu>().firstWhere(
      (menu) => menu.label == 'File',
    );
    final newNote = fileMenu.menus
        .whereType<PlatformMenuItem>()
        .firstWhere((item) => item.label == 'New Note');

    newNote.onSelected!();
    await tester.pumpAndSettle();

    final after = await runtime.log.count();
    expect(after, before + 1);
  });
}
