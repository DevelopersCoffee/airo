import 'package:airo_app/core/theme/airo_domain_resolver.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('airoDomainForLocation', () {
    test('maps product routes to their visual domain', () {
      expect(airoDomainForLocation('/home'), AiroDomain.airo);
      expect(airoDomainForLocation('/money/budget'), AiroDomain.money);
      expect(airoDomainForLocation('/assistant/chat'), AiroDomain.mind);
      expect(airoDomainForLocation('/music/player'), AiroDomain.beats);
      expect(airoDomainForLocation('/iptv/guide'), AiroDomain.live);
      expect(airoDomainForLocation('/games/chess'), AiroDomain.arena);
      expect(airoDomainForLocation('/quest/lesson'), AiroDomain.quest);
      expect(airoDomainForLocation('/reader/book/1'), AiroDomain.reader);
    });

    test('ignores query parameters and uses a neutral fallback', () {
      expect(airoDomainForLocation('/music?source=home'), AiroDomain.beats);
      expect(airoDomainForLocation('/settings'), AiroDomain.neutral);
      expect(airoDomainForLocation('/unknown'), AiroDomain.neutral);
    });
  });
}
