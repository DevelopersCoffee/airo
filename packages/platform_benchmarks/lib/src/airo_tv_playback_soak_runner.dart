import 'dart:convert';
import 'dart:io';

import 'package:platform_device_profile/platform_device_profile.dart';

import 'airo_tv_adb_memory_timeline_capture.dart';

const String kAiroTvPlaybackSoakSchemaVersion = '1.0.0';

const List<String> kDefaultAiroTvPlaybackSoakKeyEvents = [
  'DPAD_DOWN',
  'DPAD_CENTER',
  'MEDIA_PLAY_PAUSE',
  'MEDIA_PLAY_PAUSE',
  'DPAD_DOWN',
  'DPAD_CENTER',
];

class AiroTvPlaybackSoakConfig {
  const AiroTvPlaybackSoakConfig({
    required this.packageName,
    this.adbPath = 'adb',
    this.reportId = 'airo-tv-playback-soak',
    this.scenarioId = 'manual-tv-playback-soak',
    this.duration = const Duration(minutes: 30),
    this.sampleInterval = const Duration(seconds: 30),
    this.budget = AiroRuntimeMemoryBudgetPolicy.androidTvConstrainedBudget,
    this.dartHeapStartMb = 0,
    this.dartHeapEndMb = 0,
    this.imageCacheMb = 0,
    this.retainedChannelListCopies = 1,
    this.launchBeforeRun = true,
    this.keyEvents = kDefaultAiroTvPlaybackSoakKeyEvents,
    this.outputJsonPath =
        'artifacts/performance/airo-tv-playback-soak-report.json',
    this.outputMarkdownPath =
        'artifacts/performance/airo-tv-playback-soak-report.md',
  });

  final String adbPath;
  final String packageName;
  final String reportId;
  final String scenarioId;
  final Duration duration;
  final Duration sampleInterval;
  final AiroRuntimeMemoryBudget budget;
  final int dartHeapStartMb;
  final int dartHeapEndMb;
  final int imageCacheMb;
  final int retainedChannelListCopies;
  final bool launchBeforeRun;
  final List<String> keyEvents;
  final String outputJsonPath;
  final String outputMarkdownPath;

  int get sampleCount {
    final durationMs = duration.inMilliseconds;
    final intervalMs = sampleInterval.inMilliseconds;
    return (durationMs + intervalMs - 1) ~/ intervalMs + 1;
  }

  AiroTvPlaybackSoakConfig normalized() {
    final normalizedPackage = packageName.trim();
    if (normalizedPackage.isEmpty) {
      throw ArgumentError.value(
        packageName,
        'packageName',
        'must not be empty',
      );
    }
    if (duration <= Duration.zero) {
      throw ArgumentError.value(duration, 'duration', 'must be > 0');
    }
    if (sampleInterval <= Duration.zero) {
      throw ArgumentError.value(
        sampleInterval,
        'sampleInterval',
        'must be > 0',
      );
    }
    final normalizedKeyEvents = keyEvents
        .map((event) => event.trim())
        .where((event) => event.isNotEmpty)
        .toList(growable: false);
    if (normalizedKeyEvents.isEmpty) {
      throw ArgumentError.value(keyEvents, 'keyEvents', 'must not be empty');
    }
    return AiroTvPlaybackSoakConfig(
      adbPath: adbPath.trim().isEmpty ? 'adb' : adbPath.trim(),
      packageName: normalizedPackage,
      reportId: reportId.trim().isEmpty
          ? 'airo-tv-playback-soak'
          : reportId.trim(),
      scenarioId: scenarioId.trim().isEmpty
          ? 'manual-tv-playback-soak'
          : scenarioId.trim(),
      duration: duration,
      sampleInterval: sampleInterval,
      budget: budget,
      dartHeapStartMb: dartHeapStartMb < 0 ? 0 : dartHeapStartMb,
      dartHeapEndMb: dartHeapEndMb < 0 ? 0 : dartHeapEndMb,
      imageCacheMb: imageCacheMb < 0 ? 0 : imageCacheMb,
      retainedChannelListCopies: retainedChannelListCopies < 0
          ? 0
          : retainedChannelListCopies,
      launchBeforeRun: launchBeforeRun,
      keyEvents: normalizedKeyEvents,
      outputJsonPath: outputJsonPath,
      outputMarkdownPath: outputMarkdownPath,
    );
  }
}

