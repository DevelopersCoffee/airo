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
    MultiviewLayoutKind? layout,
    ValueChanged<String>? onDismiss,
    VoidCallback? onEmptySlotTap,
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
              layout: layout,
              onDismiss: onDismiss,
              onEmptySlotTap: onEmptySlotTap,
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

  testWidgets('3 channels use the two-over-one layout, no dead grid cell', (
    tester,
  ) async {
    final sessions = [session('1'), session('2'), session('3')];
    addTearDown(() => Future.wait(sessions.map((item) => item.close())));
    await pump(tester, sessions);

    expect(
      find.byKey(const ValueKey('multiview-layout-triple')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('multiview-layout-quad-3')), findsNothing);
    expect(
      find.byKey(const ValueKey('multiview-thumbnail-strip')),
      findsNothing,
    );
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
    expect(find.byIcon(Icons.volume_off), findsNWidgets(2));
  });

  testWidgets('4 channels use a stable quad layout', (tester) async {
    const count = 4;
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

  testWidgets('splitVertical stacks two channels instead of side-by-side', (
    tester,
  ) async {
    final sessions = [session('one'), session('two')];
    addTearDown(() => Future.wait(sessions.map((item) => item.close())));
    await pump(tester, sessions, layout: MultiviewLayoutKind.splitVertical);

    expect(
      find.byKey(const ValueKey('multiview-layout-split-vertical')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('multiview-layout-split')), findsNothing);
  });

  testWidgets('spotlight is the 1+3 PiP mosaic and fills unused cells', (
    tester,
  ) async {
    final sessions = [session('one'), session('two')];
    addTearDown(() => Future.wait(sessions.map((item) => item.close())));
    await pump(tester, sessions, layout: MultiviewLayoutKind.spotlight);

    expect(
      find.byKey(const ValueKey('multiview-layout-spotlight')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('multiview-empty-slot-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('multiview-empty-slot-3')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('player-one')), findsOneWidget);
    expect(find.byKey(const ValueKey('player-two')), findsOneWidget);
  });

  testWidgets('tripleLeft is the large-left mosaic', (tester) async {
    final sessions = [session('1'), session('2'), session('3')];
    addTearDown(() => Future.wait(sessions.map((item) => item.close())));
    await pump(tester, sessions, layout: MultiviewLayoutKind.tripleLeft);

    expect(
      find.byKey(const ValueKey('multiview-layout-triple-left')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('multiview-layout-triple')), findsNothing);
  });

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

  testWidgets(
    'tile menu volume slider sets that tile volume independent of the '
    'other tile (manual mix, not the pool single-audible default)',
    (tester) async {
      final sessions = [session('one'), session('two')];
      addTearDown(() => Future.wait(sessions.map((item) => item.close())));
      await pump(tester, sessions);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await tester.pumpAndSettle();

      final slider = find.byKey(const ValueKey('multiview-volume-one'));
      expect(slider, findsOneWidget);
      tester.widget<Slider>(slider).onChanged!(0.4);
      await tester.pump();

      expect(sessions.first.volume, 0.4);
      // The other tile's volume is untouched by mixing this one in.
      expect(sessions.last.volume, 1);
    },
  );

  testWidgets(
    'active tile shows a dismiss control on focus that calls onDismiss',
    (tester) async {
      final sessions = [session('one'), session('two')];
      addTearDown(() => Future.wait(sessions.map((item) => item.close())));
      String? dismissed;
      await pump(tester, sessions, onDismiss: (id) => dismissed = id);

      // Not focused yet -- the dismiss control isn't in the tree at all.
      expect(find.byKey(const ValueKey('multiview-dismiss-one')), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(
        find.byKey(const ValueKey('multiview-dismiss-one')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('multiview-dismiss-one')));
      await tester.pump();

      expect(dismissed, 'one');
    },
  );

  testWidgets(
    'Menu key (D-pad) opens tile controls with a Remove option that calls '
    'onDismiss',
    (tester) async {
      final sessions = [session('one'), session('two')];
      addTearDown(() => Future.wait(sessions.map((item) => item.close())));
      String? dismissed;
      await pump(tester, sessions, onDismiss: (id) => dismissed = id);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('multiview-controls-one')),
        findsOneWidget,
      );
      final removeOption = find.byKey(const ValueKey('multiview-remove-one'));
      expect(removeOption, findsOneWidget);

      // The dialog's option list overflows the default 800x600 test
      // surface, so the Remove row starts out below the fold inside
      // SimpleDialog's own scroll view -- scroll it into view before tapping.
      await tester.ensureVisible(removeOption);
      await tester.pumpAndSettle();
      await tester.tap(removeOption);
      await tester.pumpAndSettle();

      expect(dismissed, 'one');
      // The dialog closes after Remove is chosen.
      expect(
        find.byKey(const ValueKey('multiview-controls-one')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'long-press (touch) opens tile controls with a Remove option that calls '
    'onDismiss -- proves the dismiss path works without D-pad focus',
    (tester) async {
      final sessions = [session('one'), session('two')];
      addTearDown(() => Future.wait(sessions.map((item) => item.close())));
      String? dismissed;
      await pump(tester, sessions, onDismiss: (id) => dismissed = id);

      // No keyboard/D-pad focus at all -- the corner dismiss button never
      // renders for a touch-only user. Long-press is the touch equivalent
      // of the remote's Menu key (TvFocusable wires onLongPress to the same
      // onSecondaryAction callback as TvInputKey.menu).
      expect(find.byKey(const ValueKey('multiview-dismiss-one')), findsNothing);

      await tester.longPress(
        find.byKey(const ValueKey('multiview-promote-one')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('multiview-controls-one')),
        findsOneWidget,
      );

      final removeOption = find.byKey(const ValueKey('multiview-remove-one'));
      await tester.ensureVisible(removeOption);
      await tester.pumpAndSettle();
      await tester.tap(removeOption);
      await tester.pumpAndSettle();

      expect(dismissed, 'one');
    },
  );

  testWidgets(
    'tile controls dialog omits Remove when onDismiss is not supplied',
    (tester) async {
      final sessions = [session('one'), session('two')];
      addTearDown(() => Future.wait(sessions.map((item) => item.close())));
      await pump(tester, sessions);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('multiview-remove-one')), findsNothing);
    },
  );

  testWidgets(
    'empty slot is focusable and calls onEmptySlotTap when selected',
    (tester) async {
      final sessions = [session('one'), session('two')];
      addTearDown(() => Future.wait(sessions.map((item) => item.close())));
      var tapCount = 0;
      await pump(
        tester,
        sessions,
        layout: MultiviewLayoutKind.spotlight,
        onEmptySlotTap: () => tapCount++,
      );

      expect(
        find.byKey(const ValueKey('multiview-empty-slot-2')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('multiview-empty-slot-2')));
      await tester.pump();

      expect(tapCount, 1);
    },
  );
}

class _FakeSession implements IptvMultiviewSession {
  _FakeSession(this.channel);

  @override
  final IPTVChannel channel;
  final _states = StreamController<StreamingState>.broadcast();
  String? selectedAudioTrackId;
  String? selectedSubtitleTrackId;
  VideoQuality? selectedQuality;
  double volume = 1;

  @override
  String get id => channel.id;

  @override
  StreamingState get currentState => StreamingState(
    currentChannel: channel,
    playbackState: PlaybackState.playing,
    volume: volume,
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
  Future<void> setVolume(double value) async {
    volume = value;
  }

  @override
  Future<void> close() => _states.close();
}
