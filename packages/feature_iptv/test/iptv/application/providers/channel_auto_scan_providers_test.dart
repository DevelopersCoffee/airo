import 'package:feature_iptv/application/providers/channel_auto_scan_providers.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_streams/platform_streams.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'auto scan provider hides unavailable channels only in its active scope',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final transport = _FakeProbeTransport();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith((ref) async => _channels),
          streamProbeTransportProvider.overrideWithValue(transport),
        ],
      );
      addTearDown(container.dispose);

      await container.read(iptvChannelsProvider.future);
      final scopeId = container.read(channelAutoScanScopeProvider);
      await container
          .read(channelAutoScanProvider.notifier)
          .start(
            scopeId: scopeId,
            channels: container.read(filteredChannelsProvider),
            maxConcurrentRequests: 2,
          );
      container.read(channelAutoScanProvider.notifier).removeUnavailable();

      expect(
        container
            .read(autoScanFilteredChannelsProvider)
            .map((channel) => channel.id),
        ['available', 'restricted'],
      );
    },
  );

  test(
    'selectable channel providers skip confirmed unavailable channels',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final transport = _FakeProbeTransport();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith((ref) async => _channels),
          streamProbeTransportProvider.overrideWithValue(transport),
          currentChannelProvider.overrideWithValue(_channels.first),
        ],
      );
      addTearDown(container.dispose);

      await container.read(iptvChannelsProvider.future);
      await container
          .read(channelAutoScanProvider.notifier)
          .start(
            scopeId: 'visible',
            channels: _channels,
            maxConcurrentRequests: 2,
          );

      expect(container.read(nextSelectableChannelProvider)?.id, 'restricted');
      expect(
        container.read(previousSelectableChannelProvider)?.id,
        'restricted',
      );
    },
  );
}

const _channels = [
  IPTVChannel(
    id: 'available',
    name: 'Available',
    streamUrl: 'https://streams.example/available.m3u8',
  ),
  IPTVChannel(
    id: 'unavailable',
    name: 'Unavailable',
    streamUrl: 'https://streams.example/unavailable.m3u8',
  ),
  IPTVChannel(
    id: 'restricted',
    name: 'Restricted',
    streamUrl: 'https://streams.example/restricted.m3u8',
  ),
];

class _FakeProbeTransport implements StreamProbeTransport {
  @override
  Future<StreamProbeHttpResponse> get(
    StreamProbeRequest request, {
    required StreamProbeCancellation cancellation,
  }) async {
    return switch (request.channelId) {
      'available' => const StreamProbeHttpResponse(statusCode: 206),
      'unavailable' => const StreamProbeHttpResponse(statusCode: 404),
      _ => const StreamProbeHttpResponse(statusCode: 451),
    };
  }
}
