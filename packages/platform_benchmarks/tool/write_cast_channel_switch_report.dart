import 'dart:io';

import 'package:platform_benchmarks/src/cast_channel_switch_report.dart';

Future<void> main(List<String> args) async {
  final options = _CliOptions.parse(args);
  final evaluation = await const CastChannelSwitchReportWriter().write(
    CastChannelSwitchReportConfig(
      reportId: options.reportId,
      senderProfile: options.senderProfile,
      receiverProfile: options.receiverProfile,
      playlistProfile: options.playlistProfile,
      attemptedSwitchCount: options.attemptedSwitchCount,
      successfulSwitchCount: options.successfulSwitchCount,
      receiverReconnectCount: options.receiverReconnectCount,
      stalePreviousStatusCount: options.stalePreviousStatusCount,
      previousChannelErrorCount: options.previousChannelErrorCount,
      latestErrorMatchedSelectedChannel:
          options.latestErrorMatchedSelectedChannel,
      localPlaybackRestartCount: options.localPlaybackRestartCount,
      recoveryActionCount: options.recoveryActionCount,
      outputJsonPath: options.outputJsonPath,
      outputMarkdownPath: options.outputMarkdownPath,
    ),
  );
  stdout.writeln(evaluation.toMarkdown());
}

class _CliOptions {
  const _CliOptions({
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
    required this.outputJsonPath,
    required this.outputMarkdownPath,
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
  final String outputJsonPath;
  final String outputMarkdownPath;

  static _CliOptions parse(List<String> args) {
    final values = <String, String>{};
    for (var index = 0; index < args.length; index++) {
      final arg = args[index];
      if (!arg.startsWith('--')) _usage('Unexpected argument: $arg');
      final key = arg.substring(2);
      if (key == 'help') _usage(null, exitCode: 0);
      if (index + 1 >= args.length || args[index + 1].startsWith('--')) {
        _usage('Missing value for --$key');
      }
      values[key] = args[++index];
    }

    return _CliOptions(
      reportId: values['report-id'] ?? _usage('Missing --report-id'),
      senderProfile:
          values['sender-profile'] ?? _usage('Missing --sender-profile'),
      receiverProfile:
          values['receiver-profile'] ?? _usage('Missing --receiver-profile'),
      playlistProfile:
          values['playlist-profile'] ?? _usage('Missing --playlist-profile'),
      attemptedSwitchCount: _parseInt(
        values['attempted-switches'],
        name: 'attempted-switches',
      ),
      successfulSwitchCount: _parseInt(
        values['successful-switches'],
        name: 'successful-switches',
      ),
      receiverReconnectCount: _parseInt(
        values['receiver-reconnects'] ?? '0',
        name: 'receiver-reconnects',
      ),
      stalePreviousStatusCount: _parseInt(
        values['stale-previous-statuses'] ?? '0',
        name: 'stale-previous-statuses',
      ),
      previousChannelErrorCount: _parseInt(
        values['previous-channel-errors'] ?? '0',
        name: 'previous-channel-errors',
      ),
      latestErrorMatchedSelectedChannel: _parseBool(
        values['latest-error-matched-selected'] ?? 'true',
        name: 'latest-error-matched-selected',
      ),
      localPlaybackRestartCount: _parseInt(
        values['local-playback-restarts'] ?? '0',
        name: 'local-playback-restarts',
      ),
      recoveryActionCount: _parseInt(
        values['recovery-actions'] ?? '0',
        name: 'recovery-actions',
      ),
      outputJsonPath:
          values['output-json'] ??
          'artifacts/performance/cast-channel-switch-report.json',
      outputMarkdownPath:
          values['output-markdown'] ??
          'artifacts/performance/cast-channel-switch-report.md',
    );
  }

  static int _parseInt(String? value, {required String name}) {
    if (value == null) _usage('Missing --$name');
    return int.tryParse(value) ?? _usage('Invalid integer for --$name: $value');
  }

  static bool _parseBool(String? value, {required String name}) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null) _usage('Missing --$name');
    return switch (normalized) {
      'true' || 'yes' || '1' => true,
      'false' || 'no' || '0' => false,
      _ => _usage('Invalid boolean for --$name: $value'),
    };
  }

  static Never _usage(String? message, {int exitCode = 64}) {
    if (message != null) stderr.writeln(message);
    stderr.writeln('''
Usage:
  dart run tool/write_cast_channel_switch_report.dart \\
    --report-id pixel9-bravia-switch-pass \\
    --sender-profile pixel9-physical \\
    --receiver-profile bravia-chromecast \\
    --playlist-profile iptv-org-public \\
    --attempted-switches 2 \\
    --successful-switches 2 \\
    --receiver-reconnects 0 \\
    --stale-previous-statuses 0 \\
    --previous-channel-errors 0 \\
    --latest-error-matched-selected true \\
    --local-playback-restarts 0 \\
    --recovery-actions 0

Outputs:
  artifacts/performance/cast-channel-switch-report.json
  artifacts/performance/cast-channel-switch-report.md
''');
    exit(exitCode);
  }
}
