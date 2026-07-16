import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  group('AiroMultiSourceFailoverController', () {
    test('ranks local last-worked source ahead of global health', () {
      final controller = AiroMultiSourceFailoverController(
        sources: [
          _source(
            'primary',
            health: AiroFailoverSourceHealth.healthy,
            resolutionHeight: 1080,
            rank: 0,
          ),
          _source(
            'local',
            health: AiroFailoverSourceHealth.degraded,
            resolutionHeight: 720,
            rank: 1,
            lastWorkedHere: true,
          ),
        ],
      );

      final selected = controller.start();

      expect(selected?.sourceId, 'local');
      expect(controller.state.currentSourceId, 'local');
    });

    test('switches to next ranked source on playback error', () {
      final controller = AiroMultiSourceFailoverController(
        sources: [
          _source('primary', health: AiroFailoverSourceHealth.healthy),
          _source('backup', rank: 1),
        ],
      );

      expect(controller.start()?.sourceId, 'primary');
      final decision = controller.recordPlaybackError('primary');

      expect(decision.code, AiroFailoverDecisionCode.switched);
      expect(decision.nextSource?.sourceId, 'backup');
      expect(decision.uiStatus, 'switching_source_2/2');
      expect(controller.state.failedSourceIds, contains('primary'));
    });

    test('uses configurable stall threshold before failover', () {
      final controller = AiroMultiSourceFailoverController(
        policy: const AiroFailoverPolicy(stallThreshold: Duration(seconds: 3)),
        sources: [_source('primary'), _source('backup', rank: 1)],
      )..start();

      final ignored = controller.recordBuffering(
        sourceId: 'primary',
        duration: const Duration(seconds: 2),
      );
      final switched = controller.recordBuffering(
        sourceId: 'primary',
        duration: const Duration(seconds: 3),
      );

      expect(ignored.code, AiroFailoverDecisionCode.ignored);
      expect(switched.code, AiroFailoverDecisionCode.switched);
      expect(switched.nextSource?.sourceId, 'backup');
    });

    test('returns exhausted when every source has failed', () {
      final controller = AiroMultiSourceFailoverController(
        sources: [_source('primary'), _source('backup', rank: 1)],
      )..start();

      expect(
        controller.recordPlaybackError('primary').code,
        AiroFailoverDecisionCode.switched,
      );
      final exhausted = controller.recordPlaybackError('backup');

      expect(exhausted.code, AiroFailoverDecisionCode.exhausted);
      expect(exhausted.shouldSwitch, isFalse);
      expect(exhausted.uiStatus, 'exhausted');
    });

    test('diagnostics do not expose source handles', () {
      final source = _source('primary', handle: 'private-source-handle');
      final decision = AiroMultiSourceFailoverController(
        sources: [source, _source('backup', rank: 1)],
      )..start();

      final switched = decision.recordPlaybackError('primary');

      expect(source.toString(), isNot(contains('private-source-handle')));
      expect(switched.toString(), isNot(contains('private-source-handle')));
      expect(source.toString(), contains('sourceHandle: redacted'));
    });
  });
}

AiroFailoverSource _source(
  String id, {
  int rank = 0,
  String handle = 'source-handle',
  AiroFailoverSourceHealth health = AiroFailoverSourceHealth.unknown,
  int? resolutionHeight,
  bool lastWorkedHere = false,
}) {
  return AiroFailoverSource(
    sourceId: id,
    sourceHandle: AiroPlaybackSourceHandle.redacted('$handle-$id'),
    canonicalChannelId: 'channel-news',
    rank: rank,
    health: health,
    resolutionHeight: resolutionHeight,
    lastWorkedHere: lastWorkedHere,
  );
}
