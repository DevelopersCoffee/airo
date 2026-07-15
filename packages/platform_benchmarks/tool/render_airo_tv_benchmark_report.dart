import 'dart:io';

import 'package:platform_benchmarks/platform_benchmarks.dart';

Future<void> main(List<String> args) async {
  final config = _parseArgs(args);
  await const AiroTvBenchmarkReportRenderer().renderFile(
    inputPath: config.inputPath,
    outputPath: config.outputPath,
  );

  stdout.writeln(
    'Airo TV benchmark report wrote ${config.outputPath} '
    'from ${config.inputPath}',
  );
}

_ReportConfig _parseArgs(List<String> args) {
  var inputPath = 'artifacts/performance/airo-tv-host-benchmark.json';
  var outputPath = 'artifacts/performance/airo-tv-host-benchmark.md';

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    String nextValue() {
      if (i + 1 >= args.length) {
        throw FormatException('Missing value for $arg');
      }
      i++;
      return args[i];
    }

    if (arg == '--input') {
      inputPath = nextValue();
    } else if (arg == '--output') {
      outputPath = nextValue();
    } else if (arg == '--help' || arg == '-h') {
      stdout.writeln(
        'Usage: dart run tool/render_airo_tv_benchmark_report.dart '
        '[--input artifacts/performance/airo-tv-host-benchmark.json] '
        '[--output artifacts/performance/airo-tv-host-benchmark.md]',
      );
      exit(0);
    } else {
      throw FormatException('Unknown argument: $arg');
    }
  }

  return _ReportConfig(inputPath: inputPath, outputPath: outputPath);
}

class _ReportConfig {
  const _ReportConfig({required this.inputPath, required this.outputPath});

  final String inputPath;
  final String outputPath;
}
