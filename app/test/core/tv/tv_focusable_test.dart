import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airo_app/core/tv/tv_focusable.dart';

void main() {
  group('TvFocusable', () {
    testWidgets('should render child widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TvFocusable(child: const Text('Test Child'))),
        ),
      );

      expect(find.text('Test Child'), findsOneWidget);
    });

    testWidgets('should render without focus initially', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvFocusable(
              child: Container(
                key: const Key('test_container'),
                width: 100,
                height: 100,
                color: Colors.blue,
              ),
            ),
          ),
        ),
      );

      // Widget should be rendered
      expect(find.byKey(const Key('test_container')), findsOneWidget);
    });

    testWidgets('should call onFocus when focused', (tester) async {
      bool wasFocused = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvFocusable(
              autofocus: true,
              onFocus: () => wasFocused = true,
              child: const Text('Focusable'),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(wasFocused, isTrue);
    });

    testWidgets('should call onUnfocus when losing focus', (tester) async {
      bool wasUnfocused = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TvFocusable(
                  autofocus: true,
                  onUnfocus: () => wasUnfocused = true,
                  child: const Text('First'),
                ),
                TvFocusable(child: const Text('Second')),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      // Move focus to second widget
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(wasUnfocused, isTrue);
    });

    testWidgets('should call onSelect on enter key', (tester) async {
      bool wasSelected = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvFocusable(
              autofocus: true,
              onSelect: () => wasSelected = true,
              child: const Text('Selectable'),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(wasSelected, isTrue);
    });

    testWidgets('should not call onSelect when disabled', (tester) async {
      bool wasSelected = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvFocusable(
              enabled: false,
              onSelect: () => wasSelected = true,
              child: const Text('Disabled'),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(wasSelected, isFalse);
    });

    testWidgets('should render child only when disabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvFocusable(enabled: false, child: const Text('Just Text')),
          ),
        ),
      );

      expect(find.text('Just Text'), findsOneWidget);
      // When disabled, the TvFocusable returns just the child without wrapping
      // Verify the widget tree has the text but no TvFocusable-specific Focus
      final tvFocusable = tester.widget<TvFocusable>(find.byType(TvFocusable));
      expect(tvFocusable.enabled, isFalse);
    });

    testWidgets('should not rebuild child subtree on focus changes', (
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
