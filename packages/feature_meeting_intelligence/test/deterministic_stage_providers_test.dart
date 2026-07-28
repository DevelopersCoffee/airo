import 'package:feature_meeting_intelligence/feature_meeting_intelligence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('deterministic meeting stage providers', () {
    final request = MeetingIntelligenceJobRequest(
      jobId: 'job-1',
      meetingId: 'meeting-1',
      stages: const {
        MeetingIntelligenceStage.summary,
        MeetingIntelligenceStage.searchIndexing,
      },
      redactedTranscriptSegments: const [
        'Call [REDACTED_PHONE] about the budget risk.',
        'Action: Priya to share launch notes.',
        'Decision: Move the launch review to Tuesday.',
        'Open Question: Is the offline build ready?',
        'Follow-up: Neha to confirm the checklist.',
        'Blocker: Waiting on legal sign-off.',
        'Dependency: Finance must confirm the budget.',
        'Next: Prepare the local launch checklist.',
      ],
    );

    test('summary provider preserves the existing deterministic behavior', () {
      const provider = DeterministicMeetingSummaryProvider();

      final summary = provider.process(request);

      expect(summary.executiveSummary, hasLength(240));
      expect(summary.executiveSummary, endsWith('...'));
      expect(summary.actionItems, ['Priya to share launch notes']);
      expect(summary.keyDecisions, ['Move the launch review to Tuesday']);
      expect(
        summary.risks,
        contains('Call [REDACTED_PHONE] about the budget risk'),
      );
      expect(summary.openQuestions, ['Is the offline build ready?']);
      expect(summary.followUps, ['Neha to confirm the checklist']);
      expect(summary.blockers, ['Waiting on legal sign-off']);
      expect(summary.dependencies, ['Finance must confirm the budget']);
      expect(summary.nextSteps, ['Prepare the local launch checklist']);
    });

    test('search provider prepares only the redacted transcript snapshot', () {
      const provider = DeterministicMeetingSearchIndexProvider();

      final index = provider.process(request);

      expect(
        index.searchableText,
        request.redactedTranscriptSegments.join('\n'),
      );
      expect(index.searchableText, contains('[REDACTED_PHONE]'));
      expect(index.searchableText, isNot(contains('+91')));
    });
  });
}
