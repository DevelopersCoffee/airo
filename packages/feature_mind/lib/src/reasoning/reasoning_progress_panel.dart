import 'package:flutter/material.dart';

import 'reasoning_models.dart';

/// Collapsible progress for a reasoning pass. Shows stage labels only —
/// never answer tokens and never a thought trace.
class ReasoningProgressPanel extends StatelessWidget {
  const ReasoningProgressPanel({
    super.key,
    required this.steps,
    this.inProgress = false,
    this.summary,
  });

  final List<ReasoningProgressStep> steps;
  final bool inProgress;
  final String? summary;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty && (summary == null || summary!.isEmpty)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final count = steps.length;
    final title = count == 0
        ? 'Thinking'
        : count == 1
        ? 'Thinking · 1 step'
        : 'Thinking · $count steps';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.16),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: inProgress,
            leading: Icon(
              inProgress ? Icons.hourglass_top : Icons.check_circle_outline,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            title: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            children: [
              for (final step in steps)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('·  ', style: theme.textTheme.bodySmall),
                      Expanded(
                        child: Text(
                          step.detail == null
                              ? step.label
                              : '${step.label}: ${step.detail}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              if (summary != null && summary!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    summary!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
