import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  test('exposes exactly eight layout kinds', () {
    expect(MultiviewLayoutKind.values, hasLength(8));
  });

  test('tile counts stay within the four-session hard cap', () {
    for (final kind in MultiviewLayoutKind.values) {
      expect(kind.tileCount, inInclusiveRange(1, kAiroMultiviewHardCap));
    }
  });

  test(
    'defaultForCount preserves the layouts the stage used before picker UI',
    () {
      expect(
        MultiviewLayoutKind.defaultForCount(1),
        MultiviewLayoutKind.single,
      );
      expect(
        MultiviewLayoutKind.defaultForCount(2),
        MultiviewLayoutKind.splitHorizontal,
      );
      expect(
        MultiviewLayoutKind.defaultForCount(3),
        MultiviewLayoutKind.tripleBottom,
      );
      expect(MultiviewLayoutKind.defaultForCount(4), MultiviewLayoutKind.quad);
    },
  );

  test(
    'resolve keeps a preferred layout that still has room for every session',
    () {
      expect(
        resolveMultiviewLayout(
          preferred: MultiviewLayoutKind.spotlight,
          sessionCount: 2,
        ),
        MultiviewLayoutKind.spotlight,
      );
    },
  );

  test(
    'resolve falls back when the preferred layout cannot fit every session',
    () {
      expect(
        resolveMultiviewLayout(
          preferred: MultiviewLayoutKind.splitVertical,
          sessionCount: 4,
        ),
        MultiviewLayoutKind.quad,
      );
    },
  );

  test('tryParse round-trips every wire name and rejects unknowns', () {
    for (final kind in MultiviewLayoutKind.values) {
      expect(MultiviewLayoutKind.tryParse(kind.wireName), kind);
    }
    expect(MultiviewLayoutKind.tryParse(null), isNull);
    expect(MultiviewLayoutKind.tryParse('pip-asymmetric'), isNull);
  });
}
