import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:core_media_data/core_media_data.dart';
import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';
import 'package:platform_channels/channel_search.dart';
import 'package:platform_playlist_import/m3u_playlist_parser.dart';

const String kAiroTvHostBenchmarkSchemaVersion = '1.0.0';

class AiroTvHostBenchmarkConfig extends Equatable {
  const AiroTvHostBenchmarkConfig({
    this.channelCount = 2000,
    this.iterations = 5,
    this.outputPath = 'artifacts/performance/airo-tv-host-benchmark.json',
    this.deviceClass = 'host_local',
    this.fixturePath,
    this.fixtureId,
  });

  final int channelCount;
  final int iterations;
  final String outputPath;
  final String deviceClass;
  final String? fixturePath;
  final String? fixtureId;

  AiroTvHostBenchmarkConfig normalized() {
    final normalizedFixturePath = fixturePath?.trim();
    final normalizedFixtureId = fixtureId?.trim();
    return AiroTvHostBenchmarkConfig(
      channelCount: math.max(channelCount, 1),
      iterations: math.max(iterations, 5),
      outputPath: outputPath,
      deviceClass: deviceClass.trim().isEmpty ? 'host_local' : deviceClass,
      fixturePath:
          normalizedFixturePath == null || normalizedFixturePath.isEmpty
          ? null
          : normalizedFixturePath,
      fixtureId: normalizedFixtureId == null || normalizedFixtureId.isEmpty
          ? null
          : normalizedFixtureId,
    );
  }

  @override
  List<Object?> get props => [
    channelCount,
    iterations,
    outputPath,
    deviceClass,
    fixturePath,
    fixtureId,
  ];
}

class AiroTvHostBenchmarkArtifact extends Equatable {
  const AiroTvHostBenchmarkArtifact({
    required this.schemaVersion,
    required this.deviceClass,
    required this.capturedAt,
    required this.iterations,
    required this.channelCount,
    required this.fixture,
    required this.plan,
    required this.run,
    required this.evaluation,
    required this.host,
  });

  final String schemaVersion;
  final String deviceClass;
  final DateTime capturedAt;
  final int iterations;
  final int channelCount;
  final AiroTvBenchmarkFixtureInfo fixture;
  final AiroMediaDatabaseBenchmarkPlan plan;
  final AiroMediaDatabaseBenchmarkRun run;
  final AiroMediaDatabaseBenchmarkEvaluation evaluation;
  final AiroTvHostBenchmarkHost host;

  bool get accepted => evaluation.accepted;

  Map<String, Object?> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'deviceClass': deviceClass,
      'capturedAt': capturedAt.toUtc().toIso8601String(),
      'iterations': iterations,
      'channelCount': channelCount,
      'fixture': fixture.toJson(),
      'host': host.toJson(),
      'plan': {
        'schemaVersion': plan.schemaVersion,
        'planId': plan.planId,
        'dataset': {
          'schemaVersion': plan.dataset.schemaVersion,
          'profileId': plan.dataset.profileId,
          'kind': plan.dataset.kind.stableId,
          'liveChannelCount': plan.dataset.liveChannelCount,
          'vodItemCount': plan.dataset.vodItemCount,
          'epgProgramCount': plan.dataset.epgProgramCount,
          'playlistSourceCount': plan.dataset.playlistSourceCount,
          'metadataFieldCount': plan.dataset.metadataFieldCount,
        },
        'steps': plan.steps.map(_stepToJson).toList(growable: false),
        'requiredMetrics': plan.requiredMetrics
            .map((metric) => metric.stableId)
            .toList(growable: false),
        'budget': {
          'schemaVersion': plan.budget.schemaVersion,
          'maxElapsedMillis': plan.budget.maxElapsedMillis,
          'maxPeakMemoryMb': plan.budget.maxPeakMemoryMb,
          'maxStorageMb': plan.budget.maxStorageMb,
          'minRowsPerSecond': plan.budget.minRowsPerSecond,
        },
      },
      'run': {
        'schemaVersion': run.schemaVersion,
        'planId': run.planId,
        'runnerId': run.runnerId,
        'totalElapsedMillis': run.totalElapsedMillis,
        'peakMemoryMb': run.peakMemoryMb,
        'minRowsPerSecond': run.minRowsPerSecond,
        'failedStepIds': run.failedStepIds.toList(growable: false),
        'samples': run.samples.map(_sampleToJson).toList(growable: false),
      },
      'evaluation': {
        'planId': evaluation.planId,
        'runnerId': evaluation.runnerId,
        'accepted': evaluation.accepted,
        'blockers': evaluation.blockers
            .map((blocker) => blocker.stableId)
            .toList(growable: false),
      },
    };
  }

  String toPrettyJson() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    deviceClass,
    capturedAt,
    iterations,
    channelCount,
    fixture,
    plan,
    run,
    evaluation,
    host,
  ];
}

