import 'package:flutter/material.dart';

import '../../domain/models/media_category.dart';
import '../../domain/models/unified_media_content.dart';

class MediaContentCard extends StatelessWidget {
  const MediaContentCard({
    super.key,
    required this.item,
    this.onTap,
    this.width = 190,
    this.height = 220,
  }) : isSkeleton = false;

  const MediaContentCard.skeleton({
    super.key,
    this.width = 190,
    this.height = 220,
  }) : item = null,
       onTap = null,
       isSkeleton = true;

  final UnifiedMediaContent? item;
  final VoidCallback? onTap;
  final double width;
  final double height;
  final bool isSkeleton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isSkeleton ? null : onTap,
          child: isSkeleton
              ? _CardSkeleton(colorScheme: colorScheme)
              : _CardBody(item: item!, theme: theme),
        ),
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({required this.item, required this.theme});

  final UnifiedMediaContent item;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    final tag = item.tags.isNotEmpty ? item.tags.first : item.category.label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primaryContainer,
                      colorScheme.secondaryContainer,
                    ],
                  ),
                ),
                child: item.imageUrl == null || item.imageUrl!.isEmpty
                    ? Icon(
                        item.isLive ? Icons.live_tv : Icons.album,
                        size: 44,
                        color: colorScheme.onPrimaryContainer,
                      )
                    : Image.network(
                        item.imageUrl!,
                        fit: BoxFit.cover,
                        frameBuilder: (context, child, frame, wasLoaded) {
                          return AnimatedOpacity(
                            opacity: frame == null && !wasLoaded ? 0 : 1,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            child: child,
                          );
                        },
                        errorBuilder: (context, _, _) {
                          return Icon(
                            item.isLive ? Icons.live_tv : Icons.album,
                            size: 44,
                            color: colorScheme.onPrimaryContainer,
                          );
                        },
                      ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (item.isLive)
                      _Pill(
                        label: 'LIVE',
                        backgroundColor: colorScheme.error,
                        foregroundColor: colorScheme.onError,
                      ),
                    _Pill(
                      label: tag.toUpperCase(),
                      backgroundColor: colorScheme.surface.withValues(
                        alpha: 0.88,
                      ),
                      foregroundColor: colorScheme.onSurface,
                    ),
                  ],
                ),
              ),
              if (item.viewerCount != null)
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: _Pill(
                    label: '${item.viewerCount} watching',
                    icon: Icons.visibility_outlined,
                    backgroundColor: Colors.black.withValues(alpha: 0.68),
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: foregroundColor,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: foregroundColor),
              const SizedBox(width: 4),
            ],
            Text(label, style: labelStyle),
          ],
        ),
      ),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final shimmer = colorScheme.surfaceContainerHighest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ColoredBox(
            key: const ValueKey('media-card-skeleton-image'),
            color: shimmer,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 12, width: 120, color: shimmer),
              const SizedBox(height: 8),
              Container(height: 10, width: 80, color: shimmer),
            ],
          ),
        ),
      ],
    );
  }
}
