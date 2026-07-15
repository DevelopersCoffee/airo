import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:platform_benchmarks/platform_benchmarks.dart';

void main() {
  test('writes accepted logo scroll evidence artifacts', () async {
    final directory = await Directory.systemTemp.createTemp(
      'airo-tv-logo-scroll-report-test-',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final evaluation = await const AiroTvLogoScrollReportWriter().write(
      AiroTvLogoScrollReportConfig(
        reportId: 'shield-tv-logo-scroll-10k',
        scenarioId: 'large-logo-grid-scroll',
        playlistChannelCount: 12000,
        visibleCellCount: 24,
        durationSeconds: 180,
        baselineRssMb: 180,
        peakRssMb: 242,
        steadyRssMb: 230,
        rssPlateauDeltaMb: 8,
        imageCachePeakMb: 14,
        frameJankCount: 0,
        decodeJankFrameCount: 0,
        measuredAt: DateTime.utc(2026, 7, 15, 15),
        outputJsonPath: '${directory.path}/report.json',
        outputMarkdownPath: '${directory.path}/report.md',
      ),
    );

    expect(evaluation.accepted, isTrue);
    final json =
        jsonDecode(await File('${directory.path}/report.json').readAsString())
            as Map<String, Object?>;
    final markdown = await File('${directory.path}/report.md').readAsString();

    expect(json, containsPair('schemaVersion', '1.0.0'));
    expect(json.toString(), isNot(contains('http://')));
    expect(json.toString(), isNot(contains('192.168.')));
    expect(markdown, contains('# Airo TV Logo Scroll Benchmark'));
    expect(markdown, contains('accepted'));
  });

  test('marks RSS and image cache budget violations', () {
    final evaluation = const AiroTvLogoScrollReportWriter().evaluate(
      AiroTvLogoScrollReportConfig(
        reportId: 'rss-heavy-logo-scroll',
        scenarioId: 'large-logo-grid-scroll',
        playlistChannelCount: 12000,
        visibleCellCount: 24,
        durationSeconds: 180,
        baselineRssMb: 180,
        peakRssMb: 360,
        steadyRssMb: 280,
        rssPlateauDeltaMb: 28,
        imageCachePeakMb: 24,
        frameJankCount: 0,
        decodeJankFrameCount: 0,
        measuredAt: DateTime.utc(2026, 7, 15, 15),
      ),
    );

    expect(evaluation.accepted, isFalse);
    expect(
      evaluation.violations,
      contains(AiroTvLogoScrollViolationCode.peakRssExceeded),
    );
    expect(
      evaluation.violations,
      contains(AiroTvLogoScrollViolationCode.steadyRssExceeded),
    );
    expect(
      evaluation.violations,
      contains(AiroTvLogoScrollViolationCode.rssDidNotPlateau),
    );
    expect(
      evaluation.violations,
      contains(AiroTvLogoScrollViolationCode.imageCacheExceeded),
    );
  });

  test('marks frame and decode jank violations', () {
    final evaluation = const AiroTvLogoScrollReportWriter().evaluate(
      AiroTvLogoScrollReportConfig(
        reportId: 'janky-logo-scroll',
        scenarioId: 'large-logo-grid-scroll',
        playlistChannelCount: 12000,
        visibleCellCount: 24,
        durationSeconds: 180,
        baselineRssMb: 180,
        peakRssMb: 242,
        steadyRssMb: 230,
        rssPlateauDeltaMb: 8,
        imageCachePeakMb: 14,
        frameJankCount: 2,
        decodeJankFrameCount: 1,
        measuredAt: DateTime.utc(2026, 7, 15, 15),
      ),
    );

    expect(evaluation.accepted, isFalse);
    expect(
      evaluation.violations,
      contains(AiroTvLogoScrollViolationCode.frameJankDetected),
    );
    expect(
      evaluation.violations,
      contains(AiroTvLogoScrollViolationCode.decodeJankDetected),
    );
  });

  test('requires large playlist evidence and public labels', () {
    expect(
      const AiroTvLogoScrollReportWriter()
          .evaluate(
            AiroTvLogoScrollReportConfig(
              reportId: 'small-playlist-logo-scroll',
              scenarioId: 'large-logo-grid-scroll',
              playlistChannelCount: 9000,
              visibleCellCount: 24,
              durationSeconds: 180,
              baselineRssMb: 180,
              peakRssMb: 242,
              steadyRssMb: 230,
              rssPlateauDeltaMb: 8,
              imageCachePeakMb: 14,
              frameJankCount: 0,
              decodeJankFrameCount: 0,
            ),
          )
          .violations,
      contains(AiroTvLogoScrollViolationCode.playlistTooSmall),
    );
    expect(
      () => const AiroTvLogoScrollReportConfig(
        reportId: 'http://example.test/logo-scroll',
        scenarioId: 'large-logo-grid-scroll',
        playlistChannelCount: 12000,
        visibleCellCount: 24,
        durationSeconds: 180,
        baselineRssMb: 180,
        peakRssMb: 242,
        steadyRssMb: 230,
        rssPlateauDeltaMb: 8,
        imageCachePeakMb: 14,
        frameJankCount: 0,
        decodeJankFrameCount: 0,
      ).normalized(),
      throwsArgumentError,
    );
  });
}
