import 'package:flutter/material.dart';

import '../../../intelligence/intelligence_typography.dart';
import '../../../widgets/mind_palette.dart';
import '../../domain/models/research_event.dart';

/// Structured Deep Research progress. Execution state only — no model CoT.
class DeepResearchProgressPanel extends StatelessWidget {
  const DeepResearchProgressPanel({super.key, required this.session});

  final ResearchSession session;

  static const _steps = <(ResearchEventKind, String)>[
    (ResearchEventKind.planningStarted, 'Understanding question'),
    (ResearchEventKind.planCreated, 'Creating research plan'),
    (ResearchEventKind.searchStarted, 'Searching sources'),
    (ResearchEventKind.sourceDiscovered, 'Reading documents'),
    (ResearchEventKind.analyzingStarted, 'Comparing evidence'),
    (ResearchEventKind.gapDetected, 'Finding missing evidence'),
    (ResearchEventKind.synthesisStarted, 'Writing report'),
  ];

  @override
  Widget build(BuildContext context) {
    final kinds = session.events.map((event) => event.kind).toSet();
    final active = session.last?.kind;

    return Container(
      key: const Key('agent_chat_deep_research_progress'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: MindPalette.surface,
        border: Border.fromBorderSide(BorderSide(color: MindPalette.grid)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            session.isComplete
                ? 'RESEARCH COMPLETE'
                : session.isFailed
                ? 'RESEARCH FAILED'
                : 'RESEARCHING',
            style: IntelligenceTypography.kicker(),
          ),
          const SizedBox(height: 8),
          for (final step in _steps)
            _StepRow(
              label: step.$2,
              done:
                  session.isComplete ||
                  (kinds.contains(step.$1) && step.$1 != active),
              active: !session.isComplete && active == step.$1,
              complete: session.isComplete,
            ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.done,
    required this.active,
    required this.complete,
  });

  final String label;
  final bool done;
  final bool active;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final icon = complete || done
        ? Icons.check
        : active
        ? Icons.radio_button_checked
        : Icons.radio_button_unchecked;
    final color = complete || done
        ? MindPalette.local
        : active
        ? MindPalette.ink
        : MindPalette.ink.withValues(alpha: 0.45);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color, letterSpacing: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
