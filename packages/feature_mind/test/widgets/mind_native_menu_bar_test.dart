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

  testWidgets('every menu item resolves to something that can run', (
    tester,
  ) async {
    // The macOS menu bar reads static hooks the shell assigns. Any hook left
    // unassigned produces a dead item, and the failure mode differs by how
    // the item is wired: `onSelected: Hook.x` renders greyed out, while
    // `onSelected: () => Hook.x?.call()` renders *enabled* and silently does
    // nothing. Five items shipped in one of those two states.
    var opened = <String>[];
    MindRuntimeNavigation.openNewChat = () => opened.add('newChat');
    MindRuntimeNavigation.openModelLibrary = () => opened.add('modelLibrary');
    MindRuntimeNavigation.openDeviceCapabilities = () =>
        opened.add('deviceCapabilities');
    MindRuntimeNavigation.openPromptLab = () => opened.add('promptLab');
    MindRuntimeNavigation.openIntelligence = () => opened.add('intelligence');
    MindRuntimeNavigation.openSettings = () => opened.add('settings');
    addTearDown(() {
      MindRuntimeNavigation.openNewChat = null;
      MindRuntimeNavigation.openModelLibrary = null;
      MindRuntimeNavigation.openDeviceCapabilities = null;
      MindRuntimeNavigation.openPromptLab = null;
      MindRuntimeNavigation.openIntelligence = null;
      MindRuntimeNavigation.openSettings = null;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MindNativeMenuBar(
          runtime: FixtureMindRuntime(),
          onOpenEverythingBrowser: () {},
          child: const Scaffold(body: SizedBox()),
        ),
      ),
    );

    final bar = tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar));
    final actions = MindNativeMenuBar.collectActions(bar);

    // Scoped to the items backed by MindRuntimeNavigation, which the shell
    // is responsible for assigning. Others are contextually null by design:
    // Export/Clear Chat come from MindChatMenuActions only while the chat
    // chrome is mounted, Toggle Sidebar and About are widget parameters, and
    // Troubleshooting / Logs is assigned by MindMacosRoot.
    const shellAssigned = [
      'Settings…',
      'Intelligence',
      'New Chat',
      'Model Library',
      'Device & Acceleration…',
      'Prompt Lab / Persona',
    ];
    final dead = shellAssigned
        .where((label) => actions[label] == null)
        .toList();
    expect(
      dead,
      isEmpty,
      reason:
          'These items are backed by MindRuntimeNavigation hooks the shell '
          'assigns, so a null here renders them permanently greyed out.',
    );

    // And the ones routed through the navigation hooks must actually reach
    // them once the shell has assigned them.
    for (final label in const [
      'New Chat',
      'Model Library',
      'Device & Acceleration…',
      'Prompt Lab / Persona',
    ]) {
      expect(
        actions.containsKey(label),
        isTrue,
        reason: 'Menu item "$label" disappeared.',
      );
      opened = [];
      actions[label]!.call();
      expect(
        opened,
        isNotEmpty,
        reason:
            '"$label" ran without reaching MindRuntimeNavigation, so it does '
            'nothing on a real Mac.',
      );
    }
  });

  testWidgets('offers no Close Window item it cannot honour', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MindNativeMenuBar(
          runtime: FixtureMindRuntime(),
          onOpenEverythingBrowser: () {},
          child: const Scaffold(body: SizedBox()),
        ),
      ),
    );

    final bar = tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar));
    expect(
      MindNativeMenuBar.collectActions(bar).containsKey('Close Window'),
      isFalse,
      reason:
          'Nothing can close the window — no window-management plugin, and a '
          'single-window app with no reopen path. Restore the item only '
          'alongside a real implementation.',
    );
  });
}
