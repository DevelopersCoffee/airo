import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:platform_device_profile/platform_device_profile.dart';

typedef AiroProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);
typedef AiroDelay = Future<void> Function(Duration duration);

const String kAiroTvAdbMemoryTimelineSchemaVersion = '1.0.0';

class AiroTvAdbMemoryTimelineConfig {
  const AiroTvAdbMemoryTimelineConfig({
    required this.packageName,
    this.adbPath = 'adb',
    this.reportId = 'airo-tv-adb-memory-timeline',
    this.scenarioId = 'manual-tv-memory-capture',
    this.sampleCount = 60,
    this.sampleInterval = const Duration(seconds: 30),
    this.budget = AiroRuntimeMemoryBudgetPolicy.androidTvConstrainedBudget,
    this.dartHeapMb = 0,
    this.imageCacheMb = 0,
    this.retainedChannelListCopies = 1,
    this.outputJsonPath =
        'artifacts/performance/airo-tv-adb-memory-timeline.json',
    this.outputMarkdownPath =
        'artifacts/performance/airo-tv-adb-memory-timeline.md',
  });

  final String adbPath;
  final String packageName;
  final String reportId;
  final String scenarioId;
  final int sampleCount;
  final Duration sampleInterval;
  final AiroRuntimeMemoryBudget budget;
  final int dartHeapMb;
  final int imageCacheMb;
  final int retainedChannelListCopies;
  final String outputJsonPath;
  final String outputMarkdownPath;

  AiroTvAdbMemoryTimelineConfig normalized() {
    final normalizedPackage = packageName.trim();
    if (normalizedPackage.isEmpty) {
      throw ArgumentError.value(
        packageName,
        'packageName',
        'must not be empty',
      );
    }
    if (sampleCount <= 0) {
      throw ArgumentError.value(sampleCount, 'sampleCount', 'must be > 0');
    }
    if (sampleInterval.isNegative) {
      throw ArgumentError.value(
        sampleInterval,
        'sampleInterval',
        'must not be negative',
      );
    }
    return AiroTvAdbMemoryTimelineConfig(
      adbPath: adbPath.trim().isEmpty ? 'adb' : adbPath.trim(),
      packageName: normalizedPackage,
      reportId: reportId.trim().isEmpty
          ? 'airo-tv-adb-memory-timeline'
          : reportId.trim(),
      scenarioId: scenarioId.trim().isEmpty
          ? 'manual-tv-memory-capture'
          : scenarioId.trim(),
      sampleCount: sampleCount,
      sampleInterval: sampleInterval,
      budget: budget,
      dartHeapMb: dartHeapMb < 0 ? 0 : dartHeapMb,
      imageCacheMb: imageCacheMb < 0 ? 0 : imageCacheMb,
      retainedChannelListCopies: retainedChannelListCopies < 0
          ? 0
          : retainedChannelListCopies,
      outputJsonPath: outputJsonPath,
      outputMarkdownPath: outputMarkdownPath,
    );
  }
}

class AiroTvAdbMemoryTimelineCapture {
  const AiroTvAdbMemoryTimelineCapture({
    AiroProcessRunner? processRunner,
    AiroDelay? delay,
    DateTime Function()? clock,
  }) : _processRunner = processRunner ?? Process.run,
       _delay = delay ?? Future<void>.delayed,
       _clock = clock ?? DateTime.now;

  final AiroProcessRunner _processRunner;
  final AiroDelay _delay;
  final DateTime Function() _clock;

  Future<AiroRuntimeMemoryTimelineReport> capture(
    AiroTvAdbMemoryTimelineConfig rawConfig,
  ) async {
    final config = rawConfig.normalized();
    final points = <AiroRuntimeMemoryTimelinePoint>[];

    for (var index = 0; index < config.sampleCount; index++) {
      if (index > 0 && config.sampleInterval > Duration.zero) {
        await _delay(config.sampleInterval);
      }
      final result = await _processRunner(config.adbPath, [
        'shell',
        'dumpsys',
        'meminfo',
        config.packageName,
      ]);
      if (result.exitCode != 0) {
        throw StateError(
          'adb meminfo failed for ${config.packageName}: '
                  '${result.stderr}'
              .trim(),
        );
      }
      final rssMb = AiroTvMeminfoParser.parseTotalRssMb('${result.stdout}');
      points.add(
        AiroRuntimeMemoryTimelinePoint(
          pointId: 'sample-${index + 1}',
          sampledAt: _clock().toUtc(),
          rssMb: rssMb,
          dartHeapMb: config.dartHeapMb,
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
    AiroTvAdbMemoryTimelineConfig rawConfig,
  ) async {
    final config = rawConfig.normalized();
    final report = await capture(config);
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
}

class AiroTvMeminfoParser {
  const AiroTvMeminfoParser._();

  static int parseTotalRssMb(String output) {
    final totalRss = RegExp(
      r'^\s*TOTAL\s+RSS:\s*([0-9,]+)\s*K\b',
      multiLine: true,
    ).firstMatch(output);
    if (totalRss != null) {
      return _kilobytesToMegabytes(_parseNumber(totalRss.group(1)!));
    }

    final appSummary = RegExp(
      r'^\s*TOTAL:\s+[0-9,]+\s+([0-9,]+)\s*$',
      multiLine: true,
    ).firstMatch(output);
    if (appSummary != null) {
      return _kilobytesToMegabytes(_parseNumber(appSummary.group(1)!));
    }

    throw FormatException('Unable to find TOTAL RSS in adb meminfo output.');
  }

  static int _parseNumber(String value) => int.parse(value.replaceAll(',', ''));

  static int _kilobytesToMegabytes(int kilobytes) {
    return (kilobytes / 1024).ceil();
  }
}
