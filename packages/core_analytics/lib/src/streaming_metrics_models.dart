import 'package:equatable/equatable.dart';

import 'analytics_models.dart';

/// Validation outcome codes for [AiroStreamingSessionSummary.validate].
enum AiroStreamingSessionSummaryValidationCode {
  accepted('accepted'),
  negativeCount('negative_count'),
  rebufferRatioOutOfRange('rebuffer_ratio_out_of_range'),
  negativeThroughput('negative_throughput'),
  unsafeFieldValue('unsafe_field_value');

  const AiroStreamingSessionSummaryValidationCode(this.stableId);

  final String stableId;
}

/// Result of validating an [AiroStreamingSessionSummary].
class AiroStreamingSessionSummaryValidationResult extends Equatable {
  AiroStreamingSessionSummaryValidationResult({
    required List<AiroStreamingSessionSummaryValidationCode> codes,
  }) : codes = List.unmodifiable(codes);

  final List<AiroStreamingSessionSummaryValidationCode> codes;

  bool get accepted =>
      codes.length == 1 &&
      codes.single == AiroStreamingSessionSummaryValidationCode.accepted;

  @override
  List<Object?> get props => [codes];
}

/// Per-session streaming QoE summary (requirements F7.1), emitted once at
/// session end under [AiroAnalyticsPurpose.playbackQuality].
///
/// [activeSourceId] is a redacted source handle, never a raw stream URL —
/// [validate] and the shared [AiroAnalyticsPrivacyFilter] both reject URL-
/// or credential-shaped values so a mistaken raw URL fails loudly instead
/// of leaking (F7.6).
class AiroStreamingSessionSummary extends Equatable {
  const AiroStreamingSessionSummary({
    required this.sessionId,
    required this.activeSourceId,
    required this.networkKey,
    this.ttffMs,
    this.rebufferCount = 0,
    this.rebufferDurationRatio = 0,
    this.sourceSwitchCount = 0,
    this.throughputKbpsP50,
    this.throughputKbpsP10,
    this.schemaVersion = kAiroAnalyticsSchemaVersion,
  });

  final String sessionId;
  final String activeSourceId;
  final String networkKey;

  /// Time to first frame, in milliseconds. Null if the session ended before
  /// a first frame was rendered.
  final int? ttffMs;
  final int rebufferCount;

  /// Fraction of watch time spent rebuffering, in `[0, 1]`.
  final double rebufferDurationRatio;
  final int sourceSwitchCount;
  final double? throughputKbpsP50;
  final double? throughputKbpsP10;
  final String schemaVersion;

  AiroStreamingSessionSummaryValidationResult validate() {
    final codes = <AiroStreamingSessionSummaryValidationCode>[];

    if (rebufferCount < 0 ||
        sourceSwitchCount < 0 ||
        (ttffMs != null && ttffMs! < 0)) {
      codes.add(AiroStreamingSessionSummaryValidationCode.negativeCount);
    }
    if (rebufferDurationRatio < 0 || rebufferDurationRatio > 1) {
      codes.add(
        AiroStreamingSessionSummaryValidationCode.rebufferRatioOutOfRange,
      );
    }
    if ((throughputKbpsP50 != null && throughputKbpsP50! < 0) ||
        (throughputKbpsP10 != null && throughputKbpsP10! < 0)) {
      codes.add(AiroStreamingSessionSummaryValidationCode.negativeThroughput);
    }

    final privacy = AiroAnalyticsPrivacyFilter.standard.validate(
      toAnalyticsEvent(),
    );
    if (!privacy.isAccepted) {
      codes.add(AiroStreamingSessionSummaryValidationCode.unsafeFieldValue);
    }

    return AiroStreamingSessionSummaryValidationResult(
      codes: codes.isEmpty
          ? const [AiroStreamingSessionSummaryValidationCode.accepted]
          : codes,
    );
  }

  AiroAnalyticsEvent toAnalyticsEvent() {
    return AiroAnalyticsEvent(
      name: 'streaming_session_summary',
      owner: 'platform_player',
      purpose: AiroAnalyticsPurpose.playbackQuality,
      schemaVersion: schemaVersion,
      params: {
        'session_id': sessionId,
        'active_source_id': activeSourceId,
        'network_key': networkKey,
        if (ttffMs != null) 'ttff_ms': ttffMs,
        'rebuffer_count': rebufferCount,
        'rebuffer_duration_ratio': rebufferDurationRatio,
        'source_switch_count': sourceSwitchCount,
        if (throughputKbpsP50 != null)
          'throughput_kbps_p50': throughputKbpsP50,
        if (throughputKbpsP10 != null)
          'throughput_kbps_p10': throughputKbpsP10,
      },
    );
  }

  @override
  List<Object?> get props => [
    sessionId,
    activeSourceId,
    networkKey,
    ttffMs,
    rebufferCount,
    rebufferDurationRatio,
    sourceSwitchCount,
    throughputKbpsP50,
    throughputKbpsP10,
    schemaVersion,
  ];
}
