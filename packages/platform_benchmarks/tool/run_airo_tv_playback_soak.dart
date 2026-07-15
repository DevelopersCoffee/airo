import 'dart:io';

import 'package:platform_benchmarks/src/airo_tv_playback_soak_runner.dart';
import 'package:platform_device_profile/platform_device_profile.dart';

Future<void> main(List<String> args) async {
  final options = _CliOptions.parse(args);
  final runner = AiroTvPlaybackSoakRunner();
  final report = await runner.write(
    AiroTvPlaybackSoakConfig(
      adbPath: options.adbPath,
      packageName: options.packageName,
      reportId: options.reportId,
      scenarioId: options.scenarioId,
      duration: Duration(seconds: options.durationSeconds),
      sampleInterval: Duration(seconds: options.intervalSeconds),
      budget: options.budget,
      dartHeapStartMb: options.dartHeapStartMb,
      dartHeapEndMb: options.dartHeapEndMb,
      imageCacheMb: options.imageCacheMb,
      retainedChannelListCopies: options.retainedChannelListCopies,
      launchBeforeRun: options.launchBeforeRun,
      keyEvents: options.keyEvents,
      outputJsonPath: options.outputJsonPath,
      outputMarkdownPath: options.outputMarkdownPath,
    ),
  );
  stdout.writeln(report.toMarkdown());
  if (!report.evaluate().accepted) {
    exitCode = 1;
  }
}

class _CliOptions {
  const _CliOptions({
    required this.packageName,
    required this.adbPath,
    required this.reportId,
    required this.scenarioId,
    required this.durationSeconds,
    required this.intervalSeconds,
    required this.budget,
    required this.dartHeapStartMb,
    required this.dartHeapEndMb,
    required this.imageCacheMb,
    required this.retainedChannelListCopies,
    required this.launchBeforeRun,
    required this.keyEvents,
    required this.outputJsonPath,
    required this.outputMarkdownPath,
  });

  final String packageName;
  final String adbPath;
  final String reportId;
  final String scenarioId;
  final int durationSeconds;
  final int intervalSeconds;
  final AiroRuntimeMemoryBudget budget;
  final int dartHeapStartMb;
  final int dartHeapEndMb;
  final int imageCacheMb;
  final int retainedChannelListCopies;
  final bool launchBeforeRun;
  final List<String> keyEvents;
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
      reportId: values['report-id'] ?? 'airo-tv-playback-soak',
      scenarioId: values['scenario-id'] ?? 'manual-tv-playback-soak',
      durationSeconds: _durationSeconds(values),
      intervalSeconds: _parseInt(values['interval-seconds'], fallback: 30),
      budget: _budgetFor(values['budget'] ?? 'constrained'),
      dartHeapStartMb: values['dart-heap-start-mb'] == null
          ? _usage('Missing --dart-heap-start-mb')
          : _parseInt(values['dart-heap-start-mb'], fallback: 0),
      dartHeapEndMb: values['dart-heap-end-mb'] == null
          ? _usage('Missing --dart-heap-end-mb')
          : _parseInt(values['dart-heap-end-mb'], fallback: 0),
      imageCacheMb: _parseInt(values['image-cache-mb'], fallback: 0),
      retainedChannelListCopies: _parseInt(
        values['retained-channel-list-copies'],
        fallback: 1,
      ),
      launchBeforeRun: _parseBool(values['launch'], fallback: true),
      keyEvents: _parseKeyEvents(values['key-events']),
      outputJsonPath:
          values['output-json'] ??
          'artifacts/performance/airo-tv-playback-soak-report.json',
      outputMarkdownPath:
          values['output-markdown'] ??
          'artifacts/performance/airo-tv-playback-soak-report.md',
    );
  }

  static int _durationSeconds(Map<String, String> values) {
    if (values['duration-seconds'] != null) {
      return _parseInt(values['duration-seconds'], fallback: 1800);
    }
    final minutes = _parseInt(values['duration-minutes'], fallback: 30);
    return minutes * 60;
  }

  static int _parseInt(String? value, {required int fallback}) {
    if (value == null) return fallback;
    return int.tryParse(value) ?? _usage('Invalid integer: $value');
  }

  static bool _parseBool(String? value, {required bool fallback}) {
    if (value == null) return fallback;
    return switch (value.trim().toLowerCase()) {
      'true' || '1' || 'yes' => true,
      'false' || '0' || 'no' => false,
      _ => _usage('Invalid boolean: $value'),
    };
  }

  static List<String> _parseKeyEvents(String? value) {
    if (value == null || value.trim().isEmpty) {
      return kDefaultAiroTvPlaybackSoakKeyEvents;
    }
    return value
        .split(',')
        .map((event) => event.trim())
        .where((event) => event.isNotEmpty)
        .toList(growable: false);
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
  dart run tool/run_airo_tv_playback_soak.dart \\
    --package io.airo.app.tv \\
    --duration-minutes 30 \\
    --interval-seconds 30 \\
    --budget constrained \\
    --dart-heap-start-mb 42 \\
    --dart-heap-end-mb 42 \\
    --output-json artifacts/performance/airo-tv-playback-soak-report.json \\
    --output-markdown artifacts/performance/airo-tv-playback-soak-report.md

Budgets: constrained|1gb, standard|2gb, expanded|3gb.
Optional fields: --adb, --report-id, --scenario-id, --duration-seconds,
--image-cache-mb, --retained-channel-list-copies, --launch true|false,
--key-events DPAD_DOWN,DPAD_CENTER,MEDIA_PLAY_PAUSE.

Use Dart heap values from start/end DevTools snapshots. The command writes
sanitized aggregate evidence and exits nonzero when the memory budget fails.
''');
    exit(exitCode);
  }
}
