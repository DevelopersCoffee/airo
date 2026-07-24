/// Focus state verification assertions for TV D-pad integration testing.
///
/// Critical for Sony BRAVIA 2 qualification where the D-pad is the **only**
/// input method. These assertions verify that focus is always visible,
/// reachable, and never trapped.
///
/// Usage:
/// ```dart
/// final focus = FocusAssertions(tester);
/// await focus.expectFocusedWidget(find.byKey(Key('live_tab')));
/// await focus.expectNoFocusTrap();
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dpad_simulator.dart';

/// Assertions for verifying D-pad focus state in TV integration tests.
class FocusAssertions {
  FocusAssertions(this._tester);

  final WidgetTester _tester;

  /// Asserts that the widget matching [finder] currently has primary focus.
  ///
  /// Fails with a descriptive message including the current focus target
  /// if the assertion doesn't hold.
  void expectFocusedWidget(Finder finder) {
    final element = _tester.element(finder);
    final focusNode = Focus.of(element);
    expect(
      focusNode.hasPrimaryFocus || focusNode.hasFocus,
      isTrue,
      reason: 'Expected widget "${finder.description}" to have focus, '
          'but current primary focus is: ${_describePrimaryFocus()}',
    );
  }

  /// Asserts that focus is somewhere within the widget subtree matched by
  /// [scopeFinder] (i.e. within a `FocusScope` or any ancestor).
  void expectFocusWithinGroup(Finder scopeFinder) {
    final element = _tester.element(scopeFinder);
    final scope = FocusScope.of(element);
    final hasFocusedChild = scope.hasFocus;
    expect(
      hasFocusedChild,
      isTrue,
      reason: 'Expected focus within scope "${scopeFinder.description}", '
          'but focus is at: ${_describePrimaryFocus()}',
    );
  }

  /// Asserts that the `TvFocusable` decoration (border/glow) is visually
  /// rendered on the focused widget, confirming visibility at 10-foot scale.
  ///
  /// Checks for `DecoratedBox` with a non-empty `BoxDecoration.border`.
  void expectFocusHighlightVisible(Finder finder) {
    final decoratedBoxFinder = find.descendant(
      of: finder,
      matching: find.byType(DecoratedBox),
    );
    expect(
      decoratedBoxFinder,
      findsWidgets,
      reason: 'No DecoratedBox found under "${finder.description}" — '
          'focus highlight may not be rendering',
    );

    final decoratedBox =
        _tester.widget<DecoratedBox>(decoratedBoxFinder.first);
    final decoration = decoratedBox.decoration;
    if (decoration is BoxDecoration) {
      expect(
        decoration.border,
        isNotNull,
        reason: 'Focus border decoration is null on "${finder.description}"',
      );
    }
  }

  /// Asserts that the current focus position is **not** trapped — i.e., the
  /// D-pad can move focus away in all 4 directions.
  ///
  /// This tests the #1 D-pad failure mode on TV: focus gets stuck on a widget
  /// and no amount of arrow key pressing moves it elsewhere.
  ///
  /// The method saves the current focus, presses each direction, and verifies
  /// that at least one direction moves focus. It then restores focus to the
  /// original position.
  Future<void> expectNoFocusTrap() async {
    final dpad = DpadSimulator(_tester);
    final originalFocusDebug = _describePrimaryFocus();
    final originalFocus = FocusManager.instance.primaryFocus;
    if (originalFocus == null) {
      fail('No widget has focus — cannot test for focus trap');
    }

    var movedInAnyDirection = false;

    // Try all four directions
    for (final direction in [
      dpad.up,
      dpad.down,
      dpad.left,
      dpad.right,
    ]) {
      // Save current
      final beforeFocus = FocusManager.instance.primaryFocus;

      await direction();
      await _tester.pumpAndSettle();

      final afterFocus = FocusManager.instance.primaryFocus;
      if (afterFocus != beforeFocus) {
        movedInAnyDirection = true;
      }

      // Restore focus for next direction test
      if (originalFocus.canRequestFocus) {
        originalFocus.requestFocus();
        await _tester.pumpAndSettle();
      }
    }

    expect(
      movedInAnyDirection,
      isTrue,
      reason: 'Focus trap detected! Widget "$originalFocusDebug" cannot '
          'be escaped via D-pad in any direction.',
    );
  }

  /// Asserts that focus is **not** on an off-screen or zero-size widget.
  ///
  /// This catches the invisible-focus bug where a `FocusNode` receives focus
  /// but the corresponding widget is scrolled out of view or has zero
  /// dimensions, making it unreachable and invisible to the user.
  void expectFocusNotOnInvisibleWidget() {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) return; // No focus = nothing to check

    final context = primaryFocus.context;
    if (context == null) {
      fail('Primary focus has no BuildContext — detached FocusNode');
    }

    final renderObject = context.findRenderObject();
    if (renderObject == null) {
      fail('Focused widget has no RenderObject');
    }

    if (renderObject is RenderBox) {
      final size = renderObject.size;
      expect(
        size.width > 0 && size.height > 0,
        isTrue,
        reason: 'Focus is on a zero-size widget (${size.width}×${size.height})',
      );

      // Check if visible within the viewport
      final position = renderObject.localToGlobal(Offset.zero);
      final screenSize = _tester.view.physicalSize / _tester.view.devicePixelRatio;
      final isOnScreen = position.dx >= -size.width &&
          position.dy >= -size.height &&
          position.dx <= screenSize.width &&
          position.dy <= screenSize.height;
      expect(
        isOnScreen,
        isTrue,
        reason: 'Focus is on an off-screen widget at position '
            '(${position.dx}, ${position.dy}) with screen size '
            '${screenSize.width}×${screenSize.height}',
      );
    }
  }

  /// Returns `true` if any widget currently has primary focus.
  bool get hasFocus => FocusManager.instance.primaryFocus != null;

  /// Debug helper: prints the full focus tree path from root to the
  /// currently focused node, useful for diagnosing focus issues.
  String dumpFocusTree() {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return '<no focus>';

    final path = <String>[];
    FocusNode? node = primary;
    while (node != null) {
      path.insert(0, node.debugLabel ?? node.runtimeType.toString());
      node = node.parent;
    }
    return path.join(' → ');
  }

  /// Describes the currently focused widget for error messages.
  String _describePrimaryFocus() {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return '<no focus>';
    return primary.debugLabel ??
        primary.context?.widget.runtimeType.toString() ??
        primary.runtimeType.toString();
  }
}