class AiroTvBenchmarkFixtureInfo extends Equatable {
  const AiroTvBenchmarkFixtureInfo({
    required this.fixtureId,
    required this.sourceKind,
    required this.byteCount,
    required this.sha256,
  });

  final String fixtureId;
  final String sourceKind;
  final int byteCount;
  final String sha256;

  Map<String, Object?> toJson() {
    return {
      'fixtureId': fixtureId,
      'sourceKind': sourceKind,
      'byteCount': byteCount,
      'sha256': sha256,
    };
  }

  @override
  List<Object?> get props => [fixtureId, sourceKind, byteCount, sha256];
}

class AiroTvHostBenchmarkHost extends Equatable {
  const AiroTvHostBenchmarkHost({
    required this.operatingSystem,
    required this.operatingSystemVersion,
    required this.dartVersion,
  });

  factory AiroTvHostBenchmarkHost.current() {
    return AiroTvHostBenchmarkHost(
      operatingSystem: Platform.operatingSystem,
      operatingSystemVersion: Platform.operatingSystemVersion,
      dartVersion: Platform.version,
    );
  }

  final String operatingSystem;
  final String operatingSystemVersion;
  final String dartVersion;

  Map<String, Object?> toJson() {
    return {
      'operatingSystem': operatingSystem,
      'operatingSystemVersion': operatingSystemVersion,
      'dartVersion': dartVersion,
    };
  }

  @override
  List<Object?> get props => [
    operatingSystem,
    operatingSystemVersion,
    dartVersion,
  ];
}

class AiroTvHostBenchmarkRunner {
  const AiroTvHostBenchmarkRunner({
    this.policy = const AiroMediaDatabaseBenchmarkPolicy(),
  });

  final AiroMediaDatabaseBenchmarkPolicy policy;

  Future<AiroTvHostBenchmarkArtifact> run(
    AiroTvHostBenchmarkConfig rawConfig,
  ) async {
    final config = rawConfig.normalized();
    final input = await _loadInput(config);
    final m3u = input.content;
    final queries = input.searchQueries;

    final parseRuns = <_TimedParseRun>[];
    final searchRuns = <_TimedSearchRun>[];

    for (var i = 0; i < config.iterations; i++) {
      final parseStopwatch = Stopwatch()..start();
      final channels = parseM3UDartChannels(m3u);
      parseStopwatch.stop();
      parseRuns.add(
        _TimedParseRun(
          elapsed: parseStopwatch.elapsed,
          channelCount: channels.length,
        ),
      );

      final searchStopwatch = Stopwatch()..start();
      final index = AiroChannelSearchIndex(channels);
      var resultCount = 0;
      for (final query in queries) {
        resultCount += index.filterAndSort(query: query).length;
      }
      searchStopwatch.stop();
      searchRuns.add(
        _TimedSearchRun(
          elapsed: searchStopwatch.elapsed,
          channelCount: channels.length,
          queryCount: queries.length,
          resultCount: resultCount,
        ),
      );
    }

    final channelCount = _medianParse(parseRuns).channelCount;
    final plan = _plan(
      fixture: input.fixture,
      channelCount: channelCount,
      queryCount: queries.length,
    );
    final run = AiroMediaDatabaseBenchmarkRun(
      planId: plan.planId,
      runnerId: 'airo-tv-host-smoke',
      samples: [
        _parseSample(_medianParse(parseRuns)),
        _searchSample(_medianSearch(searchRuns)),
      ],
    );
    final evaluation = policy.evaluate(plan: plan, run: run);
    return AiroTvHostBenchmarkArtifact(
      schemaVersion: kAiroTvHostBenchmarkSchemaVersion,
      deviceClass: config.deviceClass,
      capturedAt: DateTime.now(),
      iterations: config.iterations,
      channelCount: channelCount,
      fixture: input.fixture,
      plan: plan,
      run: run,
      evaluation: evaluation,
      host: AiroTvHostBenchmarkHost.current(),
    );
  }

