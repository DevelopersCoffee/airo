/// D-pad key event injection simulator for TV integration tests.
///
/// Wraps Flutter's `simulateKeyDownEvent` / `simulateKeyUpEvent` with
/// TV-specific convenience methods that match the physical Sony BRAVIA 2
/// remote control layout. All methods include settle delays matching real
/// remote control cadence (~200 ms between presses).
///
/// Usage:
/// ```dart
/// final dpad = DpadSimulator(tester);
/// await dpad.down();      // D-pad Down
/// await dpad.select();    // OK / Enter
/// await dpad.back();      // Back button
/// await dpad.repeat(LogicalKeyboardKey.arrowDown, count: 5); // Rapid presses
/// ```
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Default settle duration between key presses, matching real remote cadence.
const Duration _kDefaultSettleDuration = Duration(milliseconds: 200);

/// Simulates D-pad / TV remote key events for integration testing.
///
/// Designed for the Sony BRAVIA 2 / Google TV remote layout:
/// - Directional pad (Up, Down, Left, Right)
/// - Select / OK button (center of D-pad)
/// - Back button
/// - Home button
/// - Media transport keys (Play/Pause, Fast Forward, Rewind, Stop)
/// - Channel Up / Down
/// - Numeric keys (0-9)
/// - Voice search / Assistant
class DpadSimulator {
  DpadSimulator(this._tester, {Duration? settleDuration})
      : _settleDuration = settleDuration ?? _kDefaultSettleDuration;

  final WidgetTester _tester;
  final Duration _settleDuration;

  // ── Directional Navigation ──

  /// Simulate D-pad Up press.
  Future<void> up() => _pressKey(LogicalKeyboardKey.arrowUp);

  /// Simulate D-pad Down press.
  Future<void> down() => _pressKey(LogicalKeyboardKey.arrowDown);

  /// Simulate D-pad Left press.
  Future<void> left() => _pressKey(LogicalKeyboardKey.arrowLeft);

  /// Simulate D-pad Right press.
  Future<void> right() => _pressKey(LogicalKeyboardKey.arrowRight);

  // ── Action Keys ──

  /// Simulate Select / OK / Enter press (center of D-pad).
  Future<void> select() => _pressKey(LogicalKeyboardKey.select);

  /// Simulate Enter key press (alternative to Select).
  Future<void> enter() => _pressKey(LogicalKeyboardKey.enter);

  /// Simulate Back button press.
  Future<void> back() => _pressKey(LogicalKeyboardKey.goBack);

  /// Simulate Escape key (alternative to Back).
  Future<void> escape() => _pressKey(LogicalKeyboardKey.escape);

  /// Simulate Home button press.
  Future<void> home() => _pressKey(LogicalKeyboardKey.browserHome);

  // ── Media Transport Keys ──

  /// Simulate Play/Pause toggle.
  Future<void> playPause() => _pressKey(LogicalKeyboardKey.mediaPlayPause);

  /// Simulate Stop.
  Future<void> stop() => _pressKey(LogicalKeyboardKey.mediaStop);

  /// Simulate Fast Forward.
  Future<void> fastForward() => _pressKey(LogicalKeyboardKey.mediaFastForward);

  /// Simulate Rewind.
  Future<void> rewind() => _pressKey(LogicalKeyboardKey.mediaRewind);

  // ── Channel Keys ──

  /// Simulate Channel Up.
  Future<void> channelUp() => _pressKey(LogicalKeyboardKey.channelUp);

  /// Simulate Channel Down.
  Future<void> channelDown() => _pressKey(LogicalKeyboardKey.channelDown);

  // ── Numeric Keys ──

  /// Simulate a numeric key press (0-9) for channel number entry.
  Future<void> numericKey(int digit) {
    assert(digit >= 0 && digit <= 9, 'Digit must be 0-9');
    final key = switch (digit) {
      0 => LogicalKeyboardKey.digit0,
      1 => LogicalKeyboardKey.digit1,
      2 => LogicalKeyboardKey.digit2,
      3 => LogicalKeyboardKey.digit3,
      4 => LogicalKeyboardKey.digit4,
      5 => LogicalKeyboardKey.digit5,
      6 => LogicalKeyboardKey.digit6,
      7 => LogicalKeyboardKey.digit7,
      8 => LogicalKeyboardKey.digit8,
      9 => LogicalKeyboardKey.digit9,
      _ => throw StateError('unreachable'),
    };
    return _pressKey(key);
  }

  // ── Special Keys ──

  /// Simulate Voice Search / Assistant button.
  Future<void> voiceSearch() => _pressKey(LogicalKeyboardKey.browserSearch);

  /// Simulate Context Menu / Options key.
  Future<void> menu() => _pressKey(LogicalKeyboardKey.contextMenu);

  // ── Batch Operations ──

  /// Simulate [count] rapid sequential presses of [key] with [interval]
  /// between each press. Useful for stress-testing rapid D-pad navigation.
  ///
  /// Example:
  /// ```dart
  /// // Press Down 10 times rapidly (50ms apart)
  /// await dpad.repeat(LogicalKeyboardKey.arrowDown,
  ///     count: 10, interval: Duration(milliseconds: 50));
  /// ```
  Future<void> repeat(
    LogicalKeyboardKey key, {
    int count = 1,
    Duration? interval,
  }) async {
    final gap = interval ?? const Duration(milliseconds: 50);
    for (var i = 0; i < count; i++) {
      await simulateKeyDownEvent(key);
      await simulateKeyUpEvent(key);
      await _tester.pump(gap);
    }
    await _tester.pumpAndSettle();
  }

  /// Navigate down [count] times with standard settle between presses.
  Future<void> downBy(int count) async {
    for (var i = 0; i < count; i++) {
      await down();
    }
  }

  /// Navigate right [count] times with standard settle between presses.
  Future<void> rightBy(int count) async {
    for (var i = 0; i < count; i++) {
      await right();
    }
  }

  /// Navigate up [count] times with standard settle between presses.
  Future<void> upBy(int count) async {
    for (var i = 0; i < count; i++) {
      await up();
    }
  }

  /// Navigate left [count] times with standard settle between presses.
  Future<void> leftBy(int count) async {
    for (var i = 0; i < count; i++) {
      await left();
    }
  }

  /// Enter a channel number by pressing numeric keys sequentially.
  /// Example: `await dpad.enterChannelNumber(123);`
  Future<void> enterChannelNumber(int channelNumber) async {
    final digits = channelNumber.toString().split('');
    for (final digit in digits) {
      await numericKey(int.parse(digit));
    }
  }

  // ── Internal ──

  Future<void> _pressKey(LogicalKeyboardKey key) async {
    await simulateKeyDownEvent(key);
    await simulateKeyUpEvent(key);
    await _tester.pump(_settleDuration);
  }
}
