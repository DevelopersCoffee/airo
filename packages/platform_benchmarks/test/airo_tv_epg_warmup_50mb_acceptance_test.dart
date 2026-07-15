import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:platform_benchmarks/platform_benchmarks.dart';

void main() {
  final fixturePath = Platform.environment['AIRO_TV_EPG_FIXTURE'];
  final outputPath =
      Platform.environment['AIRO_TV_EPG_OUTPUT'] ??
      '/tmp/airo-tv-epg-warmup-50mb.json';

  test(
    '50 MB TV EPG warmup keeps main isolate heartbeat responsive',
    () async {
      final artifact = await const AiroTvEpgWarmupBenchmarkRunner().run(
        AiroTvEpgWarmupBenchmarkConfig(
          fixturePath: fixturePath!,
          outputPath: outputPath,
          channelCount: 512,
          visibleChannelCount: 64,
          now: DateTime.utc(2026, 1, 1, 0, 15),
        ),
      );
      final output = File(outputPath);
      await output.parent.create(recursive: true);
      await output.writeAsString('${artifact.toPrettyJson()}\n');

      expect(artifact.fixtureBytes, greaterThanOrEqualTo(50 * 1024 * 1024));
      expect(artifact.visibleEntryCount, artifact.visibleChannelCount);
      expect(artifact.nowNextAccepted, isTrue);
      expect(artifact.mainHeartbeatAccepted, isTrue);
      expect(artifact.accepted, isTrue);
    },
    skip: fixturePath == null || fixturePath.trim().isEmpty
        ? 'Set AIRO_TV_EPG_FIXTURE to a 50 MB XMLTV fixture path.'
        : false,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
