import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:platform_benchmarks/platform_benchmarks.dart';

void main() {
  test('EPG warmup benchmark records accepted heartbeat evidence', () async {
    final directory = await Directory.systemTemp.createTemp(
      'airo-tv-epg-warmup-test-',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final fixturePath = '${directory.path}/fixture.xml';
    final manifestPath = '${directory.path}/fixture.manifest.json';
    await const AiroXmltvFixtureGenerator().writeFixture(
      AiroXmltvFixtureConfig(
        fixtureId: 'warmup-test',
        outputPath: fixturePath,
        manifestPath: manifestPath,
        targetByteCount: 180000,
        channelCount: 16,
        startUtc: DateTime.utc(2026),
      ),
    );

    final artifact = await const AiroTvEpgWarmupBenchmarkRunner().run(
      AiroTvEpgWarmupBenchmarkConfig(
        fixturePath: fixturePath,
        channelCount: 16,
        visibleChannelCount: 8,
        now: DateTime.utc(2026, 1, 1, 0, 15),
        maxHeartbeatDelay: const Duration(seconds: 5),
      ),
    );

    expect(artifact.fixtureBytes, greaterThanOrEqualTo(180000));
    expect(artifact.snapshotEntryCount, 16);
    expect(artifact.visibleEntryCount, 8);
    expect(artifact.warmupWallTime, lessThan(const Duration(seconds: 1)));
    expect(artifact.mainHeartbeatTicks, greaterThan(0));
    expect(artifact.nowNextAccepted, isTrue);
    expect(artifact.rssAccepted, isTrue);
    expect(
      artifact.peakRssBytes,
      greaterThanOrEqualTo(artifact.baselineRssBytes),
    );
    expect(artifact.toJson()['evaluation'], containsPair('accepted', true));
    expect(artifact.toPrettyJson(), isNot(contains(fixturePath)));
  });
}
