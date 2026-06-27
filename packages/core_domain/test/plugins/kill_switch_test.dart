import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PluginKillSwitchConfig', () {
    test('parses schema and disables targeted plugin versions', () {
      final config = PluginKillSwitchConfig.fromJson({
        'version': '2026-02-09T12:00:00Z',
        'plugins': {
          'com.airo.plugin.games': {
            'enabled': false,
            'min_version': '1.0.0',
            'max_version': '1.2.3',
            'message': 'Games temporarily unavailable',
            'disabled_at': '2026-02-09T10:00:00Z',
          },
        },
      });

      expect(config.version, '2026-02-09T12:00:00Z');
      expect(
        config.isPluginEnabled('com.airo.plugin.games', pluginVersion: '1.1.0'),
        isFalse,
      );
      expect(
        config.disabledMessageFor(
          'com.airo.plugin.games',
          pluginVersion: '1.1.0',
        ),
        'Games temporarily unavailable',
      );
      expect(
        config.isPluginEnabled('com.airo.plugin.games', pluginVersion: '1.3.0'),
        isTrue,
      );
      expect(config.isPluginEnabled('com.airo.plugin.beats'), isTrue);
    });

    test('serializes round-trip JSON', () {
      final config = PluginKillSwitchConfig.fromJson({
        'version': 'v1',
        'default_enabled': false,
        'plugins': {
          'com.airo.plugin.beats': {'enabled': true},
        },
      });

      final reparsed = PluginKillSwitchConfig.fromJson(config.toJson());

      expect(reparsed.version, 'v1');
      expect(reparsed.defaultEnabled, isFalse);
      expect(reparsed.isPluginEnabled('com.airo.plugin.unknown'), isFalse);
      expect(reparsed.isPluginEnabled('com.airo.plugin.beats'), isTrue);
    });
  });

  group('compareVersions', () {
    test('compares dotted versions with suffixes', () {
      expect(compareVersions('1.2.3', '1.2.3'), 0);
      expect(compareVersions('1.2.4', '1.2.3'), greaterThan(0));
      expect(compareVersions('1.2.3-beta1', '1.2.4'), lessThan(0));
      expect(compareVersions('1.10.0', '1.2.9'), greaterThan(0));
    });
  });
}
