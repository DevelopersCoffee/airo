import 'package:flutter/material.dart';

import '../../domain/models/unified_media_content.dart';
import 'media_content_card.dart';

class ContentCarousel extends StatelessWidget {
  const ContentCarousel({
    super.key,
    required this.items,
    required this.onSelected,
    this.title,
  }) : skeletonCount = 0;

  const ContentCarousel.skeleton({
    super.key,
    this.title,
    this.skeletonCount = 4,
  }) : items = const [],
       onSelected = _noop;

  final String? title;
  final List<UnifiedMediaContent> items;
  final ValueChanged<UnifiedMediaContent> onSelected;
  final int skeletonCount;

  static void _noop(UnifiedMediaContent _) {}

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && skeletonCount == 0) {
      return const SizedBox.shrink();
    }

    final count = skeletonCount > 0 ? skeletonCount : items.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Text(
              title!,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: count,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              if (skeletonCount > 0) {
                return const MediaContentCard.skeleton();
              }
              final item = items[index];
              return MediaContentCard(
                item: item,
                onTap: () => onSelected(item),
              );
            },
          ),
        ),
      ],
    );
  }
}
