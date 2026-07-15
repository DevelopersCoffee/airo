import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:platform_benchmarks/platform_benchmarks.dart';
import 'package:platform_player/cast_proxy_benchmark.dart';

void main() {
  test('writes accepted cast proxy benchmark artifacts', () async {
    final directory = await Directory.systemTemp.createTemp(
      'cast-proxy-benchmark-report-test-',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final evaluation = await const CastProxyBenchmarkReportWriter().write(
      CastProxyBenchmarkReportConfig(
        sampleId: 'pixel9-cast-proxy-20mbps',
        scenarioId: '20mbps-10m-cast-relay',
        targetBitrateMbps: 20,
        observedThroughputMbps: 21.4,
        senderCpuPercent: 3.2,
        durationSeconds: 600,
        droppedConnectionCount: 0,
        batteryDrainPercentPerHour: 4.2,
        measuredAt: DateTime.utc(2026, 7, 15, 12),
        outputJsonPath: '${directory.path}/report.json',
        outputMarkdownPath: '${directory.path}/report.md',
      ),
    );

    expect(evaluation.accepted, isTrue);
    final json =
        jsonDecode(await File('${directory.path}/report.json').readAsString())
            as Map<String, Object?>;
    final markdown = await File('${directory.path}/report.md').readAsString();

    expect(json, containsPair('schemaVersion', '1.0.0'));
    expect(json.toString(), isNot(contains('http://')));
    expect(json.toString(), isNot(contains('192.168.')));
    expect(markdown, contains('# Cast Proxy Benchmark'));
    expect(markdown, contains('accepted'));
  });

  test('marks CPU-heavy cast proxy samples for native investigation', () {
    final evaluation = const CastProxyBenchmarkReportWriter().evaluate(
      CastProxyBenchmarkReportConfig(
        sampleId: 'cpu-heavy',
        scenarioId: '20mbps-10m-cast-relay',
        targetBitrateMbps: 20,
        observedThroughputMbps: 20,
        senderCpuPercent: 7,
        durationSeconds: 600,
        droppedConnectionCount: 0,
        measuredAt: DateTime.utc(2026, 7, 15, 12),
      ),
    );

    expect(
      evaluation.decision,
      CastProxyBenchmarkDecision.investigateNativeDataPlane,
    );
    expect(
      evaluation.violations,
      contains(CastProxyBenchmarkViolationCode.senderCpuExceeded),
    );
  });

  test('rejects incomplete metric input before writing artifacts', () {
    expect(
      () => const CastProxyBenchmarkReportConfig(
        sampleId: '',
        scenarioId: '20mbps-10m-cast-relay',
        targetBitrateMbps: 20,
        observedThroughputMbps: 20,
        senderCpuPercent: 2,
        durationSeconds: 600,
        droppedConnectionCount: 0,
      ).normalized(),
      throwsArgumentError,
    );
  });

  test('rejects private labels before writing artifacts', () {
    expect(
      () => const CastProxyBenchmarkReportConfig(
        sampleId: 'http://example.test/private-stream.m3u8',
        scenarioId: '20mbps-10m-cast-relay',
        targetBitrateMbps: 20,
        observedThroughputMbps: 20,
        senderCpuPercent: 2,
        durationSeconds: 600,
        droppedConnectionCount: 0,
      ).normalized(),
      throwsArgumentError,
    );
  });
}