class AiroTvPlaybackSoakRunner {
  const AiroTvPlaybackSoakRunner({
    AiroProcessRunner? processRunner,
    AiroDelay? delay,
    DateTime Function()? clock,
  }) : _processRunner = processRunner ?? Process.run,
       _delay = delay ?? Future<void>.delayed,
       _clock = clock ?? DateTime.now;

  final AiroProcessRunner _processRunner;
  final AiroDelay _delay;
  final DateTime Function() _clock;

  Future<AiroRuntimeMemoryTimelineReport> run(
    AiroTvPlaybackSoakConfig rawConfig,
  ) async {
    final config = rawConfig.normalized();
    final points = <AiroRuntimeMemoryTimelinePoint>[];

    if (config.launchBeforeRun) {
      await _runAdb(config, [
        'shell',
        'monkey',
        '-p',
        config.packageName,
        '-c',
        'android.intent.category.LAUNCHER',
        '1',
      ], context: 'launch ${config.packageName}');
    }

    var elapsed = Duration.zero;
    for (var index = 0; index < config.sampleCount; index++) {
      if (index > 0) {
        final nextElapsed = _minDuration(
          config.duration,
          config.sampleInterval * index,
        );
        await _delay(nextElapsed - elapsed);
        elapsed = nextElapsed;
        final keyEvent =
            config.keyEvents[(index - 1) % config.keyEvents.length];
        await _runAdb(config, [
          'shell',
          'input',
          'keyevent',
          keyEvent,
        ], context: 'keyevent $keyEvent');
      }

      final result = await _runAdb(config, [
        'shell',
        'dumpsys',
        'meminfo',
        config.packageName,
      ], context: 'meminfo ${config.packageName}');
      final rssMb = AiroTvMeminfoParser.parseTotalRssMb('${result.stdout}');
      points.add(
        AiroRuntimeMemoryTimelinePoint(
          pointId: 'soak-sample-${index + 1}',
          sampledAt: _clock().toUtc(),
          rssMb: rssMb,
          dartHeapMb: _interpolate(
            start: config.dartHeapStartMb,
            end: config.dartHeapEndMb,
            index: index,
            sampleCount: config.sampleCount,
          ),
          imageCacheMb: config.imageCacheMb,
          retainedChannelListCopies: config.retainedChannelListCopies,
        ),
      );
    }

    return AiroRuntimeMemoryTimelineReport(
      reportId: config.reportId,
      scenarioId: config.scenarioId,
      budget: config.budget,
      points: points,
    );
  }

  Future<AiroRuntimeMemoryTimelineReport> write(
    AiroTvPlaybackSoakConfig rawConfig,
  ) async {
    final config = rawConfig.normalized();
    final report = await run(config);
    final jsonFile = File(config.outputJsonPath);
    await jsonFile.parent.create(recursive: true);
    await jsonFile.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(report.toPublicMap())}\n',
    );

    final markdownFile = File(config.outputMarkdownPath);
    await markdownFile.parent.create(recursive: true);
    await markdownFile.writeAsString(report.toMarkdown());
    return report;
  }

  Future<ProcessResult> _runAdb(
    AiroTvPlaybackSoakConfig config,
    List<String> arguments, {
    required String context,
  }) async {
    final result = await _processRunner(config.adbPath, arguments);
    if (result.exitCode != 0) {
      throw StateError('adb $context failed: ${result.stderr}'.trim());
    }
    return result;
  }

  static Duration _minDuration(Duration first, Duration second) {
    return first < second ? first : second;
  }

  static int _interpolate({
    required int start,
    required int end,
    required int index,
    required int sampleCount,
  }) {
    if (sampleCount <= 1 || start == end) return start;
    final delta = end - start;
    return start + (delta * index / (sampleCount - 1)).round();
  }
}
