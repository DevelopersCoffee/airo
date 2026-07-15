import 'package:equatable/equatable.dart';

import 'runtime_device_profile_models.dart';

const String kAiroRuntimeMemoryBudgetSchemaVersion = '1.0.0';

enum AiroRuntimeMemoryBudgetClass {
  constrainedTv1gb('constrained_tv_1gb'),
  standardTv2gb('standard_tv_2gb'),
  expandedTv3gbPlus('expanded_tv_3gb_plus'),
  unsupported('unsupported');

  const AiroRuntimeMemoryBudgetClass(this.stableId);

  final String stableId;
}

enum AiroRuntimeMemoryBudgetViolationCode {
  accepted('accepted'),
  unsupportedProfile('unsupported_profile'),
  steadyRssExceeded('steady_rss_exceeded'),
  peakRssExceeded('peak_rss_exceeded'),
  dartHeapExceeded('dart_heap_exceeded'),
  imageCacheExceeded('image_cache_exceeded'),
  retainedChannelListCopiesExceeded('retained_channel_list_copies_exceeded'),
  playbackSoakDriftExceeded('playback_soak_drift_exceeded');

  const AiroRuntimeMemoryBudgetViolationCode(this.stableId);

  final String stableId;
}

class AiroRuntimeMemoryBudget extends Equatable {
  const AiroRuntimeMemoryBudget({
    required this.budgetId,
    required this.budgetClass,
    required this.supportTier,
    required this.maxSteadyRssMb,
    required this.maxPeakRssMb,
    required this.maxDartHeapMb,
    required this.imageCacheMb,
    required this.imageCacheEntries,
    required this.maxRetainedChannelListCopies,
    required this.maxPlaybackSoakDriftMbPerHour,
    required this.sampleInterval,
    this.schemaVersion = kAiroRuntimeMemoryBudgetSchemaVersion,
  });

  final String schemaVersion;
  final String budgetId;
  final AiroRuntimeMemoryBudgetClass budgetClass;
  final AiroRuntimeSupportTier supportTier;
  final int maxSteadyRssMb;
  final int maxPeakRssMb;
  final int maxDartHeapMb;
  final int imageCacheMb;
  final int imageCacheEntries;
  final int maxRetainedChannelListCopies;
  final double maxPlaybackSoakDriftMbPerHour;
  final Duration sampleInterval;

  bool get supported => budgetClass != AiroRuntimeMemoryBudgetClass.unsupported;

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'budgetId': budgetId,
      'budgetClass': budgetClass.stableId,
      'supportTier': supportTier.stableId,
      'maxSteadyRssMb': maxSteadyRssMb,
      'maxPeakRssMb': maxPeakRssMb,
      'maxDartHeapMb': maxDartHeapMb,
      'imageCacheMb': imageCacheMb,
      'imageCacheEntries': imageCacheEntries,
      'maxRetainedChannelListCopies': maxRetainedChannelListCopies,
      'maxPlaybackSoakDriftMbPerHour': maxPlaybackSoakDriftMbPerHour,
      'sampleIntervalMs': sampleInterval.inMilliseconds,
    };
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    budgetId,
    budgetClass,
    supportTier,
    maxSteadyRssMb,
    maxPeakRssMb,
    maxDartHeapMb,
    imageCacheMb,
    imageCacheEntries,
    maxRetainedChannelListCopies,
    maxPlaybackSoakDriftMbPerHour,
    sampleInterval,
  ];
}

class AiroRuntimeMemorySample extends Equatable {
  const AiroRuntimeMemorySample({
    required this.sampleId,
    required this.steadyRssMb,
    required this.peakRssMb,
    required this.dartHeapMb,
    required this.imageCacheMb,
    required this.retainedChannelListCopies,
    required this.playbackSoakDriftMbPerHour,
    required this.sampledAt,
    this.profileId,
    this.schemaVersion = kAiroRuntimeMemoryBudgetSchemaVersion,
  });

