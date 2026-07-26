import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:platform_benchmarks/platform_benchmarks.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_playlist_import/platform_playlist_import.dart';

void main() {
  test(
    '100k named Fire TV report qualifies only inside all ceilings',
    () async {
      var calls = 0;
      final runner = PlaylistIndexBenchmarkRunner(
        channelCount: 1,
        open:
            ({
              required sourcePath,
              required cacheDirectory,
              firstPageLimit = 50,
            }) async {
              calls++;
              return benchmarkOpenResult(
                totalChannels: kPlaylistIndexAcceptanceChannelCount,
                cacheStatus: calls == 1
                    ? IndexedM3uPlaylistCacheStatus.coldBuilt
                    : IndexedM3uPlaylistCacheStatus.warmOpened,
                totalMicros: calls == 1 ? 900000 : 200000,
              );
            },
        search:
            ({
              required descriptor,
              query,
              filters = const [],
              offset = 0,
              limit = 50,
            }) async => benchmarkOpenResult(
              totalChannels: 1,
              cacheStatus: IndexedM3uPlaylistCacheStatus.warmOpened,
              totalMicros: 1,
            ).firstPage,
      );

      final report = await runner.run(
        deviceProfile: 'Fire TV Stick 4K Max (2nd gen)',
        physicalDevice: true,
      );

      expect(calls, 2);
      expect(report.meetsLatencyThresholds, isTrue);
      expect(report.meetsMemoryThreshold, isTrue);
      expect(report.meetsSearchThreshold, isTrue);
      expect(report.qualifiesMilestone, isTrue);
      expect(report.toJson(), isNot(contains('sourcePath')));
      expect(report.toJson(), isNot(contains('cachePath')));
    },
  );

  test('host evidence never claims physical-device acceptance', () {
    const report = PlaylistIndexBenchmarkReport(
      deviceProfile: 'macOS host',
      physicalDevice: false,
      channelCount: kPlaylistIndexAcceptanceChannelCount,
      firstPageCount: 50,
      coldOpenMicros: 100,
      warmOpenMicros: 100,
      firstPageMicros: 10,
      searchP50Micros: 100,
      searchP95Micros: 200,
      rssDeltaBytes: 0,
      coldCacheStatus: 'coldBuilt',
      warmCacheStatus: 'warmOpened',
    );

    expect(report.meetsLatencyThresholds, isTrue);
    expect(report.qualifiesMilestone, isFalse);
  });

  test('thresholds are strict and memory bounded', () {
    const report = PlaylistIndexBenchmarkReport(
      deviceProfile: 'Fire TV Stick',
      physicalDevice: true,
      channelCount: kPlaylistIndexAcceptanceChannelCount,
      firstPageCount: 50,
      coldOpenMicros: kPlaylistIndexColdOpenCeilingMicros,
      warmOpenMicros: kPlaylistIndexWarmOpenCeilingMicros,
      firstPageMicros: 10,
      searchP50Micros: 100,
      searchP95Micros: kPlaylistIndexSearchP95CeilingMicros,
      rssDeltaBytes: kPlaylistIndexMemoryDeltaCeilingBytes + 1,
      coldCacheStatus: 'coldBuilt',
      warmCacheStatus: 'warmOpened',
    );

    expect(report.meetsLatencyThresholds, isFalse);
    expect(report.meetsMemoryThreshold, isFalse);
    expect(report.meetsSearchThreshold, isFalse);
    expect(report.qualifiesMilestone, isFalse);
  });

  test('synthetic fixture writer streams deterministic entries', () async {
    final directory = await Directory.systemTemp.createTemp(
      'playlist-benchmark-fixture-test-',
    );
    try {
      final file = File('${directory.path}/fixture.m3u');
      await writeSyntheticPlaylist(file, 3);
      final content = await file.readAsString();

      expect(content, startsWith('#EXTM3U\n'));
      expect('#EXTINF'.allMatches(content), hasLength(3));
      expect(content, contains('Synthetic Channel 2'));
      expect(content, contains('https://stream.example/2.m3u8'));
    } finally {
      await directory.delete(recursive: true);
    }
  });
}

IndexedM3uPlaylistOpenResult benchmarkOpenResult({
  required int totalChannels,
  required IndexedM3uPlaylistCacheStatus cacheStatus,
  required int totalMicros,
}) {
  return IndexedM3uPlaylistOpenResult(
    descriptor: IndexedM3uPlaylistDescriptor(
      indexPath: '/redacted/index',
      cachePath: '/redacted/cache',
      totalChannels: totalChannels,
      sourceSizeBytes: 1,
      sourceModifiedNanos: 1,
    ),
    firstPage: IndexedM3uChannelPage(
      channels: [
        IPTVChannel.fromM3U(
          name: 'Synthetic',
          url: 'https://example.com/stream',
        ),
      ],
      offset: 0,
      total: totalChannels,
      hasMore: true,
    ),
    cacheStatus: cacheStatus,
    totalMicros: totalMicros,
    firstPageMicros: 10,
  );
}
