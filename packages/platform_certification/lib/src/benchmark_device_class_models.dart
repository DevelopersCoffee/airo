import 'package:equatable/equatable.dart';

import 'certification_models.dart';

const String kAiroBenchmarkDeviceClassSchemaVersion = '1.0.0';

enum AiroBenchmarkDeviceClass {
  constrainedTv('constrained_tv'),
  standardTv('standard_tv'),
  mobileCompanion('mobile_companion'),
  desktopCompanion('desktop_companion');

  const AiroBenchmarkDeviceClass(this.stableId);

  final String stableId;
}

enum AiroBenchmarkWorkload {
  startup('startup'),
  scrollWhileImportRuns('scroll_while_import_runs'),
  epgRefreshDuringPlayback('epg_refresh_during_playback'),
  remoteDuringPlayback('remote_during_playback'),
  protocolCompatibility('protocol_compatibility'),
  largePlaylistImport('large_playlist_import'),
  searchResponsiveness('search_responsiveness'),
  cacheCleanup('cache_cleanup');

  const AiroBenchmarkWorkload(this.stableId);

  final String stableId;
}

enum AiroBenchmarkMetric {
  elapsedMillis('elapsed_millis'),
  inputLatencyMillis('input_latency_millis'),
  peakMemoryMb('peak_memory_mb'),
  storageMb('storage_mb'),
  droppedFramePercent('dropped_frame_percent'),
  crashCount('crash_count'),
  rowsPerSecond('rows_per_second'),
  rejectedPayloadCount('rejected_payload_count');

  const AiroBenchmarkMetric(this.stableId);

  final String stableId;
}

enum AiroBenchmarkEvidenceKind {
  hostAutomation('host_automation'),
  physicalDeviceRun('physical_device_run'),
  benchmarkTrace('benchmark_trace'),
  releaseConfigReview('release_config_review');

  const AiroBenchmarkEvidenceKind(this.stableId);

  final String stableId;
}

enum AiroBenchmarkBlockerCode {
  accepted('accepted'),
  deviceClassMissing('device_class_missing'),
  unsupportedDeviceClass('unsupported_device_class'),
  gateMissing('gate_missing'),
  sampleMissing('sample_missing'),
  sampleWrongDeviceClass('sample_wrong_device_class'),
  sampleWrongGate('sample_wrong_gate'),
  sampleWrongMetric('sample_wrong_metric'),
  sampleWrongEvidenceKind('sample_wrong_evidence_kind'),
  hostOnlyEvidenceForPhysicalGate('host_only_evidence_for_physical_gate'),
  sampleStale('sample_stale'),
  metricAboveMaximum('metric_above_maximum'),
  metricBelowMinimum('metric_below_minimum'),
  unsafeStableId('unsafe_stable_id');

  const AiroBenchmarkBlockerCode(this.stableId);

  final String stableId;
}

enum AiroBenchmarkStableValueRejectionCode {
  empty('empty'),
  urlValue('url_value'),
  localPathValue('local_path_value'),
  localIpValue('local_ip_value'),
  credentialLikeValue('credential_like_value'),
  invalidStableId('invalid_stable_id');

  const AiroBenchmarkStableValueRejectionCode(this.stableId);

  final String stableId;
}

class AiroBenchmarkStableValue extends Equatable {
  const AiroBenchmarkStableValue._(this.value);

  factory AiroBenchmarkStableValue.stable(String value) {
    final rejection = validate(value);
    if (rejection != null) {
      throw ArgumentError.value(value, 'value', rejection.stableId);
    }
    return AiroBenchmarkStableValue._(value.trim());
  }

  final String value;

  static AiroBenchmarkStableValueRejectionCode? validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return AiroBenchmarkStableValueRejectionCode.empty;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return AiroBenchmarkStableValueRejectionCode.urlValue;
    }
    if (trimmed.startsWith('file://') ||
        trimmed.startsWith('/') ||
        RegExp(r'^[A-Za-z]:\\').hasMatch(trimmed)) {
      return AiroBenchmarkStableValueRejectionCode.localPathValue;
    }
    if (RegExp(
      r'\b(?:10|127|172\.(?:1[6-9]|2\d|3[0-1])|192\.168)\.',
    ).hasMatch(trimmed)) {
      return AiroBenchmarkStableValueRejectionCode.localIpValue;
    }
    if (RegExp(
      r'\b(?:bearer|basic)\s+[A-Za-z0-9._~+/=-]+',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return AiroBenchmarkStableValueRejectionCode.credentialLikeValue;
    }
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9_.-]*$').hasMatch(trimmed)) {
      return AiroBenchmarkStableValueRejectionCode.invalidStableId;
    }
    return null;
  }

  @override
  String toString() => 'AiroBenchmarkStableValue(redacted)';

  @override
  List<Object?> get props => [value];
}

