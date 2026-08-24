import 'package:flutter/material.dart';

import '../domain/live_insight.dart';

/// Collapsible live insights rail (spec §19). Renders only high-confidence
/// insights; when none clear the threshold it shows the empty-state copy
/// rather than anything speculative. The insight producer (incremental
/// Conversation IR) is wired separately; an empty [insights] list is the
/// current default until that producer lands.
class LiveInsightsRail extends StatelessWidget {
  const LiveInsightsRail({
    required this.expanded,
    required this.onToggle,
    this.insights = const [],
    super.key,
  });

  final bool expanded;
  final VoidCallback onToggle;

  /// Raw candidate insights; the rail filters these to high-confidence only.
  final List<LiveInsight> insights;

  IconData _iconFor(LiveInsightKind kind) => switch (kind) {
    LiveInsightKind.decision => Icons.check_circle_outline,
    LiveInsightKind.action => Icons.task_alt,
    LiveInsightKind.topic => Icons.topic_outlined,
    LiveInsightKind.person => Icons.person_outline,
    LiveInsightKind.date => Icons.event_outlined,
  };

  @override
  Widget build(BuildContext context) {
    if (!expanded) {
      return Align(
        alignment: Alignment.topRight,
        child: IconButton(
          key: const Key('meeting_capture_insights_expand'),
          tooltip: 'Live insights',
          onPressed: onToggle,
          icon: const Icon(Icons.insights_outlined),
        ),
      );
    }
    return Container(
      width: 220,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'LIVE INSIGHTS',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('meeting_capture_insights_collapse'),
                  onPressed: onToggle,
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
          ),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final visible = filterHighConfidenceInsights(insights);
    if (visible.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          'Decisions, actions, and topics will appear here as '
          'Airo understands the meeting.',
          style: TextStyle(fontSize: 13),
        ),
      );
    }
    return ListView.separated(
      key: const Key('meeting_capture_insights_list'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _tile(context, visible[index]),
    );
  }

  Widget _tile(BuildContext context, LiveInsight insight) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          _iconFor(insight.kind),
          size: 16,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                insight.kind.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(insight.text, style: theme.textTheme.bodyMedium),
              if (insight.detail case final detail?)
                Text(detail, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
