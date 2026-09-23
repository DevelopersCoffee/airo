import 'dart:async';

import 'package:feature_iptv/application/multiview_split_ratio.dart';
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

  test(
    'controller pauses primary, enforces cap, and resumes when empty',
    () async {
      final primary = _FakePrimaryService();
      final sessions = <String, _FakeMultiviewSession>{};
      final controller = MultiviewController(
        decoderBudget: 2,
        primaryService: primary,
        sessionFactory: (item) async =>
            sessions.putIfAbsent(item.id, () => _FakeMultiviewSession(item)),
      );
      addTearDown(controller.close);

      expect(
        await controller.toggle(channel('one')),
        MultiviewToggleResult.added,
      );
      expect(primary.pauseCalls, 1);
      expect(
        await controller.toggle(channel('two')),
        MultiviewToggleResult.added,
      );
      expect(
        await controller.toggle(channel('three')),
        MultiviewToggleResult.capacityReached,
      );
      expect(sessions, hasLength(2));

      expect(
        await controller.toggle(channel('one')),
        MultiviewToggleResult.removed,
      );
      expect(
        await controller.toggle(channel('two')),
        MultiviewToggleResult.removed,
      );
      expect(primary.resumeCalls, 1);
      expect(controller.state.sessions, isEmpty);
    },
  );

  test('setLayout is kept when sessions are added', () async {
    final controller = MultiviewController(
      decoderBudget: 4,
      primaryService: _FakePrimaryService(),
      sessionFactory: (item) async => _FakeMultiviewSession(item),
    );
    addTearDown(controller.close);

    controller.setLayout(MultiviewLayoutKind.spotlight);
    expect(
      await controller.toggle(channel('one')),
      MultiviewToggleResult.added,
    );
    expect(controller.state.layout, MultiviewLayoutKind.spotlight);
  });

  test('failed first open resumes primary and leaves no session', () async {
    final primary = _FakePrimaryService();
    final controller = MultiviewController(
      decoderBudget: 4,
      primaryService: primary,
      sessionFactory: (_) async => throw StateError('open failed'),
    );
    addTearDown(controller.close);

    expect(
      await controller.toggle(channel('bad')),
      MultiviewToggleResult.failed,
    );
    expect(primary.pauseCalls, 1);
    expect(primary.resumeCalls, 1);
    expect(controller.state.sessions, isEmpty);
  });

  test('replace tears down the old session then opens the new one', () async {
    final sessions = <String, _FakeMultiviewSession>{};
    final controller = MultiviewController(
      decoderBudget: 2,
      primaryService: _FakePrimaryService(),
      sessionFactory: (item) async =>
          sessions.putIfAbsent(item.id, () => _FakeMultiviewSession(item)),
    );
    addTearDown(controller.close);

    await controller.toggle(channel('old1'));
    await controller.toggle(channel('old2'));
    expect(controller.state.sessions, hasLength(2));

    final result = await controller.replace('old1', channel('newX'));

    expect(result, MultiviewToggleResult.added);
    final ids = controller.state.sessions.map((s) => s.id).toList();
    expect(ids, containsAll(['newX', 'old2']));
    expect(ids, isNot(contains('old1')));
    expect(ids, hasLength(2));
    expect(sessions['old1']!.closed, isTrue);
  });

  test(
    'replace leaves the slot empty, not the old session, when the new stream fails',
    () async {
      final primary = _FakePrimaryService();
      final oldSessions = <String, _FakeMultiviewSession>{};
      final controller = MultiviewController(
        decoderBudget: 2,
        primaryService: primary,
        sessionFactory: (item) async {
          if (item.id == 'newX') throw StateError('open failed');
          return oldSessions.putIfAbsent(
            item.id,
            () => _FakeMultiviewSession(item),
          );
        },
      );
      addTearDown(controller.close);

      await controller.toggle(channel('old1'));
      await controller.toggle(channel('old2'));
      expect(primary.pauseCalls, 1);

      final result = await controller.replace('old1', channel('newX'));

      expect(result, MultiviewToggleResult.failed);
      final ids = controller.state.sessions.map((s) => s.id).toList();
      expect(ids, isNot(contains('old1')));
      expect(ids, isNot(contains('newX')));
      expect(ids, hasLength(1));
      expect(ids, contains('old2'));
      expect(oldSessions['old1']!.closed, isTrue);
      // replace() must not touch _primaryHeldByMultiview bookkeeping --
      // one session (old2) is still active, so primary stays paused.
      expect(primary.resumeCalls, 0);
    },
  );

  test(
    'replace still attempts the add when oldChannelId is not in the pool',
    () async {
      final controller = MultiviewController(
        decoderBudget: 2,
        primaryService: _FakePrimaryService(),
        sessionFactory: (item) async => _FakeMultiviewSession(item),
      );
      addTearDown(controller.close);

      await controller.toggle(channel('old1'));
      await controller.toggle(channel('old2'));

      final result = await controller.replace('not-present', channel('newX'));

      // 'not-present' isn't in the pool so nothing is torn down; the pool
      // is still full (old1 + old2), so the real AiroMultiviewPool.add()
      // reports capacityReached -- verified against airo_multiview_pool.dart.
      expect(result, MultiviewToggleResult.capacityReached);
      final ids = controller.state.sessions.map((s) => s.id).toList();
      expect(ids, containsAll(['old1', 'old2']));
      expect(ids, isNot(contains('newX')));
    },
  );

  test(
    'first split-view session silences and releases primary even while buffering',
    () async {
      final watching = channel('one');
      final primary = _FakePrimaryService(
        state: StreamingState(
          playbackState: PlaybackState.buffering,
          currentChannel: watching,
          volume: 1,
          isLiveStream: true,
        ),
      );
      final controller = MultiviewController(
        decoderBudget: 2,
        primaryService: primary,
        sessionFactory: (item) async => _FakeMultiviewSession(item),
      );
      addTearDown(controller.close);

      expect(
        await controller.toggle(channel('two')),
        MultiviewToggleResult.added,
      );

      expect(
        primary.volume,
        0,
        reason: 'Watch audio must not keep mixing under split-view tiles',
      );
      expect(primary.pauseCalls, 1);
      expect(
        primary.stopCalls,
        1,
        reason:
            'Pixel 9 otherwise keeps the original ExoPlayer plus two tiles, '
            'so three containers stay alive and two voices leak',
      );
      expect(primary.currentState.currentChannel, isNull);
      expect(primary.engineHeld, isFalse);

      expect(
        await controller.toggle(channel('two')),
        MultiviewToggleResult.removed,
      );
      expect(primary.playedChannels, [watching]);
      expect(primary.volume, 1);
    },
  );

  test('close mutes and disposes every owned session', () async {
    final primary = _FakePrimaryService();
    final sessions = <_FakeMultiviewSession>[];
    final controller = MultiviewController(
      decoderBudget: 4,
      primaryService: primary,
      sessionFactory: (item) async {
        final session = _FakeMultiviewSession(item);
        sessions.add(session);
        return session;
      },
    );
    await controller.toggle(channel('one'));
    await controller.toggle(channel('two'));

    await controller.close();

    expect(sessions.every((session) => session.closed), isTrue);
    expect(sessions.every((session) => !session.audible), isTrue);
    expect(primary.resumeCalls, 1);
  });

  test(
    'splitRatio defaults to fifty and setSplitRatio keeps a two-pane stop',
    () async {
      final controller = MultiviewController(
        decoderBudget: 4,
        primaryService: _FakePrimaryService(),
        sessionFactory: (item) async => _FakeMultiviewSession(item),
      );
      addTearDown(controller.close);

      expect(controller.state.splitRatio, MultiviewSplitRatio.fifty);
      await controller.toggle(channel('one'));
      await controller.toggle(channel('two'));
      controller.setSplitRatio(MultiviewSplitRatio.ninetyFive);
      expect(controller.state.splitRatio, MultiviewSplitRatio.ninetyFive);
    },
  );

  test('third session resets splitRatio to fifty', () async {
    final controller = MultiviewController(
      decoderBudget: 4,
      primaryService: _FakePrimaryService(),
      sessionFactory: (item) async => _FakeMultiviewSession(item),
    );
    addTearDown(controller.close);

    await controller.toggle(channel('one'));
    await controller.toggle(channel('two'));
    controller.setSplitRatio(MultiviewSplitRatio.ninetyFive);
    expect(
      await controller.toggle(channel('three')),
      MultiviewToggleResult.added,
    );
    expect(controller.state.splitRatio, MultiviewSplitRatio.fifty);
  });

  test('non two-pane setLayout resets splitRatio to fifty', () async {
    final controller = MultiviewController(
      decoderBudget: 4,
      primaryService: _FakePrimaryService(),
      sessionFactory: (item) async => _FakeMultiviewSession(item),
    );
    addTearDown(controller.close);

    await controller.toggle(channel('one'));
    await controller.toggle(channel('two'));
    controller.setSplitRatio(MultiviewSplitRatio.five);
    controller.setLayout(MultiviewLayoutKind.spotlight);
    expect(controller.state.splitRatio, MultiviewSplitRatio.fifty);
  });

  test(
    'returning to two-pane after a reset starts at fifty, not the old 95',
    () async {
      final controller = MultiviewController(
        decoderBudget: 4,
        primaryService: _FakePrimaryService(),
        sessionFactory: (item) async => _FakeMultiviewSession(item),
      );
      addTearDown(controller.close);

      await controller.toggle(channel('one'));
      await controller.toggle(channel('two'));
      controller.setSplitRatio(MultiviewSplitRatio.ninetyFive);
      controller.setLayout(MultiviewLayoutKind.quad);
      expect(controller.state.splitRatio, MultiviewSplitRatio.fifty);
      controller.setLayout(MultiviewLayoutKind.splitHorizontal);
      expect(controller.state.splitRatio, MultiviewSplitRatio.fifty);
    },
  );

  test('setLayout between the two two-pane mosaics keeps the stop', () async {
    final controller = MultiviewController(
      decoderBudget: 4,
      primaryService: _FakePrimaryService(),
      sessionFactory: (item) async => _FakeMultiviewSession(item),
    );
    addTearDown(controller.close);

    await controller.toggle(channel('one'));
    await controller.toggle(channel('two'));
    controller.setSplitRatio(MultiviewSplitRatio.five);
    controller.setLayout(MultiviewLayoutKind.splitVertical);
    expect(controller.state.splitRatio, MultiviewSplitRatio.five);
  });
}

