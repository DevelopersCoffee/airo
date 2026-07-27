import 'package:feature_iptv/presentation/tv_ux/sections/ways_to_watch_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpDialog(
    WidgetTester tester, {
    required bool pictureInPictureSupported,
    required bool castAvailable,
    VoidCallback? onFitScreen,
    VoidCallback? onFullScreen,
    VoidCallback? onPictureInPicture,
    VoidCallback? onCast,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WaysToWatchDialog(
            pictureInPictureSupported: pictureInPictureSupported,
            castAvailable: castAvailable,
            onFitScreen: onFitScreen ?? () {},
            onFullScreen: onFullScreen ?? () {},
            onPictureInPicture: onPictureInPicture ?? () {},
            onCast: onCast ?? () {},
          ),
        ),
      ),
    );
  }

  testWidgets('renders fit and full but hides unsupported floating window', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      pictureInPictureSupported: false,
      castAvailable: false,
    );

    expect(find.text('Fit Screen'), findsOneWidget);
    expect(find.text('Full Screen'), findsOneWidget);
    expect(find.text('Floating Window'), findsNothing);
    expect(find.text('No Cast devices available.'), findsOneWidget);
  });

  testWidgets('renders supported floating window and invokes each action', (
    tester,
  ) async {
    var fitCount = 0;
    var fullCount = 0;
    var pipCount = 0;
    var castCount = 0;
    await pumpDialog(
      tester,
      pictureInPictureSupported: true,
      castAvailable: true,
      onFitScreen: () => fitCount++,
      onFullScreen: () => fullCount++,
      onPictureInPicture: () => pipCount++,
      onCast: () => castCount++,
    );

    await tester.tap(find.byKey(const ValueKey('ways-to-watch-fit')));
    await tester.tap(find.byKey(const ValueKey('ways-to-watch-fullscreen')));
    await tester.tap(find.byKey(const ValueKey('ways-to-watch-pip')));
    await tester.tap(find.byKey(const ValueKey('ways-to-watch-cast')));

    expect((fitCount, fullCount, pipCount, castCount), (1, 1, 1, 1));
  });

  testWidgets('Cast row is disabled when no device is available', (
    tester,
  ) async {
    var castCount = 0;
    await pumpDialog(
      tester,
      pictureInPictureSupported: true,
      castAvailable: false,
      onCast: () => castCount++,
    );

    final castTile = tester.widget<ListTile>(
      find.descendant(
        of: find.byKey(const ValueKey('ways-to-watch-cast')),
        matching: find.byType(ListTile),
      ),
    );
    expect(castTile.enabled, isFalse);
    expect(castTile.onTap, isNull);
    await tester.tap(find.byKey(const ValueKey('ways-to-watch-cast')));
    expect(castCount, 0);
  });

  testWidgets('D-pad traversal reaches and activates enabled options', (
    tester,
  ) async {
    var fullCount = 0;
    await pumpDialog(
      tester,
      pictureInPictureSupported: true,
      castAvailable: true,
      onFullScreen: () => fullCount++,
    );

    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    expect(fullCount, 1);
  });
}
