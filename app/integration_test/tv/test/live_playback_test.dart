import 'dart:io';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:core_data/core_data.dart'; // For DeviceClass
import 'package:airo_tv/app.dart'; // Assuming main entry point
import 'helpers/tv_test_harness.dart';
import 'helpers/tv_screen_robot.dart';
import 'helpers/performance_monitor.dart';
import 'helpers/network_simulator.dart';
import 'helpers/playlist_fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Live playback qualification on Sony BRAVIA 2', (WidgetTester tester) async {
    // Initialize harness with low‑end device profile.
    final harness = TvTestHarness(tester, deviceClass: DeviceClass.tvLow);
    await harness.setUp();

    // Apply network conditions.
    final network = NetworkSimulator(tester);
    await network.applyProfile(const NetworkProfile(
      downloadMbps: 5,
      uploadMbps: 2,
      latencyMs: 150,
      packetLossPercent: 2,
    ));

    // Load playlist fixture (including Vevo Pop).
    await harness.importPlaylist(PlaylistFixtures.vevoPopPlaylist);

    // Navigate to Live screen.
    final robot = TvScreenRobot(tester);
    await robot.navigateToLive();

    // Select Vevo Pop channel.
    await robot.selectChannel('Vevo Pop');

    // Start performance monitoring.
    final monitor = PerformanceMonitor();
    monitor.startFrameTracking();

    // Verify playback started.
    await robot.verifyPlayback();

    // Soak test for 30 minutes while sampling performance every 30 seconds.
    final reportFile = File('test_report.csv');
    // Write CSV header.
    reportFile.writeAsStringSync('timestamp,fps,avgFrameMs,maxFrameMs,rssMb,imageCacheMb,jankCount\n');

    final soakDuration = Duration(minutes: 30);
    final start = DateTime.now();
    while (DateTime.now().difference(start) < soakDuration) {
      // Sample performance.
      final fps = monitor.summary.fps;
      final avgMs = monitor.summary.avgFrameTimeUs / 1000.0;
      final maxMs = monitor.summary.maxFrameTimeUs / 1000.0;
      final rss = monitor.captureRss()?.rssMb ?? 0;
      final cacheMb = (PaintingBinding.instance.imageCache.currentSizeBytes / (1024 * 1024)).toStringAsFixed(1);
      final jank = monitor.summary.jankFrameCount;

      final line =
          '\${DateTime.now().toIso8601String()},\${fps.toStringAsFixed(1)},\${avgMs.toStringAsFixed(1)},\${maxMs.toStringAsFixed(1)},\${rss},\${cacheMb},\${jank}\n';
      reportFile.writeAsStringSync(line, mode: FileMode.append);

      // Capture screenshot every 5 minutes.
      final elapsed = DateTime.now().difference(start);
      if (elapsed.inMinutes % 5 == 0 && elapsed.inSeconds % 60 == 0) {
        final img = await robot.captureScreenshot('screenshot_${elapsed.inMinutes}m');
        File('screenshots/${elapsed.inMinutes}m.png').writeAsBytesSync(img);
      }

      // Wait a short interval before next sample.
      await Future.delayed(Duration(seconds: 30));
    }

    // Stop monitoring and perform final assertions.
    monitor.stopFrameTracking();
    monitor.expectSteady60Fps();
    monitor.expectNoJankFrames();
    monitor.expectRssBelowTarget();
    monitor.expectImageCacheWithinBudget();

    // Cleanup.
    await network.restore();
    await harness.tearDown();
  },
      tags: <String>{'tv_integration'});
}
