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
    final labels = MindNativeMenuBar.collectActions(bar);

    expect(labels.containsKey('Search Everything'), isTrue);
    expect(labels.containsKey('Everything Browser'), isTrue);
    expect(labels.containsKey('New Chat'), isTrue);
    expect(labels.containsKey('Model Library'), isTrue);

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
    MindNativeMenuBar.collectActions(bar)['New Note']!();
    await tester.pumpAndSettle();

    final after = await runtime.log.count();
    expect(after, before + 1);
  });
}
