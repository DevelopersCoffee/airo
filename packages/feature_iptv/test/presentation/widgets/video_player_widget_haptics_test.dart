import 'package:platform_haptics/platform_haptics.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecordingAikaHaptics implements AikaHaptics {
  @override
  Future<void> setStrength(AiroHapticStrength strength) async {}

  final plays = <AikaHapticIntent>[];
  var localAttached = 0;
  var localDetached = 0;

  @override
  Future<void> play(AikaHapticIntent intent) async => plays.add(intent);

  @override
  Future<void> attachCastSession({required String id}) async {}

  @override
  Future<void> detachCastSession() async {}

  @override
  Future<void> attachLocalPlayback() async => localAttached++;

  @override
  Future<void> detachLocalPlayback() async => localDetached++;
}

class _RecordingStreamingService extends VideoPlayerStreamingService {
  _RecordingStreamingService() : super(engine: FakeAiroPlaybackEngine());

  int goLiveCalls = 0;
  int toggleMuteCalls = 0;
  int setVolumeCalls = 0;

  @override
  Future<void> goLive() async {
    goLiveCalls++;
  }

  @override
  Future<void> toggleMute() async {
    toggleMuteCalls++;
  }

  @override
  Future<void> setVolume(double volume) async {
    setVolumeCalls++;
  }
}

void main() {
  const size = Size(360, 800);

  Future<void> pumpPlayer(
    WidgetTester tester, {
    required RecordingAikaHaptics haptics,
    _RecordingStreamingService? service,
    StreamingState? state,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final streamingService = service ?? _RecordingStreamingService();
    addTearDown(streamingService.dispose);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: size),
        child: ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            aikaHapticsProvider.overrideWith((ref) => haptics),
            iptvStreamingServiceProvider.overrideWithValue(streamingService),
            streamingStateProvider.overrideWith(
              (ref) => Stream.value(
                state ??
                    StreamingState(
                      playbackState: PlaybackState.playing,
                      isLiveStream: true,
                      currentChannel: const IPTVChannel(
                        id: 'news-1',
                        name: 'City News Live',
                        streamUrl: 'https://example.com/news.m3u8',
                        group: 'News',
                      ),
                    ),
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: size.width,
                height: size.height,
                child: const VideoPlayerWidget(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('player attach starts a local watching session', (tester) async {
    final haptics = RecordingAikaHaptics();
    await pumpPlayer(tester, haptics: haptics);
    expect(haptics.localAttached, 1);
    expect(haptics.localDetached, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(haptics.localDetached, 1);
  });

  testWidgets('LIVE tap plays goLive when behind live', (tester) async {
    final haptics = RecordingAikaHaptics();
    final service = _RecordingStreamingService();
    await pumpPlayer(
      tester,
      haptics: haptics,
      service: service,
      state: StreamingState(
        playbackState: PlaybackState.playing,
        isLiveStream: true,
        liveDelay: const Duration(seconds: 10),
        currentChannel: const IPTVChannel(
          id: 'news-1',
          name: 'City News Live',
          streamUrl: 'https://example.com/news.m3u8',
          group: 'News',
        ),
      ),
    );

    await tester.tap(find.text('LIVE'));
    await tester.pump();

    expect(service.goLiveCalls, 1);
    expect(haptics.plays, contains(AikaHapticIntent.goLive));
  });

  testWidgets('LIVE is not shown at the live edge so goLive stays silent', (
    tester,
  ) async {
    final haptics = RecordingAikaHaptics();
    final service = _RecordingStreamingService();
    await pumpPlayer(tester, haptics: haptics, service: service);

    expect(find.text('LIVE'), findsNothing);
    expect(service.goLiveCalls, 0);
    expect(haptics.plays, isNot(contains(AikaHapticIntent.goLive)));
  });

  testWidgets('mute tap plays muteOn', (tester) async {
    final haptics = RecordingAikaHaptics();
    final service = _RecordingStreamingService();
    await pumpPlayer(tester, haptics: haptics, service: service);

    await tester.tap(find.byKey(const ValueKey('iptv-player-mute-button')));
    await tester.pump();

    expect(service.toggleMuteCalls, 1);
    expect(haptics.plays, contains(AikaHapticIntent.muteOn));
  });

  testWidgets('volume up at max is silent', (tester) async {
    final haptics = RecordingAikaHaptics();
    final service = _RecordingStreamingService();
    await pumpPlayer(tester, haptics: haptics, service: service);

    await tester.tap(
      find.byKey(const ValueKey('iptv-player-volume-up-button')),
    );
    await tester.pump();

    expect(service.setVolumeCalls, 0);
    expect(haptics.plays, isNot(contains(AikaHapticIntent.volumeTick)));
  });

  testWidgets('volume up from mid plays volumeTick', (tester) async {
    final haptics = RecordingAikaHaptics();
    final service = _RecordingStreamingService();
    await pumpPlayer(
      tester,
      haptics: haptics,
      service: service,
      state: StreamingState(
        playbackState: PlaybackState.playing,
        isLiveStream: true,
        volume: 0.5,
        currentChannel: const IPTVChannel(
          id: 'news-1',
          name: 'City News Live',
          streamUrl: 'https://example.com/news.m3u8',
          group: 'News',
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('iptv-player-volume-up-button')),
    );
    await tester.pump();

    expect(service.setVolumeCalls, 1);
    expect(haptics.plays, contains(AikaHapticIntent.volumeTick));
  });

  testWidgets('fullscreen enter and exit both play fullscreen', (tester) async {
    final haptics = RecordingAikaHaptics();
    await pumpPlayer(tester, haptics: haptics);

    Finder fullscreenButton() {
      final compact = find.byKey(
        const ValueKey('iptv-player-fullscreen-button-compact'),
      );
      if (compact.evaluate().isNotEmpty) return compact;
      return find.byKey(const ValueKey('iptv-player-fullscreen-button'));
    }

    await tester.tap(fullscreenButton());
    await tester.pump();
    await tester.tap(fullscreenButton());
    await tester.pump();

    expect(
      haptics.plays.where((intent) => intent == AikaHapticIntent.fullscreen),
      hasLength(2),
    );
  });
}
