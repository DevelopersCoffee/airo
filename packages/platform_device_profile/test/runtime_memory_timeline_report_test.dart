import 'package:flutter_test/flutter_test.dart';
import 'package:platform_device_profile/platform_device_profile.dart';

void main() {
  const budget = AiroRuntimeMemoryBudgetPolicy.androidTvConstrainedBudget;
  final start = DateTime.utc(2026, 7, 15, 12);

  group('AiroRuntimeMemoryTimelineReport', () {
    test('accepts a timeline inside the selected budget', () {
      final report = AiroRuntimeMemoryTimelineReport(
        reportId: 'tv-soak-pass',
        scenarioId: '30m-playback-soak',
        budget: budget,
        points: [
          _point('start', start, rssMb: 180, dartHeapMb: 96),
          _point(
            'mid',
            start.add(const Duration(minutes: 15)),
            rssMb: 210,
            dartHeapMb: 96,
          ),
          _point(
            'end',
            start.add(const Duration(minutes: 30)),
            rssMb: 225,
            dartHeapMb: 96,
          ),
        ],
      );

      final evaluation = report.evaluate();

      expect(evaluation.accepted, isTrue);
      expect(report.duration, const Duration(minutes: 30));
      expect(report.steadyRssMb, 225);
      expect(report.peakRssMb, 225);
      expect(report.playbackSoakDriftMbPerHour, 0);
    });

    test('reports peak RSS violations separately from steady RSS', () {
      final report = AiroRuntimeMemoryTimelineReport(
        reportId: 'tv-peak-fail',
        scenarioId: 'grid-scroll',
        budget: budget,
        points: [
          _point('start', start, rssMb: 200),
          _point('spike', start.add(const Duration(seconds: 30)), rssMb: 360),
          _point('end', start.add(const Duration(minutes: 1)), rssMb: 240),
        ],
      );

      final evaluation = report.evaluate();

      expect(evaluation.accepted, isFalse);
      expect(
        evaluation.violations,
        contains(AiroRuntimeMemoryBudgetViolationCode.peakRssExceeded),
      );
      expect(
        evaluation.violations,
        isNot(contains(AiroRuntimeMemoryBudgetViolationCode.steadyRssExceeded)),
      );
    });

    test('reports steady RSS violations using the final plateau sample', () {
      final report = AiroRuntimeMemoryTimelineReport(
        reportId: 'tv-steady-fail',
        scenarioId: 'post-import-grid-idle',
        budget: budget,
        points: [
          _point('start', start, rssMb: 220),
          _point('end', start.add(const Duration(minutes: 5)), rssMb: 260),
        ],
      );

      final evaluation = report.evaluate();

      expect(evaluation.accepted, isFalse);
      expect(
        evaluation.violations,
        contains(AiroRuntimeMemoryBudgetViolationCode.steadyRssExceeded),
      );
    });

    test(
      'reports playback soak drift violations from heap growth over time',
      () {
        final report = AiroRuntimeMemoryTimelineReport(
          reportId: 'tv-drift-fail',
          scenarioId: '30m-playback-soak',
          budget: budget,
          points: [
            _point('start', start, dartHeapMb: 80),
            _point(
              'end',
              start.add(const Duration(minutes: 30)),
              dartHeapMb: 82,
            ),
          ],
        );

        final evaluation = report.evaluate();

        expect(report.playbackSoakDriftMbPerHour, 4);
        expect(evaluation.accepted, isFalse);
        expect(
          evaluation.violations,
          contains(
            AiroRuntimeMemoryBudgetViolationCode.playbackSoakDriftExceeded,
          ),
        );
      },
    );

    test('emits public maps and markdown without raw device payloads', () {
      final report = AiroRuntimeMemoryTimelineReport(
        reportId: 'tv-markdown',
        scenarioId: 'grid-scroll',
        budget: budget,
        points: [
          _point('start', start),
          _point('end', start.add(const Duration(seconds: 30))),
        ],
      );

      final publicMap = report.toPublicMap();
      final markdown = report.toMarkdown();

      expect(publicMap, containsPair('reportId', 'tv-markdown'));
      expect(publicMap, isNot(contains('dumpsys')));
      expect(markdown, contains('# Airo Runtime Memory Timeline'));
      expect(markdown, contains('| `start` |'));
      expect(markdown, isNot(contains('dumpsys')));
    });

    test('rejects empty timelines', () {
      expect(
        () => AiroRuntimeMemoryTimelineReport(
          reportId: 'empty',
          scenarioId: 'grid-scroll',
          budget: budget,
          points: const [],
        ),
        throwsArgumentError,
      );
    });
  });
}

AiroRuntimeMemoryTimelinePoint _point(
  String id,
  DateTime sampledAt, {
  int rssMb = 200,
  int dartHeapMb = 96,
  int imageCacheMb = 12,
  int retainedChannelListCopies = 1,
}) {
  return AiroRuntimeMemoryTimelinePoint(
    pointId: id,
    sampledAt: sampledAt,
    rssMb: rssMb,
    dartHeapMb: dartHeapMb,
    imageCacheMb: imageCacheMb,
    retainedChannelListCopies: retainedChannelListCopies,
  );
}
