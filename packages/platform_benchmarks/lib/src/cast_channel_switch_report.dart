import 'dart:convert';
import 'dart:io';

const String kCastChannelSwitchReportSchemaVersion = '1.0.0';

enum CastChannelSwitchViolationCode {
  accepted('accepted'),
  insufficientSwitches('insufficient_switches'),
  switchFailure('switch_failure'),
  receiverReconnected('receiver_reconnected'),
  stalePreviousStatusObserved('stale_previous_status_observed'),
  previousChannelErrorShown('previous_channel_error_shown'),
  latestErrorMisattributed('latest_error_misattributed'),
  localPlaybackRestarted('local_playback_restarted'),
  recoveryRequired('recovery_required');

  const CastChannelSwitchViolationCode(this.stableId);

  final String stableId;
}

class CastChannelSwitchReportConfig {
  const CastChannelSwitchReportConfig({
    required this.reportId,
    required this.senderProfile,
    required this.receiverProfile,
    required this.playlistProfile,
    required this.attemptedSwitchCount,
    required this.successfulSwitchCount,
    required this.receiverReconnectCount,
    required this.stalePreviousStatusCount,
    required this.previousChannelErrorCount,
    required this.latestErrorMatchedSelectedChannel,
    required this.localPlaybackRestartCount,
    required this.recoveryActionCount,
    this.measuredAt,
    this.minSwitchCount = 2,
    this.outputJsonPath =
        'artifacts/performance/cast-channel-switch-report.json',
    this.outputMarkdownPath =
        'artifacts/performance/cast-channel-switch-report.md',
  });

  final String reportId;
  final String senderProfile;
  final String receiverProfile;
  final String playlistProfile;
  final int attemptedSwitchCount;
  final int successfulSwitchCount;
  final int receiverReconnectCount;
  final int stalePreviousStatusCount;
  final int previousChannelErrorCount;
  final bool latestErrorMatchedSelectedChannel;
  final int localPlaybackRestartCount;
  final int recoveryActionCount;
  final DateTime? measuredAt;
  final int minSwitchCount;
  final String outputJsonPath;
  final String outputMarkdownPath;

  CastChannelSwitchReportConfig normalized() {
    final normalizedReportId = reportId.trim();
    final normalizedSenderProfile = senderProfile.trim();
    final normalizedReceiverProfile = receiverProfile.trim();
    final normalizedPlaylistProfile = playlistProfile.trim();
    if (normalizedReportId.isEmpty) {
      throw ArgumentError.value(reportId, 'reportId', 'must not be empty');
    }
    if (normalizedSenderProfile.isEmpty) {
      throw ArgumentError.value(
        senderProfile,
        'senderProfile',
        'must not be empty',
      );
    }
    if (normalizedReceiverProfile.isEmpty) {
      throw ArgumentError.value(
        receiverProfile,
        'receiverProfile',
        'must not be empty',
      );
    }
    if (normalizedPlaylistProfile.isEmpty) {
      throw ArgumentError.value(
        playlistProfile,
        'playlistProfile',
        'must not be empty',
      );
    }
    _validatePublicLabel(normalizedReportId, 'reportId');
    _validatePublicLabel(normalizedSenderProfile, 'senderProfile');
    _validatePublicLabel(normalizedReceiverProfile, 'receiverProfile');
    _validatePublicLabel(normalizedPlaylistProfile, 'playlistProfile');
    _validatePositive(attemptedSwitchCount, 'attemptedSwitchCount');
    _validateNonNegative(successfulSwitchCount, 'successfulSwitchCount');
    _validateNonNegative(receiverReconnectCount, 'receiverReconnectCount');
    _validateNonNegative(stalePreviousStatusCount, 'stalePreviousStatusCount');
    _validateNonNegative(
      previousChannelErrorCount,
      'previousChannelErrorCount',
    );
    _validateNonNegative(
      localPlaybackRestartCount,
      'localPlaybackRestartCount',
    );
    _validateNonNegative(recoveryActionCount, 'recoveryActionCount');
    _validatePositive(minSwitchCount, 'minSwitchCount');
    if (successfulSwitchCount > attemptedSwitchCount) {
      throw ArgumentError.value(
        successfulSwitchCount,
        'successfulSwitchCount',
        'must be <= attemptedSwitchCount',
      );
    }

    return CastChannelSwitchReportConfig(
      reportId: normalizedReportId,
      senderProfile: normalizedSenderProfile,
      receiverProfile: normalizedReceiverProfile,
      playlistProfile: normalizedPlaylistProfile,
      attemptedSwitchCount: attemptedSwitchCount,
      successfulSwitchCount: successfulSwitchCount,
      receiverReconnectCount: receiverReconnectCount,
      stalePreviousStatusCount: stalePreviousStatusCount,
      previousChannelErrorCount: previousChannelErrorCount,
      latestErrorMatchedSelectedChannel: latestErrorMatchedSelectedChannel,
      localPlaybackRestartCount: localPlaybackRestartCount,
      recoveryActionCount: recoveryActionCount,
      measuredAt: (measuredAt ?? DateTime.now()).toUtc(),
      minSwitchCount: minSwitchCount,
      outputJsonPath: outputJsonPath,
      outputMarkdownPath: outputMarkdownPath,
    );
  }
}