class AiroBenchmarkMetricThreshold extends Equatable {
  const AiroBenchmarkMetricThreshold({
    required this.metric,
    this.maximum,
    this.minimum,
  });

  final AiroBenchmarkMetric metric;
  final double? maximum;
  final double? minimum;

  bool accepts(double value) {
    final max = maximum;
    if (max != null && value > max) return false;
    final min = minimum;
    if (min != null && value < min) return false;
    return true;
  }

  @override
  List<Object?> get props => [metric, maximum, minimum];
}

class AiroBenchmarkGate extends Equatable {
  AiroBenchmarkGate({
    required this.gateId,
    required this.workload,
    required Set<AiroBenchmarkEvidenceKind> acceptedEvidenceKinds,
    required Iterable<AiroBenchmarkMetricThreshold> thresholds,
    this.requiresPhysicalDevice = false,
    this.maxEvidenceAge = const Duration(days: 14),
    this.schemaVersion = kAiroBenchmarkDeviceClassSchemaVersion,
  }) : acceptedEvidenceKinds = Set.unmodifiable(acceptedEvidenceKinds),
       thresholds = List.unmodifiable(thresholds);

  final String schemaVersion;
  final AiroBenchmarkStableValue gateId;
  final AiroBenchmarkWorkload workload;
  final Set<AiroBenchmarkEvidenceKind> acceptedEvidenceKinds;
  final List<AiroBenchmarkMetricThreshold> thresholds;
  final bool requiresPhysicalDevice;
  final Duration maxEvidenceAge;

  AiroBenchmarkMetricThreshold? thresholdFor(AiroBenchmarkMetric metric) {
    for (final threshold in thresholds) {
      if (threshold.metric == metric) return threshold;
    }
    return null;
  }

  bool accepts(AiroBenchmarkEvidenceKind evidenceKind) {
    return acceptedEvidenceKinds.contains(evidenceKind);
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    gateId,
    workload,
    acceptedEvidenceKinds,
    thresholds,
    requiresPhysicalDevice,
    maxEvidenceAge,
  ];
}

class AiroBenchmarkDeviceClassProfile extends Equatable {
  AiroBenchmarkDeviceClassProfile({
    required this.deviceClassId,
    required this.deviceClass,
    required this.platform,
    required this.productProfile,
    required Set<AiroBenchmarkStableValue> requiredGateIds,
    this.minMemoryMb,
    this.minStorageMb,
    this.minAndroidApi,
    this.canAdvertiseSupport = true,
    this.schemaVersion = kAiroBenchmarkDeviceClassSchemaVersion,
  }) : requiredGateIds = Set.unmodifiable(requiredGateIds);

  final String schemaVersion;
  final AiroBenchmarkStableValue deviceClassId;
  final AiroBenchmarkDeviceClass deviceClass;
  final AiroValidationPlatform platform;
  final AiroValidationProductProfile productProfile;
  final Set<AiroBenchmarkStableValue> requiredGateIds;
  final int? minMemoryMb;
  final int? minStorageMb;
  final int? minAndroidApi;
  final bool canAdvertiseSupport;

  @override
  List<Object?> get props => [
    schemaVersion,
    deviceClassId,
    deviceClass,
    platform,
    productProfile,
    requiredGateIds,
    minMemoryMb,
    minStorageMb,
    minAndroidApi,
    canAdvertiseSupport,
  ];
}

class AiroBenchmarkSample extends Equatable {
  const AiroBenchmarkSample({
    required this.sampleId,
    required this.deviceClassId,
    required this.gateId,
    required this.metric,
    required this.value,
    required this.evidenceKind,
    required this.capturedAt,
    this.schemaVersion = kAiroBenchmarkDeviceClassSchemaVersion,
  });

  final String schemaVersion;
  final AiroBenchmarkStableValue sampleId;
  final AiroBenchmarkStableValue deviceClassId;
  final AiroBenchmarkStableValue gateId;
  final AiroBenchmarkMetric metric;
  final double value;
  final AiroBenchmarkEvidenceKind evidenceKind;
  final DateTime capturedAt;

  @override
  List<Object?> get props => [
    schemaVersion,
    sampleId,
    deviceClassId,
    gateId,
    metric,
    value,
    evidenceKind,
    capturedAt,
  ];
}

