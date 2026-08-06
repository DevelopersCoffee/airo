import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// A titled, tappable row card with a domain-accented icon.
///
/// Extracted when the old Mind hub split into Wellbeing and Assistant: both
/// halves render the same card, and two private copies would have drifted the
/// first time one of them changed.
class AiroActionCard extends StatelessWidget {
  const AiroActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final domain = AiroDomainTokens.of(context);
    final visual = AiroVisualTokens.of(context);

    return AiroSurface(
      level: AiroSurfaceLevel.raised,
      onTap: onTap,
      semanticLabel: '$title. $subtitle',
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: domain.accent.withValues(alpha: 0.12),
              borderRadius: visual.smallRadius,
            ),
            child: Icon(icon, color: domain.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
