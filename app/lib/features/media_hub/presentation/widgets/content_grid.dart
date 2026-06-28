import 'package:flutter/material.dart';

import '../../domain/models/unified_media_content.dart';
import 'media_content_card.dart';

class ContentGrid extends StatelessWidget {
  const ContentGrid({
    super.key,
    required this.items,
    required this.onSelected,
    this.title,
  }) : skeletonCount = 0;

  const ContentGrid.skeleton({super.key, this.title, this.skeletonCount = 4})
    : items = const [],
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.86,
            ),
            itemCount: count,
            itemBuilder: (context, index) {
              if (skeletonCount > 0) {
                return const MediaContentCard.skeleton();
              }
              final item = items[index];
              return MediaContentCard(
                item: item,
                width: double.infinity,
                onTap: () => onSelected(item),
              );
            },
          ),
        ),
      ],
    );
  }
}
