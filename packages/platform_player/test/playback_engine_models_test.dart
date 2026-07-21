import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  group('AiroPlaybackBufferedRange', () {
    test('equal ranges compare equal', () {
      const a = AiroPlaybackBufferedRange(
        start: Duration.zero,
        end: Duration(seconds: 10),
      );
      const b = AiroPlaybackBufferedRange(
        start: Duration.zero,
        end: Duration(seconds: 10),
      );
      expect(a, b);
    });

    test('differing end compares unequal', () {
      const a = AiroPlaybackBufferedRange(
        start: Duration.zero,
        end: Duration(seconds: 10),
      );
      const b = AiroPlaybackBufferedRange(
        start: Duration.zero,
        end: Duration(seconds: 20),
      );
      expect(a, isNot(b));
    });
  });

  group('AiroPlaybackState.bufferedRanges', () {
    test('defaults to an empty, unmodifiable list', () {
      final state = AiroPlaybackState.idle();
      expect(state.bufferedRanges, isEmpty);
      expect(
        () => state.bufferedRanges.add(
          const AiroPlaybackBufferedRange(
            start: Duration.zero,
            end: Duration.zero,
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('copyWith replaces bufferedRanges when provided', () {
      final state = AiroPlaybackState.idle();
      final updated = state.copyWith(
        bufferedRanges: const [
          AiroPlaybackBufferedRange(
            start: Duration.zero,
            end: Duration(seconds: 5),
          ),
        ],
      );

      expect(updated.bufferedRanges, hasLength(1));
      expect(updated.bufferedRanges.single.end, const Duration(seconds: 5));
    });

    test('copyWith preserves bufferedRanges when omitted', () {
      final state = AiroPlaybackState.idle().copyWith(
        bufferedRanges: const [
          AiroPlaybackBufferedRange(
            start: Duration.zero,
            end: Duration(seconds: 5),
          ),
        ],
      );
      final untouched = state.copyWith(volume: 0.5);

      expect(untouched.bufferedRanges, state.bufferedRanges);
    });

    test('participates in state equality', () {
      final withRange = AiroPlaybackState.idle().copyWith(
        bufferedRanges: const [
          AiroPlaybackBufferedRange(
            start: Duration.zero,
            end: Duration(seconds: 5),
          ),
        ],
      );
      final withoutRange = AiroPlaybackState.idle();

      expect(withRange, isNot(withoutRange));
    });
  });
}
