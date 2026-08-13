import 'package:core_analytics/core_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_media/platform_media.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'support/fake_video_player_platform.dart';

class _RecordingAnalyticsService extends AiroNoOpAnalyticsService {
  _RecordingAnalyticsService(this.events);

  final List<AiroAnalyticsEvent> events;

  @override
  Future<AiroAnalyticsTrackResult> track(AiroAnalyticsEvent event) async {
    events.add(event);
    return AiroAnalyticsTrackResult(status: AiroAnalyticsTrackStatus.accepted);
  }
}

/// AC-9 seed: automated scan that a stream URL carrying credentials, an
/// Xtream-style path, or a query-string token never survives into an
/// emitted analytics event -- run through the *real* wired path
/// (VideoPlayerStreamingService -> StreamingSessionMetricsCollector ->
/// PlatformMediaLogger.analytics), not just the isolated model.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVideoPlayerPlatform fakePlatform;
  late VideoPlayerAiroPlaybackEngine engine;
  late VideoPlayerStreamingService service;
  late List<AiroAnalyticsEvent> recordedEvents;

  setUp(() {
    fakePlatform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakePlatform;
    engine = VideoPlayerAiroPlaybackEngine();
    service = VideoPlayerStreamingService(engine: engine);
    recordedEvents = [];
    PlatformMediaLogger.setAnalyticsService(_RecordingAnalyticsService(recordedEvents));
  });

  tearDown(() async {
    await service.dispose();
    PlatformMediaLogger.setAnalyticsService(const AiroNoOpAnalyticsService());
  });

  const hostileUrls = {
    'xtream-style user/pass in path':
        'https://provider.example/live/realuser/realpass123/98765.ts',
    'userinfo credentials':
        'https://realuser:realpass123@provider.example/live.m3u8',
    'bearer-style token in query string':
        'https://provider.example/live.m3u8?token=Bearer%20abc.def.ghi',
    'api key in query string':
        'https://provider.example/hls/stream.m3u8?api_key=sk_live_12345',
  };

  for (final entry in hostileUrls.entries) {
    test(
      'a channel URL with ${entry.key} never appears in emitted telemetry',
      () async {
        await service.playChannel(
          IPTVChannel(id: 'chan-1', name: 'Test Channel', streamUrl: entry.value),
        );
        await service.stop();

        expect(recordedEvents, isNotEmpty);
        for (final event in recordedEvents) {
          for (final value in event.params.values) {
            if (value is! String) continue;
            expect(
              value,
              isNot(contains('realuser')),
              reason: '${event.name}.$value leaked the username',
            );
            expect(
              value,
              isNot(contains('realpass123')),
              reason: '${event.name}.$value leaked the password',
            );
            expect(
              value,
              isNot(contains('sk_live_12345')),
              reason: '${event.name}.$value leaked the API key',
            );
            expect(
              value,
              isNot(startsWith('http')),
              reason: '${event.name}.$value leaked a raw URL',
            );
          }
        }
      },
    );
  }

  test(
    'the active_source_id field is always the failover-assigned stable id, '
    'never the stream URL itself',
    () async {
      await service.playChannel(
        IPTVChannel(
          id: 'chan-1',
          name: 'Test Channel',
          streamUrl: 'https://user:pass@provider.example/live/1.ts',
        ),
      );
      await service.stop();

      final summary = recordedEvents.firstWhere(
        (event) => event.name == 'streaming_session_summary',
      );
      // VideoPlayerStreamingService feeds AiroFailoverSource.sourceId (a
      // stable handle like "default" or a feed id), never the raw URL --
      // this is a structural guarantee from _beginMetricsSession's caller,
      // not something the privacy filter has to catch after the fact.
      expect(summary.params['active_source_id'], 'default');
    },
  );
}
