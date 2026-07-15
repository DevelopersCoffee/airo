import 'dart:convert';
import 'dart:io';

import 'package:platform_player/cast_proxy_benchmark.dart';

const String kCastProxyBenchmarkReportSchemaVersion = '1.0.0';

class CastProxyBenchmarkReportConfig {
  const CastProxyBenchmarkReportConfig({
    required this.sampleId,
    required this.scenarioId,
    required this.targetBitrateMbps,
    required this.observedThroughputMbps,
    required this.senderCpuPercent,
    required this.durationSeconds,
    required this.droppedConnectionCount,
    this.batteryDrainPercentPerHour,
    this.measuredAt,
    this.outputJsonPath = 'artifacts/performance/cast-proxy-benchmark.json',
    this.outputMarkdownPath = 'artifacts/performance/cast-proxy-benchmark.md',
  });

  final String sampleId;
  final String scenarioId;
  final double targetBitrateMbps;
  final double observedThroughputMbps;
  final double senderCpuPercent;
  final int durationSeconds;
  final int droppedConnectionCount;
  final double? batteryDrainPercentPerHour;
  final DateTime? measuredAt;
  final String outputJsonPath;
  final String outputMarkdownPath;

  CastProxyBenchmarkReportConfig normalized() {
    final normalizedSampleId = sampleId.trim();
    final normalizedScenarioId = scenarioId.trim();
    if (normalizedSampleId.isEmpty) {
      throw ArgumentError.value(sampleId, 'sampleId', 'must not be empty');
    }
    if (normalizedScenarioId.isEmpty) {
      throw ArgumentError.value(scenarioId, 'scenarioId', 'must not be empty');
    }
    _validatePublicLabel(normalizedSampleId, 'sampleId');
    _validatePublicLabel(normalizedScenarioId, 'scenarioId');
    if (targetBitrateMbps <= 0) {
      throw ArgumentError.value(
        targetBitrateMbps,
        'targetBitrateMbps',
        'must be > 0',
      );
    }
    if (observedThroughputMbps < 0) {
      throw ArgumentError.value(
        observedThroughputMbps,
        'observedThroughputMbps',
        'must be >= 0',
      );
    }
    if (senderCpuPercent < 0) {
      throw ArgumentError.value(
        senderCpuPercent,
        'senderCpuPercent',
        'must be >= 0',
      );
    }
    if (durationSeconds <= 0) {
      throw ArgumentError.value(
        durationSeconds,
        'durationSeconds',
        'must be > 0',
      );
    }
    if (droppedConnectionCount < 0) {
      throw ArgumentError.value(
        droppedConnectionCount,
        'droppedConnectionCount',
        'must be >= 0',
      );
    }
    if (batteryDrainPercentPerHour != null && batteryDrainPercentPerHour! < 0) {
      throw ArgumentError.value(
        batteryDrainPercentPerHour,
        'batteryDrainPercentPerHour',
        'must be >= 0',
      );
    }
    return CastProxyBenchmarkReportConfig(
      sampleId: normalizedSampleId,
      scenarioId: normalizedScenarioId,
      targetBitrateMbps: targetBitrateMbps,
      observedThroughputMbps: observedThroughputMbps,
      senderCpuPercent: senderCpuPercent,
      durationSeconds: durationSeconds,
      droppedConnectionCount: droppedConnectionCount,
      batteryDrainPercentPerHour: batteryDrainPercentPerHour,
      measuredAt: (measuredAt ?? DateTime.now()).toUtc(),
      outputJsonPath: outputJsonPath,
      outputMarkdownPath: outputMarkdownPath,
    );
  }
}

void _validatePublicLabel(String value, String name) {
  final lower = value.toLowerCase();
  final hasUrl =
      lower.contains('://') ||
      lower.contains('http.') ||
      lower.contains('https.');
  final hasIpAddress = RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b').hasMatch(value);
  final hasLocalPath =
      lower.startsWith('/users/') ||
      lower.startsWith('/var/') ||
      lower.startsWith('/private/') ||
      RegExp(r'^[a-z]:[\\/]', caseSensitive: false).hasMatch(value);

  if (hasUrl || hasIpAddress || hasLocalPath) {
    throw ArgumentError.value(
      value,
      name,
      'must be a stable public label, not a URL, IP address, or local path',
    );
  }
}

class CastProxyBenchmarkReportWriter {
  const CastProxyBenchmarkReportWriter({
    this.policy = const CastProxyBenchmarkPolicy(),
  });

  final CastProxyBenchmarkPolicy policy;

  CastProxyBenchmarkEvaluation evaluate(
    CastProxyBenchmarkReportConfig rawConfig,
  ) {
    final config = rawConfig.normalized();
    return policy.evaluate(
      CastProxyBenchmarkSample(
        sampleId: config.sampleId,
        scenarioId: config.scenarioId,
        targetBitrateMbps: config.targetBitrateMbps,
        observedThroughputMbps: config.observedThroughputMbps,
        senderCpuPercent: config.senderCpuPercent,
        duration: Duration(seconds: config.durationSeconds),
        droppedConnectionCount: config.droppedConnectionCount,
        batteryDrainPercentPerHour: config.batteryDrainPercentPerHour,
        measuredAt: config.measuredAt!,
      ),
    );
  }

  Future<CastProxyBenchmarkEvaluation> write(
    CastProxyBenchmarkReportConfig rawConfig,
  ) async {
    final config = rawConfig.normalized();
    final evaluation = evaluate(config);
    final jsonFile = File(config.outputJsonPath);
    await jsonFile.parent.create(recursive: true);
    await jsonFile.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(_publicArtifact(evaluation))}\n',
    );

    final markdownFile = File(config.outputMarkdownPath);
    await markdownFile.parent.create(recursive: true);
    await markdownFile.writeAsString(evaluation.toMarkdown());
    return evaluation;
  }

  Map<String, Object?> _publicArtifact(
    CastProxyBenchmarkEvaluation evaluation,
  ) {
    return {
      'schemaVersion': kCastProxyBenchmarkReportSchemaVersion,
      'capturedAt': DateTime.now().toUtc().toIso8601String(),
      'evaluation': evaluation.toPublicMap(),
    };
  }
}