class AiroBenchmarkBlocker extends Equatable {
  const AiroBenchmarkBlocker({
    required this.code,
    required this.deviceClassId,
    this.gateId,
    this.metric,
  });

  final AiroBenchmarkBlockerCode code;
  final AiroBenchmarkStableValue deviceClassId;
  final AiroBenchmarkStableValue? gateId;
  final AiroBenchmarkMetric? metric;

  @override
  List<Object?> get props => [code, deviceClassId, gateId, metric];
}

class AiroBenchmarkEvaluationResult extends Equatable {
  AiroBenchmarkEvaluationResult({
    required this.deviceClassId,
    required Iterable<AiroBenchmarkBlocker> blockers,
  }) : blockers = List.unmodifiable(blockers);

  final AiroBenchmarkStableValue deviceClassId;
  final List<AiroBenchmarkBlocker> blockers;

  bool get passed => blockers.isEmpty;

  Map<String, Object?> toDiagnosticMap() {
    return {
      'deviceClassId': deviceClassId.value,
      'passed': passed,
      'codes': blockers
          .map((blocker) => blocker.code.stableId)
          .toList(growable: false),
    };
  }

  @override
  List<Object?> get props => [deviceClassId, blockers];
}

class AiroBenchmarkDeviceClassMatrix extends Equatable {
  AiroBenchmarkDeviceClassMatrix({
    required Iterable<AiroBenchmarkDeviceClassProfile> profiles,
    required Iterable<AiroBenchmarkGate> gates,
    this.schemaVersion = kAiroBenchmarkDeviceClassSchemaVersion,
  }) : profiles = List.unmodifiable(profiles),
       gates = List.unmodifiable(gates);

  final String schemaVersion;
  final List<AiroBenchmarkDeviceClassProfile> profiles;
  final List<AiroBenchmarkGate> gates;

  AiroBenchmarkDeviceClassProfile? profileById(String deviceClassId) {
    for (final profile in profiles) {
      if (profile.deviceClassId.value == deviceClassId) return profile;
    }
    return null;
  }

  AiroBenchmarkGate? gateById(AiroBenchmarkStableValue gateId) {
    for (final gate in gates) {
      if (gate.gateId == gateId) return gate;
    }
    return null;
  }

  AiroBenchmarkEvaluationResult evaluate({
    required String deviceClassId,
    required Iterable<AiroBenchmarkSample> samples,
    required DateTime now,
  }) {
    final stableDeviceClassId = _stableOrFallback(deviceClassId);
    final profile = profileById(deviceClassId);
    if (profile == null) {
      return AiroBenchmarkEvaluationResult(
        deviceClassId: stableDeviceClassId,
        blockers: [
          AiroBenchmarkBlocker(
            code: AiroBenchmarkBlockerCode.deviceClassMissing,
            deviceClassId: stableDeviceClassId,
          ),
        ],
      );
    }
    if (!profile.canAdvertiseSupport) {
      return AiroBenchmarkEvaluationResult(
        deviceClassId: profile.deviceClassId,
        blockers: [
          AiroBenchmarkBlocker(
            code: AiroBenchmarkBlockerCode.unsupportedDeviceClass,
            deviceClassId: profile.deviceClassId,
          ),
        ],
      );
    }

    final blockers = <AiroBenchmarkBlocker>[];
    for (final gateId in profile.requiredGateIds) {
      final gate = gateById(gateId);
      if (gate == null) {
        blockers.add(
          AiroBenchmarkBlocker(
            code: AiroBenchmarkBlockerCode.gateMissing,
            deviceClassId: profile.deviceClassId,
            gateId: gateId,
          ),
        );
        continue;
      }
      blockers.addAll(
        _blockersForGate(
          profile: profile,
          gate: gate,
          samples: samples,
          now: now,
        ),
      );
    }

    return AiroBenchmarkEvaluationResult(
      deviceClassId: profile.deviceClassId,
      blockers: blockers,
    );
  }

