import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

class WellnessBanner extends StatelessWidget {
  const WellnessBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      margin: const EdgeInsets.fromLTRB(
        AiroSpacing.md,
        AiroSpacing.sm,
        AiroSpacing.md,
        AiroSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.health_and_safety_outlined, color: scheme.primary),
          const SizedBox(width: AiroSpacing.sm),
          Expanded(
            child: Text(
              'Anya is a general nutrition planner, not medical advice.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
