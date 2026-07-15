import 'package:equatable/equatable.dart';

const String kCastProxyBenchmarkSchemaVersion = '1.0.0';

enum CastProxyBenchmarkDecision {
  accepted('accepted'),
  rerunRequired('rerun_required'),
  investigateNativeDataPlane('investigate_native_data_plane');

  const CastProxyBenchmarkDecision(this.stableId);

  final String stableId;
}

enum CastProxyBenchmarkViolationCode {
  accepted('accepted'),
  benchmarkDurationTooShort('benchmark_duration_too_short'),
  throughputBelowTarget('throughput_below_target'),
  senderCpuExceeded('sender_cpu_exceeded'),
  droppedConnectionsObserved('dropped_connections_observed');

  const CastProxyBenchmarkViolationCode(this.stableId);

  final String stableId;
}

class CastProxyBenchmarkSample extends Equatable {
  const CastProxyBenchmarkSample({
    required this.sampleId,
    required this.scenarioId,
    required this.targetBitrateMbps,
    required this.observedThroughputMbps,
    required this.senderCpuPercent,
    required this.duration,
    required this.droppedConnectionCount,
    required this.measuredAt,
    this.batteryDrainPercentPerHour,
    this.schemaVersion = kCastProxyBenchmarkSchemaVersion,
  });

  final String schemaVersion;
  final String sampleId;
  final String scenarioId;
  final double targetBitrateMbps;
  final double observedThroughputMbps;
  final double senderCpuPercent;
  final Duration duration;
  final int droppedConnectionCount;
  final double? batteryDrainPercentPerHour;
  final DateTime measuredAt;

  double get throughputRatio {
    if (targetBitrateMbps <= 0) return 0;
    return observedThroughputMbps / targetBitrateMbps;
  }

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'sampleId': sampleId,
      'scenarioId': scenarioId,
      'targetBitrateMbps': targetBitrateMbps,
      'observedThroughputMbps': observedThroughputMbps,
      'throughputRatio': throughputRatio,
      'senderCpuPercent': senderCpuPercent,
      'durationSeconds': duration.inSeconds,
      'droppedConnectionCount': droppedConnectionCount,
      if (batteryDrainPercentPerHour != null)
        'batteryDrainPercentPerHour': batteryDrainPercentPerHour,
      'measuredAt': measuredAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    sampleId,
    scenarioId,
    targetBitrateMbps,
    observedThroughputMbps,
    senderCpuPercent,
    duration,
    droppedConnectionCount,
    batteryDrainPercentPerHour,
    measuredAt,
  ];
}

class CastProxyBenchmarkEvaluation extends Equatable {
  CastProxyBenchmarkEvaluation({
    required this.sample,
    required this.decision,
    required Iterable<CastProxyBenchmarkViolationCode> violations,
  }) : violations = List.unmodifiable(violations);

  final CastProxyBenchmarkSample sample;
  final CastProxyBenchmarkDecision decision;
  final List<CastProxyBenchmarkViolationCode> violations;

  bool get accepted => decision == CastProxyBenchmarkDecision.accepted;