  Iterable<AiroBenchmarkBlocker> _blockersForGate({
    required AiroBenchmarkDeviceClassProfile profile,
    required AiroBenchmarkGate gate,
    required Iterable<AiroBenchmarkSample> samples,
    required DateTime now,
  }) {
    final blockers = <AiroBenchmarkBlocker>[];
    final gateSamples = samples.where((sample) => sample.gateId == gate.gateId);
    if (gateSamples.isEmpty) {
      return [
        AiroBenchmarkBlocker(
          code: AiroBenchmarkBlockerCode.sampleMissing,
          deviceClassId: profile.deviceClassId,
          gateId: gate.gateId,
        ),
      ];
    }

    for (final threshold in gate.thresholds) {
      final metricSamples = gateSamples.where(
        (sample) => sample.metric == threshold.metric,
      );
      if (metricSamples.isEmpty) {
        blockers.add(
          AiroBenchmarkBlocker(
            code: AiroBenchmarkBlockerCode.sampleWrongMetric,
            deviceClassId: profile.deviceClassId,
            gateId: gate.gateId,
            metric: threshold.metric,
          ),
        );
        continue;
      }
      blockers.addAll(
        _blockersForMetricSamples(
          profile: profile,
          gate: gate,
          threshold: threshold,
          samples: metricSamples,
          now: now,
        ),
      );
    }
    return blockers;
  }

  Iterable<AiroBenchmarkBlocker> _blockersForMetricSamples({
    required AiroBenchmarkDeviceClassProfile profile,
    required AiroBenchmarkGate gate,
    required AiroBenchmarkMetricThreshold threshold,
    required Iterable<AiroBenchmarkSample> samples,
    required DateTime now,
  }) sync* {
    final usableSamples = <AiroBenchmarkSample>[];
    for (final sample in samples) {
      final sampleBlocker = _sampleBlocker(
        profile: profile,
        gate: gate,
        sample: sample,
        now: now,
      );
      if (sampleBlocker == null) {
        usableSamples.add(sample);
      } else {
        yield sampleBlocker;
      }
    }
    if (usableSamples.isEmpty) return;

    final latest = usableSamples.reduce(
      (a, b) => a.capturedAt.isAfter(b.capturedAt) ? a : b,
    );
    final max = threshold.maximum;
    if (max != null && latest.value > max) {
      yield AiroBenchmarkBlocker(
        code: AiroBenchmarkBlockerCode.metricAboveMaximum,
        deviceClassId: profile.deviceClassId,
        gateId: gate.gateId,
        metric: threshold.metric,
      );
    }
    final min = threshold.minimum;
    if (min != null && latest.value < min) {
      yield AiroBenchmarkBlocker(
        code: AiroBenchmarkBlockerCode.metricBelowMinimum,
        deviceClassId: profile.deviceClassId,
        gateId: gate.gateId,
        metric: threshold.metric,
      );
    }
  }

  AiroBenchmarkBlocker? _sampleBlocker({
    required AiroBenchmarkDeviceClassProfile profile,
    required AiroBenchmarkGate gate,
    required AiroBenchmarkSample sample,
    required DateTime now,
  }) {
    if (sample.deviceClassId != profile.deviceClassId) {
      return AiroBenchmarkBlocker(
        code: AiroBenchmarkBlockerCode.sampleWrongDeviceClass,
        deviceClassId: profile.deviceClassId,
        gateId: gate.gateId,
        metric: sample.metric,
      );
    }
    if (sample.gateId != gate.gateId) {
      return AiroBenchmarkBlocker(
        code: AiroBenchmarkBlockerCode.sampleWrongGate,
        deviceClassId: profile.deviceClassId,
        gateId: gate.gateId,
        metric: sample.metric,
      );
    }
    if (gate.requiresPhysicalDevice &&
        sample.evidenceKind != AiroBenchmarkEvidenceKind.physicalDeviceRun) {
      return AiroBenchmarkBlocker(
        code: AiroBenchmarkBlockerCode.hostOnlyEvidenceForPhysicalGate,
        deviceClassId: profile.deviceClassId,
        gateId: gate.gateId,
        metric: sample.metric,
      );
    }
    if (!gate.accepts(sample.evidenceKind)) {
      return AiroBenchmarkBlocker(
        code: AiroBenchmarkBlockerCode.sampleWrongEvidenceKind,
        deviceClassId: profile.deviceClassId,
        gateId: gate.gateId,
        metric: sample.metric,
      );
    }
    if (sample.capturedAt.add(gate.maxEvidenceAge).isBefore(now)) {
      return AiroBenchmarkBlocker(
        code: AiroBenchmarkBlockerCode.sampleStale,
        deviceClassId: profile.deviceClassId,
        gateId: gate.gateId,
        metric: sample.metric,
      );
    }
    if (AiroBenchmarkStableValue.validate(sample.sampleId.value) != null) {
      return AiroBenchmarkBlocker(
        code: AiroBenchmarkBlockerCode.unsafeStableId,
        deviceClassId: profile.deviceClassId,
        gateId: gate.gateId,
        metric: sample.metric,
      );
    }
    return null;
  }

