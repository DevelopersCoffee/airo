import 'dart:async';

import 'package:feature_iptv/application/providers/cast_multiview_receiver_bridge.dart';
import 'package:feature_iptv/application/providers/multiview_provider.dart';
import 'package:flutter/widgets.dart';
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

  late Map<String, IPTVChannel> catalog;
  late MultiviewController controller;
  late FakeMultiviewCastLink link;
  late CastMultiviewReceiverBridge bridge;
  late List<MultiviewCastState> publishedStates;

  setUp(() {
    catalog = {
      for (final id in ['one', 'two', 'three']) id: channel(id),
    };
    controller = MultiviewController(
      decoderBudget: 2,
      primaryService: _FakePrimaryService(),
      sessionFactory: (item) async => _FakeMultiviewSession(item),
    );
    link = FakeMultiviewCastLink();
    publishedStates = [];
    link.sender.stateUpdates.listen(publishedStates.add);
    bridge = CastMultiviewReceiverBridge(
      transport: link.receiver,
      controller: controller,
      resolveChannel: (id) => catalog[id],
    );
    addTearDown(() async {
      await bridge.dispose();
      await controller.close();
      await link.dispose();
    });
  });

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  test('start() eagerly publishes the current (empty) state', () async {
    bridge.start();
    await pump();

    expect(publishedStates, hasLength(1));
    expect(publishedStates.single.slots, isEmpty);
  });

  test(
    'set_slot adds the resolved channel and publishes the new state',
    () async {
      bridge.start();
      await pump();

      await link.sender.sendCommand(
        const MultiviewSetSlotCommand(slotId: 'one', channelId: 'one'),
      );
      await pump();

      final latest = publishedStates.last;
      expect(latest.slots, hasLength(1));
      expect(latest.slots.single.channelId, 'one');
      expect(latest.slots.single.channelName, 'Channel one');
      // The first (and so far only) session is always featured.
      expect(latest.slots.single.featured, isTrue);
    },
  );

  test('set_slot with an unknown channel id is silently ignored', () async {
    bridge.start();
    await pump();
    final beforeCount = publishedStates.length;

    await link.sender.sendCommand(
      const MultiviewSetSlotCommand(slotId: 'ghost', channelId: 'ghost'),
    );
    await pump();

    expect(controller.state.sessions, isEmpty);
    // No spurious publish for a command that changed nothing.
    expect(publishedStates.length, beforeCount);
  });

  test('remove_slot removes an existing session', () async {
    bridge.start();
    await link.sender.sendCommand(
      const MultiviewSetSlotCommand(slotId: 'one', channelId: 'one'),
    );
    await pump();

    await link.sender.sendCommand(
      const MultiviewRemoveSlotCommand(slotId: 'one'),
    );
    await pump();

    expect(publishedStates.last.slots, isEmpty);
  });

  test('promote makes the given slot featured', () async {
    bridge.start();
    await link.sender.sendCommand(
      const MultiviewSetSlotCommand(slotId: 'one', channelId: 'one'),
    );
    await link.sender.sendCommand(
      const MultiviewSetSlotCommand(slotId: 'two', channelId: 'two'),
    );
    await pump();
    expect(
      publishedStates.last.slots
          .firstWhere((s) => s.channelId == 'one')
          .featured,
      isTrue,
    );

    await link.sender.sendCommand(const MultiviewPromoteCommand(slotId: 'two'));
    await pump();

    final latest = publishedStates.last;
    expect(
      latest.slots.firstWhere((s) => s.channelId == 'two').featured,
      isTrue,
    );
    expect(
      latest.slots.firstWhere((s) => s.channelId == 'one').featured,
      isFalse,
    );
  });

  test('swap reorders the two slots', () async {
    bridge.start();
    await link.sender.sendCommand(
      const MultiviewSetSlotCommand(slotId: 'one', channelId: 'one'),
    );
    await link.sender.sendCommand(
      const MultiviewSetSlotCommand(slotId: 'two', channelId: 'two'),
    );
    await pump();
    expect(publishedStates.last.slots.map((s) => s.channelId), ['one', 'two']);

    await link.sender.sendCommand(
      const MultiviewSwapCommand(firstSlotId: 'one', secondSlotId: 'two'),
    );
    await pump();

    expect(publishedStates.last.slots.map((s) => s.channelId), ['two', 'one']);
  });

  test('query_state republishes without changing anything', () async {
    bridge.start();
    await link.sender.sendCommand(
      const MultiviewSetSlotCommand(slotId: 'one', channelId: 'one'),
    );
    await pump();
    final beforeCount = publishedStates.length;

    await link.sender.sendCommand(const MultiviewQueryStateCommand());
    await pump();

    expect(publishedStates.length, beforeCount + 1);
    expect(publishedStates.last, publishedStates[beforeCount - 1]);
  });
}

class _FakeMultiviewSession implements IptvMultiviewSession {
  _FakeMultiviewSession(this.channel);

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
  Future<void> setAudible(bool audible) async {}

  @override
  Future<void> close() async {
    await _states.close();
  }
}

class _FakePrimaryService implements IPTVStreamingService {
  StreamingState _state = StreamingState(playbackState: PlaybackState.playing);

  @override
  StreamingState get currentState => _state;

  @override
  Stream<StreamingState> get stateStream => const Stream.empty();

  @override
  Future<void> pause() async {
    _state = _state.copyWith(playbackState: PlaybackState.paused);
  }

  @override
  Future<void> resume() async {
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
  Future<void> toggleMute() async {}

  @override
  Future<void> stop() async {}
}