class _FakeMultiviewSession implements IptvMultiviewSession {
  _FakeMultiviewSession(this.channel);

  @override
  final IPTVChannel channel;
  bool audible = false;
  double volume = 0;
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
  Future<void> setVolume(double value) async {
    volume = value;
    audible = value > 0;
  }

  @override
  Future<void> close() async {
    closed = true;
    await _states.close();
  }
}

class _FakePrimaryService implements IPTVStreamingService {
  _FakePrimaryService({StreamingState? state})
    : _state = state ?? StreamingState(playbackState: PlaybackState.playing);

  int pauseCalls = 0;
  int resumeCalls = 0;
  int stopCalls = 0;
  double volume = 1;
  bool engineHeld = true;
  final playedChannels = <IPTVChannel>[];
  StreamingState _state;

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
    engineHeld = true;
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
  Future<void> playChannel(IPTVChannel channel) async {
    playedChannels.add(channel);
    engineHeld = true;
    _state = StreamingState(
      playbackState: PlaybackState.playing,
      currentChannel: channel,
      volume: volume,
      isMuted: volume <= 0,
    );
  }

  @override
  Future<void> retry() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setBackgroundAudioMode(bool enabled) async {}

  @override
  Future<void> setQuality(VideoQuality quality) async {}

  @override
  Future<void> setVolume(double volume) async {
    this.volume = volume;
    _state = _state.copyWith(volume: volume, isMuted: volume <= 0);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    engineHeld = false;
    _state = StreamingState();
  }

  @override
  Future<void> toggleMute() async {}
}
