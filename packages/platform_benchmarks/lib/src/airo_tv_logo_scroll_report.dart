import 'dart:convert';
import 'dart:io';

import 'package:platform_device_profile/platform_device_profile.dart';

const String kAiroTvLogoScrollReportSchemaVersion = '1.0.0';

enum AiroTvLogoScrollViolationCode {
  accepted('accepted'),
  playlistTooSmall('playlist_too_small'),
  steadyRssExceeded('steady_rss_exceeded'),
  peakRssExceeded('peak_rss_exceeded'),
  rssDidNotPlateau('rss_did_not_plateau'),
  imageCacheExceeded('image_cache_exceeded'),
  frameJankDetected('frame_jank_detected'),
  decodeJankDetected('decode_jank_detected');

  const AiroTvLogoScrollViolationCode(this.stableId);

  final String stableId;
}

class AiroTvLogoScrollReportConfig {
  const AiroTvLogoScrollReportConfig({
    required this.reportId,
    required this.scenarioId,
    required this.playlistChannelCount,
    required this.visibleCellCount,
    required this.durationSeconds,
    required this.baselineRssMb,
    required this.peakRssMb,
    required this.steadyRssMb,
    required this.rssPlateauDeltaMb,
    required this.imageCachePeakMb,
    required this.frameJankCount,
    required this.decodeJankFrameCount,
    this.measuredAt,
    this.minPlaylistChannelCount = 10000,
    this.maxRssPlateauDeltaMb = 16,
    this.budget = AiroRuntimeMemoryBudgetPolicy.androidTvConstrainedBudget,
    this.outputJsonPath =
        'artifacts/performance/airo-tv-logo-scroll-report.json',
    this.outputMarkdownPath =
        'artifacts/performance/airo-tv-logo-scroll-report.md',
  });

  final String reportId;
  final String scenarioId;
  final int playlistChannelCount;
  final int visibleCellCount;
  final int durationSeconds;
  final int baselineRssMb;
  final int peakRssMb;
  final int steadyRssMb;
  final int rssPlateauDeltaMb;
  final int imageCachePeakMb;
  final int frameJankCount;
  final int decodeJankFrameCount;
  final DateTime? measuredAt;
  final int minPlaylistChannelCount;
  final int maxRssPlateauDeltaMb;
  final AiroRuntimeMemoryBudget budget;
  final String outputJsonPath;
  final String outputMarkdownPath;

  AiroTvLogoScrollReportConfig normalized() {
    final normalizedReportId = reportId.trim();
    final normalizedScenarioId = scenarioId.trim();
    if (normalizedReportId.isEmpty) {
      throw ArgumentError.value(reportId, 'reportId', 'must not be empty');
    }
    if (normalizedScenarioId.isEmpty) {
      throw ArgumentError.value(scenarioId, 'scenarioId', 'must not be empty');
    }
    _validatePublicLabel(normalizedReportId, 'reportId');
    _validatePublicLabel(normalizedScenarioId, 'scenarioId');
    _validatePositive(playlistChannelCount, 'playlistChannelCount');
    _validatePositive(visibleCellCount, 'visibleCellCount');
    _validatePositive(durationSeconds, 'durationSeconds');
    _validatePositive(baselineRssMb, 'baselineRssMb');
    _validatePositive(peakRssMb, 'peakRssMb');
    _validatePositive(steadyRssMb, 'steadyRssMb');
    _validateNonNegative(rssPlateauDeltaMb, 'rssPlateauDeltaMb');
    _validateNonNegative(imageCachePeakMb, 'imageCachePeakMb');
    _validateNonNegative(frameJankCount, 'frameJankCount');
    _validateNonNegative(decodeJankFrameCount, 'decodeJankFrameCount');
    _validatePositive(minPlaylistChannelCount, 'minPlaylistChannelCount');
    _validateNonNegative(maxRssPlateauDeltaMb, 'maxRssPlateauDeltaMb');
    if (peakRssMb < baselineRssMb) {
      throw ArgumentError.value(
        peakRssMb,
        'peakRssMb',
        'must be >= baselineRssMb',
      );
    }

    return AiroTvLogoScrollReportConfig(
      reportId: normalizedReportId,
      scenarioId: normalizedScenarioId,
      playlistChannelCount: playlistChannelCount,
      visibleCellCount: visibleCellCount,
      durationSeconds: durationSeconds,
      baselineRssMb: baselineRssMb,
      peakRssMb: peakRssMb,
      steadyRssMb: steadyRssMb,
      rssPlateauDeltaMb: rssPlateauDeltaMb,
      imageCachePeakMb: imageCachePeakMb,
      frameJankCount: frameJankCount,
      decodeJankFrameCount: decodeJankFrameCount,
      measuredAt: (measuredAt ?? DateTime.now()).toUtc(),
      minPlaylistChannelCount: minPlaylistChannelCount,
      maxRssPlateauDeltaMb: maxRssPlateauDeltaMb,
      budget: budget,
      outputJsonPath: outputJsonPath,
      outputMarkdownPath: outputMarkdownPath,
    );
  }
}

class AiroTvLogoScrollEvaluation {
  AiroTvLogoScrollEvaluation({
    required this.config,
    required Iterable<AiroTvLogoScrollViolationCode> violations,
  }) : violations = List.unmodifiable(violations);

  final AiroTvLogoScrollReportConfig config;
  final List<AiroTvLogoScrollViolationCode> violations;

