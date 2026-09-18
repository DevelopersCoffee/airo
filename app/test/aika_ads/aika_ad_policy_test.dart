import 'package:airo_app/aika_ads/aika_ads.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AikaAdPolicy', () {
    late DateTime now;
    late AikaAdPolicy policy;

    setUp(() {
      now = DateTime.utc(2026, 9, 13, 12);
      policy = AikaAdPolicy(clock: () => now);
    });

    AikaAdDecision decide({
      bool isWeb = false,
      bool isLeanback = false,
      bool isCasting = false,
      bool sdkReady = true,
    }) {
      return policy.decide(
        isWeb: isWeb,
        isLeanback: isLeanback,
        isCasting: isCasting,
        sdkReady: sdkReady,
      );
    }

    test('denies web, leanback, Cast, and an unready SDK', () {
      policy.startSession(now.subtract(const Duration(minutes: 10)));

      expect(decide(isWeb: true).reason, 'web');
      expect(decide(isLeanback: true).reason, 'leanback');
      expect(decide(isCasting: true).reason, 'cast');
      expect(decide(sdkReady: false).reason, 'sdk');
    });

    test('keeps the first five minutes of a session ad-free', () {
      policy.startSession(now);

      expect(decide().reason, 'warmup');

      now = now.add(const Duration(minutes: 5));
      expect(decide().allowed, isTrue);
    });

    test('enforces a 30-minute impression cooldown', () {
      policy.startSession(now.subtract(const Duration(minutes: 10)));
      expect(decide().allowed, isTrue);

      policy.recordImpression(now);
      expect(decide().reason, 'cooldown');

      now = now.add(const Duration(minutes: 29));
      expect(decide().reason, 'cooldown');

      now = now.add(const Duration(minutes: 1));
      expect(decide().allowed, isTrue);
    });
  });
}
