import 'dart:async';

import 'package:feature_iptv/application/providers/multiview_provider.dart';
import 'package:feature_iptv/presentation/tv_ux/sections/multiview_stage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  _FakeSession session(String id) => _FakeSession(
    IPTVChannel(
      id: id,
      name: 'Channel $id',
      streamUrl: 'https://example.com/$id',
      group: 'News',
    ),
  );

  Future<void> pump(
    WidgetTester tester,
    List<_FakeSession> sessions, {
    ValueChanged<String>? onPromote,
    void Function(String, String)? onSwap,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 640,
            height: 360,
            child: MultiviewStage(
              sessions: sessions,
              featuredChannelId: sessions.first.id,
              onPromote: onPromote ?? (_) {},
              onSwap: onSwap,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('one channel uses the single layout', (tester) async {
    final sessions = [session('one')];
    addTearDown(sessions.single.close);
    await pump(tester, sessions);

    expect(
      find.byKey(const ValueKey('multiview-layout-single')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('player-one')), findsOneWidget);
  });

  testWidgets('two channels use split layout', (tester) async {
    final sessions = [session('one'), session('two')];
    addTearDown(() => Future.wait(sessions.map((item) => item.close())));
    await pump(tester, sessions);

    expect(
      find.byKey(const ValueKey('multiview-layout-split')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('player-one')), findsOneWidget);
    expect(find.byKey(const ValueKey('player-two')), findsOneWidget);
  });

  for (final count in [3, 4]) {
    testWidgets('$count channels use a stable quad layout', (tester) async {
      final sessions = [
        for (var index = 1; index <= count; index++) session('$index'),
      ];
      addTearDown(() => Future.wait(sessions.map((item) => item.close())));
      await pump(tester, sessions);

      expect(
        find.byKey(ValueKey('multiview-layout-quad-$count')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('multiview-thumbnail-strip')),
        findsNothing,
      );
      expect(find.byIcon(Icons.volume_up), findsOneWidget);
      expect(find.byIcon(Icons.volume_off), findsNWidgets(count - 1));
    });
  }

  testWidgets('D-pad focus promotes the focused tile for audio', (
    tester,
  ) async {
    final sessions = [session('one'), session('two'), session('three')];
    addTearDown(() => Future.wait(sessions.map((item) => item.close())));
    String? promoted;
    await pump(tester, sessions, onPromote: (id) => promoted = id);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(promoted, 'two');
  });

  testWidgets('OK swaps focused tile with featured tile', (tester) async {
    final sessions = [session('one'), session('two')];
    addTearDown(() => Future.wait(sessions.map((item) => item.close())));
    (String, String)? swapped;
    await pump(
      tester,
      sessions,
      onSwap: (first, second) => swapped = (first, second),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(swapped, ('one', 'two'));
  });

  testWidgets('tile menu exposes independent track and quality controls', (
    tester,
  ) async {
    final sessions = [session('one'), session('two')];
    addTearDown(() => Future.wait(sessions.map((item) => item.close())));
    await pump(tester, sessions);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('multiview-controls-one')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('multiview-audio-one-audio-en')),
    );
    await tester.tap(
      find.byKey(const ValueKey('multiview-subtitle-one-subtitle-en')),
    );
    await tester.tap(find.byKey(const ValueKey('multiview-quality-one-low')));
    await tester.pump();

    expect(sessions.first.selectedAudioTrackId, 'audio-en');
    expect(sessions.first.selectedSubtitleTrackId, 'subtitle-en');
    expect(sessions.first.selectedQuality, VideoQuality.low);
    expect(sessions.last.selectedAudioTrackId, isNull);
    expect(sessions.last.selectedSubtitleTrackId, isNull);
    expect(sessions.last.selectedQuality, isNull);
  });
}

class _FakeSession implements IptvMultiviewSession {
  _FakeSession(this.channel);

  @override
  final IPTVChannel channel;
  final _states = StreamController<StreamingState>.broadcast();
  String? selectedAudioTrackId;
  String? selectedSubtitleTrackId;
  VideoQuality? selectedQuality;

  @override
  String get id => channel.id;

  @override
  StreamingState get currentState => StreamingState(
    currentChannel: channel,
    playbackState: PlaybackState.playing,
    tracks: const [
      AiroPlaybackTrackOption(
        id: 'audio-en',
        kind: AiroPlaybackTrackKind.audio,
        label: 'English audio',
      ),
      AiroPlaybackTrackOption(
        id: 'subtitle-en',
        kind: AiroPlaybackTrackKind.subtitle,
        label: 'English subtitles',
      ),
    ],
  );

  @override
  Stream<StreamingState> get states => _states.stream;

  @override
  Widget buildView() => SizedBox(key: ValueKey('player-$id'));

  @override
  Future<void> clearTrackSelection(AiroPlaybackTrackKind kind) async {
    if (kind == AiroPlaybackTrackKind.audio) selectedAudioTrackId = null;
    if (kind == AiroPlaybackTrackKind.subtitle) {
      selectedSubtitleTrackId = null;
    }
  }

  @override
  Future<void> selectTrack({
    required AiroPlaybackTrackKind kind,
    required String trackId,
  }) async {
    if (kind == AiroPlaybackTrackKind.audio) selectedAudioTrackId = trackId;
    if (kind == AiroPlaybackTrackKind.subtitle) {
      selectedSubtitleTrackId = trackId;
    }
  }

  @override
  Future<void> setQuality(VideoQuality quality) async {
    selectedQuality = quality;
  }

  @override
  Future<void> setAudible(bool audible) async {}

  @override
  Future<void> close() => _states.close();
}
