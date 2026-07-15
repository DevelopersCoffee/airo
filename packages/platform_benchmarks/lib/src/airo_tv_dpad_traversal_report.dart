import 'dart:convert';
import 'dart:io';

const String kAiroTvDpadTraversalReportSchemaVersion = '1.0.0';

enum AiroTvDpadTraversalViolationCode {
  accepted('accepted'),
  actionReachabilityIncomplete('action_reachability_incomplete'),
  channelTraversalTooShallow('channel_traversal_too_shallow'),
  helpDialogNotOperable('help_dialog_not_operable'),
  focusLossDetected('focus_loss_detected'),
  overflowDetected('overflow_detected'),
  renderErrorDetected('render_error_detected');

  const AiroTvDpadTraversalViolationCode(this.stableId);

  final String stableId;
}

class AiroTvDpadTraversalReportConfig {
  const AiroTvDpadTraversalReportConfig({
    required this.reportId,
    required this.deviceProfile,
    required this.viewportProfile,
    required this.requiredActionCount,
    required this.reachableActionCount,
    required this.channelCardTraversalCount,
    required this.helpDialogOpened,
    required this.helpDialogDismissed,
    required this.focusLossCount,
    required this.overflowCount,
    required this.renderErrorCount,
    this.measuredAt,
    this.minChannelCardTraversalCount = 8,
    this.outputJsonPath =
        'artifacts/performance/airo-tv-dpad-traversal-report.json',
    this.outputMarkdownPath =
        'artifacts/performance/airo-tv-dpad-traversal-report.md',
  });

  final String reportId;
  final String deviceProfile;
  final String viewportProfile;
  final int requiredActionCount;
  final int reachableActionCount;
  final int channelCardTraversalCount;
  final bool helpDialogOpened;
  final bool helpDialogDismissed;
  final int focusLossCount;
  final int overflowCount;
  final int renderErrorCount;
  final DateTime? measuredAt;
  final int minChannelCardTraversalCount;
  final String outputJsonPath;
  final String outputMarkdownPath;

  AiroTvDpadTraversalReportConfig normalized() {
    final normalizedReportId = reportId.trim();
    final normalizedDeviceProfile = deviceProfile.trim();
    final normalizedViewportProfile = viewportProfile.trim();
    if (normalizedReportId.isEmpty) {
      throw ArgumentError.value(reportId, 'reportId', 'must not be empty');
    }
    if (normalizedDeviceProfile.isEmpty) {
      throw ArgumentError.value(
        deviceProfile,
        'deviceProfile',
        'must not be empty',
      );
    }
    if (normalizedViewportProfile.isEmpty) {
      throw ArgumentError.value(
        viewportProfile,
        'viewportProfile',
        'must not be empty',
      );
    }
    _validatePublicLabel(normalizedReportId, 'reportId');
    _validatePublicLabel(normalizedDeviceProfile, 'deviceProfile');
    _validatePublicLabel(normalizedViewportProfile, 'viewportProfile');
    _validatePositive(requiredActionCount, 'requiredActionCount');
    _validateNonNegative(reachableActionCount, 'reachableActionCount');
    _validateNonNegative(
      channelCardTraversalCount,
      'channelCardTraversalCount',
    );
    _validateNonNegative(focusLossCount, 'focusLossCount');
    _validateNonNegative(overflowCount, 'overflowCount');
    _validateNonNegative(renderErrorCount, 'renderErrorCount');
    _validatePositive(
      minChannelCardTraversalCount,
      'minChannelCardTraversalCount',
    );
    if (reachableActionCount > requiredActionCount) {
      throw ArgumentError.value(
        reachableActionCount,
        'reachableActionCount',
        'must be <= requiredActionCount',
      );
    }

    return AiroTvDpadTraversalReportConfig(
      reportId: normalizedReportId,
      deviceProfile: normalizedDeviceProfile,
      viewportProfile: normalizedViewportProfile,
      requiredActionCount: requiredActionCount,
      reachableActionCount: reachableActionCount,
      channelCardTraversalCount: channelCardTraversalCount,
      helpDialogOpened: helpDialogOpened,
      helpDialogDismissed: helpDialogDismissed,
      focusLossCount: focusLossCount,
      overflowCount: overflowCount,
      renderErrorCount: renderErrorCount,
      measuredAt: (measuredAt ?? DateTime.now()).toUtc(),
      minChannelCardTraversalCount: minChannelCardTraversalCount,
      outputJsonPath: outputJsonPath,
      outputMarkdownPath: outputMarkdownPath,
    );
  }
}

