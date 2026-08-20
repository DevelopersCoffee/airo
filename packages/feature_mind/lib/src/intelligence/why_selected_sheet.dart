import 'package:core_ai/core_ai.dart';
import 'package:flutter/material.dart';

import '../widgets/mind_palette.dart';
import 'intelligence_typography.dart';

void showWhySelectedSheet(BuildContext context, WhySelected why) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: MindPalette.surface,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WHY THIS MODEL', style: IntelligenceTypography.kicker()),
            const SizedBox(height: 8),
            Text(
              why.automatic
                  ? 'Airo selected this automatically.'
                  : 'This is your saved choice.',
              style: IntelligenceTypography.body(theme),
            ),
            const SizedBox(height: 16),
            for (final reason in why.reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reason.code == WhySelectedCode.automatic ? '·' : '✓',
                      style: IntelligenceTypography.status(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        reason.message,
                        style: IntelligenceTypography.body(theme),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
}
