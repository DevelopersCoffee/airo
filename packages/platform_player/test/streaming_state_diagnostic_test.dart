import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  group('StreamingState.diagnostic', () {
    const diagnostic = AiroPlaybackDiagnostic(
      code: AiroPlaybackDiagnosticCode.streamStalled,
      severity: AiroPlaybackDiagnosticSeverity.recoverable,
      retryEligible: true,
      userMessage: 'Stream stalled. Reconnecting…',
    );

    test('defaults to null and carries through copyWith', () {
      const initial = StreamingState();
      expect(initial.diagnostic, isNull);

      final withDiagnostic = initial.copyWith(diagnostic: diagnostic);
      expect(withDiagnostic.diagnostic, diagnostic);

      final carried = withDiagnostic.copyWith(volume: 0.5);
      expect(carried.diagnostic, diagnostic);
    });

    test('clearDiagnostic removes a stale diagnostic', () {
      final withDiagnostic = const StreamingState().copyWith(
        diagnostic: diagnostic,
      );

      final cleared = withDiagnostic.copyWith(clearDiagnostic: true);

      expect(cleared.diagnostic, isNull);
    });

    test('participates in equality', () {
      final a = const StreamingState().copyWith(diagnostic: diagnostic);
      final b = const StreamingState().copyWith(diagnostic: diagnostic);
      const c = StreamingState();

      expect(a, b);
      expect(a, isNot(c));
    });
  });
}
