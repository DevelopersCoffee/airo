import 'package:flutter/material.dart';

/// A titled, horizontally-scrolling rail of content (e.g. "Top 50 India").
/// Wraps [children] (typically [AiroRailCard]s) in a horizontal-scroll row
/// below a title + subtitle header, matching the source design's rail
/// layout exactly (26px page padding, 10px card gap, 11px header spacing).
class AiroRail extends StatelessWidget {
  const AiroRail({
    required this.title,
    required this.children,
    super.key,
    this.subtitle,
    this.padding = const EdgeInsets.symmetric(horizontal: 26),
    this.railHeight = 156,
    this.headerGap = 16,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final EdgeInsets padding;

  /// [ListView] needs a bounded cross-axis height for its scroll direction.
  /// Defaults to [AiroRailCard]'s natural height at its default
  /// thumbnailHeight (104) plus its two-line text block (~52) — override
  /// if using a different thumbnailHeight or single-line (no subtitle) cards.
  final double railHeight;

  /// Vertical gap between the title/subtitle header and the card row.
  /// Defaults to 16 (the platform-wide value); callers with a tight vertical
  /// budget (e.g. a compact TV viewport) may override this to reclaim space.
  final double headerGap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(
              left: padding.left,
              right: padding.right,
              bottom: headerGap,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      subtitle!,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            height: railHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.only(
                left: padding.left,
                right: padding.right,
                top: 2,
                bottom: 4,
              ),
              itemCount: children.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) => children[index],
            ),
          ),
        ],
      ),
    );
  }
}
