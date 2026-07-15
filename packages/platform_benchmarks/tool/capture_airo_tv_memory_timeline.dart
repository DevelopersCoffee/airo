import 'dart:io';

import 'package:platform_benchmarks/src/airo_tv_adb_memory_timeline_capture.dart';
import 'package:platform_device_profile/platform_device_profile.dart';

Future<void> main(List<String> args) async {
  final options = _CliOptions.parse(args);
  final capture = AiroTvAdbMemoryTimelineCapture();
  final report = await capture.write(
    AiroTvAdbMemoryTimelineConfig(
      adbPath: options.adbPath,
      packageName: options.packageName,
      reportId: options.reportId,
      scenarioId: options.scenarioId,
      sampleCount: options.sampleCount,
      sampleInterval: Duration(seconds: options.intervalSeconds),
      budget: options.budget,
      dartHeapMb: options.dartHeapMb,
      imageCacheMb: options.imageCacheMb,
      retainedChannelListCopies: options.retainedChannelListCopies,
      outputJsonPath: options.outputJsonPath,
      outputMarkdownPath: options.outputMarkdownPath,
    ),
  );
  stdout.writeln(report.toMarkdown());
}

class _CliOptions {
  const _CliOptions({
    required this.packageName,
    required this.adbPath,
    required this.reportId,
    required this.scenarioId,
    required this.sampleCount,
    required this.intervalSeconds,
    required this.budget,
    required this.dartHeapMb,
    required this.imageCacheMb,
    required this.retainedChannelListCopies,
    required this.outputJsonPath,
    required this.outputMarkdownPath,
  });

  final String packageName;
  final String adbPath;
  final String reportId;
  final String scenarioId;
  final int sampleCount;
  final int intervalSeconds;
  final AiroRuntimeMemoryBudget budget;
  final int dartHeapMb;
  final int imageCacheMb;
  final int retainedChannelListCopies;
  final String outputJsonPath;
  final String outputMarkdownPath;

  static _CliOptions parse(List<String> args) {
    final values = <String, String>{};
    for (var index = 0; index < args.length; index++) {
      final arg = args[index];
      if (!arg.startsWith('--')) {
        _usage('Unexpected argument: $arg');
      }
      final key = arg.substring(2);
      if (key == 'help') _usage(null, exitCode: 0);
      if (index + 1 >= args.length || args[index + 1].startsWith('--')) {
        _usage('Missing value for --$key');
      }
      values[key] = args[++index];
    }

    return _CliOptions(
      packageName: values['package'] ?? _usage('Missing --package'),
      adbPath: values['adb'] ?? 'adb',
      reportId: values['report-id'] ?? 'airo-tv-adb-memory-timeline',
      scenarioId: values['scenario-id'] ?? 'manual-tv-memory-capture',
      sampleCount: _parseInt(values['samples'], fallback: 60),
      intervalSeconds: _parseInt(values['interval-seconds'], fallback: 30),
      budget: _budgetFor(values['budget'] ?? 'constrained'),
      dartHeapMb: _parseInt(values['dart-heap-mb'], fallback: 0),
      imageCacheMb: _parseInt(values['image-cache-mb'], fallback: 0),
      retainedChannelListCopies: _parseInt(
        values['retained-channel-list-copies'],
        fallback: 1,
      ),
      outputJsonPath:
          values['output-json'] ??
          'artifacts/performance/airo-tv-adb-memory-timeline.json',
      outputMarkdownPath:
          values['output-markdown'] ??
          'artifacts/performance/airo-tv-adb-memory-timeline.md',
    );
  }

  static int _parseInt(String? value, {required int fallback}) {
    if (value == null) return fallback;
    return int.tryParse(value) ?? _usage('Invalid integer: $value');
  }

  static AiroRuntimeMemoryBudget _budgetFor(String value) {
    return switch (value) {
      'constrained' ||
      '1gb' => AiroRuntimeMemoryBudgetPolicy.androidTvConstrainedBudget,
      'standard' ||
      '2gb' => AiroRuntimeMemoryBudgetPolicy.androidTvStandardBudget,
      'expanded' ||
      '3gb' => AiroRuntimeMemoryBudgetPolicy.androidTvExpandedBudget,
      _ => _usage('Unknown budget: $value'),
    };
  }

  static Never _usage(String? message, {int exitCode = 64}) {
    if (message != null) stderr.writeln(message);
    stderr.writeln('''
Usage:
  dart run tool/capture_airo_tv_memory_timeline.dart \\
    --package io.airo.app \\
    --samples 60 \\
    --interval-seconds 30 \\
    --budget constrained \\
    --output-json artifacts/performance/airo-tv-memory.json \\
    --output-markdown artifacts/performance/airo-tv-memory.md

Budgets: constrained|1gb, standard|2gb, expanded|3gb.
Optional aggregate fields: --dart-heap-mb, --image-cache-mb,
--retained-channel-list-copies.
''');
    exit(exitCode);
  }
}
