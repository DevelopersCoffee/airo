import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:platform_benchmarks/platform_benchmarks.dart';

void main() {
  test('writes accepted D-pad traversal evidence artifacts', () async {
    final directory = await Directory.systemTemp.createTemp(
      'airo-tv-dpad-traversal-report-test-',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final evaluation = await const AiroTvDpadTraversalReportWriter().write(
      AiroTvDpadTraversalReportConfig(
        reportId: 'shield-tv-dpad-traversal',
        deviceProfile: 'shield-tv-physical',
        viewportProfile: 'android-tv-1080p',
        requiredActionCount: 9,
        reachableActionCount: 9,
        channelCardTraversalCount: 12,
        helpDialogOpened: true,
        helpDialogDismissed: true,
        focusLossCount: 0,
        overflowCount: 0,
        renderErrorCount: 0,
        measuredAt: DateTime.utc(2026, 7, 15, 16),
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
    expect(markdown, contains('# Airo TV D-pad Traversal Evidence'));
    expect(markdown, contains('accepted'));
  });

  test('marks unreachable actions and shallow channel traversal', () {
    final evaluation = const AiroTvDpadTraversalReportWriter().evaluate(
      AiroTvDpadTraversalReportConfig(
        reportId: 'incomplete-dpad-traversal',
        deviceProfile: 'fire-tv-physical',
        viewportProfile: 'android-tv-720p',
        requiredActionCount: 9,
        reachableActionCount: 7,
        channelCardTraversalCount: 3,
        helpDialogOpened: true,
        helpDialogDismissed: true,
        focusLossCount: 0,
        overflowCount: 0,
        renderErrorCount: 0,
        measuredAt: DateTime.utc(2026, 7, 15, 16),
      ),
    );

    expect(evaluation.accepted, isFalse);
    expect(
      evaluation.violations,
      contains(AiroTvDpadTraversalViolationCode.actionReachabilityIncomplete),
    );
    expect(
      evaluation.violations,
      contains(AiroTvDpadTraversalViolationCode.channelTraversalTooShallow),
    );
  });

  test('marks focus, overflow, render, and help dialog violations', () {
    final evaluation = const AiroTvDpadTraversalReportWriter().evaluate(
      AiroTvDpadTraversalReportConfig(
        reportId: 'unstable-dpad-traversal',
        deviceProfile: 'fire-tv-physical',
        viewportProfile: 'android-tv-720p',
        requiredActionCount: 9,
        reachableActionCount: 9,
        channelCardTraversalCount: 12,
        helpDialogOpened: true,
        helpDialogDismissed: false,
        focusLossCount: 1,
        overflowCount: 2,
        renderErrorCount: 1,
        measuredAt: DateTime.utc(2026, 7, 15, 16),
      ),
    );

    expect(evaluation.accepted, isFalse);
    expect(
      evaluation.violations,
      contains(AiroTvDpadTraversalViolationCode.helpDialogNotOperable),
    );
    expect(
      evaluation.violations,
      contains(AiroTvDpadTraversalViolationCode.focusLossDetected),
    );
    expect(
      evaluation.violations,
      contains(AiroTvDpadTraversalViolationCode.overflowDetected),
    );
    expect(
      evaluation.violations,
      contains(AiroTvDpadTraversalViolationCode.renderErrorDetected),
    );
  });

  test('rejects invalid metric counts and private labels', () {
    expect(
      () => const AiroTvDpadTraversalReportConfig(
        reportId: 'too-many-actions',
        deviceProfile: 'fire-tv-physical',
        viewportProfile: 'android-tv-720p',
        requiredActionCount: 9,
        reachableActionCount: 10,
        channelCardTraversalCount: 12,
        helpDialogOpened: true,
        helpDialogDismissed: true,
        focusLossCount: 0,
        overflowCount: 0,
        renderErrorCount: 0,
      ).normalized(),
      throwsArgumentError,
    );
    expect(
      () => const AiroTvDpadTraversalReportConfig(
        reportId: 'valid-id',
        deviceProfile: '192.168.1.25',
        viewportProfile: 'android-tv-720p',
        requiredActionCount: 9,
        reachableActionCount: 9,
        channelCardTraversalCount: 12,
        helpDialogOpened: true,
        helpDialogDismissed: true,
        focusLossCount: 0,
        overflowCount: 0,
        renderErrorCount: 0,
      ).normalized(),
      throwsArgumentError,
    );
  });
}
