import 'package:equatable/equatable.dart';

const String kAiroPerformanceInstrumentationSchemaVersion = '1.0.0';

enum AiroPerformanceArea {
  ui('ui'),
  playback('playback'),
  import('import'),
  search('search'),
  protocol('protocol'),
  command('command'),
  memory('memory'),
  storage('storage'),
  network('network'),
  pairing('pairing');

  const AiroPerformanceArea(this.stableId);

  final String stableId;
}

enum AiroPerformanceMetric {
  appStartup('app_startup'),
  frameBuild('frame_build'),
  frameRaster('frame_raster'),
  focusLatency('focus_latency'),
  playbackStartup('playback_startup'),
  timeToFirstFrame('time_to_first_frame'),
  rebufferDuration('rebuffer_duration'),
  rebufferCount('rebuffer_count'),
  failoverRecovery('failover_recovery'),
  decoderFallback('decoder_fallback'),
  importDuration('import_duration'),
  importThroughput('import_throughput'),
  searchLatency('search_latency'),
  protocolRoundTrip('protocol_round_trip'),
  commandAcknowledgement('command_acknowledgement'),
  memoryUsage('memory_usage'),
  storageUsage('storage_usage'),
  analyticsEnqueueLatency('analytics_enqueue_latency');

  const AiroPerformanceMetric(this.stableId);

  final String stableId;
}

enum AiroPerformanceUnit {
  milliseconds('milliseconds'),
  count('count'),
  megabytes('megabytes'),
  rowsPerSecond('rows_per_second'),
  ratio('ratio');

  const AiroPerformanceUnit(this.stableId);

  final String stableId;
}

enum AiroPerformanceBucket {
  under5ms('under_5ms'),
  under16ms('under_16ms'),
  under33ms('under_33ms'),
  under100ms('under_100ms'),
  under500ms('under_500ms'),
  under1s('under_1s'),
  oneTo3s('1_to_3s'),
  threeTo10s('3_to_10s'),
  over10s('over_10s'),
  notBucketed('not_bucketed');

  const AiroPerformanceBucket(this.stableId);

  final String stableId;
}

enum AiroPerformanceBudgetBlockerCode {
  accepted('accepted'),
  missingSample('missing_sample'),
  areaMismatch('area_mismatch'),
  metricMismatch('metric_mismatch'),
  unitMismatch('unit_mismatch'),
  aboveMaximum('above_maximum'),
  belowMinimum('below_minimum'),
  privacyUnsafeDimension('privacy_unsafe_dimension');

  const AiroPerformanceBudgetBlockerCode(this.stableId);

  final String stableId;
}

enum AiroPerformanceSafeValueRejectionCode {
  empty('empty'),
  prohibitedDimension('prohibited_dimension'),
  urlValue('url_value'),
  localPathValue('local_path_value'),
  localIpValue('local_ip_value'),
  credentialLikeValue('credential_like_value'),
  invalidStableId('invalid_stable_id');

  const AiroPerformanceSafeValueRejectionCode(this.stableId);

  final String stableId;
}

class AiroPerformanceSafeValue extends Equatable {
  const AiroPerformanceSafeValue._(this.value);

  factory AiroPerformanceSafeValue.stable(String value) {
    final rejection = validate(value);
    if (rejection != null) {
      throw ArgumentError.value(value, 'value', rejection.stableId);
    }
    return AiroPerformanceSafeValue._(value.trim());
  }

  static const Set<String> prohibitedDimensions = {
    'channel',
    'channelname',
    'mediatitle',
    'movietitle',
    'programtitle',
    'playlistname',
    'playlisturl',
    'streamurl',
    'signedurl',
    'url',
    'authorization',
    'authheader',
    'cookie',
    'credential',
    'providercredential',
    'providerdomain',
    'localpath',
    'path',
    'localip',
    'ipaddress',
    'query',
    'searchquery',
    'voicetranscript',
    'deviceid',
    'androidid',
    'serial',
    'macaddress',
  };

  final String value;

