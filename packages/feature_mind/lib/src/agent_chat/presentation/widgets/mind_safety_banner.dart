import 'package:flutter/material.dart';

import '../../../runtime/models/capability_models.dart';

/// Surface 02's safety banner.
///
/// Driven by the capability's [CapabilitySafetyClass], not hardcoded per
/// screen: any surface that renders an answer backed by a health capability
/// carries the same wellness-only notice, wherever that surface lives.
class MindSafetyBanner extends StatelessWidget {
  const MindSafetyBanner({super.key, this.safetyClass});

  final CapabilitySafetyClass? safetyClass;

  static const Map<CapabilitySafetyClass, String> copy = {
    CapabilitySafetyClass.health:
        'General wellness only. Airo will not change a dosage or raise a '
        'diagnostic alert.',
    CapabilitySafetyClass.financial:
        'General information only. Airo will not place a trade or file a '
        'return.',
    CapabilitySafetyClass.legal:
        'General information only. Airo will not file or submit anything '
        'on your behalf.',
  };

  @override
  Widget build(BuildContext context) {
    final safetyClass = this.safetyClass;
    if (safetyClass == null || safetyClass == CapabilitySafetyClass.general) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Container(
      key: const Key('mind.safetyBanner'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.tertiary.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 18,
            color: theme.colorScheme.tertiary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(copy[safetyClass]!, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