  bool get accepted =>
      violations.length == 1 &&
      violations.first == AiroTvLogoScrollViolationCode.accepted;

  int get rssDeltaMb => config.peakRssMb - config.baselineRssMb;

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': kAiroTvLogoScrollReportSchemaVersion,
      'reportId': config.reportId,
      'scenarioId': config.scenarioId,
      'measuredAt': config.measuredAt!.toIso8601String(),
      'accepted': accepted,
      'violations': violations
          .map((violation) => violation.stableId)
          .toList(growable: false),
      'budget': {
        'budgetId': config.budget.budgetId,
        'maxSteadyRssMb': config.budget.maxSteadyRssMb,
        'maxPeakRssMb': config.budget.maxPeakRssMb,
        'imageCacheMb': config.budget.imageCacheMb,
      },
      'sample': {
        'playlistChannelCount': config.playlistChannelCount,
        'minPlaylistChannelCount': config.minPlaylistChannelCount,
        'visibleCellCount': config.visibleCellCount,
        'durationSeconds': config.durationSeconds,
        'baselineRssMb': config.baselineRssMb,
        'peakRssMb': config.peakRssMb,
        'steadyRssMb': config.steadyRssMb,
        'rssDeltaMb': rssDeltaMb,
        'rssPlateauDeltaMb': config.rssPlateauDeltaMb,
        'maxRssPlateauDeltaMb': config.maxRssPlateauDeltaMb,
        'imageCachePeakMb': config.imageCachePeakMb,
        'frameJankCount': config.frameJankCount,
        'decodeJankFrameCount': config.decodeJankFrameCount,
      },
    };
  }

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# Airo TV Logo Scroll Benchmark')
      ..writeln()
      ..writeln('- Report: `${config.reportId}`')
      ..writeln('- Scenario: `${config.scenarioId}`')
      ..writeln('- Accepted: `$accepted`')
      ..writeln(
        '- Violations: `${violations.map((code) => code.stableId).join(', ')}`',
      )
      ..writeln('- Playlist channels: ${config.playlistChannelCount}')
      ..writeln('- Visible cells: ${config.visibleCellCount}')
      ..writeln('- Duration: ${config.durationSeconds}s')
      ..writeln(
        '- RSS: baseline ${config.baselineRssMb} MB, peak '
        '${config.peakRssMb} MB, steady ${config.steadyRssMb} MB',
      )
      ..writeln(
        '- RSS plateau delta: ${config.rssPlateauDeltaMb} MB / '
        '${config.maxRssPlateauDeltaMb} MB',
      )
      ..writeln(
        '- Image cache peak: ${config.imageCachePeakMb} MB / '
        '${config.budget.imageCacheMb} MB',
      )
      ..writeln('- Frame jank count: ${config.frameJankCount}')
      ..writeln('- Decode jank frame count: ${config.decodeJankFrameCount}');
    return buffer.toString();
  }
}

class AiroTvLogoScrollReportWriter {
  const AiroTvLogoScrollReportWriter();

  AiroTvLogoScrollEvaluation evaluate(AiroTvLogoScrollReportConfig rawConfig) {
    final config = rawConfig.normalized();
    final violations = <AiroTvLogoScrollViolationCode>[];
    if (config.playlistChannelCount < config.minPlaylistChannelCount) {
      violations.add(AiroTvLogoScrollViolationCode.playlistTooSmall);
    }
    if (config.steadyRssMb > config.budget.maxSteadyRssMb) {
      violations.add(AiroTvLogoScrollViolationCode.steadyRssExceeded);
    }
    if (config.peakRssMb > config.budget.maxPeakRssMb) {
      violations.add(AiroTvLogoScrollViolationCode.peakRssExceeded);
    }
    if (config.rssPlateauDeltaMb > config.maxRssPlateauDeltaMb) {
      violations.add(AiroTvLogoScrollViolationCode.rssDidNotPlateau);
    }
    if (config.imageCachePeakMb > config.budget.imageCacheMb) {
      violations.add(AiroTvLogoScrollViolationCode.imageCacheExceeded);
    }
    if (config.frameJankCount > 0) {
      violations.add(AiroTvLogoScrollViolationCode.frameJankDetected);
    }
    if (config.decodeJankFrameCount > 0) {
      violations.add(AiroTvLogoScrollViolationCode.decodeJankDetected);
    }
    if (violations.isEmpty) {
      violations.add(AiroTvLogoScrollViolationCode.accepted);
    }
    return AiroTvLogoScrollEvaluation(config: config, violations: violations);
  }

  Future<AiroTvLogoScrollEvaluation> write(
    AiroTvLogoScrollReportConfig rawConfig,
  ) async {
    final evaluation = evaluate(rawConfig);
    final jsonFile = File(evaluation.config.outputJsonPath);
    await jsonFile.parent.create(recursive: true);
    await jsonFile.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(evaluation.toPublicMap())}\n',
    );

    final markdownFile = File(evaluation.config.outputMarkdownPath);
    await markdownFile.parent.create(recursive: true);
    await markdownFile.writeAsString(evaluation.toMarkdown());
    return evaluation;
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

void _validatePositive(int value, String name) {
  if (value <= 0) {
    throw ArgumentError.value(value, name, 'must be > 0');
  }
}

void _validateNonNegative(int value, String name) {
  if (value < 0) {
    throw ArgumentError.value(value, name, 'must be >= 0');
  }
}
