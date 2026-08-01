import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const channel = IPTVChannel(
    id: 'channel-1',
    name: 'Test channel',
    streamUrl: 'https://example.com/live.m3u8',
    qualityUrls: {'high': 'https://example.com/live-720.m3u8'},
  );
  const tracks = [
    AiroPlaybackTrackOption(
      id: 'audio-en',
      kind: AiroPlaybackTrackKind.audio,
      label: 'English audio',
    ),
    AiroPlaybackTrackOption(
      id: 'audio-fr',
      kind: AiroPlaybackTrackKind.audio,
      label: 'French audio',
    ),
    AiroPlaybackTrackOption(
      id: 'sub-en',
      kind: AiroPlaybackTrackKind.subtitle,
      label: 'English subtitles',
    ),
    AiroPlaybackTrackOption(
      id: 'sub-fr',
      kind: AiroPlaybackTrackKind.subtitle,
      label: 'French subtitles',
    ),
  ];

  Future<_RecordingStreamingService> pumpPlayer(
    WidgetTester tester, {
    Map<AiroPlaybackTrackKind, String> selectedTrackIds = const {},
    Future<void> Function(bool enabled)? setAudioOnlyMode,
    Future<bool> Function()? requestPictureInPicture,
    VoidCallback? onFullscreenToggle,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = _RecordingStreamingService();
    addTearDown(service.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvStreamingServiceProvider.overrideWithValue(service),
          streamingStateProvider.overrideWith(
            (ref) => Stream.value(
              StreamingState(
                playbackState: PlaybackState.playing,
                isLiveStream: true,
                currentChannel: channel,
                currentQuality: VideoQuality.high,
                selectedQuality: VideoQuality.high,
                tracks: tracks,
                selectedTrackIds: selectedTrackIds,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 960,
              height: 540,
              child: VideoPlayerWidget(
                initiallyFullscreen: true,
                enableTouchGestures: false,
                useTvTransportBar: true,
                onFullscreenToggle: onFullscreenToggle,
                setAudioOnlyMode: setAudioOnlyMode,
                requestPictureInPicture: requestPictureInPicture,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return service;
  }

  // Resolve the TvFocusable's own Focus rather than calling Focus.of() from
  // inside its child: TvFocusable wraps the child in ExcludeFocus so Material
  // descendants cannot become a second invisible D-pad stop, which means
  // Focus.of(childContext) now answers with that exclusion node.
  Focus tvFocusOf(WidgetTester tester, String key) {
    final wrapper = find.ancestor(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(TvFocusable),
    );
    return tester.widget<Focus>(
      find.descendant(of: wrapper, matching: find.byType(Focus)).first,
    );
  }

  bool ownsPrimaryFocus(WidgetTester tester, String key) {
    return tvFocusOf(tester, key).focusNode?.hasPrimaryFocus ?? false;
  }

  void requestTvFocusable(WidgetTester tester, Finder wrapper) {
    final focus = tester.widget<Focus>(
      find.descendant(of: wrapper, matching: find.byType(Focus)).first,
    );
    focus.focusNode!.requestFocus();
  }

  Future<void> openPlayerActions(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.pumpAndSettle();
    expect(find.text('Player actions'), findsOneWidget);
  }

  testWidgets(
    'player actions traps logical D-pad traversal and restores player focus',
    (tester) async {
      await pumpPlayer(tester);
      await openPlayerActions(tester);

      const orderedKeys = [
        'iptv-player-pip-menu-action',
        'iptv-player-quality-menu-action',
        'iptv-player-subtitle-menu-action',
        'iptv-player-audio-only-menu-action',
        'iptv-player-aspect-ratio-menu-action',
        'iptv-player-cinema-menu-action',
        'iptv-player-fullscreen-menu-action',
      ];
      expect(ownsPrimaryFocus(tester, orderedKeys[3]), isTrue);

      for (var index = 2; index >= 0; index--) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(
          ownsPrimaryFocus(tester, orderedKeys[index]),
          isTrue,
          reason: 'UP must focus ${orderedKeys[index]} exactly once',
        );
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(
        ownsPrimaryFocus(tester, orderedKeys.first),
        isTrue,
        reason: 'UP at the first action must remain trapped in the modal',
      );
      for (var index = 1; index < orderedKeys.length; index++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(
          ownsPrimaryFocus(tester, orderedKeys[index]),
          isTrue,
          reason: 'DOWN must focus ${orderedKeys[index]} exactly once',
        );
        expect(find.text('Mini guide'), findsNothing);
        expect(find.text('Recent channels'), findsNothing);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        ownsPrimaryFocus(tester, orderedKeys.last),
        isTrue,
        reason: 'DOWN at the last action must remain trapped in the modal',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Player actions'), findsNothing);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'player center control',
      );
    },
  );

  testWidgets(
    'subtitle and quality selectors autofocus, traverse, apply, and restore',
    (tester) async {
      final service = await pumpPlayer(
        tester,
        selectedTrackIds: const {AiroPlaybackTrackKind.subtitle: 'sub-fr'},
      );
      await openPlayerActions(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'player action Subtitles',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'player subtitle option French subtitles',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Subtitles'), findsWidgets);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'player action Subtitles',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'player subtitle option English subtitles',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(service.selectedTracks, [
        (kind: AiroPlaybackTrackKind.subtitle, trackId: 'sub-en'),
      ]);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'player action Subtitles',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'player action Quality',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'player quality option 720p',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'player action Quality',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'player quality option Auto',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(service.qualities, [VideoQuality.auto]);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'player action Quality',
      );
    },
  );

  testWidgets(
    'Off and audio-track rows use visible focus and CENTER applies once',
    (tester) async {
      final service = await pumpPlayer(tester);
      await openPlayerActions(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'player subtitle option Off',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(service.clearedTrackKinds, [AiroPlaybackTrackKind.subtitle]);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'player action Subtitles',
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      final audioButton = find.byKey(const ValueKey('iptv-tv-transport-audio'));
      requestTvFocusable(tester, audioButton);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'player audio option English audio',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'player audio option French audio',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'player audio track',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(service.selectedTracks.last, (
        kind: AiroPlaybackTrackKind.audio,
        trackId: 'audio-fr',
      ));
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'player audio track',
      );
    },
  );

  testWidgets('every direct player-action row activates exactly once', (
    tester,
  ) async {
    var pipRequests = 0;
    var audioOnlyRequests = 0;
    var fullscreenToggles = 0;
    await pumpPlayer(
      tester,
      onFullscreenToggle: () => fullscreenToggles++,
      requestPictureInPicture: () async {
        pipRequests++;
        return true;
      },
      setAudioOnlyMode: (enabled) async => audioOnlyRequests++,
    );

    Future<void> activate(String key) async {
      await openPlayerActions(tester);
      final action = find.byKey(ValueKey(key));
      if (action.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          action,
          120,
          scrollable: find.byType(Scrollable).last,
        );
      }
      tvFocusOf(tester, key).focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
    }

    await activate('iptv-player-pip-menu-action');
    expect(pipRequests, 1);

    await activate('iptv-player-audio-only-menu-action');
    expect(audioOnlyRequests, 1);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(VideoPlayerWidget)),
    );
    final aspectBefore = container.read(videoAspectRatioProvider);
    await activate('iptv-player-aspect-ratio-menu-action');
    expect(container.read(videoAspectRatioProvider), isNot(aspectBefore));

    await activate('iptv-player-cinema-menu-action');
    await openPlayerActions(tester);
    final standardMode = find.text('Standard mode');
    await tester.scrollUntilVisible(
      standardMode,
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(standardMode, findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await activate('iptv-player-fullscreen-menu-action');
    expect(fullscreenToggles, 1);
  });
}

class _RecordingStreamingService extends VideoPlayerStreamingService {
  _RecordingStreamingService() : super(engine: FakeAiroPlaybackEngine());

  final List<({AiroPlaybackTrackKind kind, String trackId})> selectedTracks =
      [];
  final List<AiroPlaybackTrackKind> clearedTrackKinds = [];
  final List<VideoQuality> qualities = [];

  @override
  Future<void> selectTrack({
    required AiroPlaybackTrackKind kind,
    required String trackId,
  }) async {
    selectedTracks.add((kind: kind, trackId: trackId));
  }

  @override
  Future<void> clearTrackSelection(AiroPlaybackTrackKind kind) async {
    clearedTrackKinds.add(kind);
  }

  @override
  Future<void> setQuality(VideoQuality quality) async {
    qualities.add(quality);
  }
}
