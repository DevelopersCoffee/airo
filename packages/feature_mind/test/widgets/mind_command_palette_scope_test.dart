import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_mind/src/runtime/fixture/fixture_mind_runtime.dart';
import 'package:feature_mind/src/runtime/mind_global_shortcut.dart';
import 'package:feature_mind/src/widgets/mind_command_palette_scope.dart';

/// A shortcut double the test triggers directly, sidestepping real keyboard
/// event simulation — [MindInAppGlobalShortcut] already has its own tests.
class _FakeShortcut implements MindGlobalShortcut {
  VoidCallback? onTrigger;
  var disposed = false;

  @override
  void register(VoidCallback onTrigger) => this.onTrigger = onTrigger;

  @override
  void dispose() => disposed = true;

  void fire() => onTrigger?.call();
}

/// Runs [body] with `defaultTargetPlatform` overridden, then resets it.
///
/// The reset must happen inside the `testWidgets` callback itself — a
/// `tearDown` registered with package:test runs after
/// `TestWidgetsFlutterBinding` has already asserted no foundation debug
/// variable was left set, so a global `setUp`/`tearDown` pair is too late.
Future<void> onPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  testWidgets('the summon key opens the browser over the child surface', (
    tester,
  ) async {
    await onPlatform(TargetPlatform.macOS, () async {
      final shortcut = _FakeShortcut();

      await tester.pumpWidget(
        MaterialApp(
          home: MindCommandPaletteScope(
            runtime: FixtureMindRuntime(),
            shortcut: shortcut,
            child: const Scaffold(body: Text('host surface')),
          ),
        ),
      );

      expect(find.text('host surface'), findsOneWidget);
      expect(
        find.byKey(const Key('mind.commandPalette.overlay')),
        findsNothing,
      );

      shortcut.fire();
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const Key('mind.commandPalette.overlay')),
        findsOneWidget,
      );
      // The host surface stays mounted underneath — ⌘K summons an overlay,
      // it does not navigate away.
      expect(find.text('host surface'), findsOneWidget);
    });
  });

  testWidgets('closing the palette returns to just the host surface', (
    tester,
  ) async {
    await onPlatform(TargetPlatform.macOS, () async {
      final shortcut = _FakeShortcut();

      await tester.pumpWidget(
        MaterialApp(
          home: MindCommandPaletteScope(
            runtime: FixtureMindRuntime(),
            shortcut: shortcut,
            child: const Scaffold(body: Text('host surface')),
          ),
        ),
      );

      shortcut.fire();
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const Key('mind.commandPalette.overlay')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('mind.everythingBrowser.close')));
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const Key('mind.commandPalette.overlay')),
        findsNothing,
      );
    });
  });

  testWidgets('registers the shortcut only on macOS', (tester) async {
    await onPlatform(TargetPlatform.android, () async {
      final shortcut = _FakeShortcut();

      await tester.pumpWidget(
        MaterialApp(
          home: MindCommandPaletteScope(
            runtime: FixtureMindRuntime(),
            shortcut: shortcut,
            child: const Scaffold(body: Text('host surface')),
          ),
        ),
      );

      expect(shortcut.onTrigger, isNull);
    });
  });

  testWidgets('disposes the shortcut when the scope unmounts', (
    tester,
  ) async {
    await onPlatform(TargetPlatform.macOS, () async {
      final shortcut = _FakeShortcut();

      await tester.pumpWidget(
        MaterialApp(
          home: MindCommandPaletteScope(
            runtime: FixtureMindRuntime(),
            shortcut: shortcut,
            child: const Scaffold(body: Text('host surface')),
          ),
        ),
      );

      await tester.pumpWidget(const SizedBox());

      expect(shortcut.disposed, isTrue);
    });
  });
}