  AiroBenchmarkStableValue _stableOrFallback(String value) {
    try {
      return AiroBenchmarkStableValue.stable(value);
    } on ArgumentError {
      return AiroBenchmarkStableValue.stable('invalid-device-class');
    }
  }

  @override
  List<Object?> get props => [schemaVersion, profiles, gates];
}

abstract interface class AiroBenchmarkEvidenceProvider {
  Future<List<AiroBenchmarkSample>> samplesForDeviceClass(
    AiroBenchmarkStableValue deviceClassId,
  );
}

class AiroNoOpBenchmarkEvidenceProvider
    implements AiroBenchmarkEvidenceProvider {
  const AiroNoOpBenchmarkEvidenceProvider();

  @override
  Future<List<AiroBenchmarkSample>> samplesForDeviceClass(
    AiroBenchmarkStableValue deviceClassId,
  ) async {
    return const [];
  }
}

class AiroFakeBenchmarkEvidenceProvider
    implements AiroBenchmarkEvidenceProvider {
  AiroFakeBenchmarkEvidenceProvider({
    required Iterable<AiroBenchmarkSample> samples,
  }) : _samples = List.unmodifiable(samples);

  final List<AiroBenchmarkSample> _samples;

  @override
  Future<List<AiroBenchmarkSample>> samplesForDeviceClass(
    AiroBenchmarkStableValue deviceClassId,
  ) async {
    return [
      for (final sample in _samples)
        if (sample.deviceClassId == deviceClassId) sample,
    ];
  }
}

class AiroBenchmarkDeviceClasses {
  const AiroBenchmarkDeviceClasses._();

  static AiroBenchmarkDeviceClassMatrix matrix() {
    return AiroBenchmarkDeviceClassMatrix(
      profiles: _profiles(),
      gates: _gates(),
    );
  }

  static List<AiroBenchmarkDeviceClassProfile> _profiles() {
    return [
      AiroBenchmarkDeviceClassProfile(
        deviceClassId: AiroBenchmarkStableValue.stable(
          'constrained-tv-class-a',
        ),
        deviceClass: AiroBenchmarkDeviceClass.constrainedTv,
        platform: AiroValidationPlatform.androidTv,
        productProfile: AiroValidationProductProfile.liteReceiver,
        minMemoryMb: 1024,
        minStorageMb: 256,
        minAndroidApi: 26,
        requiredGateIds: _gateIds(const [
          'startup-latency',
          'scroll-while-import',
          'epg-refresh-during-playback',
          'protocol-compatibility',
        ]),
      ),
      AiroBenchmarkDeviceClassProfile(
        deviceClassId: AiroBenchmarkStableValue.stable('standard-tv-class-b'),
        deviceClass: AiroBenchmarkDeviceClass.standardTv,
        platform: AiroValidationPlatform.androidTv,
        productProfile: AiroValidationProductProfile.fullTv,
        minMemoryMb: 2048,
        minStorageMb: 512,
        minAndroidApi: 28,
        requiredGateIds: _gateIds(const [
          'startup-latency',
          'remote-during-playback',
          'large-playlist-import',
          'protocol-compatibility',
        ]),
      ),
      AiroBenchmarkDeviceClassProfile(
        deviceClassId: AiroBenchmarkStableValue.stable(
          'mobile-companion-class',
        ),
        deviceClass: AiroBenchmarkDeviceClass.mobileCompanion,
        platform: AiroValidationPlatform.androidMobile,
        productProfile: AiroValidationProductProfile.companion,
        requiredGateIds: _gateIds(const [
          'search-responsiveness',
          'large-playlist-import',
          'protocol-compatibility',
        ]),
      ),
      AiroBenchmarkDeviceClassProfile(
        deviceClassId: AiroBenchmarkStableValue.stable(
          'desktop-companion-class',
        ),
        deviceClass: AiroBenchmarkDeviceClass.desktopCompanion,
        platform: AiroValidationPlatform.desktop,
        productProfile: AiroValidationProductProfile.desktopCompanion,
        requiredGateIds: _gateIds(const [
          'search-responsiveness',
          'large-playlist-import',
          'cache-cleanup',
        ]),
      ),
    ];
  }

