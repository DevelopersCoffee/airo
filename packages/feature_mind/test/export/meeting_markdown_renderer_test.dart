import 'package:feature_mind/src/export/domain/meeting_export_models.dart';
import 'package:feature_mind/src/export/domain/meeting_markdown_renderer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatTimestamp', () {
    test('renders plain bracketed HH:MM:SS, not a deep link', () {
      expect(formatTimestamp(0), '[00:00:00]');
      expect(formatTimestamp(754000), '[00:12:34]');
      expect(formatTimestamp(3661000), '[01:01:01]');
    });

    test('never emits an app URI scheme', () {
      final result = formatTimestamp(754000);
      expect(result, isNot(contains('://')));
      expect(result, isNot(contains('airo')));
    });
  });

  group('formatDurationHms', () {
    test('omits the hour unit under an hour', () {
      expect(
        formatDurationHms(const Duration(minutes: 5, seconds: 12)),
        '5m 12s',
      );
    });

    test('omits leading zero units but keeps seconds', () {
      expect(formatDurationHms(Duration.zero), '0s');
      expect(formatDurationHms(const Duration(seconds: 9)), '9s');
    });

    test('includes hours once the meeting is that long', () {
      expect(
        formatDurationHms(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1h 2m 3s',
      );
    });
  });

  group('renderFrontmatter', () {
    test('emits a YAML block with title, date and duration', () {
      final fm = renderFrontmatter(
        title: 'Signaling capacity review',
        date: DateTime.utc(2026, 8, 14, 9, 30),
        duration: const Duration(minutes: 42),
      );
      expect(fm, startsWith('---\n'));
      expect(fm, contains('title: "Signaling capacity review"'));
      expect(fm, contains('date: 2026-08-14T09:30:00.000Z'));
      expect(fm, contains('duration: "42m 0s"'));
      expect(fm.trimRight(), endsWith('---'));
    });

    test('omits duration when null', () {
      final fm = renderFrontmatter(title: 'x', date: DateTime.utc(2026, 1, 1));
      expect(fm, isNot(contains('duration:')));
    });

    test('escapes double quotes in the title', () {
      final fm = renderFrontmatter(
        title: 'The "big" sync',
        date: DateTime.utc(2026, 1, 1),
      );
      expect(fm, contains(r'title: "The \"big\" sync"'));
    });
  });

  group('renderTranscriptMarkdown', () {
    test('renders timestamped lines when segments are available', () {
      final md = renderTranscriptMarkdown(
        title: 'Standup',
        recordedAt: DateTime.utc(2026, 8, 14),
        lines: const [
          TranscriptExportLine(startMs: 0, text: 'Let’s get started.'),
          TranscriptExportLine(
            startMs: 5000,
            text: 'First up, the signaling limit.',
          ),
        ],
      );
      expect(md, contains('## Transcript'));
      expect(md, contains('[00:00:00] Let’s get started.'));
      expect(md, contains('[00:00:05] First up, the signaling limit.'));
    });

    test('includes speaker label prefix when present', () {
      final md = renderTranscriptMarkdown(
        title: 'Standup',
        recordedAt: DateTime.utc(2026, 8, 14),
        lines: const [
          TranscriptExportLine(
            startMs: 65000,
            text: 'Priya said the lag is the bottleneck.',
            speakerLabel: 'sp0',
          ),
        ],
      );
      expect(
        md,
        contains(
          '[00:01:05] sp0: Priya said the lag is the bottleneck.',
        ),
      );
    });

    test('skips blank lines', () {
      final md = renderTranscriptMarkdown(
        title: 'Standup',
        recordedAt: DateTime.utc(2026, 8, 14),
        lines: const [
          TranscriptExportLine(startMs: 0, text: '   '),
          TranscriptExportLine(startMs: 1000, text: 'Real line'),
        ],
      );
      expect(md, isNot(contains('[00:00:00]')));
      expect(md, contains('[00:00:01] Real line'));
    });

    test('falls back to the flat transcript when there are no segments', () {
      final md = renderTranscriptMarkdown(
        title: 'Old meeting',
        recordedAt: DateTime.utc(2026, 1, 1),
        fallbackTranscript: 'Everything said, with no timestamps at all.',
      );
      expect(md, contains('Everything said, with no timestamps at all.'));
      expect(md, isNot(contains('[00:')));
    });

    test('says so when there is nothing to export', () {
      final md = renderTranscriptMarkdown(
        title: 'Empty',
        recordedAt: DateTime.utc(2026, 1, 1),
      );
      expect(md, contains('_No transcript available._'));
    });

    test('leads with frontmatter before the heading', () {
      final md = renderTranscriptMarkdown(
        title: 'Standup',
        recordedAt: DateTime.utc(2026, 8, 14),
        fallbackTranscript: 'hi',
      );
      final frontmatterEnd = md.indexOf('---', 4);
      final headingStart = md.indexOf('# Standup');
      expect(frontmatterEnd, greaterThan(0));
      expect(headingStart, greaterThan(frontmatterEnd));
    });
  });

  group('renderActionItemsMarkdown', () {
    test('empty list renders nothing', () {
      expect(renderActionItemsMarkdown(const []), '');
    });

    test('renders a table with placeholders for missing fields', () {
      final md = renderActionItemsMarkdown(const [
        ExportActionItem(
          task: 'Check the signaling limit',
          owner: 'Dev',
          due: 'Friday',
        ),
        ExportActionItem(task: 'Update the runbook'),
      ]);
      expect(md, contains('## Action Items'));
      expect(
        md,
        contains('| Check the signaling limit | Dev | Friday | Open |'),
      );
      expect(md, contains('| Update the runbook | — | — | Open |'));
    });

    test('uses the supplied status when present', () {
      final md = renderActionItemsMarkdown(const [
        ExportActionItem(task: 'Ship it', status: 'Done'),
      ]);
      expect(md, contains('| Ship it | — | — | Done |'));
    });
  });

  group('meetingExportFolderName', () {
    test('combines date and a slugified title', () {
      expect(
        meetingExportFolderName(
          title: 'Friday Standup!',
          date: DateTime.utc(2026, 8, 14),
        ),
        '2026-08-14-friday-standup',
      );
    });

    test('falls back to the date alone for an empty/symbol-only title', () {
      expect(
        meetingExportFolderName(title: '!!!', date: DateTime.utc(2026, 8, 14)),
        '2026-08-14',
      );
    });

    test('collapses repeated separators and pads single digits', () {
      expect(
        meetingExportFolderName(
          title: 'Q3   Review -- v2',
          date: DateTime.utc(2026, 1, 2),
        ),
        '2026-01-02-q3-review-v2',
      );
    });
  });

  group('composeMeetingExportBundle', () {
    test('always renders transcript.md', () {
      final bundle = composeMeetingExportBundle(
        MeetingExportInput(
          meetingId: 'm1',
          title: 'Standup',
          recordedAt: DateTime.utc(2026, 8, 14),
          fallbackTranscript: 'hello',
        ),
      );
      expect(bundle.folderName, '2026-08-14-standup');
      expect(bundle.files.keys, ['transcript.md']);
      expect(bundle.files['transcript.md'], contains('hello'));
    });

    test('adds mom.md when momMarkdown is present, action items untouched '
        'because the MoM text already has its own table', () {
      final bundle = composeMeetingExportBundle(
        MeetingExportInput(
          meetingId: 'm1',
          title: 'Standup',
          recordedAt: DateTime.utc(2026, 8, 14),
          momMarkdown:
              '# Minutes of Meeting\n\n## Action Items\n\n| Task | Owner | Due | Status |\n',
          actionItems: const [ExportActionItem(task: 'duplicate?')],
        ),
      );
      expect(bundle.files.keys, containsAll(['transcript.md', 'mom.md']));
      // Only one "Action Items" section -- the MoM's own, not a second one
      // appended from `actionItems`.
      final momFile = bundle.files['mom.md']!;
      expect('Action Items'.allMatches(momFile).length, 1);
    });

    test('appends actionItems to mom.md when the MoM text has no table of '
        'its own', () {
      final bundle = composeMeetingExportBundle(
        MeetingExportInput(
          meetingId: 'm1',
          title: 'Standup',
          recordedAt: DateTime.utc(2026, 8, 14),
          momMarkdown: '# Minutes of Meeting\n\nJust prose, no table.',
          actionItems: const [ExportActionItem(task: 'Follow up')],
        ),
      );
      final momFile = bundle.files['mom.md']!;
      expect(momFile, contains('## Action Items'));
      expect(momFile, contains('Follow up'));
    });

    test('gives action items their own file when there is no MoM at all', () {
      final bundle = composeMeetingExportBundle(
        MeetingExportInput(
          meetingId: 'm1',
          title: 'Standup',
          recordedAt: DateTime.utc(2026, 8, 14),
          actionItems: const [ExportActionItem(task: 'Solo item')],
        ),
      );
      expect(
        bundle.files.keys,
        containsAll(['transcript.md', 'action-items.md']),
      );
      expect(bundle.files['action-items.md'], contains('Solo item'));
    });
  });

  group('composeBatchExport', () {
    test('renders one bundle per input, preserving order', () {
      final bundles = composeBatchExport([
        MeetingExportInput(
          meetingId: 'a',
          title: 'First',
          recordedAt: DateTime.utc(2026, 1, 1),
          fallbackTranscript: 'one',
        ),
        MeetingExportInput(
          meetingId: 'b',
          title: 'Second',
          recordedAt: DateTime.utc(2026, 1, 2),
          fallbackTranscript: 'two',
        ),
      ]);
      expect(bundles, hasLength(2));
      expect(bundles[0].folderName, '2026-01-01-first');
      expect(bundles[1].folderName, '2026-01-02-second');
    });

    test('empty input list renders no bundles', () {
      expect(composeBatchExport(const []), isEmpty);
    });
  });
}
