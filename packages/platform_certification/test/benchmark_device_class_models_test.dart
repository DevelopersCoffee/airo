import 'package:flutter_test/flutter_test.dart';
import 'package:platform_certification/platform_certification.dart';

void main() {
  group('Airo benchmark device-class gates', () {
    final now = DateTime.utc(2026, 7, 14, 12);

    test('default matrix exposes stable benchmark device classes', () {
      final matrix = AiroBenchmarkDeviceClasses.matrix();

      expect(matrix.schemaVersion, kAiroBenchmarkDeviceClassSchemaVersion);
      expect(matrix.profileById('constrained-tv-class-a'), isNotNull);
      expect(matrix.profileById('standard-tv-class-b'), isNotNull);
      expect(matrix.profileById('mobile-companion-class'), isNotNull);
      expect(matrix.profileById('desktop-companion-class'), isNotNull);
      expect(
        matrix.profileById('constrained-tv-class-a')!.requiredGateIds,
        contains(AiroBenchmarkStableValue.stable('scroll-while-import')),
      );
    });

    test('passing constrained TV evidence satisfies required gates', () {
      final matrix = AiroBenchmarkDeviceClasses.matrix();
      final samples = _passingSamplesFor(
        matrix: matrix,
        deviceClassId: 'constrained-tv-class-a',
        now: now,
      );

      final result = matrix.evaluate(
        deviceClassId: 'constrained-tv-class-a',
        samples: samples,
        now: now,
      );

      expect(result.passed, isTrue);
      expect(result.toDiagnosticMap(), {
        'deviceClassId': 'constrained-tv-class-a',
        'passed': true,
        'codes': <String>[],
      });
    });

    test('missing and wrong-class samples return deterministic blockers', () {
      final matrix = AiroBenchmarkDeviceClasses.matrix();
      final result = matrix.evaluate(
        deviceClassId: 'constrained-tv-class-a',
        now: now,
        samples: [
          _sample(
            deviceClassId: 'standard-tv-class-b',
            gateId: 'startup-latency',
            metric: AiroBenchmarkMetric.elapsedMillis,
            value: 1000,
            evidenceKind: AiroBenchmarkEvidenceKind.physicalDeviceRun,
            now: now,
          ),
        ],
      );

      expect(result.passed, isFalse);
      expect(
        result.blockers.map((blocker) => blocker.code),
        contains(AiroBenchmarkBlockerCode.sampleWrongDeviceClass),
      );
      expect(
        result.blockers.map((blocker) => blocker.code),
        contains(AiroBenchmarkBlockerCode.sampleMissing),
      );
    });

    test('host-only and stale samples cannot satisfy physical gates', () {
      final matrix = AiroBenchmarkDeviceClasses.matrix();
      final result = matrix.evaluate(
        deviceClassId: 'constrained-tv-class-a',
        now: now,
        samples: [
          _sample(
            gateId: 'startup-latency',
            metric: AiroBenchmarkMetric.elapsedMillis,
            value: 1000,
            evidenceKind: AiroBenchmarkEvidenceKind.hostAutomation,
            capturedAt: now,
            now: now,
          ),
          _sample(
            gateId: 'startup-latency',
            metric: AiroBenchmarkMetric.peakMemoryMb,
            value: 100,
            evidenceKind: AiroBenchmarkEvidenceKind.physicalDeviceRun,
            capturedAt: now.subtract(const Duration(days: 30)),
            now: now,
          ),
        ],
      );

      expect(
        result.blockers.map((blocker) => blocker.code),
        contains(AiroBenchmarkBlockerCode.hostOnlyEvidenceForPhysicalGate),
      );
      expect(
        result.blockers.map((blocker) => blocker.code),
        contains(AiroBenchmarkBlockerCode.sampleStale),
      );
    });

    test('metric threshold failures are typed by direction', () {
      final matrix = AiroBenchmarkDeviceClasses.matrix();
      final result = matrix.evaluate(
        deviceClassId: 'standard-tv-class-b',
        now: now,
        samples: [
          ..._passingSamplesFor(
            matrix: matrix,
            deviceClassId: 'standard-tv-class-b',
            now: now,
          ),
          _sample(
            deviceClassId: 'standard-tv-class-b',
            gateId: 'large-playlist-import',
            metric: AiroBenchmarkMetric.rowsPerSecond,
            value: 10,
            evidenceKind: AiroBenchmarkEvidenceKind.hostAutomation,
            now: now,
          ),
          _sample(
            deviceClassId: 'standard-tv-class-b',
            gateId: 'remote-during-playback',
            metric: AiroBenchmarkMetric.droppedFramePercent,
            value: 50,
            evidenceKind: AiroBenchmarkEvidenceKind.physicalDeviceRun,
            now: now,
          ),
        ],
      );

      expect(
        result.blockers.map((blocker) => blocker.code),
        contains(AiroBenchmarkBlockerCode.metricBelowMinimum),
      );
      expect(
        result.blockers.map((blocker) => blocker.code),
        contains(AiroBenchmarkBlockerCode.metricAboveMaximum),
      );
    });

    test('unknown and unsupported classes fail before support claims', () {
      final matrix = AiroBenchmarkDeviceClassMatrix(
        profiles: [
          AiroBenchmarkDeviceClassProfile(
            deviceClassId: AiroBenchmarkStableValue.stable('unsupported-box'),
            deviceClass: AiroBenchmarkDeviceClass.constrainedTv,
            platform: AiroValidationPlatform.androidTv,
            productProfile: AiroValidationProductProfile.liteReceiver,
            canAdvertiseSupport: false,
            requiredGateIds: const {},
          ),
        ],
        gates: const [],
      );

      final missing = matrix.evaluate(
        deviceClassId: 'missing-class',
        samples: const [],
        now: now,
      );
      final unsupported = matrix.evaluate(
        deviceClassId: 'unsupported-box',
        samples: const [],
        now: now,
      );

      expect(
        missing.blockers.single.code,
        AiroBenchmarkBlockerCode.deviceClassMissing,
      );
      expect(
        unsupported.blockers.single.code,
        AiroBenchmarkBlockerCode.unsupportedDeviceClass,
      );
    });

    test('stable value rejects raw private benchmark identifiers', () {
      expect(
        () => AiroBenchmarkStableValue.stable('https://example.com/sample'),
        throwsArgumentError,
      );
      expect(
        () => AiroBenchmarkStableValue.stable('/Users/me/sample'),
        throwsArgumentError,
      );
      expect(
        () => AiroBenchmarkStableValue.stable('10.0.0.20'),
        throwsArgumentError,
      );
      expect(
        () => AiroBenchmarkStableValue.stable('Basic abc123'),
        throwsArgumentError,
      );
    });

    test('no-op and fake evidence providers are deterministic', () async {
      const noop = AiroNoOpBenchmarkEvidenceProvider();
      final fake = AiroFakeBenchmarkEvidenceProvider(
        samples: [
          _sample(
            deviceClassId: 'desktop-companion-class',
            gateId: 'cache-cleanup',
            metric: AiroBenchmarkMetric.storageMb,
            value: 128,
            now: now,
          ),
          _sample(
            deviceClassId: 'mobile-companion-class',
            gateId: 'search-responsiveness',
            metric: AiroBenchmarkMetric.elapsedMillis,
            value: 80,
            now: now,
          ),
        ],
      );

      expect(
        await noop.samplesForDeviceClass(
          AiroBenchmarkStableValue.stable('desktop-companion-class'),
        ),
        isEmpty,
      );
      expect(
        await fake.samplesForDeviceClass(
          AiroBenchmarkStableValue.stable('desktop-companion-class'),
        ),
        hasLength(1),
      );
    });
  });
}

