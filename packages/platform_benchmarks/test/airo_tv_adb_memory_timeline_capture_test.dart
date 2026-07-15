import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:platform_benchmarks/platform_benchmarks.dart';
import 'package:platform_device_profile/platform_device_profile.dart';

void main() {
  group('AiroTvMeminfoParser', () {
    test('parses TOTAL RSS lines from Android meminfo', () {
      const output = '''
Applications Memory Usage (in Kilobytes):
Uptime: 123 Realtime: 456

App Summary
                       Pss(KB)                        Rss(KB)
                        ------                         ------
           Java Heap:     1200                          2048
         Native Heap:     4096                          8192
                Code:     1024                          1024
               Stack:      100                           200
            Graphics:     2048                          4096
       Private Other:      512                          1024
              System:     2048                          2048

               TOTAL:    11028                         18632
           TOTAL RSS:  214,016K
''';

      expect(AiroTvMeminfoParser.parseTotalRssMb(output), 209);
    });

    test('falls back to app summary TOTAL RSS column', () {
      const output = '''
App Summary
                       Pss(KB)                        Rss(KB)
                        ------                         ------
               TOTAL:    98,304                       131,072
''';

      expect(AiroTvMeminfoParser.parseTotalRssMb(output), 128);
    });

    test('rejects output without total RSS', () {
      expect(
        () => AiroTvMeminfoParser.parseTotalRssMb('No process found.'),
        throwsFormatException,
      );
    });
  });

  test('captures adb samples into runtime memory timeline reports', () async {
    var calls = 0;
    final base = DateTime.utc(2026, 7, 15, 10);
    final capture = AiroTvAdbMemoryTimelineCapture(
      clock: () => base.add(Duration(seconds: calls++ * 30)),
      delay: (_) async {},
      processRunner: (_, args) async {
        expect(args, ['shell', 'dumpsys', 'meminfo', 'io.airo.tv']);
        final rssKb = calls == 0 ? 120 * 1024 : 124 * 1024;
        return ProcessResult(42, 0, 'TOTAL RSS: ${rssKb}K\n', '');
      },
    );

    final report = await capture.capture(
      const AiroTvAdbMemoryTimelineConfig(
        packageName: 'io.airo.tv',
        sampleCount: 2,
        sampleInterval: Duration(seconds: 30),
        dartHeapMb: 40,
        imageCacheMb: 8,
      ),
    );

    expect(report.points.map((point) => point.rssMb), [120, 124]);
    expect(report.duration, const Duration(seconds: 30));
    expect(report.evaluate().accepted, isTrue);
    expect(report.toPublicMap(), containsPair('sampleCount', 2));
  });

  test('writes sanitized JSON and markdown evidence files', () async {
    final directory = await Directory.systemTemp.createTemp(
      'airo-tv-adb-memory-capture-test-',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final capture = AiroTvAdbMemoryTimelineCapture(
      clock: () => DateTime.utc(2026, 7, 15, 10),
      processRunner: (_, _) async {
        return ProcessResult(42, 0, 'TOTAL RSS: 200000K\n', '');
      },
    );

    final report = await capture.write(
      AiroTvAdbMemoryTimelineConfig(
        packageName: 'io.airo.tv',
        sampleCount: 1,
        budget: AiroRuntimeMemoryBudgetPolicy.androidTvConstrainedBudget,
        outputJsonPath: '${directory.path}/memory.json',
        outputMarkdownPath: '${directory.path}/memory.md',
      ),
    );

    expect(report.peakRssMb, 196);
    expect(
      await File('${directory.path}/memory.json').readAsString(),
      contains('"peakRssMb": 196'),
    );
    expect(
      await File('${directory.path}/memory.md').readAsString(),
      contains('# Airo Runtime Memory Timeline'),
    );
  });
}
