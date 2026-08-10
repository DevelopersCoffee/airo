import 'package:core_analytics/core_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiroNetworkKey.derive', () {
    const salt = 'install-salt-1';

    test('wifi with a bssid hashes it, never exposing the raw value', () {
      const bssid = 'AA:BB:CC:DD:EE:FF';
      final key = AiroNetworkKey.derive(
        const AiroNetworkSnapshot(
          linkType: AiroNetworkLinkType.wifi,
          bssid: bssid,
        ),
        installSalt: salt,
      );

      expect(key, startsWith('wifi:'));
      expect(key, isNot(contains(bssid)));
      expect(key, isNot(contains('AA:BB')));
    });

    test('wifi hash is stable for the same bssid and salt', () {
      const snapshot = AiroNetworkSnapshot(
        linkType: AiroNetworkLinkType.wifi,
        bssid: 'AA:BB:CC:DD:EE:FF',
      );

      final first = AiroNetworkKey.derive(snapshot, installSalt: salt);
      final second = AiroNetworkKey.derive(snapshot, installSalt: salt);

      expect(first, second);
    });

    test('wifi hash differs across install salts (not globally correlatable)', () {
      const snapshot = AiroNetworkSnapshot(
        linkType: AiroNetworkLinkType.wifi,
        bssid: 'AA:BB:CC:DD:EE:FF',
      );

      final onInstallA = AiroNetworkKey.derive(
        snapshot,
        installSalt: 'install-a',
      );
      final onInstallB = AiroNetworkKey.derive(
        snapshot,
        installSalt: 'install-b',
      );

      expect(onInstallA, isNot(onInstallB));
    });

    test('wifi hash differs across distinct bssids', () {
      final first = AiroNetworkKey.derive(
        const AiroNetworkSnapshot(
          linkType: AiroNetworkLinkType.wifi,
          bssid: 'AA:BB:CC:DD:EE:FF',
        ),
        installSalt: salt,
      );
      final second = AiroNetworkKey.derive(
        const AiroNetworkSnapshot(
          linkType: AiroNetworkLinkType.wifi,
          bssid: '11:22:33:44:55:66',
        ),
        installSalt: salt,
      );

      expect(first, isNot(second));
    });

    test('wifi without a bssid degrades to wifi:unknown', () {
      final key = AiroNetworkKey.derive(
        const AiroNetworkSnapshot(linkType: AiroNetworkLinkType.wifi),
        installSalt: salt,
      );

      expect(key, 'wifi:unknown');
    });

    test('wifi with a blank bssid degrades to wifi:unknown', () {
      final key = AiroNetworkKey.derive(
        const AiroNetworkSnapshot(
          linkType: AiroNetworkLinkType.wifi,
          bssid: '   ',
        ),
        installSalt: salt,
      );

      expect(key, 'wifi:unknown');
    });

    test('cellular formats as cell:<carrier>:<radio-tech>', () {
      final key = AiroNetworkKey.derive(
        const AiroNetworkSnapshot(
          linkType: AiroNetworkLinkType.cellular,
          carrier: 'jio',
          radioTechnology: '5g',
        ),
        installSalt: salt,
      );

      expect(key, 'cell:jio:5g');
    });

    test('cellular with missing carrier/tech falls back to unknown segments', () {
      final key = AiroNetworkKey.derive(
        const AiroNetworkSnapshot(linkType: AiroNetworkLinkType.cellular),
        installSalt: salt,
      );

      expect(key, 'cell:unknown:unknown');
    });

    test('ethernet formats as a bare literal', () {
      final key = AiroNetworkKey.derive(
        const AiroNetworkSnapshot(linkType: AiroNetworkLinkType.ethernet),
        installSalt: salt,
      );

      expect(key, 'ethernet');
    });

    test('offline formats as a bare literal', () {
      final key = AiroNetworkKey.derive(
        const AiroNetworkSnapshot(linkType: AiroNetworkLinkType.offline),
        installSalt: salt,
      );

      expect(key, 'offline');
    });

    test('unknown link type degrades to wifi:unknown rather than throwing', () {
      final key = AiroNetworkKey.derive(
        const AiroNetworkSnapshot(linkType: AiroNetworkLinkType.unknown),
        installSalt: salt,
      );

      expect(key, 'wifi:unknown');
    });
  });

  group('AiroNetworkSnapshot', () {
    test('is Equatable by value', () {
      const a = AiroNetworkSnapshot(
        linkType: AiroNetworkLinkType.wifi,
        bssid: 'AA:BB:CC:DD:EE:FF',
      );
      const b = AiroNetworkSnapshot(
        linkType: AiroNetworkLinkType.wifi,
        bssid: 'AA:BB:CC:DD:EE:FF',
      );

      expect(a, b);
    });
  });
}