  static AiroPerformanceSafeValueRejectionCode? validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return AiroPerformanceSafeValueRejectionCode.empty;
    }
    final normalized = trimmed
        .replaceAll(RegExp('[^A-Za-z0-9]'), '')
        .toLowerCase();
    if (prohibitedDimensions.contains(normalized)) {
      return AiroPerformanceSafeValueRejectionCode.prohibitedDimension;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return AiroPerformanceSafeValueRejectionCode.urlValue;
    }
    if (trimmed.startsWith('file://') ||
        trimmed.startsWith('/') ||
        RegExp(r'^[A-Za-z]:\\').hasMatch(trimmed)) {
      return AiroPerformanceSafeValueRejectionCode.localPathValue;
    }
    if (RegExp(
      r'\b(?:10|127|172\.(?:1[6-9]|2\d|3[0-1])|192\.168)\.',
    ).hasMatch(trimmed)) {
      return AiroPerformanceSafeValueRejectionCode.localIpValue;
    }
    if (RegExp(
      r'\b(?:bearer|basic)\s+[A-Za-z0-9._~+/=-]+',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return AiroPerformanceSafeValueRejectionCode.credentialLikeValue;
    }
    if (!RegExp(r'^[A-Za-z0-9_.:-]+$').hasMatch(trimmed)) {
      return AiroPerformanceSafeValueRejectionCode.invalidStableId;
    }
    return null;
  }

  @override
  String toString() => 'AiroPerformanceSafeValue(redacted)';

  @override
  List<Object?> get props => [value];
}

class AiroPerformanceDimension extends Equatable {
  const AiroPerformanceDimension({
    required this.key,
    required this.value,
    this.schemaVersion = kAiroPerformanceInstrumentationSchemaVersion,
  });

  final String schemaVersion;
  final AiroPerformanceSafeValue key;
  final AiroPerformanceSafeValue value;

  @override
  String toString() {
    return 'AiroPerformanceDimension(key: ${key.value}, value: redacted)';
  }

  @override
  List<Object?> get props => [schemaVersion, key, value];
}

class AiroPerformanceSample extends Equatable {
  AiroPerformanceSample({
    required this.sampleId,
    required this.area,
    required this.metric,
    required this.unit,
    required this.value,
    required this.observedAt,
    this.bucket = AiroPerformanceBucket.notBucketed,
    Iterable<AiroPerformanceDimension> dimensions = const [],
    this.schemaVersion = kAiroPerformanceInstrumentationSchemaVersion,
  }) : dimensions = List.unmodifiable(dimensions) {
    _throwIfUnsafeStableId(sampleId, 'sampleId');
  }

  final String schemaVersion;
  final String sampleId;
  final AiroPerformanceArea area;
  final AiroPerformanceMetric metric;
  final AiroPerformanceUnit unit;
  final double value;
  final AiroPerformanceBucket bucket;
  final DateTime observedAt;
  final List<AiroPerformanceDimension> dimensions;

  bool get isLatencyMetric =>
      unit == AiroPerformanceUnit.milliseconds &&
      {
        AiroPerformanceMetric.appStartup,
        AiroPerformanceMetric.frameBuild,
        AiroPerformanceMetric.frameRaster,
        AiroPerformanceMetric.focusLatency,
        AiroPerformanceMetric.playbackStartup,
        AiroPerformanceMetric.timeToFirstFrame,
        AiroPerformanceMetric.failoverRecovery,
        AiroPerformanceMetric.searchLatency,
        AiroPerformanceMetric.protocolRoundTrip,
        AiroPerformanceMetric.commandAcknowledgement,
        AiroPerformanceMetric.analyticsEnqueueLatency,
      }.contains(metric);

  @override
  String toString() {
    return 'AiroPerformanceSample('
        'sampleId: $sampleId, '
        'area: ${area.stableId}, '
        'metric: ${metric.stableId}, '
        'unit: ${unit.stableId}, '
        'value: $value, '
        'bucket: ${bucket.stableId}, '
        'dimensionCount: ${dimensions.length}'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    sampleId,
    area,
    metric,
    unit,
    value,
    bucket,
    observedAt,
    dimensions,
  ];
}

class AiroPerformanceBudget extends Equatable {
  AiroPerformanceBudget({
    required this.budgetId,
    required this.area,
    required this.metric,
    required this.unit,
    this.maximum,
    this.minimum,
    this.schemaVersion = kAiroPerformanceInstrumentationSchemaVersion,
  }) {
    _throwIfUnsafeStableId(budgetId, 'budgetId');
  }

  final String schemaVersion;
  final String budgetId;
  final AiroPerformanceArea area;
  final AiroPerformanceMetric metric;
  final AiroPerformanceUnit unit;
  final double? maximum;
  final double? minimum;

  @override
  List<Object?> get props => [
    schemaVersion,
    budgetId,
    area,
    metric,
    unit,
    maximum,
    minimum,
  ];
}

class AiroPerformanceBudgetEvaluation extends Equatable {
  AiroPerformanceBudgetEvaluation({
    required this.budgetId,
    required this.sampleId,
    required Iterable<AiroPerformanceBudgetBlockerCode> blockers,
  }) : blockers = List.unmodifiable(blockers);

