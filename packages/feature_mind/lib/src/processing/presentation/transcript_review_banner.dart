import 'package:flutter/material.dart';

import '../application/transcript_quality_evaluator.dart';
import '../../widgets/mind_palette.dart';

/// Honest transcript confidence banner for the meeting reader.
class TranscriptReviewBanner extends StatelessWidget {
  const TranscriptReviewBanner({required this.report, super.key});

  final MeetingTranscriptQualityReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final needsReview = report.needsReview;
    final color = needsReview ? MindPalette.alarm : MindPalette.local;

    return Semantics(
      container: true,
      label: report.summary,
      child: DecoratedBox(
        key: const Key('transcript_review_banner'),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.6)),
          color: color.withValues(alpha: needsReview ? 0.12 : 0.08),
        ),
        child: ExpansionTile(
          key: const Key('transcript_review_expansion'),
          tilePadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          leading: Icon(
            needsReview ? Icons.warning_amber_outlined : Icons.verified_outlined,
            color: color,
            size: 20,
          ),
          title: Text(
            report.headline,
            style: theme.textTheme.titleSmall?.copyWith(color: color),
          ),
          subtitle: Text(
            report.summary,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (report.retryCount > 0)
                    Text(
                      'Retried segments: ${report.retriedSegmentIds.join(', ')}',
                      style: theme.textTheme.labelSmall,
                    ),
                  if (report.segmentIssues.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Sections to double-check:',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    for (final issue in report.segmentIssues)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '• ${_formatClock(issue.startMs)}–'
                          '${_formatClock(issue.endMs)}: '
                          '${issue.text.trim()} '
                          '(${issue.signals.join(', ')})',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatClock(int ms) {
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}
