import 'package:airo_app/core/app/tv_shell.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Televisions with overscan enabled crop roughly the outer 5% of the panel.
///
/// Measured on the rig Fire TV Stick at 1920x1080 before the inset existed
/// (#1429): the sidebar's leftmost pixel sat at x=32 against a 96px safe inset,
/// and the cast/favourite actions sat inside the right band. On a cropping TV
/// that removes the only way to navigate the app.
void main() {
  group('title-safe geometry', () {
    test('reserves 5% of every edge at 1080p', () {
      final insets = tvTitleSafeInsets(const Size(1920, 1080));

      expect(insets.left, 96);
      expect(insets.right, 96);
      expect(insets.top, 54);
      expect(insets.bottom, 54);
    });

    test('scales with the viewport rather than assuming 1080p', () {
      final insets = tvTitleSafeInsets(const Size(3840, 2160));

      expect(insets.left, 192);
      expect(insets.top, 108);
    });

    test('keeps the measured sidebar edge inside the safe band', () {
      // The rail is 88pt wide and its logo began at x=32 of the raw panel.
      // Once the shell is inset, the same rail starts at the inset instead,
      // so its content can no longer land in the cropped band.
      final insets = tvTitleSafeInsets(const Size(1920, 1080));
      const measuredLeftmostContentBeforeFix = 32.0;

      expect(
        measuredLeftmostContentBeforeFix,
        lessThan(insets.left),
        reason: 'this is the regression the inset exists to prevent',
      );
      expect(
        insets.left,
        greaterThanOrEqualTo(measuredLeftmostContentBeforeFix),
        reason: 'the inset has to be at least as wide as the observed overhang',
      );
    });
  });

  group('shell applies the inset', () {
    Future<void> pumpShell(
      WidgetTester tester, {
      required bool fullscreen,
    }) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isFullscreenModeProvider.overrideWith((ref) => fullscreen),
          ],
          child: const MaterialApp(home: TvShell(child: SizedBox.shrink())),
        ),
      );
      await tester.pump();
    }

    testWidgets('chrome is inset when the player is not fullscreen', (
      tester,
    ) async {
      await pumpShell(tester, fullscreen: false);

      final padding = tester.widget<Padding>(
        find.byKey(const Key('tv-title-safe-inset')),
      );

      expect(
        padding.padding,
        const EdgeInsets.symmetric(horizontal: 96, vertical: 54),
        reason: 'the rail must start inside the croppable band',
      );
    });

    testWidgets('fullscreen playback is not inset', (tester) async {
      await pumpShell(tester, fullscreen: true);

      expect(
        find.byKey(const Key('tv-title-safe-inset')),
        findsNothing,
        reason:
            'video should fill the panel; losing picture to overscan is normal, '
            'losing navigation is not',
      );
    });
  });
}
