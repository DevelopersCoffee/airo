import 'package:core_ui/core_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
