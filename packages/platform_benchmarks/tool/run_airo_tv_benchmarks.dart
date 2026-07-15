import 'dart:io';

import 'package:platform_benchmarks/platform_benchmarks.dart';

Future<void> main(List<String> args) async {
  final config = _parseArgs(args).normalized();
  final artifact = await const AiroTvHostBenchmarkRunner().runAndWrite(config);

  stdout.writeln(
    'Airo TV host benchmark wrote ${config.outputPath} '
    '(accepted: ${artifact.accepted})',
  );

  if (!artifact.accepted) {
    stderr.writeln(
      'Benchmark rejected: '
      '${artifact.evaluation.blockers.map((blocker) => blocker.stableId).join(', ')}',
    );
    exitCode = 1;
  }
}

AiroTvHostBenchmarkConfig _parseArgs(List<String> args) {
  var channelCount = 2000;
  var iterations = 5;
  var outputPath = 'artifacts/performance/airo-tv-host-benchmark.json';
  var deviceClass = 'host_local';

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    String nextValue() {
      if (i + 1 >= args.length) {
        throw FormatException('Missing value for $arg');
      }
      i++;
      return args[i];
    }

    if (arg == '--channels') {
      channelCount = int.parse(nextValue());
    } else if (arg == '--iterations') {
      iterations = int.parse(nextValue());
    } else if (arg == '--output') {
      outputPath = nextValue();
    } else if (arg == '--device-class') {
      deviceClass = nextValue();
    } else if (arg == '--help' || arg == '-h') {
      stdout.writeln(
        'Usage: dart run tool/run_airo_tv_benchmarks.dart '
        '[--channels 2000] [--iterations 5] '
        '[--output artifacts/performance/airo-tv-host-benchmark.json] '
        '[--device-class host_local]',
      );
      exit(0);
    } else {
      throw FormatException('Unknown argument: $arg');
    }
  }

  return AiroTvHostBenchmarkConfig(
    channelCount: channelCount,
    iterations: iterations,
    outputPath: outputPath,
    deviceClass: deviceClass,
  );
}
