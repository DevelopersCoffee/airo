import 'package:feature_iptv/presentation/tv_ux/iptv_resume_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Durations are pinned here rather than inherited from the widget defaults
  // so retuning the splash timing cannot silently invalidate these tests.
  const minDisplay = Duration(milliseconds: 500);
  const maxDisplay = Duration(seconds: 2);

  Widget harness({
    required bool playbackReady,
    required VoidCallback onFinished,
  }) {
    return MaterialApp(
      home: IptvResumeSplash(
        playbackReady: playbackReady,
        onFinished: onFinished,
        minDisplay: minDisplay,
        maxDisplay: maxDisplay,
      ),
    );
  }

  testWidgets('holds until minDisplay when playback is already ready', (
    tester,
  ) async {
    var finished = 0;
    await tester.pumpWidget(
      harness(playbackReady: true, onFinished: () => finished++),
    );

    await tester.pump(minDisplay - const Duration(milliseconds: 50));
    expect(finished, 0);

    await tester.pump(const Duration(milliseconds: 100));
    expect(finished, 1);
  });

  testWidgets('waits for playback readiness after minDisplay', (tester) async {
    var finished = 0;
    await tester.pumpWidget(
      harness(playbackReady: false, onFinished: () => finished++),
    );

    await tester.pump(minDisplay + const Duration(milliseconds: 50));
    expect(finished, 0);

    await tester.pumpWidget(
      harness(playbackReady: true, onFinished: () => finished++),
    );
    await tester.pump();
    expect(finished, 1);
  });

  testWidgets('finishes at maxDisplay when playback never becomes ready', (
    tester,
  ) async {
    var finished = 0;
    await tester.pumpWidget(
      harness(playbackReady: false, onFinished: () => finished++),
    );

    await tester.pump(maxDisplay + const Duration(milliseconds: 100));
    expect(finished, 1);
  });

  testWidgets('tap skips immediately', (tester) async {
    var finished = 0;
    await tester.pumpWidget(
      harness(playbackReady: false, onFinished: () => finished++),
    );

    await tester.tap(find.byType(IptvResumeSplash));
    await tester.pump();
    expect(finished, 1);
  });

  testWidgets('key event skips immediately', (tester) async {
    var finished = 0;
    await tester.pumpWidget(
      harness(playbackReady: false, onFinished: () => finished++),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(finished, 1);
  });

  testWidgets('onFinished never fires twice', (tester) async {
    var finished = 0;
    await tester.pumpWidget(
      harness(playbackReady: true, onFinished: () => finished++),
    );

    await tester.tap(find.byType(IptvResumeSplash));
    await tester.pump(const Duration(seconds: 7));
    expect(finished, 1);
  });
}