  Future<AiroTvHostBenchmarkArtifact> runAndWrite(
    AiroTvHostBenchmarkConfig config,
  ) async {
    final artifact = await run(config);
    final file = File(config.normalized().outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsString('${artifact.toPrettyJson()}\n');
    return artifact;
  }

  Future<_AiroTvBenchmarkInput> _loadInput(
    AiroTvHostBenchmarkConfig config,
  ) async {
    final fixturePath = config.fixturePath;
    if (fixturePath != null) {
      final bytes = await File(fixturePath).readAsBytes();
      return _AiroTvBenchmarkInput(
        content: utf8.decode(bytes),
        searchQueries: const ['news', 'sports', 'music', 'kids', 'global'],
        fixture: AiroTvBenchmarkFixtureInfo(
          fixtureId: config.fixtureId ?? 'file-backed-m3u',
          sourceKind: 'file_m3u',
          byteCount: bytes.length,
          sha256: sha256.convert(bytes).toString(),
        ),
      );
    }

    final fixture = AiroTvSyntheticPlaylistFixture(
      channelCount: config.channelCount,
    );
    final content = fixture.toM3u();
    final bytes = utf8.encode(content);
    return _AiroTvBenchmarkInput(
      content: content,
      searchQueries: fixture.searchQueries,
      fixture: AiroTvBenchmarkFixtureInfo(
        fixtureId: 'synthetic-iptv-${config.channelCount}',
        sourceKind: 'synthetic_m3u',
        byteCount: bytes.length,
        sha256: sha256.convert(bytes).toString(),
      ),
    );
  }

  AiroMediaDatabaseBenchmarkPlan _plan({
    required AiroTvBenchmarkFixtureInfo fixture,
    required int channelCount,
    required int queryCount,
  }) {
    return AiroMediaDatabaseBenchmarkPlan(
      planId: 'airo-tv-host-${fixture.fixtureId}',
      dataset: AiroMediaBenchmarkDatasetProfile(
        profileId: fixture.fixtureId,
        kind: AiroMediaBenchmarkDatasetKind.liveIptv,
        liveChannelCount: channelCount,
        vodItemCount: 0,
        epgProgramCount: 0,
        playlistSourceCount: 1,
        metadataFieldCount: 6,
      ),
      steps: [
        AiroMediaBenchmarkWorkloadStep(
          stepId: 'parse-m3u',
          operation: AiroMediaBenchmarkOperation.importBatch,
          recordCount: channelCount,
        ),
        AiroMediaBenchmarkWorkloadStep(
          stepId: 'search-index',
          operation: AiroMediaBenchmarkOperation.searchText,
          recordCount: channelCount,
          queryCount: queryCount,
        ),
      ],
      requiredMetrics: const {
        AiroMediaBenchmarkMetric.elapsedMillis,
        AiroMediaBenchmarkMetric.rowsPerSecond,
      },
      budget: const AiroMediaBenchmarkBudget(
        maxElapsedMillis: 30000,
        maxPeakMemoryMb: 512,
        maxStorageMb: 64,
        minRowsPerSecond: 50,
      ),
    );
  }
}

class _AiroTvBenchmarkInput {
  const _AiroTvBenchmarkInput({
    required this.content,
    required this.searchQueries,
    required this.fixture,
  });

  final String content;
  final List<String> searchQueries;
  final AiroTvBenchmarkFixtureInfo fixture;
}

class AiroTvSyntheticPlaylistFixture extends Equatable {
  const AiroTvSyntheticPlaylistFixture({required this.channelCount});

  final int channelCount;

