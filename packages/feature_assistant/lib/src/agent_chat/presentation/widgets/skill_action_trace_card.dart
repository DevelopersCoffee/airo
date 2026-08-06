import 'package:flutter/material.dart';

import '../../domain/models/agent_skill.dart';

class SkillActionTraceCard extends StatelessWidget {
  const SkillActionTraceCard({super.key, required this.traces});

  final List<AgentActionTrace> traces;

  @override
  Widget build(BuildContext context) {
    if (traces.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_fix_high,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Performed action',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final trace in traces) _TraceRow(trace: trace),
        ],
      ),
    );
  }
}

class _TraceRow extends StatelessWidget {
  const _TraceRow({required this.trace});

  final AgentActionTrace trace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            trace.success ? Icons.circle : Icons.error_outline,
            size: trace.success ? 8 : 16,
            color: trace.success
                ? theme.colorScheme.primary
                : theme.colorScheme.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trace.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (trace.durationMs != null)
                  Text(
                    _formatDuration(trace.durationMs!),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(trace.detail, style: theme.textTheme.bodySmall),
                if (trace.parameters.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Parameters: ${trace.parameters}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDuration(int durationMs) {
  if (durationMs < 1000) {
    return '${durationMs}ms';
  }
  return '${(durationMs / 1000).toStringAsFixed(1)}s';
}