List<AiroBenchmarkSample> _passingSamplesFor({
  required AiroBenchmarkDeviceClassMatrix matrix,
  required String deviceClassId,
  required DateTime now,
}) {
  final profile = matrix.profileById(deviceClassId)!;
  final samples = <AiroBenchmarkSample>[];
  for (final gateId in profile.requiredGateIds) {
    final gate = matrix.gateById(gateId)!;
    for (final threshold in gate.thresholds) {
      samples.add(
        _sample(
          deviceClassId: deviceClassId,
          gateId: gateId.value,
          metric: threshold.metric,
          value: _passingValue(threshold),
          evidenceKind: gate.requiresPhysicalDevice
              ? AiroBenchmarkEvidenceKind.physicalDeviceRun
              : AiroBenchmarkEvidenceKind.hostAutomation,
          now: now,
        ),
      );
    }
  }
  return samples;
}

double _passingValue(AiroBenchmarkMetricThreshold threshold) {
  final max = threshold.maximum;
  if (max != null) return max / 2;
  final min = threshold.minimum;
  if (min != null) return min * 2;
  return 1;
}

AiroBenchmarkSample _sample({
  required String gateId,
  required AiroBenchmarkMetric metric,
  required double value,
  required DateTime now,
  String deviceClassId = 'constrained-tv-class-a',
  AiroBenchmarkEvidenceKind evidenceKind =
      AiroBenchmarkEvidenceKind.hostAutomation,
  DateTime? capturedAt,
}) {
  return AiroBenchmarkSample(
    sampleId: AiroBenchmarkStableValue.stable(
      '$deviceClassId-$gateId-${metric.stableId}',
    ),
    deviceClassId: AiroBenchmarkStableValue.stable(deviceClassId),
    gateId: AiroBenchmarkStableValue.stable(gateId),
    metric: metric,
    value: value,
    evidenceKind: evidenceKind,
    capturedAt: capturedAt ?? now,
  );
}
