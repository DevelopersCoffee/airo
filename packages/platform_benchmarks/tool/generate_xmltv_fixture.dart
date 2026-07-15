import 'dart:io';

import 'package:platform_benchmarks/platform_benchmarks.dart';

Future<void> main(List<String> args) async {
  final config = _parseArgs(args).normalized();
  final manifest = await const AiroXmltvFixtureGenerator().writeFixture(config);

  stdout
    ..writeln('Airo XMLTV fixture wrote ${config.outputPath}')
    ..writeln('Manifest wrote ${config.manifestPath}')
    ..writeln('bytes: ${manifest.byteCount}')
    ..writeln('sha256: ${manifest.sha256}')
    ..writeln('channels: ${manifest.channelCount}')
    ..writeln('programmes: ${manifest.programmeCount}');
}

AiroXmltvFixtureConfig _parseArgs(List<String> args) {
  var fixtureId = 'generated-xmltv-50mb-v1';
  var outputPath = 'iptv-data/fixtures/xmltv/generated-50mb.xml';
  var manifestPath = 'iptv-data/fixtures/xmltv/generated-50mb.manifest.json';
  var targetByteCount = kAiroXmltvFixtureDefaultTargetBytes;
  var channelCount = 512;
  var programmeDurationMinutes = 30;
  var startUtc = DateTime.utc(2026);

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    String nextValue() {
      if (i + 1 >= args.length) {
        throw FormatException('Missing value for $arg');
      }
      i++;
      return args[i];
    }

    if (arg == '--fixture-id') {
      fixtureId = nextValue();
    } else if (arg == '--output') {
      outputPath = nextValue();
    } else if (arg == '--manifest') {
      manifestPath = nextValue();
    } else if (arg == '--target-bytes') {
      targetByteCount = int.parse(nextValue());
    } else if (arg == '--channels') {
      channelCount = int.parse(nextValue());
    } else if (arg == '--programme-minutes') {
      programmeDurationMinutes = int.parse(nextValue());
    } else if (arg == '--start-utc') {
      startUtc = DateTime.parse(nextValue()).toUtc();
    } else if (arg == '--help' || arg == '-h') {
      stdout.writeln(
        'Usage: dart run tool/generate_xmltv_fixture.dart '
        '[--fixture-id generated-xmltv-50mb-v1] '
        '[--output iptv-data/fixtures/xmltv/generated-50mb.xml] '
        '[--manifest iptv-data/fixtures/xmltv/generated-50mb.manifest.json] '
        '[--target-bytes 52428800] [--channels 512] '
        '[--programme-minutes 30] [--start-utc 2026-01-01T00:00:00Z]',
      );
      exit(0);
    } else {
      throw FormatException('Unknown argument: $arg');
    }
  }

  return AiroXmltvFixtureConfig(
    fixtureId: fixtureId,
    outputPath: outputPath,
    manifestPath: manifestPath,
    targetByteCount: targetByteCount,
    channelCount: channelCount,
    programmeDurationMinutes: programmeDurationMinutes,
    startUtc: startUtc,
  );
}