  List<String> get searchQueries => const [
    'news',
    'sports',
    'music',
    'kids',
    'global',
  ];

  String toM3u() {
    final buffer = StringBuffer('#EXTM3U\n');
    for (var i = 0; i < channelCount; i++) {
      final category = _categoryFor(i);
      final language = i.isEven ? 'en' : 'hi';
      buffer
        ..write('#EXTINF:-1 tvg-id="$i" tvg-name="Airo $category $i" ')
        ..write('tvg-logo="https://logos.example.test/$i.png" ')
        ..write('group-title="$category" tvg-language="$language",')
        ..writeln('Airo $category Channel $i')
        ..writeln('https://streams.example.test/$category/$i.m3u8');
    }
    return buffer.toString();
  }

  String _categoryFor(int index) {
    return switch (index % 5) {
      0 => 'News',
      1 => 'Sports',
      2 => 'Music',
      3 => 'Kids',
      _ => 'Global',
    };
  }

  @override
  List<Object?> get props => [channelCount];
}

Map<String, Object?> _stepToJson(AiroMediaBenchmarkWorkloadStep step) {
  return {
    'schemaVersion': step.schemaVersion,
    'stepId': step.stepId,
    'operation': step.operation.stableId,
    'recordCount': step.recordCount,
    'queryCount': step.queryCount,
    'concurrency': step.concurrency,
  };
}

Map<String, Object?> _sampleToJson(AiroMediaBenchmarkMetricSample sample) {
  return {
    'schemaVersion': sample.schemaVersion,
    'stepId': sample.stepId,
    'operation': sample.operation.stableId,
    'completedRecordCount': sample.completedRecordCount,
    if (sample.elapsedMillis != null) 'elapsedMillis': sample.elapsedMillis,
    if (sample.peakMemoryMb != null) 'peakMemoryMb': sample.peakMemoryMb,
    if (sample.storageMb != null) 'storageMb': sample.storageMb,
    if (sample.rowsPerSecond != null) 'rowsPerSecond': sample.rowsPerSecond,
  };
}

AiroMediaBenchmarkMetricSample _parseSample(_TimedParseRun run) {
  return AiroMediaBenchmarkMetricSample(
    stepId: 'parse-m3u',
    operation: AiroMediaBenchmarkOperation.importBatch,
    completedRecordCount: run.channelCount,
    elapsedMillis: run.elapsed.inMilliseconds,
    rowsPerSecond: run.rowsPerSecond,
  );
}

AiroMediaBenchmarkMetricSample _searchSample(_TimedSearchRun run) {
  return AiroMediaBenchmarkMetricSample(
    stepId: 'search-index',
    operation: AiroMediaBenchmarkOperation.searchText,
    completedRecordCount: run.channelCount * run.queryCount,
    elapsedMillis: run.elapsed.inMilliseconds,
    rowsPerSecond: run.rowsPerSecond,
  );
}

_TimedParseRun _medianParse(List<_TimedParseRun> runs) {
  final sorted = [...runs]
    ..sort(
      (a, b) => a.elapsed.inMicroseconds.compareTo(b.elapsed.inMicroseconds),
    );
  return sorted[sorted.length ~/ 2];
}

_TimedSearchRun _medianSearch(List<_TimedSearchRun> runs) {
  final sorted = [...runs]
    ..sort(
      (a, b) => a.elapsed.inMicroseconds.compareTo(b.elapsed.inMicroseconds),
    );
  return sorted[sorted.length ~/ 2];
}

class _TimedParseRun {
  const _TimedParseRun({required this.elapsed, required this.channelCount});

  final Duration elapsed;
  final int channelCount;

  double get rowsPerSecond {
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    return seconds <= 0 ? channelCount.toDouble() : channelCount / seconds;
  }
}

class _TimedSearchRun {
  const _TimedSearchRun({
    required this.elapsed,
    required this.channelCount,
    required this.queryCount,
    required this.resultCount,
  });

  final Duration elapsed;
  final int channelCount;
  final int queryCount;
  final int resultCount;

  double get rowsPerSecond {
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final rows = channelCount * queryCount;
    return seconds <= 0 ? rows.toDouble() : rows / seconds;
  }
}
