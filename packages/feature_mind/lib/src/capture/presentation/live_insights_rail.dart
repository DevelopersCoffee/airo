import 'package:flutter/material.dart';

/// Collapsible live insights rail (`P1` stub — structure only).
class LiveInsightsRail extends StatelessWidget {
  const LiveInsightsRail({
    required this.expanded,
    required this.onToggle,
    super.key,
  });

  final bool expanded;
  final VoidCallback onToggle;

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
        border: Border(
          left: BorderSide(color: Theme.of(context).dividerColor),
        ),
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Decisions, actions, and topics will appear here as '
              'Airo understands the meeting.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
