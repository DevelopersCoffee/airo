import 'dart:io';

import 'package:platform_benchmarks/src/airo_tv_dpad_traversal_report.dart';

Future<void> main(List<String> args) async {
  final options = _CliOptions.parse(args);
  final evaluation = await const AiroTvDpadTraversalReportWriter().write(
    AiroTvDpadTraversalReportConfig(
      reportId: options.reportId,
      deviceProfile: options.deviceProfile,
      viewportProfile: options.viewportProfile,
      requiredActionCount: options.requiredActionCount,
      reachableActionCount: options.reachableActionCount,
      channelCardTraversalCount: options.channelCardTraversalCount,
      helpDialogOpened: options.helpDialogOpened,
      helpDialogDismissed: options.helpDialogDismissed,
      focusLossCount: options.focusLossCount,
      overflowCount: options.overflowCount,
      renderErrorCount: options.renderErrorCount,
      outputJsonPath: options.outputJsonPath,
      outputMarkdownPath: options.outputMarkdownPath,
    ),
  );
  stdout.writeln(evaluation.toMarkdown());
}

class _CliOptions {
  const _CliOptions({
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
    required this.outputJsonPath,
    required this.outputMarkdownPath,
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
      deviceProfile:
          values['device-profile'] ?? _usage('Missing --device-profile'),
      viewportProfile:
          values['viewport-profile'] ?? _usage('Missing --viewport-profile'),
      requiredActionCount: _parseInt(
        values['required-actions'],
        name: 'required-actions',
      ),
      reachableActionCount: _parseInt(
        values['reachable-actions'],
        name: 'reachable-actions',
      ),
      channelCardTraversalCount: _parseInt(
        values['channel-cards-traversed'],
        name: 'channel-cards-traversed',
      ),
      helpDialogOpened: _parseBool(values['help-opened'], name: 'help-opened'),
      helpDialogDismissed: _parseBool(
        values['help-dismissed'],
        name: 'help-dismissed',
      ),
      focusLossCount: _parseInt(
        values['focus-loss-count'] ?? '0',
        name: 'focus-loss-count',
      ),
      overflowCount: _parseInt(
        values['overflow-count'] ?? '0',
        name: 'overflow-count',
      ),
      renderErrorCount: _parseInt(
        values['render-error-count'] ?? '0',
        name: 'render-error-count',
      ),
      outputJsonPath:
          values['output-json'] ??
          'artifacts/performance/airo-tv-dpad-traversal-report.json',
      outputMarkdownPath:
          values['output-markdown'] ??
          'artifacts/performance/airo-tv-dpad-traversal-report.md',
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
  dart run tool/write_dpad_traversal_report.dart \\
    --report-id shield-tv-dpad-traversal \\
    --device-profile shield-tv-physical \\
    --viewport-profile android-tv-1080p \\
    --required-actions 9 \\
    --reachable-actions 9 \\
    --channel-cards-traversed 12 \\
    --help-opened true \\
    --help-dismissed true \\
    --focus-loss-count 0 \\
    --overflow-count 0 \\
    --render-error-count 0

Outputs:
  artifacts/performance/airo-tv-dpad-traversal-report.json
  artifacts/performance/airo-tv-dpad-traversal-report.md
''');
    exit(exitCode);
  }
}