class AiroTvDpadTraversalEvaluation {
  AiroTvDpadTraversalEvaluation({
    required this.config,
    required Iterable<AiroTvDpadTraversalViolationCode> violations,
  }) : violations = List.unmodifiable(violations);

  final AiroTvDpadTraversalReportConfig config;
  final List<AiroTvDpadTraversalViolationCode> violations;

  bool get accepted =>
      violations.length == 1 &&
      violations.first == AiroTvDpadTraversalViolationCode.accepted;

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': kAiroTvDpadTraversalReportSchemaVersion,
      'reportId': config.reportId,
      'deviceProfile': config.deviceProfile,
      'viewportProfile': config.viewportProfile,
      'measuredAt': config.measuredAt!.toIso8601String(),
      'accepted': accepted,
      'violations': violations
          .map((violation) => violation.stableId)
          .toList(growable: false),
      'sample': {
        'requiredActionCount': config.requiredActionCount,
        'reachableActionCount': config.reachableActionCount,
        'channelCardTraversalCount': config.channelCardTraversalCount,
        'minChannelCardTraversalCount': config.minChannelCardTraversalCount,
        'helpDialogOpened': config.helpDialogOpened,
        'helpDialogDismissed': config.helpDialogDismissed,
        'focusLossCount': config.focusLossCount,
        'overflowCount': config.overflowCount,
        'renderErrorCount': config.renderErrorCount,
      },
    };
  }

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# Airo TV D-pad Traversal Evidence')
      ..writeln()
      ..writeln('- Report: `${config.reportId}`')
      ..writeln('- Device profile: `${config.deviceProfile}`')
      ..writeln('- Viewport profile: `${config.viewportProfile}`')
      ..writeln('- Accepted: `$accepted`')
      ..writeln(
        '- Violations: `${violations.map((code) => code.stableId).join(', ')}`',
      )
      ..writeln(
        '- Actions reached: ${config.reachableActionCount} / '
        '${config.requiredActionCount}',
      )
      ..writeln(
        '- Channel cards traversed: ${config.channelCardTraversalCount} / '
        '${config.minChannelCardTraversalCount}',
      )
      ..writeln('- Help dialog opened: ${config.helpDialogOpened}')
      ..writeln('- Help dialog dismissed: ${config.helpDialogDismissed}')
      ..writeln('- Focus losses: ${config.focusLossCount}')
      ..writeln('- Overflow count: ${config.overflowCount}')
      ..writeln('- Render error count: ${config.renderErrorCount}');
    return buffer.toString();
  }
}

class AiroTvDpadTraversalReportWriter {
  const AiroTvDpadTraversalReportWriter();

  AiroTvDpadTraversalEvaluation evaluate(
    AiroTvDpadTraversalReportConfig rawConfig,
  ) {
    final config = rawConfig.normalized();
    final violations = <AiroTvDpadTraversalViolationCode>[];
    if (config.reachableActionCount < config.requiredActionCount) {
      violations.add(
        AiroTvDpadTraversalViolationCode.actionReachabilityIncomplete,
      );
    }
    if (config.channelCardTraversalCount <
        config.minChannelCardTraversalCount) {
      violations.add(
        AiroTvDpadTraversalViolationCode.channelTraversalTooShallow,
      );
    }
    if (!config.helpDialogOpened || !config.helpDialogDismissed) {
      violations.add(AiroTvDpadTraversalViolationCode.helpDialogNotOperable);
    }
    if (config.focusLossCount > 0) {
      violations.add(AiroTvDpadTraversalViolationCode.focusLossDetected);
    }
    if (config.overflowCount > 0) {
      violations.add(AiroTvDpadTraversalViolationCode.overflowDetected);
    }
    if (config.renderErrorCount > 0) {
      violations.add(AiroTvDpadTraversalViolationCode.renderErrorDetected);
    }
    if (violations.isEmpty) {
      violations.add(AiroTvDpadTraversalViolationCode.accepted);
    }
    return AiroTvDpadTraversalEvaluation(
      config: config,
      violations: violations,
    );
  }

  Future<AiroTvDpadTraversalEvaluation> write(
    AiroTvDpadTraversalReportConfig rawConfig,
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
