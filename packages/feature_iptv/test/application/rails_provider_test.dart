import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feature_iptv/feature_iptv.dart';

/// Rails come from channel metadata only — "honest regional discovery". A
/// channel that never declared a country is not swept into a country rail just
/// to make the row look populated, and the old `top-india` rail id no longer
/// exists.
void main() {
  const attributed = IPTVChannel(
    id: 'in-1',
    name: 'India One',
    streamUrl: 'https://cdn.example.com/in-1.m3u8',
    country: 'IN',
  );
  const unattributed = IPTVChannel(
    id: 'x',
    name: 'X',
    streamUrl: 'https://cdn.example.com/x.m3u8',
  );

  ProviderContainer containerWith({
    required List<IPTVChannel> channels,
    Future<List<IPTVChannel>> Function()? favorites,
  }) {
    final container = ProviderContainer(
      overrides: [
        // Pin the region: the default reads the host locale, which is en-US
        // under `flutter test` and would never match an IN channel.
        regionalDiscoveryLocaleProvider.overrideWithValue(
          const Locale('en', 'IN'),
        ),
        iptvChannelsProvider.overrideWith((ref) async => channels),
        favoriteChannelsProvider.overrideWith(
          (ref) async =>
              favorites == null ? <IPTVChannel>[] : await favorites(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('builds a regional rail from channel country metadata', () async {
    final container = containerWith(channels: const [attributed]);

    final rails = await container.read(railsProvider.future);

    expect(rails, isNotEmpty);
    expect(rails.first.definition.id, 'regional-IN');
    expect(rails.first.channels, contains(attributed));
  });

  test('channels without country metadata get no regional rail', () async {
    final container = containerWith(channels: const [unattributed]);

    final rails = await container.read(railsProvider.future);

    expect(
      rails.where((rail) => rail.definition.id.startsWith('regional-')),
      isEmpty,
      reason:
          'inventing a country rail for unattributed channels is the fake '
          'popularity this provider exists to avoid',
    );
    expect(
      rails.expand((rail) => rail.channels),
      isNot(contains(unattributed)),
    );
  });

  test('rails still build when the favorites provider throws', () async {
    final container = containerWith(
      channels: const [attributed],
      favorites: () async => throw StateError('storage corrupt'),
    );

    final rails = await container.read(railsProvider.future);

    expect(rails, isNotEmpty);
    expect(rails.first.definition.id, 'regional-IN');
  });
}
