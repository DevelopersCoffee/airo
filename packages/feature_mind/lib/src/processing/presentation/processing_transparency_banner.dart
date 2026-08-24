import 'package:flutter/material.dart';

import '../domain/processing_plan.dart';
import '../../widgets/mind_palette.dart';

/// Shows how Airo chose a processing strategy for this recording.
class ProcessingTransparencyBanner extends StatelessWidget {
  const ProcessingTransparencyBanner({required this.plan, super.key});

  final ProcessingPlan? plan;

  @override
  Widget build(BuildContext context) {
    final plan = this.plan;
    if (plan == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: plan.summaryLine,
      child: DecoratedBox(
        key: const Key('processing_transparency_banner'),
        decoration: BoxDecoration(
          border: Border.all(color: MindPalette.grid),
          color: MindPalette.surface.withValues(alpha: 0.25),
        ),
        child: ExpansionTile(
          key: const Key('processing_transparency_expansion'),
          tilePadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          title: Text(
            plan.summaryLine,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
            ),
          ),
          subtitle: Text(
            plan.modelTierLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in plan.detailLines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• $line',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
