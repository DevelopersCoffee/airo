import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:platform_benchmarks/platform_benchmarks.dart';
import 'package:platform_device_profile/platform_device_profile.dart';

void main() {
  test('runs playback key events while sampling adb memory', () async {
    final commands = <List<String>>[];
    var clockTick = 0;
    var meminfoCalls = 0;
    final runner = AiroTvPlaybackSoakRunner(
      delay: (_) async {},
      clock: () => DateTime.utc(
        2026,
        7,
        15,
        12,
      ).add(Duration(seconds: 30 * clockTick++)),
      processRunner: (_, args) async {
        commands.add(args);
        if (args.contains('meminfo')) {
          meminfoCalls += 1;
          return ProcessResult(
            42,
            0,
            'TOTAL RSS: ${120 * 1024 + meminfoCalls * 1024}K\n',
            '',
          );
        }
        return ProcessResult(42, 0, '', '');
      },
    );

    final report = await runner.run(
      const AiroTvPlaybackSoakConfig(
        packageName: 'io.airo.app.tv',
        duration: Duration(seconds: 60),
        sampleInterval: Duration(seconds: 30),
        dartHeapStartMb: 40,
        dartHeapEndMb: 40,
        keyEvents: ['DPAD_CENTER', 'DPAD_DOWN'],
      ),
    );

    expect(report.points.map((point) => point.pointId), [
      'soak-sample-1',
      'soak-sample-2',
      'soak-sample-3',
    ]);
    expect(report.duration, const Duration(seconds: 60));
    expect(report.evaluate().accepted, isTrue);
    expect(
      commands.first,
      containsAllInOrder([
        'shell',
        'monkey',
        '-p',
        'io.airo.app.tv',
        '-c',
        'android.intent.category.LAUNCHER',
        '1',
      ]),
    );
    expect(commands.where((command) => command.contains('keyevent')).toList(), [
      ['shell', 'input', 'keyevent', 'DPAD_CENTER'],
      ['shell', 'input', 'keyevent', 'DPAD_DOWN'],
    ]);
  });

  test(
    'reports playback drift violations from start and end heap snapshots',
    () async {
      var clockTick = 0;
      final runner = AiroTvPlaybackSoakRunner(
        delay: (_) async {},
        clock: () => DateTime.utc(
          2026,
          7,
          15,
          12,
        ).add(Duration(minutes: 15 * clockTick++)),
        processRunner: (_, args) async {
          if (args.contains('meminfo')) {
            return ProcessResult(42, 0, 'TOTAL RSS: ${120 * 1024}K\n', '');
          }
          return ProcessResult(42, 0, '', '');
        },
      );

      final report = await runner.run(
        const AiroTvPlaybackSoakConfig(
          packageName: 'io.airo.app.tv',
          duration: Duration(minutes: 30),
          sampleInterval: Duration(minutes: 15),
          dartHeapStartMb: 40,
          dartHeapEndMb: 42,
        ),
      );

      expect(report.playbackSoakDriftMbPerHour, 4);
      expect(
        report.evaluate().violations,
        contains(
          AiroRuntimeMemoryBudgetViolationCode.playbackSoakDriftExceeded,
        ),
      );
    },
  );

  test('fails fast when adb key event fails', () async {
    final runner = AiroTvPlaybackSoakRunner(
      delay: (_) async {},
      processRunner: (_, args) async {
        if (args.contains('keyevent')) {
          return ProcessResult(42, 1, '', 'device offline');
        }
        return ProcessResult(42, 0, 'TOTAL RSS: ${120 * 1024}K\n', '');
      },
    );

    expect(
      () => runner.run(
        const AiroTvPlaybackSoakConfig(
          packageName: 'io.airo.app.tv',
          duration: Duration(seconds: 30),
          sampleInterval: Duration(seconds: 30),
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('writes sanitized JSON and markdown evidence', () async {
    final directory = await Directory.systemTemp.createTemp(
      'airo-tv-playback-soak-test-',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final runner = AiroTvPlaybackSoakRunner(
      delay: (_) async {},
      clock: () => DateTime.utc(2026, 7, 15, 12),
      processRunner: (_, args) async {
        if (args.contains('meminfo')) {
          return ProcessResult(42, 0, 'TOTAL RSS: ${140 * 1024}K\n', '');
        }
        return ProcessResult(42, 0, '', '');
      },
    );

    await runner.write(
      AiroTvPlaybackSoakConfig(
        packageName: 'io.airo.app.tv',
        duration: const Duration(seconds: 1),
        sampleInterval: const Duration(seconds: 1),
        dartHeapStartMb: 41,
        dartHeapEndMb: 41,
        outputJsonPath: '${directory.path}/soak.json',
        outputMarkdownPath: '${directory.path}/soak.md',
      ),
    );

    final json = await File('${directory.path}/soak.json').readAsString();
    final markdown = await File('${directory.path}/soak.md').readAsString();

    expect(json, contains('"reportId": "airo-tv-playback-soak"'));
    expect(json, isNot(contains('io.airo.app.tv')));
    expect(markdown, contains('# Airo Runtime Memory Timeline'));
  });
}