  final String schemaVersion;
  final String sampleId;
  final String? profileId;
  final int steadyRssMb;
  final int peakRssMb;
  final int dartHeapMb;
  final int imageCacheMb;
  final int retainedChannelListCopies;
  final double playbackSoakDriftMbPerHour;
  final DateTime sampledAt;

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'sampleId': sampleId,
      if (profileId != null) 'profileId': profileId,
      'steadyRssMb': steadyRssMb,
      'peakRssMb': peakRssMb,
      'dartHeapMb': dartHeapMb,
      'imageCacheMb': imageCacheMb,
      'retainedChannelListCopies': retainedChannelListCopies,
      'playbackSoakDriftMbPerHour': playbackSoakDriftMbPerHour,
      'sampledAt': sampledAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    sampleId,
    profileId,
    steadyRssMb,
    peakRssMb,
    dartHeapMb,
    imageCacheMb,
    retainedChannelListCopies,
    playbackSoakDriftMbPerHour,
    sampledAt,
  ];
}

class AiroRuntimeMemoryBudgetEvaluation extends Equatable {
  AiroRuntimeMemoryBudgetEvaluation({
    required this.budget,
    required this.sample,
    required Iterable<AiroRuntimeMemoryBudgetViolationCode> violations,
  }) : violations = List.unmodifiable(violations);

  final AiroRuntimeMemoryBudget budget;
  final AiroRuntimeMemorySample sample;
  final List<AiroRuntimeMemoryBudgetViolationCode> violations;

  bool get accepted =>
      violations.length == 1 &&
      violations.first == AiroRuntimeMemoryBudgetViolationCode.accepted;

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': budget.schemaVersion,
      'budgetId': budget.budgetId,
      'sampleId': sample.sampleId,
      'accepted': accepted,
      'violations': violations
          .map((violation) => violation.stableId)
          .toList(growable: false),
    };
  }

  @override
  List<Object?> get props => [budget, sample, violations];
}

class AiroRuntimeMemoryTimelinePoint extends Equatable {
  const AiroRuntimeMemoryTimelinePoint({
    required this.pointId,
    required this.sampledAt,
    required this.rssMb,
    required this.dartHeapMb,
    required this.imageCacheMb,
    required this.retainedChannelListCopies,
    this.schemaVersion = kAiroRuntimeMemoryBudgetSchemaVersion,
  });

  final String schemaVersion;
  final String pointId;
  final DateTime sampledAt;
  final int rssMb;
  final int dartHeapMb;
  final int imageCacheMb;
  final int retainedChannelListCopies;

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'pointId': pointId,
      'sampledAt': sampledAt.toIso8601String(),
      'rssMb': rssMb,
      'dartHeapMb': dartHeapMb,
      'imageCacheMb': imageCacheMb,
      'retainedChannelListCopies': retainedChannelListCopies,
    };
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    pointId,
    sampledAt,
    rssMb,
    dartHeapMb,
    imageCacheMb,
    retainedChannelListCopies,
  ];
}

class AiroRuntimeMemoryTimelineReport extends Equatable {
  AiroRuntimeMemoryTimelineReport({
    required this.reportId,
    required this.scenarioId,
    required this.budget,
    required Iterable<AiroRuntimeMemoryTimelinePoint> points,
    this.schemaVersion = kAiroRuntimeMemoryBudgetSchemaVersion,
  }) : points = List.unmodifiable(
         points.toList()..sort((a, b) => a.sampledAt.compareTo(b.sampledAt)),
       ) {
    if (this.points.isEmpty) {
      throw ArgumentError.value(points, 'points', 'must not be empty');
    }
  }

  final String schemaVersion;
  final String reportId;
  final String scenarioId;
  final AiroRuntimeMemoryBudget budget;
  final List<AiroRuntimeMemoryTimelinePoint> points;

  AiroRuntimeMemoryTimelinePoint get firstPoint => points.first;
  AiroRuntimeMemoryTimelinePoint get lastPoint => points.last;