  static List<AiroBenchmarkGate> _gates() {
    return [
      _gate(
        id: 'startup-latency',
        workload: AiroBenchmarkWorkload.startup,
        requiresPhysicalDevice: true,
        thresholds: const [
          AiroBenchmarkMetricThreshold(
            metric: AiroBenchmarkMetric.elapsedMillis,
            maximum: 3000,
          ),
          AiroBenchmarkMetricThreshold(
            metric: AiroBenchmarkMetric.peakMemoryMb,
            maximum: 256,
          ),
        ],
      ),
      _gate(
        id: 'scroll-while-import',
        workload: AiroBenchmarkWorkload.scrollWhileImportRuns,
        requiresPhysicalDevice: true,
        thresholds: const [
          AiroBenchmarkMetricThreshold(
            metric: AiroBenchmarkMetric.inputLatencyMillis,
            maximum: 120,
          ),
          AiroBenchmarkMetricThreshold(
            metric: AiroBenchmarkMetric.droppedFramePercent,
            maximum: 2,
          ),
        ],
      ),
      _gate(
        id: 'epg-refresh-during-playback',
        workload: AiroBenchmarkWorkload.epgRefreshDuringPlayback,
        requiresPhysicalDevice: true,
        thresholds: const [
          AiroBenchmarkMetricThreshold(
            metric: AiroBenchmarkMetric.peakMemoryMb,
            maximum: 256,
          ),
          AiroBenchmarkMetricThreshold(
            metric: AiroBenchmarkMetric.droppedFramePercent,
            maximum: 2,
          ),
        ],
      ),
      _gate(
        id: 'remote-during-playback',
        workload: AiroBenchmarkWorkload.remoteDuringPlayback,
        requiresPhysicalDevice: true,
        thresholds: const [
          AiroBenchmarkMetricThreshold(
            metric: AiroBenchmarkMetric.inputLatencyMillis,
            maximum: 80,
          ),
          AiroBenchmarkMetricThreshold(
            metric: AiroBenchmarkMetric.droppedFramePercent,
            maximum: 1,
          ),
        ],
      ),
      _gate(
        id: 'protocol-compatibility',
        workload: AiroBenchmarkWorkload.protocolCompatibility,
        thresholds: const [
          AiroBenchmarkMetricThreshold(
            metric: AiroBenchmarkMetric.rejectedPayloadCount,
            minimum: 3,
          ),
          AiroBenchmarkMetricThreshold(
            metric: AiroBenchmarkMetric.crashCount,
            maximum: 0,
          ),
        ],
      ),
      _gate(
        id: 'large-playlist-import',
        workload: AiroBenchmarkWorkload.largePlaylistImport,
        thresholds: const [
          AiroBenchmarkMetricThreshold(
            metric: AiroBenchmarkMetric.rowsPerSecond,
            minimum: 1000,
          ),
          AiroBenchmarkMetricThreshold(
            metric: AiroBenchmarkMetric.peakMemoryMb,
            maximum: 512,
          ),
        ],
      ),
      _gate(
        id: 'search-responsiveness',
        workload: AiroBenchmarkWorkload.searchResponsiveness,
        thresholds: const [
          AiroBenchmarkMetricThreshold(
            metric: AiroBenchmarkMetric.elapsedMillis,
            maximum: 150,
          ),
        ],
      ),
      _gate(
        id: 'cache-cleanup',
        workload: AiroBenchmarkWorkload.cacheCleanup,
        thresholds: const [
          AiroBenchmarkMetricThreshold(
            metric: AiroBenchmarkMetric.storageMb,
            maximum: 256,
          ),
        ],
      ),
    ];
  }

  static AiroBenchmarkGate _gate({
    required String id,
    required AiroBenchmarkWorkload workload,
    required List<AiroBenchmarkMetricThreshold> thresholds,
    bool requiresPhysicalDevice = false,
  }) {
    return AiroBenchmarkGate(
      gateId: AiroBenchmarkStableValue.stable(id),
      workload: workload,
      requiresPhysicalDevice: requiresPhysicalDevice,
      acceptedEvidenceKinds: requiresPhysicalDevice
          ? const {
              AiroBenchmarkEvidenceKind.physicalDeviceRun,
              AiroBenchmarkEvidenceKind.benchmarkTrace,
            }
          : const {
              AiroBenchmarkEvidenceKind.hostAutomation,
              AiroBenchmarkEvidenceKind.benchmarkTrace,
            },
      thresholds: thresholds,
    );
  }

  static Set<AiroBenchmarkStableValue> _gateIds(List<String> ids) {
    return {for (final id in ids) AiroBenchmarkStableValue.stable(id)};
  }
}
