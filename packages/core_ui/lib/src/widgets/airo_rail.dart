import 'package:flutter/material.dart';

import 'media_card.dart';

/// A titled, horizontally-scrolling rail of content (e.g. "Top 50 India").
/// Wraps [children] (typically [MediaCard]s) in a horizontal-scroll row
/// below a title + subtitle header, matching the source design's rail
/// layout exactly (26px page padding, 10px card gap, 16px header spacing
/// by default (configurable via `headerGap`)).
class AiroRail extends StatelessWidget {
  const AiroRail({
    required this.title,
    required this.children,
    super.key,
    this.subtitle,
    this.padding = const EdgeInsets.symmetric(horizontal: 26),
    this.railHeight,
    this.cardVariant,
    this.headerGap = 16,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final EdgeInsets padding;

  /// Explicit override for the rail's height. Takes priority over
  /// [cardVariant]. Rarely needed — prefer [cardVariant] so the height
  /// stays derived from [MediaCard]'s actual dimensions instead of a
  /// hand-tuned magic number that can drift out of sync with them.
  final double? railHeight;

  /// The [MediaCardVariant] hosted by this rail's [children]. When set (and
  /// [railHeight] isn't explicitly overridden), the rail height is derived
  /// from [MediaCard.railHeightFor] so card and rail sizing can never drift
  /// apart. Leave null (with an explicit [railHeight]) for rails that don't
  /// host [MediaCard] children.
  final MediaCardVariant? cardVariant;

  /// Vertical gap between the title/subtitle header and the card row.
  /// Defaults to 16 (the platform-wide value); callers with a tight vertical
  /// budget (e.g. a compact TV viewport) may override this to reclaim space.
  final double headerGap;

  /// [ListView] needs a bounded cross-axis height for its scroll direction.
  /// Uses [railHeight] if set, else derives from [cardVariant] via
  /// [MediaCard.railHeightFor], else falls back to the historical default
  /// (104px thumbnail + ~52px text block) for callers using neither.
  double get _effectiveRailHeight {
    final height = railHeight;
    if (height != null) return height;
    final variant = cardVariant;
    if (variant != null) return MediaCard.railHeightFor(variant);
    return 156;
  }

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
            height: _effectiveRailHeight,
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
