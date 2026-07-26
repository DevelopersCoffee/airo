import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:platform_benchmarks/platform_benchmarks.dart';

void main() {
  final enabled =
      Platform.environment['AIRO_RUN_PLAYLIST_INDEX_BENCHMARK'] == 'true';

  test(
    'native 100k playlist cold and warm acceptance',
    () async {
      final deviceProfile =
          Platform.environment['AIRO_PLAYLIST_BENCHMARK_DEVICE']?.trim() ??
          'host';
      final physicalDevice =
          Platform.environment['AIRO_PLAYLIST_BENCHMARK_PHYSICAL'] == 'true';
      final report = await PlaylistIndexBenchmarkRunner().run(
        deviceProfile: deviceProfile,
        physicalDevice: physicalDevice,
      );

      // JSON output is deliberately aggregate-only and safe to attach to an
      // issue. It contains no temporary paths, channels, or stream URLs.
      // ignore: avoid_print
      print(const JsonEncoder.withIndent('  ').convert(report.toJson()));

      expect(report.channelCount, kPlaylistIndexAcceptanceChannelCount);
      expect(report.firstPageCount, greaterThan(0));
      expect(report.coldCacheStatus, 'coldBuilt');
      expect(report.warmCacheStatus, 'warmOpened');
      if (physicalDevice) {
        expect(
          report.qualifiesMilestone,
          isTrue,
          reason: 'Physical qualification must meet every milestone ceiling.',
        );
      }
    },
    skip: enabled
        ? false
        : 'Set AIRO_RUN_PLAYLIST_INDEX_BENCHMARK=true after building core_native.',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
