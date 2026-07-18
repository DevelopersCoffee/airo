import 'package:feature_iptv/presentation/widgets/playback_diagnostic_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  const stalled = AiroPlaybackDiagnostic(
    code: AiroPlaybackDiagnosticCode.streamStalled,
    severity: AiroPlaybackDiagnosticSeverity.recoverable,
    retryEligible: true,
    userMessage: 'Stream stalled. Reconnecting…',
    technicalDetail: 'code=stream_stalled stalledMs=6000 source=http://host',
  );

  const authDenied = AiroPlaybackDiagnostic(
    code: AiroPlaybackDiagnosticCode.providerAuthDenied,
    severity: AiroPlaybackDiagnosticSeverity.fatal,
    retryEligible: false,
    userMessage:
        'Your provider rejected this stream. Check your playlist credentials.',
    technicalDetail: 'code=provider_auth_denied http=401 source=http://host',
  );

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(1280, 720),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(backgroundColor: Colors.black, body: child),
      ),
    );
  }

  testWidgets('shows user-safe copy for a fatal diagnostic', (tester) async {
    await pump(tester, const PlaybackDiagnosticOverlay(diagnostic: authDenied));

    expect(
      find.textContaining('provider rejected this stream'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows reconnect progress for a retryable diagnostic', (
    tester,
  ) async {
    await pump(
      tester,
      const PlaybackDiagnosticOverlay(
        diagnostic: stalled,
        retryAttempt: 2,
        maxRetryAttempts: 3,
      ),
    );

    expect(find.textContaining('Stream stalled'), findsOneWidget);
    expect(find.textContaining('2 of 3'), findsOneWidget);
  });

  testWidgets('technical detail hidden by default, visible when enabled', (
    tester,
  ) async {
    await pump(tester, const PlaybackDiagnosticOverlay(diagnostic: stalled));
    expect(find.textContaining('stalledMs'), findsNothing);

    await pump(
      tester,
      const PlaybackDiagnosticOverlay(diagnostic: stalled, showDetail: true),
    );
    expect(find.textContaining('stalledMs'), findsOneWidget);
  });

  testWidgets('does not overflow at TV size with long copy', (tester) async {
    await pump(
      tester,
      const PlaybackDiagnosticOverlay(diagnostic: authDenied),
      size: const Size(960, 540),
    );

    expect(tester.takeException(), isNull);
  });
}
