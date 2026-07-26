import 'dart:io';

import 'package:platform_playlist_import/platform_playlist_import.dart';

const int kPlaylistIndexAcceptanceChannelCount = 100000;
const int kPlaylistIndexColdOpenCeilingMicros = 1000000;
const int kPlaylistIndexWarmOpenCeilingMicros = 300000;
const int kPlaylistIndexMemoryDeltaCeilingBytes = 96 * 1024 * 1024;

typedef PlaylistIndexOpen =
    Future<IndexedM3uPlaylistOpenResult?> Function({
      required String sourcePath,
      required String cacheDirectory,
      int firstPageLimit,
    });

class PlaylistIndexBenchmarkReport {
  const PlaylistIndexBenchmarkReport({
    required this.deviceProfile,
    required this.physicalDevice,
    required this.channelCount,
    required this.firstPageCount,
    required this.coldOpenMicros,
    required this.warmOpenMicros,
    required this.firstPageMicros,
    required this.rssDeltaBytes,
    required this.coldCacheStatus,
    required this.warmCacheStatus,
  });

  final String deviceProfile;
  final bool physicalDevice;
  final int channelCount;
  final int firstPageCount;
  final int coldOpenMicros;
  final int warmOpenMicros;
  final int firstPageMicros;
  final int rssDeltaBytes;
  final String coldCacheStatus;
  final String warmCacheStatus;

  bool get meetsLatencyThresholds =>
      coldOpenMicros < kPlaylistIndexColdOpenCeilingMicros &&
      warmOpenMicros < kPlaylistIndexWarmOpenCeilingMicros;

  bool get meetsMemoryThreshold =>
      rssDeltaBytes <= kPlaylistIndexMemoryDeltaCeilingBytes;

  /// Milestone acceptance requires a named physical Fire TV profile. A fast
  /// host run remains useful regression evidence but cannot qualify release.
  bool get qualifiesMilestone =>
      physicalDevice &&
      deviceProfile.trim().isNotEmpty &&
      deviceProfile.toLowerCase().contains('fire tv') &&
      channelCount == kPlaylistIndexAcceptanceChannelCount &&
      firstPageCount > 0 &&
      meetsLatencyThresholds &&
      meetsMemoryThreshold &&
      coldCacheStatus == 'coldBuilt' &&
      warmCacheStatus == 'warmOpened';

  Map<String, Object> toJson() => {
    'schemaVersion': '1.0.0',
    'deviceProfile': deviceProfile,
    'physicalDevice': physicalDevice,
    'channelCount': channelCount,
    'firstPageCount': firstPageCount,
    'coldOpenMicros': coldOpenMicros,
    'warmOpenMicros': warmOpenMicros,
    'firstPageMicros': firstPageMicros,
    'rssDeltaBytes': rssDeltaBytes,
    'coldCacheStatus': coldCacheStatus,
    'warmCacheStatus': warmCacheStatus,
    'coldOpenCeilingMicros': kPlaylistIndexColdOpenCeilingMicros,
    'warmOpenCeilingMicros': kPlaylistIndexWarmOpenCeilingMicros,
    'memoryDeltaCeilingBytes': kPlaylistIndexMemoryDeltaCeilingBytes,
    'qualifiesMilestone': qualifiesMilestone,
  };
}

class PlaylistIndexBenchmarkRunner {
  PlaylistIndexBenchmarkRunner({
    PlaylistIndexOpen? open,
    this.channelCount = kPlaylistIndexAcceptanceChannelCount,
    this.firstPageLimit = 50,
  }) : open = open ?? const IndexedM3uPlaylistService().open;

  final PlaylistIndexOpen open;
  final int channelCount;
  final int firstPageLimit;

  Future<PlaylistIndexBenchmarkReport> run({
    required String deviceProfile,
    required bool physicalDevice,
  }) async {
    if (channelCount <= 0) {
      throw ArgumentError.value(
        channelCount,
        'channelCount',
        'must be positive',
      );
    }
    final directory = await Directory.systemTemp.createTemp(
      'airo-playlist-index-benchmark-',
    );
    try {
      final source = File('${directory.path}/synthetic.m3u');
      final cache = Directory('${directory.path}/cache');
      await writeSyntheticPlaylist(source, channelCount);
      final rssBefore = ProcessInfo.currentRss;

      final cold = await open(
        sourcePath: source.path,
        cacheDirectory: cache.path,
        firstPageLimit: firstPageLimit,
      );
      if (cold == null) {
        throw StateError(
          'Native playlist index is unavailable; build and initialize '
          'core_native before running this benchmark.',
        );
      }
      final rssAfterCold = ProcessInfo.currentRss;
      final warm = await open(
        sourcePath: source.path,
        cacheDirectory: cache.path,
        firstPageLimit: firstPageLimit,
      );
      if (warm == null) {
        throw StateError(
          'Native playlist index became unavailable on warm open.',
        );
      }
      final rssAfterWarm = ProcessInfo.currentRss;

      return PlaylistIndexBenchmarkReport(
        deviceProfile: deviceProfile,
        physicalDevice: physicalDevice,
        channelCount: cold.descriptor.totalChannels,
        firstPageCount: cold.firstPage.channels.length,
        coldOpenMicros: cold.totalMicros,
        warmOpenMicros: warm.totalMicros,
        firstPageMicros: cold.firstPageMicros,
        rssDeltaBytes: [
          rssAfterCold - rssBefore,
          rssAfterWarm - rssBefore,
          0,
        ].reduce((current, next) => current > next ? current : next),
        coldCacheStatus: cold.cacheStatus.name,
        warmCacheStatus: warm.cacheStatus.name,
      );
    } finally {
      await directory.delete(recursive: true);
    }
  }
}

Future<void> writeSyntheticPlaylist(File file, int channelCount) async {
  final sink = file.openWrite();
  try {
    sink.writeln('#EXTM3U');
    for (var index = 0; index < channelCount; index++) {
      sink.writeln(
        '#EXTINF:-1 tvg-id="synthetic.$index" '
        'tvg-logo="https://cdn.example/$index.png" '
        'group-title="Synthetic" tvg-language="en",'
        'Synthetic Channel $index',
      );
      sink.writeln('https://stream.example/$index.m3u8');
    }
  } finally {
    await sink.close();
  }
}
