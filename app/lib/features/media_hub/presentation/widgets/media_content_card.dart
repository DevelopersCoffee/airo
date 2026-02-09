import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../domain/models/media_mode.dart';
import '../../domain/models/unified_media_content.dart';

/// A reusable card widget for displaying media content in the discovery grid.
///
/// Displays thumbnail, title, subtitle, genre tag, LIVE badge (for TV),
/// and optional viewer count. Uses lazy-loading with fade-in animation.
class MediaContentCard extends StatelessWidget {
  const MediaContentCard({
    super.key,
    required this.content,
    this.onTap,
    this.onLongPress,
    this.width,
    this.height,
    this.showViewerCount = true,
    this.showProgress = true,
  });

  /// The media content to display
  final UnifiedMediaContent content;

  /// Callback when card is tapped
  final VoidCallback? onTap;

  /// Callback when card is long-pressed
  final VoidCallback? onLongPress;

  /// Optional fixed width
  final double? width;

  /// Optional fixed height
  final double? height;

  /// Whether to show viewer count for live TV
  final bool showViewerCount;

  /// Whether to show progress indicator for resumable content
  final bool showProgress;

  /// Animation duration for thumbnail fade-in
  static const Duration fadeInDuration = Duration(milliseconds: 200);

  /// Minimum touch target size for accessibility
  static const double minTouchTarget = 44.0;

  /// Default card aspect ratio (16:9 for thumbnail + info)
  static const double aspectRatio = 0.75;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      height: height,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail with badges
              Expanded(flex: 3, child: _buildThumbnail(theme)),
              // Content info
              Expanded(flex: 2, child: _buildInfo(theme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(ThemeData theme) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Thumbnail image with lazy loading
        _buildThumbnailImage(theme),

        // Gradient overlay for better text visibility
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 40,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.6),
                ],
              ),
            ),
          ),
        ),

        // LIVE badge for TV content
        if (content.isLive)
          Positioned(top: 8, left: 8, child: _buildLiveBadge()),

        // Viewer count for live TV
        if (content.isLive && showViewerCount && content.viewerCount != null)
          Positioned(top: 8, right: 8, child: _buildViewerCount(theme)),

        // Duration badge for non-live content
        if (!content.isLive && content.duration != null)
          Positioned(bottom: 8, right: 8, child: _buildDurationBadge(theme)),

        // Progress indicator for resumable content
        if (showProgress && content.canResume)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildProgressIndicator(theme),
          ),
      ],
    );
  }

  Widget _buildThumbnailImage(ThemeData theme) {
    if (content.thumbnailUrl == null || content.thumbnailUrl!.isEmpty) {
      return _buildPlaceholder(theme);
    }

    return CachedNetworkImage(
      imageUrl: content.thumbnailUrl!,
      fit: BoxFit.cover,
      fadeInDuration: fadeInDuration,
      placeholder: (context, url) => _buildLoadingSkeleton(theme),
      errorWidget: (context, url, error) => _buildPlaceholder(theme),
    );
  }

  Widget _buildLoadingSkeleton(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: theme.colorScheme.primary.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          content.type == MediaMode.tv ? Icons.live_tv : Icons.music_note,
          size: 48,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          semanticLabel: content.type == MediaMode.tv
              ? 'TV content'
              : 'Music content',
        ),
      ),
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'LIVE',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildViewerCount(ThemeData theme) {
    final count = content.viewerCount!;
    final displayCount = count >= 1000
        ? '${(count / 1000).toStringAsFixed(1)}K'
        : count.toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.visibility, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            displayCount,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationBadge(ThemeData theme) {
    final duration = content.duration!;
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final displayDuration = minutes > 0
        ? '$minutes:${seconds.toString().padLeft(2, '0')}'
        : '0:${seconds.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        displayDuration,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(ThemeData theme) {
    return LinearProgressIndicator(
      value: content.progress,
      minHeight: 3,
      backgroundColor: Colors.black.withValues(alpha: 0.3),
      valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
    );
  }

  Widget _buildInfo(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            content.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          // Subtitle (artist/group)
          if (content.subtitle != null)
            Text(
              content.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const Spacer(),
          // Genre tag
          if (content.category != null || content.tags.isNotEmpty)
            _buildGenreTag(theme),
        ],
      ),
    );
  }

  Widget _buildGenreTag(ThemeData theme) {
    final tagText =
        content.category?.label ??
        (content.tags.isNotEmpty ? content.tags.first : null);
    if (tagText == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        tagText,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
