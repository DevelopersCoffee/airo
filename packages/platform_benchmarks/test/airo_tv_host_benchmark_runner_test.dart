import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:platform_benchmarks/platform_benchmarks.dart';

void main() {
  test('synthetic fixture generates deterministic M3U rows', () {
    const fixture = AiroTvSyntheticPlaylistFixture(channelCount: 3);

    final m3u = fixture.toM3u();

    expect(m3u, startsWith('#EXTM3U'));
    expect('#EXTINF'.allMatches(m3u), hasLength(3));
    expect(m3u, contains('Airo News Channel 0'));
    expect(m3u, contains('Airo Sports Channel 1'));
    expect(m3u, contains('Airo Music Channel 2'));
  });

  test('runner writes accepted host benchmark artifact JSON', () async {
    final output = File(
      '${Directory.systemTemp.path}/airo-tv-host-benchmark-test.json',
    );
    if (output.existsSync()) {
      output.deleteSync();
    }

    final artifact = await const AiroTvHostBenchmarkRunner().runAndWrite(
      AiroTvHostBenchmarkConfig(
        channelCount: 20,
        iterations: 5,
        outputPath: output.path,
      ),
    );

    expect(artifact.accepted, isTrue);
    expect(output.existsSync(), isTrue);

    final json = jsonDecode(output.readAsStringSync()) as Map<String, dynamic>;
    expect(json['schemaVersion'], kAiroTvHostBenchmarkSchemaVersion);
    expect(json['deviceClass'], 'host_local');
    expect(json['iterations'], 5);
    expect(json['channelCount'], 20);
    expect(json['fixture'], containsPair('sourceKind', 'synthetic_m3u'));
    expect(json['evaluation'], containsPair('accepted', true));

    final run = json['run'] as Map<String, dynamic>;
    final samples = run['samples'] as List<dynamic>;
    expect(samples, hasLength(2));
    expect(
      samples.map((sample) => (sample as Map<String, dynamic>)['stepId']),
      containsAll(['parse-m3u', 'search-index']),
    );
  });

  test(
    'runner accepts file-backed M3U fixture without exposing raw URLs',
    () async {
      final fixture = File('${Directory.systemTemp.path}/airo-tv-fixture.m3u')
        ..writeAsStringSync('''
#EXTM3U
#EXTINF:-1 tvg-id="news" tvg-logo="https://logo.example/news.png" group-title="News",Fixture News
https://stream.example/news.m3u8
#EXTINF:-1 tvg-id="sports" group-title="Sports",Fixture Sports
https://stream.example/sports.m3u8
''');

      final artifact = await const AiroTvHostBenchmarkRunner().run(
        AiroTvHostBenchmarkConfig(
          fixturePath: fixture.path,
          fixtureId: 'public-fixture-test',
        ),
      );

      final json = artifact.toJson();
      final encoded = jsonEncode(json);

      expect(artifact.accepted, isTrue);
      expect(artifact.channelCount, 2);
      expect(json['fixture'], containsPair('fixtureId', 'public-fixture-test'));
      expect(json['fixture'], containsPair('sourceKind', 'file_m3u'));
      expect(encoded, isNot(contains('stream.example')));
      expect(encoded, isNot(contains('logo.example')));
      expect(encoded, isNot(contains(fixture.path)));
    },
  );

  test('renders privacy-safe markdown benchmark report', () async {
    final artifact = await const AiroTvHostBenchmarkRunner().run(
      const AiroTvHostBenchmarkConfig(channelCount: 20, iterations: 5),
    );

    final report = const AiroTvBenchmarkReportRenderer().render(
      artifact.toJson(),
    );

    expect(report, contains('# Airo TV Host Benchmark Report'));
    expect(report, contains('| Status | `accepted` |'));
    expect(report, contains('| Fixture source | `synthetic_m3u` |'));
    expect(report, contains('| `parse-m3u` | `import_batch` |'));
    expect(report, contains('| `search-index` | `search_text` |'));
    expect(report, isNot(contains('https://')));
    expect(report, isNot(contains('/Users/')));
    expect(report, isNot(contains('token')));
  });

  test('config enforces minimum benchmark iterations', () {
    const config = AiroTvHostBenchmarkConfig(
      channelCount: 0,
      iterations: 1,
      deviceClass: '',
    );

    final normalized = config.normalized();

    expect(normalized.channelCount, 1);
    expect(normalized.iterations, 5);
    expect(normalized.deviceClass, 'host_local');
  });
}
