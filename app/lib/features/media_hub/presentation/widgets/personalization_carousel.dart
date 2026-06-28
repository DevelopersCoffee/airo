import 'package:flutter/material.dart';

import '../../domain/models/media_mode.dart';
import '../../domain/models/unified_media_content.dart';

class PersonalizationCarousel extends StatelessWidget {
  const PersonalizationCarousel({
    super.key,
    required this.title,
    required this.items,
    this.emptyMessage,
    this.onSelected,
    this.showFavoriteButton = false,
    this.isFavorite,
    this.onFavoriteToggle,
  });

  final String title;
  final List<UnifiedMediaContent> items;
  final String? emptyMessage;
  final ValueChanged<UnifiedMediaContent>? onSelected;
  final bool showFavoriteButton;
  final bool Function(UnifiedMediaContent item)? isFavorite;
  final ValueChanged<UnifiedMediaContent>? onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return _PersonalizationTile(
                item: item,
                onTap: onSelected == null ? null : () => onSelected!(item),
                showFavoriteButton: showFavoriteButton,
                isFavorite: isFavorite?.call(item) ?? false,
                onFavoriteToggle: onFavoriteToggle == null
                    ? null
                    : () => onFavoriteToggle!(item),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PersonalizationTile extends StatelessWidget {
  const _PersonalizationTile({
    required this.item,
    this.onTap,
    this.showFavoriteButton = false,
    this.isFavorite = false,
    this.onFavoriteToggle,
  });

  final UnifiedMediaContent item;
  final VoidCallback? onTap;
  final bool showFavoriteButton;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final showProgress =
        item.canResume && item.lastPosition > const Duration(seconds: 10);
    final progress = item.duration.inMilliseconds == 0
        ? 0.0
        : (item.lastPosition.inMilliseconds / item.duration.inMilliseconds)
              .clamp(0.0, 1.0);
    return SizedBox(
      width: 210,
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      item.isLive ? Icons.live_tv : Icons.history,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (showFavoriteButton)
                      IconButton(
                        tooltip: isFavorite
                            ? 'Remove from favorites'
                            : 'Add to favorites',
                        onPressed: onFavoriteToggle,
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            key: ValueKey(isFavorite),
                            color: isFavorite
                                ? colorScheme.error
                                : colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                if (showProgress) ...[
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 6),
                  Text(
                    '${_formatDuration(item.lastPosition)} / ${_formatDuration(item.duration)}',
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  item.mode.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (value.inHours > 0) {
      final hours = value.inHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
