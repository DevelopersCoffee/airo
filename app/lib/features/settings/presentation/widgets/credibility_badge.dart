import 'package:flutter/material.dart';
import 'package:core_ai/core_ai.dart';

/// A badge widget that displays the credibility level of an AI model.
///
/// Shows an icon and label colored according to the trust level.
/// Used in ModelCard and ModelDetailScreen to indicate model source reliability.
class CredibilityBadge extends StatelessWidget {
  const CredibilityBadge({
    super.key,
    required this.credibility,
    this.showLabel = true,
    this.size = CredibilityBadgeSize.medium,
  });

  /// The credibility level to display.
  final ModelCredibility credibility;

  /// Whether to show the text label or just the icon.
  final bool showLabel;

  /// Size of the badge.
  final CredibilityBadgeSize size;

  Color get _badgeColor {
    // Convert hex color from ModelCredibility to Color
    final hex = credibility.colorHex.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  double get _fontSize => switch (size) {
    CredibilityBadgeSize.small => 10,
    CredibilityBadgeSize.medium => 12,
    CredibilityBadgeSize.large => 14,
  };

  double get _iconSize => switch (size) {
    CredibilityBadgeSize.small => 12,
    CredibilityBadgeSize.medium => 14,
    CredibilityBadgeSize.large => 18,
  };

  EdgeInsets get _padding => switch (size) {
    CredibilityBadgeSize.small => const EdgeInsets.symmetric(
      horizontal: 6,
      vertical: 2,
    ),
    CredibilityBadgeSize.medium => const EdgeInsets.symmetric(
      horizontal: 8,
      vertical: 4,
    ),
    CredibilityBadgeSize.large => const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 6,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final color = _badgeColor;
    final backgroundColor = color.withAlpha((0.15 * 255).round());

    return Container(
      padding: _padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withAlpha((0.3 * 255).round()),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            credibility.icon,
            style: TextStyle(fontSize: _iconSize, color: color),
          ),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              credibility.displayName,
              style: TextStyle(
                fontSize: _fontSize,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Size options for CredibilityBadge.
enum CredibilityBadgeSize { small, medium, large }

/// Shows a tooltip with detailed trust information when tapped.
class CredibilityBadgeWithInfo extends StatelessWidget {
  const CredibilityBadgeWithInfo({
    super.key,
    required this.credibility,
    this.size = CredibilityBadgeSize.medium,
  });

  final ModelCredibility credibility;
  final CredibilityBadgeSize size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: credibility.trustInfo,
      preferBelow: false,
      child: InkWell(
        onTap: () => _showTrustInfoDialog(context),
        borderRadius: BorderRadius.circular(6),
        child: CredibilityBadge(credibility: credibility, size: size),
      ),
    );
  }

  void _showTrustInfoDialog(BuildContext context) {
    final color = Color(
      int.parse('FF${credibility.colorHex.replaceFirst('#', '')}', radix: 16),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(
              credibility.icon,
              style: TextStyle(fontSize: 24, color: color),
            ),
            const SizedBox(width: 8),
            Text(credibility.displayName),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(credibility.trustInfo),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Trust Score: '),
                Text(
                  '${credibility.trustScore}/100',
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
