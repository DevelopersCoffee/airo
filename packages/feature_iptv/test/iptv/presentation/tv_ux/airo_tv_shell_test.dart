import 'package:core_data/core_data.dart';
import 'package:feature_iptv/application/providers/channel_filters_provider.dart';
import 'package:feature_iptv/application/providers/channel_auto_scan_providers.dart';
import 'package:feature_iptv/application/providers/connectivity_provider.dart';
import 'package:feature_iptv/application/providers/control_row_visibility_provider.dart';
import 'package:feature_iptv/application/providers/hotbar_channels_provider.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/application/providers/multiview_provider.dart';
import 'package:feature_iptv/application/services/wifi_settings_launcher.dart';
import 'package:feature_iptv/presentation/tv_ux/airo_tv_shell.dart';
import 'package:feature_iptv/presentation/tv_ux/sections/channel_library_grid.dart';
import 'package:feature_iptv/presentation/tv_ux/sections/channel_name_overlay.dart';
import 'package:feature_iptv/presentation/tv_ux/sections/filter_row.dart';
import 'package:feature_iptv/presentation/tv_ux/sections/hotbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'dart:convert';
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
    bool showVideoStage = true,
    bool isOnline = true,
    IPTVChannel? currentChannel,
    StreamingState? streamingState,
    Future<void> Function(Uint8List)? onShareVideoFrame,
    Future<Uint8List> Function(RenderRepaintBoundary)? videoFrameEncoder,
    VoidCallback? onWaysToWatchTap,
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
                showVideoStage: showVideoStage,
                videoStage: const SizedBox(key: ValueKey('video-stage')),
                onChannelSelected: (_) {},
                onShareVideoFrame: onShareVideoFrame,
                videoFrameEncoder: videoFrameEncoder,
                onWaysToWatchTap: onWaysToWatchTap,
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
    expect(
      find.byKey(const ValueKey('airo-tv-shell-help-action')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('airo-tv-shell-help-action')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('airo-tv-shell-help-dialog')),
      findsOneWidget,
    );
    expect(find.text('Aika Stream Help'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('airo-tv-shell-help-dialog')),
      findsNothing,
    );
  });

  testWidgets('screenshot captures the video scope without shell chrome', (
    tester,
  ) async {
    final capturedCompleter = Completer<Uint8List>();
    await pumpAt(
      tester,
      900,
      currentChannel: channels.first,
      onShareVideoFrame: (bytes) async => capturedCompleter.complete(bytes),
      videoFrameEncoder: (_) async =>
          Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
    );
    await tester.pumpAndSettle();

    final scope = find.byKey(const ValueKey('airo-tv-video-capture-scope'));
    expect(
      find.descendant(
        of: scope,
        matching: find.byKey(const ValueKey('video-stage')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: scope, matching: find.byTooltip('Share video frame')),
      findsNothing,
    );

    tester
        .widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.photo_camera_outlined),
        )
        .onPressed!
        .call();
    await tester.pump();
    final captured = await tester.runAsync(
      () => capturedCompleter.future.timeout(const Duration(seconds: 2)),
    );
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
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
      'iptv_row_filter_visible': false,
      'iptv_row_playlist_visible': false,
    });

    await pumpAt(tester, 900, currentChannel: channels.first);

    expect(find.byKey(const ValueKey('airo-tv-channel-library')), findsNothing);
    expect(find.text('FILTER'), findsNothing);
    expect(
      find.byKey(const ValueKey('airo-tv-shell-settings-action')),
      findsOneWidget,
    );
  });

  testWidgets('stats row shows exact live values and hides without a stream', (
    tester,
  ) async {
    // The stats row now defaults to hidden (#compact-tv-chrome) — opt back
    // in via the same SharedPreferences key the real settings toggle
    // writes, so this test exercises the row's content logic rather than
    // its default visibility.
    SharedPreferences.setMockInitialValues({
      channelCountryPromptCompletedStorageKey: true,
      AiroTvControlRow.stats.storageKey: true,
    });
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
    // No LIVE chrome row any more — channel identity moved onto the stage
    // as ChannelNameOverlay, and this case has no channel playing.
    expect(find.text('LIVE'), findsNothing);
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

  testWidgets('grid-first TV layout reclaims the small preview area', (
    tester,
  ) async {
    await pumpAt(tester, 1280, showVideoStage: false);

    expect(
      find.byKey(const ValueKey('airo-tv-explorer-video-stage')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('video-stage')), findsNothing);
    expect(
      find.byKey(const ValueKey('airo-tv-explorer-panel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('airo-tv-channel-library')),
      findsOneWidget,
    );
  });

  testWidgets('TV-sized layout keeps channel rows focusable', (tester) async {
    await pumpAt(tester, 1280);
    expect(find.byType(Focus), findsWidgets);
  });

  testWidgets('no multiview toggle is offered without a video stage', (
    tester,
  ) async {
    // MultiviewStage is built inside videoStage, so with the stage hidden
    // the remote's menu key confirmed "X added to multiview" against
    // something that never renders. A null callback also tells
    // ChannelLibraryGrid to drop the binding and the per-tile button.
    await pumpAt(tester, 1280, showVideoStage: false);
    expect(
      tester
          .widget<ChannelLibraryGrid>(find.byType(ChannelLibraryGrid))
          .onMultiviewToggle,
      isNull,
    );
  });

  testWidgets('channel name overlay is mounted with the current channel', (
    tester,
  ) async {
    await pumpAt(tester, 1280, currentChannel: channels.first);
    await tester.pump();

    final overlay = tester.widget<ChannelNameOverlay>(
      find.byType(ChannelNameOverlay),
    );
    expect(overlay.channel, channels.first);
    expect(overlay.dismissRequested, isFalse);
    // It lives in the stage's Stack, not in the chrome column below it.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('airo-tv-explorer-video-stage')),
        matching: find.byType(ChannelNameOverlay),
      ),
      findsOneWidget,
    );
    expect(find.text('One'), findsWidgets);
  });

  testWidgets(
    'grid-first TV layout has no ChannelNameOverlay -- no stage to overlay',
    (tester) async {
      // showVideoStage: false renders no stage at all, so ChannelNameOverlay
      // (which mounts inside the stage's Stack) correctly never appears
      // there. See the next test for what *does* host Help/Ways-to-Watch on
      // this layout.
      await pumpAt(tester, 1280, showVideoStage: false);

      expect(find.byType(ChannelNameOverlay), findsNothing);
    },
  );

  testWidgets(
    'grid-first TV layout keeps the LIVE info bar as its Help/Ways-to-Watch '
    'host',
    (tester) async {
      // Fix-up (TV player premium revamp, Task 8): the grid-first ten-foot
      // layout (showVideoStage: false) never builds a video stage, so it
      // never gets ChannelNameOverlay or the stage action row either --
      // before this task, ChannelInfoBar was this layout's *only* host for
      // Help and Ways to Watch. Restore it specifically for this case (see
      // `showInfoBar` in airo_tv_shell.dart) so those two actions stay
      // reachable for every Android TV / Fire TV user before they select a
      // channel.
      var waysToWatchTapped = false;
      await pumpAt(
        tester,
        1280,
        showVideoStage: false,
        currentChannel: channels.first,
        onWaysToWatchTap: () => waysToWatchTapped = true,
      );
      await tester.pumpAndSettle();

      // One 'LIVE' from the _ExplorerSection row label, one from the
      // ChannelInfoBar's own Chip.
      expect(find.text('LIVE'), findsNWidgets(2));

      await tester.tap(find.byKey(const ValueKey('airo-tv-shell-help-action')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('airo-tv-shell-help-dialog')),
        findsOneWidget,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('channel-info-ways-to-watch')),
      );
      await tester.pumpAndSettle();
      expect(waysToWatchTapped, isTrue);
    },
  );

  testWidgets('Explorer rows settings no longer offers a Channel toggle', (
    tester,
  ) async {
    await pumpAt(tester, 1280, currentChannel: channels.first);
    await tester.tap(
      find.byKey(const ValueKey('airo-tv-shell-settings-action')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('airo-tv-row-toggle-channel')),
      findsNothing,
    );
    expect(find.text('Channel'), findsNothing);
    expect(
      find.byKey(const ValueKey('airo-tv-row-toggle-filter')),
      findsOneWidget,
    );
  });

  testWidgets('opening the settings dialog dismisses the overlay immediately', (
    tester,
  ) async {
    await pumpAt(tester, 1280, currentChannel: channels.first);
    await tester.pump();
    expect(
      tester
          .widget<ChannelNameOverlay>(find.byType(ChannelNameOverlay))
          .dismissRequested,
      isFalse,
    );

    await tester.tap(
      find.byKey(const ValueKey('airo-tv-shell-settings-action')),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<ChannelNameOverlay>(find.byType(ChannelNameOverlay))
          .dismissRequested,
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('airo-tv-shell-settings-done')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<ChannelNameOverlay>(find.byType(ChannelNameOverlay))
          .dismissRequested,
      isFalse,
    );
  });

  testWidgets('the filter row seeds D-pad focus now the LIVE bar is gone', (
    tester,
  ) async {
    // The LIVE bar used to be the first candidate in the focus-seeding
    // chain. With it removed, the topmost focusable chrome row on a fresh
    // install (no pinned hotbar channels) is the filter chip row — cold
    // launch must not leave focus nowhere.
    await pumpAt(tester, 1280);
    await tester.pumpAndSettle();

    expect(
      tester
          .widgetList<FilterRow>(find.byType(FilterRow))
          .map((r) => r.autofocus),
      everyElement(isTrue),
    );
    expect(tester.binding.focusManager.primaryFocus?.hasPrimaryFocus, isTrue);
  });

  testWidgets(
    'the filter row still seeds D-pad focus when a hotbar channel is pinned',
    (tester) async {
      // `filterRowAutofocus` used to be gated behind `!showHotbar &&
      // showFilter` — since `Hotbar` has no autofocus seam of its own, a
      // pinned hotbar channel left D-pad focus nowhere on cold launch. That
      // used to only affect users who had explicitly hidden the LIVE/channel
      // row; with the channel row gone entirely, it became the default
      // outcome for anyone with a pinned hotbar channel. Seed the hotbar
      // storage key directly (mirrors saved_filters_provider_test.dart's
      // round-trip) so `hasHotbar` is true without going through the pin UI.
      SharedPreferences.setMockInitialValues({
        channelCountryPromptCompletedStorageKey: true,
        hotbarChannelsStorageKey: jsonEncode([
          const HotbarChannelEntry(
            channelId: 'one',
            filters: ChannelFilters(),
          ).toJson(),
        ]),
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          streamProbeTransportProvider.overrideWithValue(_FakeProbeTransport()),
          isOnlineProvider.overrideWith((ref) => Stream.value(true)),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 1280,
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
      await tester.pumpAndSettle();

      // Sanity check: the hotbar really is showing (otherwise this test
      // would pass for the wrong reason).
      expect(find.byType(Hotbar), findsOneWidget);
      expect(
        tester
            .widgetList<FilterRow>(find.byType(FilterRow))
            .map((r) => r.autofocus),
        everyElement(isTrue),
      );
      expect(tester.binding.focusManager.primaryFocus?.hasPrimaryFocus, isTrue);
    },
  );

  testWidgets('multiview toggle stays wired where the stage does render', (
    tester,
  ) async {
    await pumpAt(tester, 1280);
    expect(
      tester
          .widget<ChannelLibraryGrid>(find.byType(ChannelLibraryGrid))
          .onMultiviewToggle,
      isNotNull,
    );
  });

  testWidgets(
    'hitting multiview capacity opens the replace dialog, and picking a '
    'slot swaps that session for the new channel',
    (tester) async {
      final primary = _FakeMultiviewPrimaryService();
      final sessions = <String, _FakeMultiviewSession>{};
      final controller = MultiviewController(
        decoderBudget: 1,
        primaryService: primary,
        sessionFactory: (item) async =>
            sessions.putIfAbsent(item.id, () => _FakeMultiviewSession(item)),
      );
      addTearDown(controller.close);
      // Fill the single-stream capacity with 'one' before the shell mounts.
      await controller.toggle(channels[0]);

      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          streamProbeTransportProvider.overrideWithValue(_FakeProbeTransport()),
          isOnlineProvider.overrideWith((ref) => Stream.value(true)),
          multiviewProvider.overrideWith((ref) => controller),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 1280,
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
      await tester.pumpAndSettle();

      // Same call the grid's per-tile multiview button makes.
      tester
          .widget<ChannelLibraryGrid>(find.byType(ChannelLibraryGrid))
          .onMultiviewToggle!(channels[1]);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('airo-tv-multiview-replace-dialog')),
        findsOneWidget,
      );
      expect(find.text('Screen 1: One'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('multiview-replace-slot-one')),
      );
      await tester.pumpAndSettle();

      final ids = controller.state.sessions.map((s) => s.id).toList();
      expect(ids, ['two']);
      expect(sessions['one']!.closed, isTrue);
      expect(find.text('Two added to multiview'), findsOneWidget);
    },
  );

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

  // issues/04-recovery-states.md acceptance criterion 4, second half: a
  // real platform adapter, or omitted where unsupported.
  testWidgets(
    'offline banner Wi-Fi Settings action opens settings and reports failure',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final launcher = _FakeWifiSettingsLauncher(opened: false);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          streamProbeTransportProvider.overrideWithValue(_FakeProbeTransport()),
          isOnlineProvider.overrideWith((ref) => Stream.value(false)),
          connectivityServiceProvider.overrideWithValue(
            _FakeConnectivityService(false),
          ),
          wifiSettingsLauncherProvider.overrideWithValue(launcher),
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

      final button = find.byKey(const ValueKey('offline-banner-wifi-settings'));
      expect(button, findsOneWidget);

      await tester.tap(button);
      await tester.pump();

      expect(launcher.openCallCount, 1);
      expect(find.text("Couldn't open Wi-Fi settings"), findsOneWidget);
    },
  );

  testWidgets(
    'offline banner hides the Wi-Fi Settings action where unsupported',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          streamProbeTransportProvider.overrideWithValue(_FakeProbeTransport()),
          isOnlineProvider.overrideWith((ref) => Stream.value(false)),
          connectivityServiceProvider.overrideWithValue(
            _FakeConnectivityService(false),
          ),
          wifiSettingsLauncherProvider.overrideWithValue(
            _FakeWifiSettingsLauncher(opened: false, isSupported: false),
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

      expect(
        find.byKey(const ValueKey('offline-banner-wifi-settings')),
        findsNothing,
      );
    },
  );
}