  Duration get duration => lastPoint.sampledAt.difference(firstPoint.sampledAt);

  int get steadyRssMb => lastPoint.rssMb;

  int get peakRssMb => points
      .map((point) => point.rssMb)
      .reduce((current, next) => current > next ? current : next);

  int get peakDartHeapMb => points
      .map((point) => point.dartHeapMb)
      .reduce((current, next) => current > next ? current : next);

  int get peakImageCacheMb => points
      .map((point) => point.imageCacheMb)
      .reduce((current, next) => current > next ? current : next);

  int get peakRetainedChannelListCopies => points
      .map((point) => point.retainedChannelListCopies)
      .reduce((current, next) => current > next ? current : next);

  double get playbackSoakDriftMbPerHour {
    if (duration.inMilliseconds <= 0) return 0;
    final driftMb = lastPoint.dartHeapMb - firstPoint.dartHeapMb;
    if (driftMb <= 0) return 0;
    return driftMb / (duration.inMilliseconds / Duration.millisecondsPerHour);
  }

  AiroRuntimeMemorySample get aggregateSample {
    return AiroRuntimeMemorySample(
      sampleId: '$reportId-aggregate',
      profileId: budget.budgetId,
      steadyRssMb: steadyRssMb,
      peakRssMb: peakRssMb,
      dartHeapMb: peakDartHeapMb,
      imageCacheMb: peakImageCacheMb,
      retainedChannelListCopies: peakRetainedChannelListCopies,
      playbackSoakDriftMbPerHour: playbackSoakDriftMbPerHour,
      sampledAt: lastPoint.sampledAt,
    );
  }

  AiroRuntimeMemoryBudgetEvaluation evaluate({
    AiroRuntimeMemoryBudgetPolicy policy =
        const AiroRuntimeMemoryBudgetPolicy(),
  }) {
    return policy.evaluate(budget: budget, sample: aggregateSample);
  }

  Map<String, Object?> toPublicMap({
    AiroRuntimeMemoryBudgetPolicy policy =
        const AiroRuntimeMemoryBudgetPolicy(),
  }) {
    final evaluation = evaluate(policy: policy);
    return {
      'schemaVersion': schemaVersion,
      'reportId': reportId,
      'scenarioId': scenarioId,
      'budgetId': budget.budgetId,
      'accepted': evaluation.accepted,
      'violations': evaluation.violations
          .map((violation) => violation.stableId)
          .toList(growable: false),
      'durationSeconds': duration.inSeconds,
      'sampleCount': points.length,
      'steadyRssMb': steadyRssMb,
      'peakRssMb': peakRssMb,
      'peakDartHeapMb': peakDartHeapMb,
      'peakImageCacheMb': peakImageCacheMb,
      'peakRetainedChannelListCopies': peakRetainedChannelListCopies,
      'playbackSoakDriftMbPerHour': playbackSoakDriftMbPerHour,
      'points': points
          .map((point) => point.toPublicMap())
          .toList(growable: false),
    };
  }

