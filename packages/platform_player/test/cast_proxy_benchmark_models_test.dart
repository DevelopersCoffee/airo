import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  const policy = CastProxyBenchmarkPolicy();
  final measuredAt = DateTime.utc(2026, 7, 15, 12);

  group('CastProxyBenchmarkPolicy', () {
    test('accepts a sustained sample under the CPU gate', () {
      final evaluation = policy.evaluate(
        _sample(
          measuredAt: measuredAt,
          targetBitrateMbps: 20,
          observedThroughputMbps: 22,
          senderCpuPercent: 1.8,
        ),
      );

      expect(evaluation.accepted, isTrue);
      expect(evaluation.violations, const [
        CastProxyBenchmarkViolationCode.accepted,
      ]);
      expect(evaluation.requiresNativeDataPlaneInvestigation, isFalse);
    });

    test('requires native data-plane investigation when CPU exceeds gate', () {
      final evaluation = policy.evaluate(
        _sample(
          measuredAt: measuredAt,
          targetBitrateMbps: 10,
          observedThroughputMbps: 11,
          senderCpuPercent: 5.1,
        ),
      );

      expect(evaluation.accepted, isFalse);
      expect(
        evaluation.decision,
        CastProxyBenchmarkDecision.investigateNativeDataPlane,
      );
      expect(
        evaluation.violations,
        contains(CastProxyBenchmarkViolationCode.senderCpuExceeded),
      );
    });

    test('flags throughput and connection failures', () {
      final evaluation = policy.evaluate(
        _sample(
          measuredAt: measuredAt,
          targetBitrateMbps: 20,
          observedThroughputMbps: 18,
          droppedConnectionCount: 1,
        ),
      );

      expect(evaluation.accepted, isFalse);
      expect(
        evaluation.violations,
        containsAll(const {
          CastProxyBenchmarkViolationCode.throughputBelowTarget,
          CastProxyBenchmarkViolationCode.droppedConnectionsObserved,
        }),
      );
    });

    test('asks for rerun when only the duration is too short', () {
      final evaluation = policy.evaluate(
        _sample(measuredAt: measuredAt, duration: const Duration(minutes: 3)),
      );

      expect(evaluation.accepted, isFalse);
      expect(evaluation.decision, CastProxyBenchmarkDecision.rerunRequired);
      expect(evaluation.violations, const [
        CastProxyBenchmarkViolationCode.benchmarkDurationTooShort,
      ]);
    });

    test('emits sanitized public map and markdown evidence', () {
      final evaluation = policy.evaluate(
        _sample(
          measuredAt: measuredAt,
          sampleId: 'pixel9-cast-proxy-20mbps',
          scenarioId: '20mbps-10m-cast-relay',
          batteryDrainPercentPerHour: 4.2,
        ),
      );

      final publicMap = evaluation.toPublicMap();
      final markdown = evaluation.toMarkdown();

      expect(publicMap, containsPair('sampleId', 'pixel9-cast-proxy-20mbps'));
      expect(publicMap, isNot(contains('url')));
      expect(publicMap, isNot(contains('receiverId')));
      expect(markdown, contains('# Cast Proxy Benchmark'));
      expect(markdown, contains('20mbps-10m-cast-relay'));
      expect(markdown, isNot(contains('http://')));
      expect(markdown, isNot(contains('192.168.')));
    });
  });
}

CastProxyBenchmarkSample _sample({
  required DateTime measuredAt,
  String sampleId = 'sample',
  String scenarioId = '20mbps-10m-cast-relay',
  double targetBitrateMbps = 20,
  double observedThroughputMbps = 20.5,
  double senderCpuPercent = 2,
  Duration duration = const Duration(minutes: 10),
  int droppedConnectionCount = 0,
  double? batteryDrainPercentPerHour,
}) {
  return CastProxyBenchmarkSample(
    sampleId: sampleId,
    scenarioId: scenarioId,
    targetBitrateMbps: targetBitrateMbps,
    observedThroughputMbps: observedThroughputMbps,
    senderCpuPercent: senderCpuPercent,
    duration: duration,
    droppedConnectionCount: droppedConnectionCount,
    batteryDrainPercentPerHour: batteryDrainPercentPerHour,
    measuredAt: measuredAt,
  );
}
