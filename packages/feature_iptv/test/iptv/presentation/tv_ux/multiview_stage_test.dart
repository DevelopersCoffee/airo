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
    testWidgets('$count channels use featured plus thumbnail strip', (
      tester,
    ) async {
      final sessions = [
        for (var index = 1; index <= count; index++) session('$index'),
      ];
      addTearDown(() => Future.wait(sessions.map((item) => item.close())));
      await pump(tester, sessions);

      expect(
        find.byKey(ValueKey('multiview-layout-featured-$count')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('multiview-thumbnail-strip')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.volume_up), findsOneWidget);
      expect(find.byIcon(Icons.volume_off), findsNWidgets(count - 1));
    });
  }

  testWidgets('thumbnail supports D-pad promotion', (tester) async {
    final sessions = [session('one'), session('two'), session('three')];
    addTearDown(() => Future.wait(sessions.map((item) => item.close())));
    String? promoted;
    await pump(tester, sessions, onPromote: (id) => promoted = id);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(promoted, 'two');
  });
}

class _FakeSession implements IptvMultiviewSession {
  _FakeSession(this.channel);

  @override
  final IPTVChannel channel;
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
  Widget buildView() => SizedBox(key: ValueKey('player-$id'));

  @override
  Future<void> setAudible(bool audible) async {}

  @override
  Future<void> close() => _states.close();
}