  bool get requiresNativeDataPlaneInvestigation =>
      decision == CastProxyBenchmarkDecision.investigateNativeDataPlane;

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': sample.schemaVersion,
      'sampleId': sample.sampleId,
      'scenarioId': sample.scenarioId,
      'accepted': accepted,
      'decision': decision.stableId,
      'violations': violations
          .map((violation) => violation.stableId)
          .toList(growable: false),
      'targetBitrateMbps': sample.targetBitrateMbps,
      'observedThroughputMbps': sample.observedThroughputMbps,
      'throughputRatio': sample.throughputRatio,
      'senderCpuPercent': sample.senderCpuPercent,
      'durationSeconds': sample.duration.inSeconds,
      'droppedConnectionCount': sample.droppedConnectionCount,
      if (sample.batteryDrainPercentPerHour != null)
        'batteryDrainPercentPerHour': sample.batteryDrainPercentPerHour,
      'measuredAt': sample.measuredAt.toIso8601String(),
    };
  }

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# Cast Proxy Benchmark')
      ..writeln()
      ..writeln('- Sample: `${sample.sampleId}`')
      ..writeln('- Scenario: `${sample.scenarioId}`')
      ..writeln('- Decision: `${decision.stableId}`')
      ..writeln('- Accepted: `$accepted`')
      ..writeln(
        '- Target bitrate: ${sample.targetBitrateMbps.toStringAsFixed(2)} Mbps',
      )
      ..writeln(
        '- Observed throughput: ${sample.observedThroughputMbps.toStringAsFixed(2)} Mbps',
      )
      ..writeln(
        '- Throughput ratio: ${sample.throughputRatio.toStringAsFixed(2)}',
      )
      ..writeln('- Sender CPU: ${sample.senderCpuPercent.toStringAsFixed(2)}%')
      ..writeln('- Duration: ${sample.duration.inSeconds}s')
      ..writeln('- Dropped connections: ${sample.droppedConnectionCount}')
      ..writeln(
        '- Violations: ${violations.map((violation) => violation.stableId).join(', ')}',
      );

    final battery = sample.batteryDrainPercentPerHour;
    if (battery != null) {
      buffer.writeln('- Battery drain: ${battery.toStringAsFixed(2)}%/h');
    }

    return buffer.toString();
  }

  @override
  List<Object?> get props => [sample, decision, violations];
}

class CastProxyBenchmarkPolicy extends Equatable {
  const CastProxyBenchmarkPolicy({
    this.minimumDuration = const Duration(minutes: 10),
    this.minimumThroughputRatio = 1,
    this.cpuGateBitrateMbps = 10,
    this.maxSenderCpuPercentAtGate = 5,
  });

  final Duration minimumDuration;
  final double minimumThroughputRatio;
  final double cpuGateBitrateMbps;
  final double maxSenderCpuPercentAtGate;

  CastProxyBenchmarkEvaluation evaluate(CastProxyBenchmarkSample sample) {
    final violations = <CastProxyBenchmarkViolationCode>[];

    if (sample.duration < minimumDuration) {
      violations.add(CastProxyBenchmarkViolationCode.benchmarkDurationTooShort);
    }
    if (sample.throughputRatio < minimumThroughputRatio) {
      violations.add(CastProxyBenchmarkViolationCode.throughputBelowTarget);
    }
    if (sample.targetBitrateMbps >= cpuGateBitrateMbps &&
        sample.senderCpuPercent > maxSenderCpuPercentAtGate) {
      violations.add(CastProxyBenchmarkViolationCode.senderCpuExceeded);
    }
    if (sample.droppedConnectionCount > 0) {
      violations.add(
        CastProxyBenchmarkViolationCode.droppedConnectionsObserved,
      );
    }

    final decision = _decisionFor(violations);
    return CastProxyBenchmarkEvaluation(
      sample: sample,
      decision: decision,
      violations: violations.isEmpty
          ? const [CastProxyBenchmarkViolationCode.accepted]
          : violations,
    );
  }

  CastProxyBenchmarkDecision _decisionFor(
    List<CastProxyBenchmarkViolationCode> violations,
  ) {
    if (violations.isEmpty) return CastProxyBenchmarkDecision.accepted;
    if (violations.length == 1 &&
        violations.first ==
            CastProxyBenchmarkViolationCode.benchmarkDurationTooShort) {
      return CastProxyBenchmarkDecision.rerunRequired;
    }
    return CastProxyBenchmarkDecision.investigateNativeDataPlane;
  }

  @override
  List<Object?> get props => [
    minimumDuration,
    minimumThroughputRatio,
    cpuGateBitrateMbps,
    maxSenderCpuPercentAtGate,
  ];
}
