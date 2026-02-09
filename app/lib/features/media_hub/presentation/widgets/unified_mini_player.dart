import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../iptv/application/providers/iptv_providers.dart';
import '../../application/providers/unified_player_provider.dart';
import '../../domain/models/media_mode.dart';
import '../../domain/models/unified_player_state.dart';
import '../utils/media_hub_animations.dart';
import '../../../../shared/widgets/responsive_center.dart';

/// Unified mini player bar for both Music and TV content.
///
/// Features:
/// - Shows when content is playing and not on Media Hub
/// - Displays: Thumbnail, Title, Play/Pause, Next
/// - Tap expands to full player
/// - Height: 64px mobile, 72px tablet
/// - Respects safe areas (iOS/Android)
class UnifiedMiniPlayer extends ConsumerWidget {
  const UnifiedMiniPlayer({super.key});

  static const double mobileHeight = 64.0;
  static const double tabletHeight = 72.0;
  static const double minTouchTarget = 44.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(unifiedPlayerProvider);
    final currentTab = ref.watch(currentNavigationTabProvider);

    // Media tab is at index 2
    const mediaTabIndex = 2;
    final isOnMediaTab = currentTab == mediaTabIndex;

    // Don't show if no content or on Media tab
    if (!playerState.hasContent || isOnMediaTab) {
      return const SizedBox.shrink();
    }

    final isTablet =
        ResponsiveBreakpoints.isTablet(context) ||
        ResponsiveBreakpoints.isDesktop(context);
    final height = isTablet ? tabletHeight : mobileHeight;

    return SafeArea(
      top: false,
      child: PressableScale(
        onTap: () {
          // Navigate to Media tab
          ref.read(currentNavigationTabProvider.notifier).state = mediaTabIndex;
          context.go('/media');
        },
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Thumbnail
              _buildThumbnail(context, playerState, height),

              // Content info
              Expanded(child: _buildContentInfo(context, playerState)),

              // Controls
              _buildControls(context, ref, playerState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(
    BuildContext context,
    UnifiedPlayerState playerState,
    double height,
  ) {
    final content = playerState.currentContent!;
    final theme = Theme.of(context);

    return Container(
      width: height,
      height: height,
      color: theme.colorScheme.surfaceContainerHighest,
      child: content.thumbnailUrl != null
          ? FadeInWidget(
              child: Image.network(
                content.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildPlaceholderIcon(context, content.type),
              ),
            )
          : _buildPlaceholderIcon(context, content.type),
    );
  }

  Widget _buildPlaceholderIcon(BuildContext context, MediaMode type) {
    return Center(
      child: Icon(
        type.icon,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: 28,
      ),
    );
  }

  Widget _buildContentInfo(
    BuildContext context,
    UnifiedPlayerState playerState,
  ) {
    final content = playerState.currentContent!;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            content.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (content.subtitle != null)
            Text(
              content.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControls(
    BuildContext context,
    WidgetRef ref,
    UnifiedPlayerState playerState,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Play/Pause button
        _PlayPauseButton(playerState: playerState),
        const SizedBox(width: 4),
        // Next button (only for music with queue)
        if (playerState.isMusic && playerState.hasNext)
          _NextButton(playerState: playerState),
        // Close button
        _CloseButton(playerState: playerState),
        const SizedBox(width: 8),
      ],
    );
  }
}

/// Play/Pause button with loading state.
class _PlayPauseButton extends ConsumerWidget {
  const _PlayPauseButton({required this.playerState});

  final UnifiedPlayerState playerState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = playerState.isLoading || playerState.isBuffering;
    final isPlaying = playerState.isPlaying;

    return Semantics(
      label: isPlaying ? 'Pause' : 'Play',
      button: true,
      child: SizedBox(
        width: UnifiedMiniPlayer.minTouchTarget,
        height: UnifiedMiniPlayer.minTouchTarget,
        child: PressableScale(
          onTap: () => _handleTap(ref),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                : Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 32,
                  ),
          ),
        ),
      ),
    );
  }

  void _handleTap(WidgetRef ref) {
    MediaHubAnimations.lightHaptic();
    final notifier = ref.read(unifiedPlayerProvider.notifier);
    if (playerState.isPlaying) {
      notifier.pause();
    } else {
      notifier.resume();
    }
  }
}

/// Next track button (music only).
class _NextButton extends ConsumerWidget {
  const _NextButton({required this.playerState});

  final UnifiedPlayerState playerState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      label: 'Next track',
      button: true,
      child: SizedBox(
        width: UnifiedMiniPlayer.minTouchTarget,
        height: UnifiedMiniPlayer.minTouchTarget,
        child: PressableScale(
          onTap: () => _handleTap(ref),
          child: Center(
            child: Icon(
              Icons.skip_next_rounded,
              color: Theme.of(context).colorScheme.onSurface,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  void _handleTap(WidgetRef ref) {
    MediaHubAnimations.lightHaptic();
    ref.read(unifiedPlayerProvider.notifier).playNext();
  }
}

/// Close/Stop button.
class _CloseButton extends ConsumerWidget {
  const _CloseButton({required this.playerState});

  final UnifiedPlayerState playerState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      label: 'Close player',
      button: true,
      child: SizedBox(
        width: UnifiedMiniPlayer.minTouchTarget,
        height: UnifiedMiniPlayer.minTouchTarget,
        child: PressableScale(
          onTap: () => _handleTap(ref),
          child: Center(
            child: Icon(
              Icons.close_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  void _handleTap(WidgetRef ref) {
    MediaHubAnimations.lightHaptic();
    ref.read(unifiedPlayerProvider.notifier).stop();
  }
}
