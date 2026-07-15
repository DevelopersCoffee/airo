import 'dart:io';

import 'package:platform_benchmarks/src/airo_tv_logo_scroll_report.dart';

Future<void> main(List<String> args) async {
  final options = _CliOptions.parse(args);
  final evaluation = await const AiroTvLogoScrollReportWriter().write(
    AiroTvLogoScrollReportConfig(
      reportId: options.reportId,
      scenarioId: options.scenarioId,
      playlistChannelCount: options.playlistChannelCount,
      visibleCellCount: options.visibleCellCount,
      durationSeconds: options.durationSeconds,
      baselineRssMb: options.baselineRssMb,
      peakRssMb: options.peakRssMb,
      steadyRssMb: options.steadyRssMb,
      rssPlateauDeltaMb: options.rssPlateauDeltaMb,
      imageCachePeakMb: options.imageCachePeakMb,
      frameJankCount: options.frameJankCount,
      decodeJankFrameCount: options.decodeJankFrameCount,
      outputJsonPath: options.outputJsonPath,
      outputMarkdownPath: options.outputMarkdownPath,
    ),
  );
  stdout.writeln(evaluation.toMarkdown());
}

class _CliOptions {
  const _CliOptions({
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
    required this.outputJsonPath,
    required this.outputMarkdownPath,
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
      scenarioId: values['scenario-id'] ?? 'large-logo-grid-scroll',
      playlistChannelCount: _parseInt(
        values['playlist-channels'],
        name: 'playlist-channels',
      ),
      visibleCellCount: _parseInt(
        values['visible-cells'],
        name: 'visible-cells',
      ),
      durationSeconds: _parseInt(
        values['duration-seconds'],
        name: 'duration-seconds',
      ),
      baselineRssMb: _parseInt(
        values['baseline-rss-mb'],
        name: 'baseline-rss-mb',
      ),
      peakRssMb: _parseInt(values['peak-rss-mb'], name: 'peak-rss-mb'),
      steadyRssMb: _parseInt(values['steady-rss-mb'], name: 'steady-rss-mb'),
      rssPlateauDeltaMb: _parseInt(
        values['rss-plateau-delta-mb'],
        name: 'rss-plateau-delta-mb',
      ),
      imageCachePeakMb: _parseInt(
        values['image-cache-peak-mb'],
        name: 'image-cache-peak-mb',
      ),
      frameJankCount: _parseInt(
        values['frame-jank-count'] ?? '0',
        name: 'frame-jank-count',
      ),
      decodeJankFrameCount: _parseInt(
        values['decode-jank-frame-count'] ?? '0',
        name: 'decode-jank-frame-count',
      ),
      outputJsonPath:
          values['output-json'] ??
          'artifacts/performance/airo-tv-logo-scroll-report.json',
      outputMarkdownPath:
          values['output-markdown'] ??
          'artifacts/performance/airo-tv-logo-scroll-report.md',
    );
  }

  static int _parseInt(String? value, {required String name}) {
    if (value == null) _usage('Missing --$name');
    return int.tryParse(value) ?? _usage('Invalid integer for --$name: $value');
  }

  static Never _usage(String? message, {int exitCode = 64}) {
    if (message != null) stderr.writeln(message);
    stderr.writeln('''
Usage:
  dart run tool/write_logo_scroll_report.dart \\
    --report-id shield-tv-logo-scroll-10k \\
    --scenario-id large-logo-grid-scroll \\
    --playlist-channels 12000 \\
    --visible-cells 24 \\
    --duration-seconds 180 \\
    --baseline-rss-mb 180 \\
    --peak-rss-mb 242 \\
    --steady-rss-mb 230 \\
    --rss-plateau-delta-mb 8 \\
    --image-cache-peak-mb 14 \\
    --frame-jank-count 0 \\
    --decode-jank-frame-count 0

Outputs:
  artifacts/performance/airo-tv-logo-scroll-report.json
  artifacts/performance/airo-tv-logo-scroll-report.md
''');
    exit(exitCode);
  }
}
