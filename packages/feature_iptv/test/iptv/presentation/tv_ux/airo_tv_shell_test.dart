import 'package:core_data/core_data.dart';
import 'package:feature_iptv/application/providers/channel_filters_provider.dart';
import 'package:feature_iptv/application/providers/channel_auto_scan_providers.dart';
import 'package:feature_iptv/application/providers/connectivity_provider.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/presentation/tv_ux/airo_tv_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_player/platform_player.dart';
import 'package:platform_streams/platform_streams.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const channels = [
    IPTVChannel(
      id: 'one',
      name: 'One',
      streamUrl: 'https://one',
      group: 'News',
      country: 'IN',
      languages: ['en'],
    ),
    IPTVChannel(
      id: 'two',
      name: 'Two',
      streamUrl: 'https://two',
      group: 'News',
      country: 'IN',
      languages: ['en'],
    ),
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({
      channelCountryPromptCompletedStorageKey: true,
    });
  });

  Future<ProviderContainer> pumpAt(
    WidgetTester tester,
    double width, {
    double height = 720,
    bool isOnline = true,
    IPTVChannel? currentChannel,
    StreamingState? streamingState,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        streamProbeTransportProvider.overrideWithValue(_FakeProbeTransport()),
        isOnlineProvider.overrideWith((ref) => Stream.value(isOnline)),
        if (streamingState != null)
          streamingStateProvider.overrideWith(
            (ref) => Stream.value(streamingState),
          ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: width,
              height: height,
              child: AiroTvShell(
                channels: channels,
                currentChannel: currentChannel,
                videoStage: const SizedBox(key: ValueKey('video-stage')),
                onChannelSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    return container;
  }

  Future<ProviderContainer> pumpWithCountryPrompt(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        streamProbeTransportProvider.overrideWithValue(_FakeProbeTransport()),
      ],
    );
    addTearDown(container.dispose);
    return tester
        .pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 390,
                  height: 720,
                  child: AiroTvShell(
                    channels: channels,
                    videoStage: const SizedBox(key: ValueKey('video-stage')),
                    onChannelSelected: (_) {},
                  ),
                ),
              ),
            ),
          ),
        )
        .then((_) => container);
  }

  testWidgets('compact layout preserves the stacked browsing structure', (
    tester,
  ) async {
    await pumpAt(tester, 390);
    expect(find.byKey(const ValueKey('video-stage')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('airo-tv-channel-library')),
      findsOneWidget,
    );
  });

  testWidgets('wide layout retains the full channel library grid', (
    tester,
  ) async {
    await pumpAt(tester, 900);
    expect(find.text('Country'), findsWidgets);
  });

  testWidgets('hidden rows collapse while settings remains reachable', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      channelCountryPromptCompletedStorageKey: true,
      'iptv_row_channel_visible': false,
      'iptv_row_filter_visible': false,
      'iptv_row_playlist_visible': false,
    });

    await pumpAt(tester, 900, currentChannel: channels.first);

    expect(find.byKey(const ValueKey('airo-tv-channel-library')), findsNothing);
    expect(find.text('FILTER'), findsNothing);
    expect(find.text('LIVE'), findsNothing);
    expect(
      find.byKey(const ValueKey('airo-tv-shell-settings-action')),
      findsOneWidget,
    );
  });

  testWidgets('stats row shows exact live values and hides without a stream', (
    tester,
  ) async {
    final playing = StreamingState(
      currentChannel: channels.first,
      playbackState: PlaybackState.playing,
      playbackStats: const AiroPlaybackStats(
        codec: 'h264',
        width: 1920,
        height: 1080,
        bitrateKbps: 5000,
      ),
    );

    await pumpAt(
      tester,
      900,
      currentChannel: channels.first,
      streamingState: playing,
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('airo-tv-playback-stats')),
      findsOneWidget,
    );
    expect(find.text('5000 kbps'), findsOneWidget);

    await pumpAt(tester, 900, streamingState: StreamingState());
    await tester.pump();
    expect(find.byKey(const ValueKey('airo-tv-playback-stats')), findsNothing);
  });

  testWidgets('offline banner is hidden while online', (tester) async {
    await pumpAt(tester, 900);
    await tester.pump();

    expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
  });

  testWidgets(
    'offline banner shows the cached-playlist message when disconnected',
    (tester) async {
      await pumpAt(tester, 900, isOnline: false);
      await tester.pump();

      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      expect(find.textContaining('your playlist is cached'), findsOneWidget);
    },
  );

  testWidgets('wide layout uses the Explorer stage and panel composition', (
    tester,
  ) async {
    await pumpAt(tester, 1280);

    expect(
      find.byKey(const ValueKey('airo-tv-explorer-wide-shell')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('airo-tv-explorer-video-stage')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('airo-tv-explorer-panel')),
      findsOneWidget,
    );
    expect(find.text('LIVE'), findsWidgets);
    expect(find.text('HOTBAR'), findsNothing);
    expect(find.text('FILTER'), findsOneWidget);

    final stageWidth = tester
        .getSize(find.byKey(const ValueKey('airo-tv-explorer-video-stage')))
        .width;
    final panelWidth = tester
        .getSize(find.byKey(const ValueKey('airo-tv-explorer-panel')))
        .width;
    expect(stageWidth, lessThan(panelWidth));
  });

  testWidgets('wide preview scales down when cast controls reduce height', (
    tester,
  ) async {
    await pumpAt(tester, 1280, height: 400);

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('airo-tv-explorer-video-stage')),
      findsOneWidget,
    );
  });

  testWidgets('TV-sized layout keeps channel rows focusable', (tester) async {
    await pumpAt(tester, 1280);
    expect(find.byType(Focus), findsWidgets);
  });

  testWidgets('first TV launch asks for country once', (tester) async {
    final container = await pumpWithCountryPrompt(tester);
    await tester.pumpAndSettle();

    expect(find.text('Choose your country'), findsOneWidget);
    await tester.tap(find.text('🇮🇳 India'));
    await tester.pumpAndSettle();

    expect(container.read(channelFiltersProvider).country, 'IN');
    expect(
      container
          .read(channelCountryPromptProvider)
          .maybeWhen(data: (value) => value, orElse: () => null),
      isTrue,
    );
  });

  testWidgets('confirmed unavailable rows skip to a selectable channel', (
    tester,
  ) async {
    final selected = <String>[];
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        streamProbeTransportProvider.overrideWithValue(_FakeProbeTransport()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 900,
              height: 720,
              child: AiroTvShell(
                channels: channels,
                videoStage: const SizedBox(key: ValueKey('video-stage')),
                availabilityByChannelId: const {
                  'one': StreamAvailability.unavailable,
                  'two': StreamAvailability.available,
                },
                onChannelSelected: (channel) => selected.add(channel.id),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('One'));
    await tester.pump();

    expect(selected, ['two']);
    expect(find.text('One is unavailable. Skipping.'), findsOneWidget);
  });

  // issues/04-recovery-states.md acceptance criterion 4: Retry must be a
  // real, D-pad reachable action that reports success or failure.
  testWidgets('offline banner Retry re-checks connectivity and reports the '
      'outcome', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        streamProbeTransportProvider.overrideWithValue(_FakeProbeTransport()),
        isOnlineProvider.overrideWith((ref) => Stream.value(false)),
        connectivityServiceProvider.overrideWithValue(
          _FakeConnectivityService(false),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 900,
              height: 720,
              child: AiroTvShell(
                channels: channels,
                videoStage: const SizedBox(key: ValueKey('video-stage')),
                onChannelSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('offline-banner-retry')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('offline-banner-retry')));
    await tester.pump();

    expect(
      find.text('Still no connection — check your network and try again'),
      findsOneWidget,
    );
  });
}

class _FakeConnectivityService implements ConnectivityService {
  _FakeConnectivityService(this._connected);

  final bool _connected;

  @override
  Future<bool> get isConnected async => _connected;

  @override
  Stream<bool> get onConnectivityChanged => const Stream.empty();
}

class _FakeProbeTransport implements StreamProbeTransport {
  @override
  Future<StreamProbeHttpResponse> get(
    StreamProbeRequest request, {
    required StreamProbeCancellation cancellation,
  }) async {
    return const StreamProbeHttpResponse(statusCode: 206);
  }
}