  final String budgetId;
  final String sampleId;
  final List<AiroPerformanceBudgetBlockerCode> blockers;

  bool get accepted =>
      blockers.length == 1 &&
      blockers.single == AiroPerformanceBudgetBlockerCode.accepted;

  @override
  List<Object?> get props => [budgetId, sampleId, blockers];
}

class AiroPerformanceBudgetPolicy {
  const AiroPerformanceBudgetPolicy();

  AiroPerformanceBudgetEvaluation evaluate({
    required AiroPerformanceBudget budget,
    AiroPerformanceSample? sample,
  }) {
    final blockers = <AiroPerformanceBudgetBlockerCode>[];
    if (sample == null) {
      blockers.add(AiroPerformanceBudgetBlockerCode.missingSample);
      return AiroPerformanceBudgetEvaluation(
        budgetId: budget.budgetId,
        sampleId: 'missing',
        blockers: blockers,
      );
    }

    if (sample.area != budget.area) {
      blockers.add(AiroPerformanceBudgetBlockerCode.areaMismatch);
    }
    if (sample.metric != budget.metric) {
      blockers.add(AiroPerformanceBudgetBlockerCode.metricMismatch);
    }
    if (sample.unit != budget.unit) {
      blockers.add(AiroPerformanceBudgetBlockerCode.unitMismatch);
    }
    if (budget.maximum != null && sample.value > budget.maximum!) {
      blockers.add(AiroPerformanceBudgetBlockerCode.aboveMaximum);
    }
    if (budget.minimum != null && sample.value < budget.minimum!) {
      blockers.add(AiroPerformanceBudgetBlockerCode.belowMinimum);
    }

    return AiroPerformanceBudgetEvaluation(
      budgetId: budget.budgetId,
      sampleId: sample.sampleId,
      blockers: blockers.isEmpty
          ? const [AiroPerformanceBudgetBlockerCode.accepted]
          : blockers,
    );
  }
}

abstract interface class AiroPerformanceInstrumentationSink {
  Future<AiroPerformanceRecordResult> record(AiroPerformanceSample sample);
}

class AiroPerformanceRecordResult extends Equatable {
  const AiroPerformanceRecordResult({required this.accepted, this.reason});

  final bool accepted;
  final AiroPerformanceBudgetBlockerCode? reason;

  @override
  List<Object?> get props => [accepted, reason];
}

class AiroNoOpPerformanceInstrumentationSink
    implements AiroPerformanceInstrumentationSink {
  const AiroNoOpPerformanceInstrumentationSink();

  @override
  Future<AiroPerformanceRecordResult> record(
    AiroPerformanceSample sample,
  ) async {
    return const AiroPerformanceRecordResult(accepted: true);
  }
}

class AiroFakePerformanceInstrumentationSink
    implements AiroPerformanceInstrumentationSink {
  AiroFakePerformanceInstrumentationSink({this.maxSamples = 100});

  final int maxSamples;
  final List<AiroPerformanceSample> _samples = [];

  List<AiroPerformanceSample> get samples => List.unmodifiable(_samples);

  @override
  Future<AiroPerformanceRecordResult> record(
    AiroPerformanceSample sample,
  ) async {
    if (_samples.length >= maxSamples) {
      return const AiroPerformanceRecordResult(
        accepted: false,
        reason: AiroPerformanceBudgetBlockerCode.aboveMaximum,
      );
    }
    _samples.add(sample);
    return const AiroPerformanceRecordResult(accepted: true);
  }
}

AiroPerformanceBucket bucketLatency(Duration duration) {
  final millis = duration.inMilliseconds;
  if (millis < 5) return AiroPerformanceBucket.under5ms;
  if (millis < 16) return AiroPerformanceBucket.under16ms;
  if (millis < 33) return AiroPerformanceBucket.under33ms;
  if (millis < 100) return AiroPerformanceBucket.under100ms;
  if (millis < 500) return AiroPerformanceBucket.under500ms;
  if (millis < 1000) return AiroPerformanceBucket.under1s;
  if (millis < 3000) return AiroPerformanceBucket.oneTo3s;
  if (millis < 10000) return AiroPerformanceBucket.threeTo10s;
  return AiroPerformanceBucket.over10s;
}

void _throwIfUnsafeStableId(String value, String name) {
  final rejection = AiroPerformanceSafeValue.validate(value);
  if (rejection != null) {
    throw ArgumentError.value(value, name, rejection.stableId);
  }
}
