import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_streaming_engine/platform_streaming_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = EventChannel('com.airo.player/streaming_engine/state');
  late MockStreamHandlerEventSink sink;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          channel,
          MockStreamHandler.inline(
            onListen: (arguments, events) => sink = events,
          ),
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(channel, null);
  });

  group('AiroStreamingEngineState.phaseStream', () {
    test('maps a known native phase string onto AiroPlaybackEnginePhase', () async {
      final phases = <AiroPlaybackEnginePhase>[];
      final subscription = AiroStreamingEngineState.phaseStream.listen(
        phases.add,
      );
      addTearDown(subscription.cancel);

      sink.success('playing');
      await Future<void>.delayed(Duration.zero);

      expect(phases, [AiroPlaybackEnginePhase.playing]);
    });

    test('maps every AiroPlaybackEnginePhase stableId round-trip', () async {
      for (final phase in AiroPlaybackEnginePhase.values) {
        final phases = <AiroPlaybackEnginePhase>[];
        final subscription = AiroStreamingEngineState.phaseStream.listen(
          phases.add,
        );

        sink.success(phase.stableId);
        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        expect(phases, [phase], reason: 'stableId "${phase.stableId}"');
      }
    });

    test('an unrecognized native phase string degrades to unavailable', () async {
      final phases = <AiroPlaybackEnginePhase>[];
      final subscription = AiroStreamingEngineState.phaseStream.listen(
        phases.add,
      );
      addTearDown(subscription.cancel);

      sink.success('some_future_native_phase_this_client_does_not_know');
      await Future<void>.delayed(Duration.zero);

      expect(phases, [AiroPlaybackEnginePhase.unavailable]);
    });
  });
}