  String toMarkdown({
    AiroRuntimeMemoryBudgetPolicy policy =
        const AiroRuntimeMemoryBudgetPolicy(),
  }) {
    final evaluation = evaluate(policy: policy);
    final buffer = StringBuffer()
      ..writeln('# Airo Runtime Memory Timeline')
      ..writeln()
      ..writeln('- Report: `$reportId`')
      ..writeln('- Scenario: `$scenarioId`')
      ..writeln('- Budget: `${budget.budgetId}`')
      ..writeln('- Accepted: `${evaluation.accepted}`')
      ..writeln('- Duration: ${duration.inSeconds}s')
      ..writeln('- Samples: ${points.length}')
      ..writeln('- Steady RSS: $steadyRssMb MB / ${budget.maxSteadyRssMb} MB')
      ..writeln('- Peak RSS: $peakRssMb MB / ${budget.maxPeakRssMb} MB')
      ..writeln(
        '- Dart heap peak: $peakDartHeapMb MB / ${budget.maxDartHeapMb} MB',
      )
      ..writeln(
        '- Image cache peak: $peakImageCacheMb MB / ${budget.imageCacheMb} MB',
      )
      ..writeln(
        '- Playback drift: ${playbackSoakDriftMbPerHour.toStringAsFixed(2)} MB/h / '
        '${budget.maxPlaybackSoakDriftMbPerHour.toStringAsFixed(2)} MB/h',
      )
      ..writeln(
        '- Violations: ${evaluation.violations.map((code) => code.stableId).join(', ')}',
      )
      ..writeln()
      ..writeln(
        '| Sample | Time | RSS MB | Dart heap MB | Image cache MB | Retained channel lists |',
      )
      ..writeln('| --- | --- | ---: | ---: | ---: | ---: |');

    for (final point in points) {
      buffer.writeln(
        '| `${point.pointId}` | ${point.sampledAt.toIso8601String()} | '
        '${point.rssMb} | ${point.dartHeapMb} | ${point.imageCacheMb} | '
        '${point.retainedChannelListCopies} |',
      );
    }

    return buffer.toString();
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    reportId,
    scenarioId,
    budget,
    points,
  ];
}

class AiroRuntimeMemoryBudgetPolicy extends Equatable {
  const AiroRuntimeMemoryBudgetPolicy({
    this.constrainedBudget = androidTvConstrainedBudget,
    this.standardBudget = androidTvStandardBudget,
    this.expandedBudget = androidTvExpandedBudget,
    this.unsupportedBudget = androidTvUnsupportedBudget,
  });

  static const int bytesPerMb = 1024 * 1024;
  static const int constrainedTvImageCacheMb = 16;
  static const int constrainedTvImageCacheEntries = 150;
  static const int standardTvImageCacheMb = 32;
  static const int standardTvImageCacheEntries = 225;
  static const int expandedTvImageCacheMb = 64;
  static const int expandedTvImageCacheEntries = 300;

  static const androidTvConstrainedBudget = AiroRuntimeMemoryBudget(
    budgetId: 'android-tv-1gb-constrained',
    budgetClass: AiroRuntimeMemoryBudgetClass.constrainedTv1gb,
    supportTier: AiroRuntimeSupportTier.legacyOptimized,
    maxSteadyRssMb: 250,
    maxPeakRssMb: 350,
    maxDartHeapMb: 128,
    imageCacheMb: constrainedTvImageCacheMb,
    imageCacheEntries: constrainedTvImageCacheEntries,
    maxRetainedChannelListCopies: 2,
    maxPlaybackSoakDriftMbPerHour: 1,
    sampleInterval: Duration(seconds: 30),
  );

  static const androidTvStandardBudget = AiroRuntimeMemoryBudget(
    budgetId: 'android-tv-2gb-standard',
    budgetClass: AiroRuntimeMemoryBudgetClass.standardTv2gb,
    supportTier: AiroRuntimeSupportTier.fullySupported,
    maxSteadyRssMb: 384,
    maxPeakRssMb: 512,
    maxDartHeapMb: 192,
    imageCacheMb: standardTvImageCacheMb,
    imageCacheEntries: standardTvImageCacheEntries,
    maxRetainedChannelListCopies: 2,
    maxPlaybackSoakDriftMbPerHour: 1,
    sampleInterval: Duration(seconds: 30),
  );

  static const androidTvExpandedBudget = AiroRuntimeMemoryBudget(
    budgetId: 'android-tv-3gb-plus-expanded',
    budgetClass: AiroRuntimeMemoryBudgetClass.expandedTv3gbPlus,
    supportTier: AiroRuntimeSupportTier.fullySupported,
    maxSteadyRssMb: 512,
    maxPeakRssMb: 768,
    maxDartHeapMb: 256,
    imageCacheMb: expandedTvImageCacheMb,
    imageCacheEntries: expandedTvImageCacheEntries,
    maxRetainedChannelListCopies: 2,
    maxPlaybackSoakDriftMbPerHour: 1,
    sampleInterval: Duration(seconds: 30),
  );

