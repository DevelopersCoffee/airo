import 'package:feature_iptv/domain/channel_region_availability.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';

IPTVChannel channel(
  String id, {
  String? country,
  ChannelSourceHealth health = ChannelSourceHealth.available,
}) => IPTVChannel(
  id: id,
  name: id,
  streamUrl: 'https://example.test/$id.m3u8',
  country: country,
  streamSources: [
    ChannelStreamSource(url: 'https://example.test/$id.m3u8', health: health),
  ],
);

void main() {
  test(
    'matching/global channels are available and conflict is likely blocked',
    () {
      expect(
        classifyChannelRegion(channel('india', country: 'IN'), 'IN'),
        ChannelRegionAvailability.available,
      );
      expect(
        classifyChannelRegion(channel('global', country: 'WW'), 'IN'),
        ChannelRegionAvailability.available,
      );
      expect(
        classifyChannelRegion(channel('us', country: 'US'), 'IN'),
        ChannelRegionAvailability.likelyBlocked,
      );
    },
  );

  test('explicit restricted source is blocked even when country matches', () {
    expect(
      classifyChannelRegion(
        channel(
          'restricted',
          country: 'IN',
          health: ChannelSourceHealth.restricted,
        ),
        'IN',
      ),
      ChannelRegionAvailability.likelyBlocked,
    );
  });

  test('sort is stable and default selection skips likely blocked', () {
    final blocked = channel('blocked', country: 'US');
    final first = channel('first', country: 'IN');
    final second = channel('second');

    final sorted = sortChannelsForRegion([blocked, first, second], 'IN');

    expect(sorted.map((item) => item.id), ['first', 'second', 'blocked']);
    expect(firstRegionAvailableChannel([blocked, first], 'IN'), same(first));
  });
}
