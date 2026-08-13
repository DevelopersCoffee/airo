import 'package:core_analytics/core_analytics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_media/platform_media.dart';
import 'package:platform_player/platform_player.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVideoPlayerPlatform fakePlatform;
  late VideoPlayerAiroPlaybackEngine engine;
  late VideoPlayerStreamingService service;
  late List<AiroAnalyticsEvent> recordedEvents;

  IPTVChannel channel({String streamUrl = 'https://example.com/live.m3u8'}) {
    return IPTVChannel(id: 'chan-1', name: 'Test Channel', streamUrl: streamUrl);
  }

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

  group('VideoPlayerStreamingService streaming QoE telemetry (F7.1)', () {
    test('a successful playChannel emits a started event then a summary event on stop', () async {
      await service.playChannel(channel());
      await service.stop();

      final names = recordedEvents.map((event) => event.name).toList();
      expect(names, ['streaming_session_started', 'streaming_session_summary']);
    });

    test('the summary event carries the playback_quality purpose', () async {
      await service.playChannel(channel());
      await service.stop();

      final summary = recordedEvents.firstWhere(
        (event) => event.name == 'streaming_session_summary',
      );
      expect(summary.purpose, AiroAnalyticsPurpose.playbackQuality);
    });

    test('the summary event never carries a raw stream URL or credentials', () async {
      await service.playChannel(
        channel(
          streamUrl: 'https://user:secretpass@provider.example/live/1.ts',
        ),
      );
      await service.stop();

      final summary = recordedEvents.firstWhere(
        (event) => event.name == 'streaming_session_summary',
      );
      for (final value in summary.params.values) {
        if (value is! String) continue;
        expect(value, isNot(contains('secretpass')));
        expect(value, isNot(startsWith('https://')));
        expect(value, isNot(startsWith('http://')));
      }
    });

    test('the summary event validates cleanly against the shared privacy filter', () async {
      await service.playChannel(channel());
      await service.stop();

      final summary = recordedEvents.firstWhere(
        (event) => event.name == 'streaming_session_summary',
      );
      final result = validateEvent(
        summary,
        consent: const AiroAnalyticsConsentState.allEnabled(),
      );
      expect(result.status, AiroAnalyticsTrackStatus.accepted);
    });

    test('stopping without ever playing emits nothing', () async {
      await service.stop();

      expect(recordedEvents, isEmpty);
    });

    test('a second playChannel finalizes the prior session before starting a new one', () async {
      await service.playChannel(channel());
      recordedEvents.clear();

      await service.playChannel(channel(streamUrl: 'https://example.com/other.m3u8'));

      final names = recordedEvents.map((event) => event.name).toList();
      expect(names, [
        'streaming_session_summary', // prior session finalized
        'streaming_session_started', // new session begins
      ]);
    });

    test('dispose finalizes an in-progress session', () async {
      await service.playChannel(channel());
      recordedEvents.clear();

      await service.dispose();

      expect(
        recordedEvents.map((event) => event.name),
        contains('streaming_session_summary'),
      );
    });

    test(
      'a decoder failure that never reaches playing does not crash telemetry '
      'and reports a null ttff when the session is later finalized',
      () async {
        fakePlatform.scriptedInitError = PlatformException(
          code: 'VideoError',
          message: 'decoder rejected format',
        );

        await service.playChannel(channel());
        expect(service.currentState.playbackState, PlaybackState.error);

        // The session started when the loop first attempted a source but
        // was never handed a first frame; it's only finalized -- and only
        // then does the summary reach PlatformMediaLogger -- once something ends it.
        recordedEvents.clear();
        await service.stop();

        final summary = recordedEvents.firstWhere(
          (event) => event.name == 'streaming_session_summary',
        );
        expect(summary.params['ttff_ms'], isNull);
      },
    );
  });
}