  static const androidTvUnsupportedBudget = AiroRuntimeMemoryBudget(
    budgetId: 'android-tv-unsupported',
    budgetClass: AiroRuntimeMemoryBudgetClass.unsupported,
    supportTier: AiroRuntimeSupportTier.unsupported,
    maxSteadyRssMb: 128,
    maxPeakRssMb: 180,
    maxDartHeapMb: 64,
    imageCacheMb: 8,
    imageCacheEntries: 75,
    maxRetainedChannelListCopies: 1,
    maxPlaybackSoakDriftMbPerHour: 0.5,
    sampleInterval: Duration(seconds: 30),
  );

  final AiroRuntimeMemoryBudget constrainedBudget;
  final AiroRuntimeMemoryBudget standardBudget;
  final AiroRuntimeMemoryBudget expandedBudget;
  final AiroRuntimeMemoryBudget unsupportedBudget;

  AiroRuntimeMemoryBudget budgetForProfile(AiroRuntimeDeviceProfile profile) {
    return budgetForSignals(profile.signals, supportTier: profile.supportTier);
  }

  AiroRuntimeMemoryBudget budgetForSignals(
    AiroRuntimeDeviceSignals signals, {
    AiroRuntimeSupportTier supportTier = AiroRuntimeSupportTier.fullySupported,
  }) {
    if (supportTier == AiroRuntimeSupportTier.unsupported ||
        signals.memoryMb < 1024 ||
        signals.memoryPressure.blocksSupport) {
      return unsupportedBudget;
    }
    if (supportTier == AiroRuntimeSupportTier.legacyOptimized ||
        signals.memoryPressure.forcesLegacy ||
        signals.memoryMb < 2048) {
      return constrainedBudget;
    }
    if (signals.memoryMb < 3072) {
      return standardBudget;
    }
    return expandedBudget;
  }

  AiroRuntimeMemoryBudgetEvaluation evaluate({
    required AiroRuntimeMemoryBudget budget,
    required AiroRuntimeMemorySample sample,
  }) {
    final violations = <AiroRuntimeMemoryBudgetViolationCode>[];
    if (!budget.supported) {
      violations.add(AiroRuntimeMemoryBudgetViolationCode.unsupportedProfile);
    }
    if (sample.steadyRssMb > budget.maxSteadyRssMb) {
      violations.add(AiroRuntimeMemoryBudgetViolationCode.steadyRssExceeded);
    }
    if (sample.peakRssMb > budget.maxPeakRssMb) {
      violations.add(AiroRuntimeMemoryBudgetViolationCode.peakRssExceeded);
    }
    if (sample.dartHeapMb > budget.maxDartHeapMb) {
      violations.add(AiroRuntimeMemoryBudgetViolationCode.dartHeapExceeded);
    }
    if (sample.imageCacheMb > budget.imageCacheMb) {
      violations.add(AiroRuntimeMemoryBudgetViolationCode.imageCacheExceeded);
    }
    if (sample.retainedChannelListCopies >
        budget.maxRetainedChannelListCopies) {
      violations.add(
        AiroRuntimeMemoryBudgetViolationCode.retainedChannelListCopiesExceeded,
      );
    }
    if (sample.playbackSoakDriftMbPerHour >
        budget.maxPlaybackSoakDriftMbPerHour) {
      violations.add(
        AiroRuntimeMemoryBudgetViolationCode.playbackSoakDriftExceeded,
      );
    }

    return AiroRuntimeMemoryBudgetEvaluation(
      budget: budget,
      sample: sample,
      violations: violations.isEmpty
          ? const [AiroRuntimeMemoryBudgetViolationCode.accepted]
          : violations,
    );
  }

  @override
  List<Object?> get props => [
    constrainedBudget,
    standardBudget,
    expandedBudget,
    unsupportedBudget,
  ];
}
