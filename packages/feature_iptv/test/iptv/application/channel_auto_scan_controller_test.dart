import 'package:feature_iptv/application/channel_auto_scan_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_streams/platform_streams.dart';

void main() {
  test(
    'removes only unavailable channels from the completed scan scope',
    () async {
      final transport = _FakeProbeTransport({
        'available': const StreamProbeHttpResponse(statusCode: 206),
        'unavailable': const StreamProbeHttpResponse(statusCode: 404),
        'restricted': const StreamProbeHttpResponse(statusCode: 451),
      });
      final controller = ChannelAutoScanController(
        probe: StreamAvailabilityProbe(transport: transport),
      );
      addTearDown(controller.dispose);
      final channels = [
        _channel('available'),
        _channel('unavailable'),
        _channel('restricted'),
      ];

      await controller.start(
        scopeId: 'news',
        channels: channels,
        maxConcurrentRequests: 3,
      );
      controller.removeUnavailable();

      expect(controller.state.unavailableCount, 1);
      expect(
        controller
            .channelsForScope(scopeId: 'news', channels: channels)
            .map((channel) => channel.id),
        ['available', 'restricted'],
      );

      controller.restore();

      expect(
        controller
            .channelsForScope(scopeId: 'news', channels: channels)
            .map((channel) => channel.id),
        ['available', 'unavailable', 'restricted'],
      );
    },
  );

  test(
    'uses the active player as an available result without probing it',
    () async {
      final transport = _FakeProbeTransport({
        'other': const StreamProbeHttpResponse(statusCode: 200),
      });
      final controller = ChannelAutoScanController(
        probe: StreamAvailabilityProbe(transport: transport),
      );
      addTearDown(controller.dispose);
      final channels = [_channel('playing'), _channel('other')];

      await controller.start(
        scopeId: 'all',
        channels: channels,
        currentPlayingChannelId: 'playing',
        maxConcurrentRequests: 1,
      );

      expect(controller.state.completedCount, 2);
      expect(
        controller.state.availabilityByChannelId['playing'],
        StreamAvailability.available,
      );
      expect(transport.requestedChannelIds, ['other']);
    },
  );

  test('keeps removal scoped to the filter that was scanned', () async {
    final controller = ChannelAutoScanController(
      probe: StreamAvailabilityProbe(
        transport: _FakeProbeTransport({
          'news': const StreamProbeHttpResponse(statusCode: 404),
        }),
      ),
    );
    addTearDown(controller.dispose);
    final channels = [_channel('news')];

    await controller.start(
      scopeId: 'news-filter',
      channels: channels,
      maxConcurrentRequests: 1,
    );
    controller.removeUnavailable();

    expect(
      controller.channelsForScope(scopeId: 'sports-filter', channels: channels),
      channels,
    );
  });
}

IPTVChannel _channel(String id) {
  return IPTVChannel(
    id: id,
    name: id,
    streamUrl: 'https://streams.example/$id.m3u8',
  );
}

class _FakeProbeTransport implements StreamProbeTransport {
  _FakeProbeTransport(this.responses);

  final Map<String, StreamProbeHttpResponse> responses;
  final List<String> requestedChannelIds = [];

  @override
  Future<StreamProbeHttpResponse> get(
    StreamProbeRequest request, {
    required StreamProbeCancellation cancellation,
  }) async {
    requestedChannelIds.add(request.channelId);
    return responses[request.channelId]!;
  }
}