class _FakeConnectivityService implements ConnectivityService {
  _FakeConnectivityService(this._connected);

  final bool _connected;

  @override
  Future<bool> get isConnected async => _connected;

  @override
  Stream<bool> get onConnectivityChanged => const Stream.empty();
}

class _FakeWifiSettingsLauncher extends WifiSettingsLauncher {
  _FakeWifiSettingsLauncher({required this._opened, this._isSupported = true});

  final bool _opened;
  final bool _isSupported;
  int openCallCount = 0;

  @override
  bool get isSupported => _isSupported;

  @override
  Future<bool> open() async {
    openCallCount++;
    return _opened;
  }
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

class _FakeMultiviewSession implements IptvMultiviewSession {
  _FakeMultiviewSession(this.channel);

  @override
  final IPTVChannel channel;
  bool closed = false;
  final _states = StreamController<StreamingState>.broadcast();

  @override
  String get id => channel.id;

  @override
  StreamingState get currentState => StreamingState(
    currentChannel: channel,
    playbackState: PlaybackState.playing,
  );

  @override
  Stream<StreamingState> get states => _states.stream;

  @override
  Widget buildView() => const SizedBox();

  @override
  Future<void> clearTrackSelection(AiroPlaybackTrackKind kind) async {}

  @override
  Future<void> selectTrack({
    required AiroPlaybackTrackKind kind,
    required String trackId,
  }) async {}

  @override
  Future<void> setQuality(VideoQuality quality) async {}

  @override
  Future<void> setVolume(double value) async {}

  @override
  Future<void> close() async {
    closed = true;
    await _states.close();
  }
}

class _FakeMultiviewPrimaryService implements IPTVStreamingService {
  int pauseCalls = 0;
  int resumeCalls = 0;
  StreamingState _state = StreamingState(playbackState: PlaybackState.playing);

  @override
  StreamingState get currentState => _state;

  @override
  Stream<StreamingState> get stateStream => const Stream.empty();

  @override
  Future<void> pause() async {
    pauseCalls++;
    _state = _state.copyWith(playbackState: PlaybackState.paused);
  }

  @override
  Future<void> resume() async {
    resumeCalls++;
    _state = _state.copyWith(playbackState: PlaybackState.playing);
  }

  @override
  Future<void> clearTrackSelection(AiroPlaybackTrackKind kind) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> goLive() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> playChannel(IPTVChannel channel) async {}

  @override
  Future<void> retry() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setBackgroundAudioMode(bool enabled) async {}

  @override
  Future<void> setQuality(VideoQuality quality) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> toggleMute() async {}
}
