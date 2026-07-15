import 'dart:io';

import 'package:platform_benchmarks/src/cast_proxy_benchmark_report.dart';

Future<void> main(List<String> args) async {
  final options = _CliOptions.parse(args);
  final writer = const CastProxyBenchmarkReportWriter();
  final evaluation = await writer.write(
    CastProxyBenchmarkReportConfig(
      sampleId: options.sampleId,
      scenarioId: options.scenarioId,
      targetBitrateMbps: options.targetBitrateMbps,
      observedThroughputMbps: options.observedThroughputMbps,
      senderCpuPercent: options.senderCpuPercent,
      durationSeconds: options.durationSeconds,
      droppedConnectionCount: options.droppedConnectionCount,
      batteryDrainPercentPerHour: options.batteryDrainPercentPerHour,
      outputJsonPath: options.outputJsonPath,
      outputMarkdownPath: options.outputMarkdownPath,
    ),
  );
  stdout.writeln(evaluation.toMarkdown());
}

class _CliOptions {
  const _CliOptions({
    required this.sampleId,
    required this.scenarioId,
    required this.targetBitrateMbps,
    required this.observedThroughputMbps,
    required this.senderCpuPercent,
    required this.durationSeconds,
    required this.droppedConnectionCount,
    required this.batteryDrainPercentPerHour,
    required this.outputJsonPath,
    required this.outputMarkdownPath,
  });

  final String sampleId;
  final String scenarioId;
  final double targetBitrateMbps;
  final double observedThroughputMbps;
  final double senderCpuPercent;
  final int durationSeconds;
  final int droppedConnectionCount;
  final double? batteryDrainPercentPerHour;
  final String outputJsonPath;
  final String outputMarkdownPath;

  static _CliOptions parse(List<String> args) {
    final values = <String, String>{};
    for (var index = 0; index < args.length; index++) {
      final arg = args[index];
      if (!arg.startsWith('--')) _usage('Unexpected argument: $arg');
      final key = arg.substring(2);
      if (key == 'help') _usage(null, exitCode: 0);
      if (index + 1 >= args.length || args[index + 1].startsWith('--')) {
        _usage('Missing value for --$key');
      }
      values[key] = args[++index];
    }

    return _CliOptions(
      sampleId: values['sample-id'] ?? _usage('Missing --sample-id'),
      scenarioId: values['scenario-id'] ?? '20mbps-10m-cast-relay',
      targetBitrateMbps: _parseDouble(
        values['target-mbps'],
        name: 'target-mbps',
      ),
      observedThroughputMbps: _parseDouble(
        values['observed-mbps'],
        name: 'observed-mbps',
      ),
      senderCpuPercent: _parseDouble(
        values['cpu-percent'],
        name: 'cpu-percent',
      ),
      durationSeconds: _parseInt(
        values['duration-seconds'],
        name: 'duration-seconds',
      ),
      droppedConnectionCount: _parseInt(
        values['dropped-connections'] ?? '0',
        name: 'dropped-connections',
      ),
      batteryDrainPercentPerHour: values['battery-percent-per-hour'] == null
          ? null
          : _parseDouble(
              values['battery-percent-per-hour'],
              name: 'battery-percent-per-hour',
            ),
      outputJsonPath:
          values['output-json'] ??
          'artifacts/performance/cast-proxy-benchmark.json',
      outputMarkdownPath:
          values['output-markdown'] ??
          'artifacts/performance/cast-proxy-benchmark.md',
    );
  }

  static int _parseInt(String? value, {required String name}) {
    if (value == null) _usage('Missing --$name');
    return int.tryParse(value) ?? _usage('Invalid integer for --$name: $value');
  }

  static double _parseDouble(String? value, {required String name}) {
    if (value == null) _usage('Missing --$name');
    return double.tryParse(value) ??
        _usage('Invalid number for --$name: $value');
  }

  static Never _usage(String? message, {int exitCode = 64}) {
    if (message != null) stderr.writeln(message);
    stderr.writeln('''
Usage:
  dart run tool/write_cast_proxy_benchmark_report.dart \\
    --sample-id pixel9-cast-proxy-20mbps \\
    --scenario-id 20mbps-10m-cast-relay \\
    --target-mbps 20 \\
    --observed-mbps 21.4 \\
    --cpu-percent 3.2 \\
    --duration-seconds 600 \\
    --dropped-connections 0 \\
    --battery-percent-per-hour 4.2

Outputs:
  artifacts/performance/cast-proxy-benchmark.json
  artifacts/performance/cast-proxy-benchmark.md
''');
    exit(exitCode);
  }
}
