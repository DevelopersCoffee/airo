import 'package:flutter/material.dart';

import '../domain/live_insight.dart';

/// Collapsible live insights rail — decisions, actions, questions, topics.
class LiveInsightsRail extends StatelessWidget {
  const LiveInsightsRail({
    required this.expanded,
    required this.onToggle,
    this.insights = const [],
    super.key,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final List<LiveInsight> insights;

  @override
  Widget build(BuildContext context) {
    if (!expanded) {
      return Align(
        alignment: Alignment.topRight,
        child: IconButton(
          key: const Key('meeting_capture_insights_expand'),
          tooltip: 'Live insights',
          onPressed: onToggle,
          icon: Badge(
            isLabelVisible: insights.isNotEmpty,
            label: Text('${insights.length}'),
            child: const Icon(Icons.insights_outlined),
          ),
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
          Expanded(
            child: insights.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Decisions, actions, and topics will appear here as '
                      'Airo understands the meeting.',
                      style: TextStyle(fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    key: const Key('meeting_capture_insights_list'),
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: insights.length,
                    itemBuilder: (context, index) {
                      final item = insights[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          '${_label(item.kind)} · ${item.text}',
                          key: Key('meeting_capture_insights_item_$index'),
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

String _label(LiveInsightKind kind) {
  return switch (kind) {
    LiveInsightKind.decision => 'Decision',
    LiveInsightKind.action => 'Action',
    LiveInsightKind.question => 'Question',
    LiveInsightKind.topic => 'Topic',
    LiveInsightKind.entity => 'Entity',
  };
}
