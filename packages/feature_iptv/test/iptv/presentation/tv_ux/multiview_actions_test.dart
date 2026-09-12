import 'dart:async';

import 'package:feature_iptv/application/providers/multiview_provider.dart';
import 'package:feature_iptv/presentation/tv_ux/sections/multiview_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  IPTVChannel channel(String id) => IPTVChannel(
    id: id,
    name: 'Channel $id',
    streamUrl: 'https://example.com/$id.m3u8',
    group: 'News',
  );

  _FakeSession session(String id) => _FakeSession(channel(id));

  Future<void> pumpTriggerButton(WidgetTester tester, VoidCallback onPressed) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) =>
                ElevatedButton(onPressed: onPressed, child: const Text('open')),
          ),
        ),
      ),
    );
  }

  group('showMultiviewReplaceDialog', () {
    testWidgets('lists sessions by slot number and name', (tester) async {
      final sessions = [session('one'), session('two')];
      addTearDown(() => Future.wait(sessions.map((item) => item.close())));

      await pumpTriggerButton(tester, () {});
      final context = tester.element(find.byType(ElevatedButton));
      unawaited(
        showMultiviewReplaceDialog(
          context,
          sessions: sessions,
          onReplace: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('airo-tv-multiview-replace-dialog')),
        findsOneWidget,
      );
      expect(find.text('Screen 1: Channel one'), findsOneWidget);
      expect(find.text('Screen 2: Channel two'), findsOneWidget);
    });

    testWidgets(
      'tapping a slot calls onReplace with that session id and closes the dialog',
      (tester) async {
        final sessions = [session('one'), session('two')];
        addTearDown(() => Future.wait(sessions.map((item) => item.close())));
        String? replaced;

        await pumpTriggerButton(tester, () {});
        final context = tester.element(find.byType(ElevatedButton));
        unawaited(
          showMultiviewReplaceDialog(
            context,
            sessions: sessions,
            onReplace: (id) => replaced = id,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('multiview-replace-slot-two')),
        );
        await tester.pumpAndSettle();

        expect(replaced, 'two');
        expect(
          find.byKey(const ValueKey('airo-tv-multiview-replace-dialog')),
          findsNothing,
        );
      },
    );

    testWidgets('Cancel closes the dialog without calling onReplace', (
      tester,
    ) async {
      final sessions = [session('one')];
      addTearDown(() => Future.wait(sessions.map((item) => item.close())));
      var replaceCalls = 0;

      await pumpTriggerButton(tester, () {});
      final context = tester.element(find.byType(ElevatedButton));
      unawaited(
        showMultiviewReplaceDialog(
          context,
          sessions: sessions,
          onReplace: (_) => replaceCalls++,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(replaceCalls, 0);
      expect(
        find.byKey(const ValueKey('airo-tv-multiview-replace-dialog')),
        findsNothing,
      );
    });
  });

  group('showMultiviewEmptySlotPicker', () {
    testWidgets('excludes channels already in excludeChannelIds', (
      tester,
    ) async {
      final allChannels = [channel('one'), channel('two'), channel('three')];
      IPTVChannel? selected;

      await pumpTriggerButton(tester, () {});
      final context = tester.element(find.byType(ElevatedButton));
      unawaited(
        showMultiviewEmptySlotPicker(
          context,
          allChannels: allChannels,
          excludeChannelIds: {'one', 'two'},
          onSelected: (channel) => selected = channel,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('multiview-picker-one')), findsNothing);
      expect(find.byKey(const ValueKey('multiview-picker-two')), findsNothing);
      expect(
        find.byKey(const ValueKey('multiview-picker-three')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('multiview-picker-three')));
      await tester.pumpAndSettle();

      expect(selected?.id, 'three');
    });

    testWidgets('shows a message when nothing is pickable', (tester) async {
      final allChannels = [channel('one')];

      await pumpTriggerButton(tester, () {});
      final context = tester.element(find.byType(ElevatedButton));
      unawaited(
        showMultiviewEmptySlotPicker(
          context,
          allChannels: allChannels,
          excludeChannelIds: {'one'},
          onSelected: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No other channels available to add here.'),
        findsOneWidget,
      );
    });
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
  Future<void> close() => _states.close();
}
