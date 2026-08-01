import 'package:core_ui/core_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'TvFocusable exposes ActivateIntent and SELECT fires exactly once',
    (tester) async {
      var selectCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvFocusable(
              autofocus: true,
              onSelect: () => selectCount += 1,
              child: const Text('Activate me'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final focusedContext = FocusManager.instance.primaryFocus!.context!;
      expect(
        Actions.maybeFind<ActivateIntent>(focusedContext),
        isNotNull,
        reason: 'Fire TV SELECT is dispatched through the app shortcut system',
      );

      Actions.invoke(focusedContext, const ActivateIntent());
      await tester.pump();
      expect(selectCount, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(
        selectCount,
        2,
        reason: 'one SELECT down/up pair must invoke one action',
      );
    },
  );

  testWidgets(
    'focusable Material children do not create duplicate D-pad stops',
    (tester) async {
      final firstNode = FocusNode();
      final secondNode = FocusNode();
      addTearDown(firstNode.dispose);
      addTearDown(secondNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                TvFocusable(
                  focusNode: firstNode,
                  autofocus: true,
                  onSelect: () {},
                  child: IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.share),
                  ),
                ),
                TvFocusable(
                  focusNode: secondNode,
                  onSelect: () {},
                  child: IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.monitor),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(firstNode.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(firstNode.hasFocus, isFalse);
      expect(
        secondNode.hasPrimaryFocus,
        isTrue,
        reason: 'one RIGHT must move to the next visible TV action',
      );
    },
  );

  testWidgets('TvFocusable supports cursor hover focus and mouse selection', (
    tester,
  ) async {
    var focusCount = 0;
    var selectCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 160,
              height: 80,
              child: TvFocusable(
                onFocus: () => focusCount += 1,
                onSelect: () => selectCount += 1,
                semanticLabel: 'Play channel',
                child: const Center(child: Text('Play')),
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);

    await gesture.addPointer(location: Offset.zero);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.text('Play')));
    await tester.pumpAndSettle();

    expect(focusCount, 1);
    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);

    await tester.tap(find.text('Play'), kind: PointerDeviceKind.mouse);
    await tester.pump();

    expect(selectCount, 1);
  });

  testWidgets('TvFocusable preserves child subtree during focus changes', (
    tester,
  ) async {
    var buildCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 160,
              height: 80,
              child: TvFocusable(
                child: _BuildCounter(
                  onBuild: () => buildCount += 1,
                  child: const Text('Stable child'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(buildCount, 1);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);

    await gesture.addPointer(location: Offset.zero);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.text('Stable child')));
    await tester.pumpAndSettle();

    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);
    expect(buildCount, 1);
  });

  testWidgets('TvFocusable triggers onSecondaryAction via the menu key', (
    tester,
  ) async {
    var secondaryCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 160,
              height: 80,
              child: TvFocusable(
                autofocus: true,
                onSelect: () {},
                onSecondaryAction: () => secondaryCount += 1,
                child: const Center(child: Text('Favorite me')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.pump();

    expect(secondaryCount, 1);
  });

  testWidgets('handled global D-pad input does not traverse a second time', (
    tester,
  ) async {
    final nodes = List.generate(3, (_) => FocusNode());
    addTearDown(() {
      for (final node in nodes) {
        node.dispose();
      }
    });

    await tester.pumpWidget(
      MaterialApp(
        home: TvInputHandler(
          onInput: (key) {
            if (key == TvInputKey.right) {
              FocusManager.instance.primaryFocus!.focusInDirection(
                TraversalDirection.right,
              );
              return TvInputResult.handled;
            }
            return TvInputResult.notHandled;
          },
          child: Row(
            children: [
              for (var index = 0; index < nodes.length; index++)
                TvFocusable(
                  focusNode: nodes[index],
                  autofocus: index == 0,
                  child: Text('Box $index'),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(nodes[0].hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(nodes[1].hasFocus, isTrue);
    expect(
      nodes[2].hasFocus,
      isFalse,
      reason: 'one Fire TV key press must advance exactly one visual box',
    );
  });

  testWidgets(
    'TvFocusable scrolls itself into view when it gains focus off-screen '
    '(D-pad through a long list must not leave focus invisible)',
    (tester) async {
      final scrollController = ScrollController();
      final focusNodes = List.generate(20, (_) => FocusNode());
      addTearDown(() {
        for (final node in focusNodes) {
          node.dispose();
        }
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              // Eagerly-built children (unlike ListView.builder) so the
              // test isolates ensureVisible-on-focus from lazy-build
              // timing — every item already exists in the tree, only
              // scroll position needs to catch up to focus.
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  children: [
                    for (var index = 0; index < 20; index++)
                      SizedBox(
                        height: 100,
                        child: TvFocusable(
                          focusNode: focusNodes[index],
                          onSelect: () {},
                          child: Text('Item $index'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(scrollController.offset, 0);

      // Item 10 is far below the 300px viewport (10 * 100 = 1000px down).
      focusNodes[10].requestFocus();
      await tester.pumpAndSettle();

      expect(
        scrollController.offset,
        greaterThan(0),
        reason: 'focused item 10 is off-screen; the list must scroll to it',
      );
    },
  );

  testWidgets(
    'sequential D-pad moves down a long list scroll by one row at a time, '
    'never overshooting past the newly-focused item',
    (tester) async {
      const rowHeight = 100.0;
      const viewportHeight = 300.0;
      final scrollController = ScrollController();
      final focusNodes = List.generate(10, (_) => FocusNode());
      addTearDown(() {
        for (final node in focusNodes) {
          node.dispose();
        }
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: viewportHeight,
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  children: [
                    for (var index = 0; index < 10; index++)
                      SizedBox(
                        height: rowHeight,
                        child: TvFocusable(
                          focusNode: focusNodes[index],
                          onSelect: () {},
                          child: Text('Item $index'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // Items 0-2 fit in the 300px viewport untouched; from item 3 on,
      // each step must scroll by at most one row's worth (100px) to bring
      // the newly-focused row's trailing edge into view -- never more.
      for (var index = 0; index < 10; index++) {
        final before = scrollController.offset;
        focusNodes[index].requestFocus();
        await tester.pumpAndSettle();
        final delta = scrollController.offset - before;

        expect(
          delta,
          lessThanOrEqualTo(rowHeight + 0.01),
          reason:
              'focusing item $index scrolled by $delta px, more than one '
              'row -- this is the double-scroll/skip regression',
        );
        expect(
          find.text('Item $index'),
          findsOneWidget,
          reason: 'item $index must still be in the tree after scrolling',
        );
      }
    },
  );

  testWidgets(
    'TvFocusable does not scroll when the focused item is already visible '
    '(recentering on every focus reads as rows skipping under the D-pad)',
    (tester) async {
      final scrollController = ScrollController();
      final focusNodes = List.generate(20, (_) => FocusNode());
      addTearDown(() {
        for (final node in focusNodes) {
          node.dispose();
        }
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  children: [
                    for (var index = 0; index < 20; index++)
                      SizedBox(
                        height: 100,
                        child: TvFocusable(
                          focusNode: focusNodes[index],
                          onSelect: () {},
                          child: Text('Item $index'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // Items 0-2 fill the 300px viewport. Focusing item 2 — fully visible
      // at the bottom edge — must leave the scroll position untouched (a
      // center-aligning scroll would move to offset 100).
      focusNodes[2].requestFocus();
      await tester.pumpAndSettle();

      expect(
        scrollController.offset,
        0,
        reason:
            'item 2 was already fully on-screen; scrolling anyway makes '
            'the list shift under every focus move',
      );
    },
  );

  testWidgets('TvFocusable triggers onSecondaryAction via long-press', (
    tester,
  ) async {
    var secondaryCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 160,
              height: 80,
              child: TvFocusable(
                onSelect: () {},
                onSecondaryAction: () => secondaryCount += 1,
                child: const Center(child: Text('Favorite me')),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.text('Favorite me'));
    await tester.pump();

    expect(secondaryCount, 1);
  });

  // issues/02-focus-tokens-reduced-motion.md acceptance criterion 2:
  // reduced motion makes focus scale instantaneous/absent without removing
  // focus visibility (the border must still appear).
  Widget wrap({required bool disableAnimations}) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 160,
              height: 80,
              child: TvFocusable(
                autofocus: true,
                onSelect: () {},
                child: const Center(child: Text('Focus me')),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('normal motion animates scale up to the design token (1.04) once '
      'settled', (tester) async {
    await tester.pumpWidget(wrap(disableAnimations: false));
    await tester.pumpAndSettle();

    final transform = tester.widget<Transform>(
      find.descendant(
        of: find.byType(TvFocusable),
        matching: find.byType(Transform),
      ),
    );
    expect(transform.transform.getMaxScaleOnAxis(), closeTo(1.04, 0.001));

    final decoratedBox = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(TvFocusable),
        matching: find.byType(DecoratedBox),
      ),
    );
    final decoration = decoratedBox.decoration as BoxDecoration;
    expect(decoration.border, isNotNull);
  });

  testWidgets(
    'reduced motion keeps scale at 1.0 but still draws the focus border',
    (tester) async {
      await tester.pumpWidget(wrap(disableAnimations: true));
      await tester.pumpAndSettle();

      final transform = tester.widget<Transform>(
        find.descendant(
          of: find.byType(TvFocusable),
          matching: find.byType(Transform),
        ),
      );
      expect(transform.transform.getMaxScaleOnAxis(), closeTo(1.0, 0.001));

      final decoratedBox = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(TvFocusable),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = decoratedBox.decoration as BoxDecoration;
      expect(
        decoration.border,
        isNotNull,
        reason: 'reduced motion must not remove focus visibility',
      );
    },
  );

  // Excluding descendant focus is right for a Material button, but a text
  // field that cannot take focus can never receive typed input -- on a TV that
  // reads as a search box that silently swallows everything you type.
  testWidgets(
    'descendantsAreFocusable lets a wrapped TextField accept typed input',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvFocusable(
              onSelect: () {},
              descendantsAreFocusable: true,
              child: TextField(
                key: const ValueKey('field'),
                controller: controller,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('field')), 'news');
      await tester.pump();

      expect(controller.text, 'news');
    },
  );

  testWidgets('descendant focus is excluded by default', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvFocusable(
            onSelect: () {},
            child: TextField(
              key: const ValueKey('field'),
              controller: controller,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<ExcludeFocus>(find.byType(ExcludeFocus)).excluding,
      isTrue,
      reason: 'Material children must not add a second D-pad stop by default',
    );
  });
}

class _BuildCounter extends StatelessWidget {
  final VoidCallback onBuild;
  final Widget child;

  const _BuildCounter({required this.onBuild, required this.child});

  @override
  Widget build(BuildContext context) {
    onBuild();
    return child;
  }
}
