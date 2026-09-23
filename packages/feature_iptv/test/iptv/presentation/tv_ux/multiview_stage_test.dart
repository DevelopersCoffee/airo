import 'dart:async';

import 'package:feature_iptv/application/multiview_split_ratio.dart';
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
    MultiviewSplitRatio splitRatio = MultiviewSplitRatio.fifty,
    ValueChanged<MultiviewSplitRatio>? onSplitRatioChanged,
    double width = 640,
    double height = 360,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            height: height,
            child: MultiviewStage(
              sessions: sessions,
              featuredChannelId: sessions.first.id,
              onPromote: onPromote ?? (_) {},
              onSwap: onSwap,
              layout: layout,
              onDismiss: onDismiss,
              onEmptySlotTap: onEmptySlotTap,
              splitRatio: splitRatio,
              onSplitRatioChanged: onSplitRatioChanged,
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

  List<Expanded> splitExpanded(WidgetTester tester, Key layoutKey) {
    final handle = find.descendant(
      of: find.byKey(layoutKey),
      matching: find.byKey(const ValueKey('multiview-split-handle')),
    );
    final splitFinder = find.ancestor(
      of: handle,
      matching: find.byWidgetPredicate(
        (widget) => widget is Row || widget is Column,
      ),
    );
    final panes = <Expanded>[];
    tester.element(splitFinder.first).visitChildren((child) {
      final widget = child.widget;
      if (widget is Expanded) {
        panes.add(widget);
      }
    });
    return panes;
  }

  testWidgets('two-pane split shows a handle and 50/50 flex by default', (
    tester,
  ) async {
    final sessions = [session('one'), session('two')];
    addTearDown(() => Future.wait(sessions.map((item) => item.close())));
    await pump(tester, sessions);

    expect(
      find.byKey(const ValueKey('multiview-split-handle')),
      findsOneWidget,
    );
    final panes = splitExpanded(
      tester,
      const ValueKey('multiview-layout-split'),
    );
    expect(panes, hasLength(2));
    expect(panes[0].flex, 1);
    expect(panes[1].flex, 1);
  });

  testWidgets('five stop paints 80dp floor flex at 360px width', (tester) async {
    final sessions = [session('one'), session('two')];
    addTearDown(() => Future.wait(sessions.map((item) => item.close())));
    await pump(
      tester,
      sessions,
      splitRatio: MultiviewSplitRatio.five,
      width: 360,
    );

    final expectedFirst = (80 / 360 * 1000).round();
    final panes = splitExpanded(
      tester,
      const ValueKey('multiview-layout-split'),
    );
    expect(panes[0].flex, inInclusiveRange(expectedFirst - 1, expectedFirst + 1));
    expect(panes[1].flex, 1000 - panes[0].flex);
  });

  testWidgets('ninetyFive stop paints effective max flex at 1600px width', (
    tester,
  ) async {
    const width = 1600.0;
    tester.view.physicalSize = const Size(width, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sessions = [session('one'), session('two')];
    addTearDown(() => Future.wait(sessions.map((item) => item.close())));
    await pump(
      tester,
      sessions,
      splitRatio: MultiviewSplitRatio.ninetyFive,
      width: width,
    );

    final expectedMin = (effectiveMultiviewSplitMin(width) * 1000).round();
    final expectedMax = 1000 - expectedMin;
    final panes = splitExpanded(
      tester,
      const ValueKey('multiview-layout-split'),
    );
    expect(panes[0].flex, expectedMax);
    expect(panes[1].flex, expectedMin);
  });

  testWidgets('stacked two-pane also shows the handle', (tester) async {
    final sessions = [session('one'), session('two')];
    addTearDown(() => Future.wait(sessions.map((item) => item.close())));
    await pump(tester, sessions, layout: MultiviewLayoutKind.splitVertical);

    expect(
      find.byKey(const ValueKey('multiview-layout-split-vertical')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('multiview-split-handle')),
      findsOneWidget,
    );
  });

  testWidgets('triple and quad mosaics have no split handle', (tester) async {
    final triple = [session('1'), session('2'), session('3')];
    addTearDown(() => Future.wait(triple.map((item) => item.close())));
    await pump(tester, triple);
    expect(find.byKey(const ValueKey('multiview-split-handle')), findsNothing);

    final quad = [session('a'), session('b'), session('c'), session('d')];
    addTearDown(() => Future.wait(quad.map((item) => item.close())));
    await pump(tester, quad);
    expect(find.byKey(const ValueKey('multiview-split-handle')), findsNothing);
  });

  testWidgets('split handle is not focused after the initial pump', (
    tester,
  ) async {
    final sessions = [session('one'), session('two')];
    addTearDown(() => Future.wait(sessions.map((item) => item.close())));
    await pump(tester, sessions);

    final handleContext = tester.element(
      find.byKey(const ValueKey('multiview-split-handle')),
    );
    expect(Focus.maybeOf(handleContext)?.hasPrimaryFocus, isNot(true));
  });

  testWidgets('drag toward the left edge snaps to five', (tester) async {
    final sessions = [session('one'), session('two')];
    addTearDown(() => Future.wait(sessions.map((item) => item.close())));
    MultiviewSplitRatio? committed;
    await pump(
      tester,
      sessions,
      onSplitRatioChanged: (ratio) => committed = ratio,
    );

    await tester.drag(
      find.byKey(const ValueKey('multiview-split-handle')),
      const Offset(-180, 0),
    );
    await tester.pumpAndSettle();

    expect(committed, MultiviewSplitRatio.five);
  });

  testWidgets('drag that stays near center snaps to fifty', (tester) async {
    final sessions = [session('one'), session('two')];
    addTearDown(() => Future.wait(sessions.map((item) => item.close())));
    MultiviewSplitRatio? committed;
    await pump(
      tester,
      sessions,
      onSplitRatioChanged: (ratio) => committed = ratio,
    );

    // 24px exceeds Flutter kTouchSlop (~18) so the drag arena wins.
    await tester.drag(
      find.byKey(const ValueKey('multiview-split-handle')),
      const Offset(24, 0),
    );
    await tester.pumpAndSettle();

    expect(committed, MultiviewSplitRatio.fifty);
  });

  testWidgets('tap on the handle does not commit a split', (tester) async {
    final sessions = [session('one'), session('two')];
    addTearDown(() => Future.wait(sessions.map((item) => item.close())));
    MultiviewSplitRatio? committed;
    await pump(
      tester,
      sessions,
      onSplitRatioChanged: (ratio) => committed = ratio,
    );
    await tester.tap(find.byKey(const ValueKey('multiview-split-handle')));
    await tester.pumpAndSettle();
    expect(committed, isNull);
  });

  FocusNode focusableNode(WidgetTester tester, Finder host) {
    return tester
        .widgetList<Focus>(
          find.descendant(of: host, matching: find.byType(Focus)),
        )
        .map((focus) => focus.focusNode)
        .whereType<FocusNode>()
        .firstWhere((candidate) => candidate.canRequestFocus);
  }

  Future<void> focusHandle(WidgetTester tester) async {
    final handle = find.byKey(const ValueKey('multiview-split-handle'));
    // The handle key is on TvFocusable. Focus.maybeOf that element hits the
    // ancestor TvInputHandler Focus (not focusable); ExcludeFocus adds a
    // second descendant Focus. Drive the inner node that can take focus.
    final node = focusableNode(tester, handle);
    node.requestFocus();
    await tester.pump();
    expect(node.hasPrimaryFocus, isTrue);
  }

  testWidgets(
    'Right from fifty commits ninetyFive; further Right leaves the handle',
    (tester) async {
      final sessions = [session('one'), session('two')];
      addTearDown(() => Future.wait(sessions.map((item) => item.close())));
      final committed = <MultiviewSplitRatio>[];
      await pump(tester, sessions, onSplitRatioChanged: committed.add);
      await focusHandle(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(committed, [MultiviewSplitRatio.ninetyFive]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1600,
              height: 360,
              child: MultiviewStage(
                sessions: sessions,
                featuredChannelId: sessions.first.id,
                onPromote: (_) {},
                splitRatio: MultiviewSplitRatio.ninetyFive,
                onSplitRatioChanged: committed.add,
              ),
            ),
          ),
        ),
      );
      await focusHandle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(committed, [MultiviewSplitRatio.ninetyFive]);
      expect(
        focusableNode(
          tester,
          find.byKey(const ValueKey('multiview-promote-two')),
        ).hasPrimaryFocus,
        isTrue,
      );
    },
  );

  testWidgets('Select on the handle does not promote or swap', (tester) async {
    final sessions = [session('one'), session('two')];
    addTearDown(() => Future.wait(sessions.map((item) => item.close())));
    final promoted = <String>[];
    var swapped = 0;
    await pump(
      tester,
      sessions,
      onPromote: promoted.add,
      onSwap: (_, __) => swapped++,
    );
    promoted.clear();
    await focusHandle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(promoted, isEmpty);
    expect(swapped, 0);
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
