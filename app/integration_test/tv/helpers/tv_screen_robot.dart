// TV screen robot for integration tests – abstracts UI interactions.
// Utilizes Flutter's WidgetTester to perform D‑Pad navigation, tap,
// focus checks and screenshot capture.

library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:core_ui/core_ui.dart'; // Assuming this exports tv_focusable etc.

/// A high‑level robot that drives the Airo TV UI.
///
/// Example usage in a test:
/// ```dart
/// final robot = TvScreenRobot(tester);
/// await robot.navigateToLive();
/// await robot.selectChannel('VevoPop');
/// await robot.verifyPlayback();
/// ```
class TvScreenRobot {
  TvScreenRobot(this.tester);

  final WidgetTester tester;

  /// Press a D‑Pad key – uses the same key codes as the real remote.
  Future<void> pressKey(LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    // Allow UI to settle after the key press.
    await tester.pumpAndSettle();
  }

  /// Navigate to a top‑level route via the sidebar.
  ///
  /// `routeName` must match one of the named routes defined in `TvRouter`.
  Future<void> navigateTo(String routeName) async {
    // Open the drawer if needed – the TV UI shows a persistent sidebar,
    // but we ensure the focus is on the navigation list.
    await pressKey(LogicalKeyboardKey.arrowLeft);
    await pressKey(LogicalKeyboardKey.enter);
    // Find the navigation button by its semantic label.
    final navFinder = find.bySemanticsLabel(routeName);
    expect(navFinder, findsOneWidget, reason: 'Navigation item $routeName missing');
    await tester.tap(navFinder);
    await tester.pumpAndSettle();
  }

  /// Shortcut helpers for common routes.
  Future<void> navigateToLive() => navigateTo('Live');
  Future<void> navigateToGuide() => navigateTo('Guide');
  Future<void> navigateToVOD() => navigateTo('VOD');
  Future<void> navigateToFavorites() => navigateTo('Favorites');
  Future<void> navigateToSettings() => navigateTo('Settings');

  /// Select a channel from the live channel list by its title.
  ///
  /// The live list uses `TvFocusable` cards keyed by the channel name.
  Future<void> selectChannel(String channelName) async {
    // The list may be scrollable – we attempt to find the widget; if not
    // found we scroll down until it appears or we reach the end.
    final channelFinder = find.text(channelName);
    if (channelFinder.evaluate().isEmpty) {
      // Scroll until we find it – use a reasonable max attempt to avoid
      // infinite loops in a badly built UI.
      const maxScrollAttempts = 20;
      int attempts = 0;
      while (channelFinder.evaluate().isEmpty && attempts < maxScrollAttempts) {
        await tester.drag(find.byType(Scrollable), const Offset(0, -300));
        await tester.pumpAndSettle();
        attempts++;
      }
    }
    expect(channelFinder, findsOneWidget,
        reason: 'Channel $channelName not found after scrolling');
    await tester.tap(channelFinder);
    await tester.pumpAndSettle();
  }

  /// Verify that a video player is presenting a playing stream.
  ///
  /// Checks for the existence of the `VideoPlayer` widget and that its
  /// `controller.value.isPlaying` flag is true.
  Future<void> verifyPlayback() async {
    final playerFinder = find.byType(VideoPlayer);
    expect(playerFinder, findsOneWidget, reason: 'Video player missing');
    final playerWidget = tester.widget<VideoPlayer>(playerFinder);
    expect(playerWidget.controller.value.isPlaying, isTrue,
        reason: 'Video player is not playing');
  }

  /// Capture a screenshot of the current frame – useful for visual inspection.
  /// Returns a PNG `Uint8List`.
  Future<Uint8List> captureScreenshot(String name) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized()
        as TestWidgetsFlutterBinding;
    final image = await binding.takeScreenshot(name);
    return image;
  }
}
