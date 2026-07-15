import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:platform_benchmarks/platform_benchmarks.dart';

void main() {
  test('writes accepted Cast channel-switch artifacts', () async {
    final directory = await Directory.systemTemp.createTemp(
      'cast-channel-switch-report-test-',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final evaluation = await const CastChannelSwitchReportWriter().write(
      CastChannelSwitchReportConfig(
        reportId: 'pixel9-bravia-switch-pass',
        senderProfile: 'pixel9-physical',
        receiverProfile: 'bravia-chromecast',
        playlistProfile: 'iptv-org-public',
        attemptedSwitchCount: 2,
        successfulSwitchCount: 2,
        receiverReconnectCount: 0,
        stalePreviousStatusCount: 0,
        previousChannelErrorCount: 0,
        latestErrorMatchedSelectedChannel: true,
        localPlaybackRestartCount: 0,
        recoveryActionCount: 0,
        measuredAt: DateTime.utc(2026, 7, 15, 17),
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
    expect(markdown, contains('# Cast Channel Switch Evidence'));
    expect(markdown, contains('accepted'));
  });

  test('marks failed switches and reconnects', () {
    final evaluation = const CastChannelSwitchReportWriter().evaluate(
      CastChannelSwitchReportConfig(
        reportId: 'failed-switch',
        senderProfile: 'pixel9-physical',
        receiverProfile: 'bravia-chromecast',
        playlistProfile: 'iptv-org-public',
        attemptedSwitchCount: 2,
        successfulSwitchCount: 1,
        receiverReconnectCount: 1,
        stalePreviousStatusCount: 0,
        previousChannelErrorCount: 0,
        latestErrorMatchedSelectedChannel: true,
        localPlaybackRestartCount: 0,
        recoveryActionCount: 0,
        measuredAt: DateTime.utc(2026, 7, 15, 17),
      ),
    );

    expect(evaluation.accepted, isFalse);
    expect(
      evaluation.violations,
      contains(CastChannelSwitchViolationCode.switchFailure),
    );
    expect(
      evaluation.violations,
      contains(CastChannelSwitchViolationCode.receiverReconnected),
    );
  });

  test('marks stale status, wrong error attribution, and recovery', () {
    final evaluation = const CastChannelSwitchReportWriter().evaluate(
      CastChannelSwitchReportConfig(
        reportId: 'stale-status-switch',
        senderProfile: 'pixel9-physical',
        receiverProfile: 'bravia-chromecast',
        playlistProfile: 'iptv-org-public',
        attemptedSwitchCount: 2,
        successfulSwitchCount: 2,
        receiverReconnectCount: 0,
        stalePreviousStatusCount: 1,
        previousChannelErrorCount: 1,
        latestErrorMatchedSelectedChannel: false,
        localPlaybackRestartCount: 1,
        recoveryActionCount: 1,
        measuredAt: DateTime.utc(2026, 7, 15, 17),
      ),
    );

    expect(evaluation.accepted, isFalse);
    expect(
      evaluation.violations,
      contains(CastChannelSwitchViolationCode.stalePreviousStatusObserved),
    );
    expect(
      evaluation.violations,
      contains(CastChannelSwitchViolationCode.previousChannelErrorShown),
    );
    expect(
      evaluation.violations,
      contains(CastChannelSwitchViolationCode.latestErrorMisattributed),
    );
    expect(
      evaluation.violations,
      contains(CastChannelSwitchViolationCode.localPlaybackRestarted),
    );
    expect(
      evaluation.violations,
      contains(CastChannelSwitchViolationCode.recoveryRequired),
    );
  });

  test('requires enough switches and public labels', () {
    expect(
      const CastChannelSwitchReportWriter()
          .evaluate(
            CastChannelSwitchReportConfig(
              reportId: 'single-switch',
              senderProfile: 'pixel9-physical',
              receiverProfile: 'bravia-chromecast',
              playlistProfile: 'iptv-org-public',
              attemptedSwitchCount: 1,
              successfulSwitchCount: 1,
              receiverReconnectCount: 0,
              stalePreviousStatusCount: 0,
              previousChannelErrorCount: 0,
              latestErrorMatchedSelectedChannel: true,
              localPlaybackRestartCount: 0,
              recoveryActionCount: 0,
            ),
          )
          .violations,
      contains(CastChannelSwitchViolationCode.insufficientSwitches),
    );
    expect(
      () => const CastChannelSwitchReportConfig(
        reportId: 'http://example.test/private-playlist.m3u8',
        senderProfile: 'pixel9-physical',
        receiverProfile: 'bravia-chromecast',
        playlistProfile: 'iptv-org-public',
        attemptedSwitchCount: 2,
        successfulSwitchCount: 2,
        receiverReconnectCount: 0,
        stalePreviousStatusCount: 0,
        previousChannelErrorCount: 0,
        latestErrorMatchedSelectedChannel: true,
        localPlaybackRestartCount: 0,
        recoveryActionCount: 0,
      ).normalized(),
      throwsArgumentError,
    );
  });
}
