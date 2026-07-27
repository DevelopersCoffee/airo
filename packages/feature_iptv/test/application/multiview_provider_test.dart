import 'dart:async';

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
}

class _FakeMultiviewSession implements IptvMultiviewSession {
  _FakeMultiviewSession(this.channel);

  @override
  final IPTVChannel channel;
  bool audible = false;
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
  Future<void> setAudible(bool value) async {
    audible = value;
  }

  @override
  Future<void> close() async {
    closed = true;
    await _states.close();
  }
}

class _FakePrimaryService implements IPTVStreamingService {
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
