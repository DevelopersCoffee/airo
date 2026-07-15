import 'package:benchmark_harness/benchmark_harness.dart';

import 'results.dart';

/// Generates a synthetic M3U playlist with [channelCount] entries.
String generateM3UFixture(int channelCount) {
  final buf = StringBuffer('#EXTM3U\n');
  for (var i = 0; i < channelCount; i++) {
    buf.writeln(
      '#EXTINF:-1 tvg-id="ch$i" tvg-name="Channel $i" '
      'tvg-logo="https://example.com/logo$i.png" '
      'group-title="Group ${i % 5}",Channel $i',
    );
    buf.writeln('https://stream.example.com/live/channel$i.m3u8');
  }
  return buf.toString();
}

/// Minimal parsed channel representation used by the benchmark.
///
/// Mirrors the fields extracted by the production [M3UParserService] in
/// `platform_playlist_import` without pulling in the Flutter SDK.
class _ParsedChannel {
  final String name;
  final String url;
  final String? logo;
  final String? group;
  final String? tvgId;
  final String? tvgName;

  const _ParsedChannel({
    required this.name,
    required this.url,
    this.logo,
    this.group,
    this.tvgId,
    this.tvgName,
  });
}

/// Parse an M3U string into a list of channels.
///
/// This mirrors the production parser in
/// `packages/platform_playlist_import/lib/src/m3u_parser_service.dart`.
List<_ParsedChannel> parseM3U(String content) {
  final lines = content.split('\n');
  final channels = <_ParsedChannel>[];

  String? currentName;
  String? currentLogo;
  String? currentGroup;
  String? currentTvgId;
  String? currentTvgName;

  final attrPattern = RegExp(r'(\w+[-\w]*)="([^"]*)"');

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();

    if (line.startsWith('#EXTINF:')) {
      final commaIndex = line.lastIndexOf(',');
      if (commaIndex != -1) {
        currentName = line.substring(commaIndex + 1).trim();
      }
      for (final match in attrPattern.allMatches(line)) {
        final key = match.group(1)!;
        final value = match.group(2)!;
        switch (key) {
          case 'tvg-logo':
            currentLogo = value;
          case 'group-title':
            currentGroup = value;
          case 'tvg-id':
            currentTvgId = value;
          case 'tvg-name':
            currentTvgName = value;
        }
      }
    } else if (line.isNotEmpty && !line.startsWith('#') && currentName != null) {
      channels.add(_ParsedChannel(
        name: currentName,
        url: line,
        logo: currentLogo,
        group: currentGroup,
        tvgId: currentTvgId,
        tvgName: currentTvgName,
      ));
      currentName = null;
      currentLogo = null;
      currentGroup = null;
      currentTvgId = null;
      currentTvgName = null;
    }
  }
  return channels;
}

/// Benchmark that measures M3U parsing throughput.
class M3UParseBenchmark extends BenchmarkBase {
  static const int _channelCount = 50;
  late final String _fixture;

  M3UParseBenchmark() : super('M3UParse');

  @override
  void setup() {
    _fixture = generateM3UFixture(_channelCount);
  }

  @override
  void run() {
    final channels = parseM3U(_fixture);
    // Prevent the compiler from optimizing the call away.
    if (channels.length != _channelCount) {
      throw StateError('Expected $_channelCount channels');
    }
  }

  /// Run the benchmark and return structured results.
  List<BenchmarkResult> measureResults() {
    // Warm up + measure via the harness (reports us/iteration).
    final usPerIteration = BenchmarkBase.measureFor(run, 2000);

    // Each iteration parses _channelCount channels.
    final channelsPerSec =
        _channelCount / (usPerIteration / Duration.microsecondsPerSecond);

    final bytesPerSec =
        _fixture.length / (usPerIteration / Duration.microsecondsPerSecond);

    final now = DateTime.now().toUtc();
    return [
      BenchmarkResult(
        name: 'm3u_parse_${_channelCount}ch',
        metric: 'channels_per_sec',
        value: channelsPerSec,
        unit: 'channels/s',
        deviceClass: 'desktop',
        timestamp: now,
      ),
      BenchmarkResult(
        name: 'm3u_parse_${_channelCount}ch',
        metric: 'bytes_per_sec',
        value: bytesPerSec,
        unit: 'bytes/s',
        deviceClass: 'desktop',
        timestamp: now,
      ),
    ];
  }
}