class CastChannelSwitchEvaluation {
  CastChannelSwitchEvaluation({
    required this.config,
    required Iterable<CastChannelSwitchViolationCode> violations,
  }) : violations = List.unmodifiable(violations);

  final CastChannelSwitchReportConfig config;
  final List<CastChannelSwitchViolationCode> violations;

  bool get accepted =>
      violations.length == 1 &&
      violations.first == CastChannelSwitchViolationCode.accepted;

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': kCastChannelSwitchReportSchemaVersion,
      'reportId': config.reportId,
      'senderProfile': config.senderProfile,
      'receiverProfile': config.receiverProfile,
      'playlistProfile': config.playlistProfile,
      'measuredAt': config.measuredAt!.toIso8601String(),
      'accepted': accepted,
      'violations': violations
          .map((violation) => violation.stableId)
          .toList(growable: false),
      'sample': {
        'attemptedSwitchCount': config.attemptedSwitchCount,
        'successfulSwitchCount': config.successfulSwitchCount,
        'minSwitchCount': config.minSwitchCount,
        'receiverReconnectCount': config.receiverReconnectCount,
        'stalePreviousStatusCount': config.stalePreviousStatusCount,
        'previousChannelErrorCount': config.previousChannelErrorCount,
        'latestErrorMatchedSelectedChannel':
            config.latestErrorMatchedSelectedChannel,
        'localPlaybackRestartCount': config.localPlaybackRestartCount,
        'recoveryActionCount': config.recoveryActionCount,
      },
    };
  }

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# Cast Channel Switch Evidence')
      ..writeln()
      ..writeln('- Report: `${config.reportId}`')
      ..writeln('- Sender profile: `${config.senderProfile}`')
      ..writeln('- Receiver profile: `${config.receiverProfile}`')
      ..writeln('- Playlist profile: `${config.playlistProfile}`')
      ..writeln('- Accepted: `$accepted`')
      ..writeln(
        '- Violations: `${violations.map((code) => code.stableId).join(', ')}`',
      )
      ..writeln(
        '- Switches: ${config.successfulSwitchCount} / '
        '${config.attemptedSwitchCount}',
      )
      ..writeln('- Receiver reconnects: ${config.receiverReconnectCount}')
      ..writeln('- Stale previous statuses: ${config.stalePreviousStatusCount}')
      ..writeln(
        '- Previous-channel errors shown: ${config.previousChannelErrorCount}',
      )
      ..writeln(
        '- Latest error matched selected channel: '
        '${config.latestErrorMatchedSelectedChannel}',
      )
      ..writeln(
        '- Local playback restarts: ${config.localPlaybackRestartCount}',
      )
      ..writeln('- Recovery actions: ${config.recoveryActionCount}');
    return buffer.toString();
  }
}

class CastChannelSwitchReportWriter {
  const CastChannelSwitchReportWriter();

  CastChannelSwitchEvaluation evaluate(
    CastChannelSwitchReportConfig rawConfig,
  ) {
    final config = rawConfig.normalized();
    final violations = <CastChannelSwitchViolationCode>[];
    if (config.attemptedSwitchCount < config.minSwitchCount) {
      violations.add(CastChannelSwitchViolationCode.insufficientSwitches);
    }
    if (config.successfulSwitchCount < config.attemptedSwitchCount) {
      violations.add(CastChannelSwitchViolationCode.switchFailure);
    }
    if (config.receiverReconnectCount > 0) {
      violations.add(CastChannelSwitchViolationCode.receiverReconnected);
    }
    if (config.stalePreviousStatusCount > 0) {
      violations.add(
        CastChannelSwitchViolationCode.stalePreviousStatusObserved,
      );
    }
    if (config.previousChannelErrorCount > 0) {
      violations.add(CastChannelSwitchViolationCode.previousChannelErrorShown);
    }
    if (!config.latestErrorMatchedSelectedChannel) {
      violations.add(CastChannelSwitchViolationCode.latestErrorMisattributed);
    }
    if (config.localPlaybackRestartCount > 0) {
      violations.add(CastChannelSwitchViolationCode.localPlaybackRestarted);
    }
    if (config.recoveryActionCount > 0) {
      violations.add(CastChannelSwitchViolationCode.recoveryRequired);
    }
    if (violations.isEmpty) {
      violations.add(CastChannelSwitchViolationCode.accepted);
    }
    return CastChannelSwitchEvaluation(config: config, violations: violations);
  }

  Future<CastChannelSwitchEvaluation> write(
    CastChannelSwitchReportConfig rawConfig,
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
