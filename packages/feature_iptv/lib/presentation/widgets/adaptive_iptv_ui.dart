import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import "package:platform_channels/platform_channels.dart";
import "package:platform_player/platform_player.dart";
import "package:platform_media/platform_media.dart";
import '../tv/iptv_tv.dart';
import 'channel_list_widget.dart';
import 'tv_channel_grid.dart';
import 'tv_player_controls.dart';
import 'video_player_widget.dart';

/// Adaptive IPTV UI that renders TV or mobile UI based on device type
///
/// On Android TV/Fire TV:
/// - Uses [TvChannelGrid] for channel selection (grid layout)
/// - Uses [TvPlayerControls] for video player controls
/// - D-pad navigation enabled throughout
///
/// On mobile/tablet:
/// - Uses [ChannelListWidget] for channel selection (list layout)
/// - Uses standard [VideoPlayerWidget] controls
/// - Touch-based interaction
class AdaptiveIptvUI extends ConsumerWidget {
  final Function(IPTVChannel) onChannelSelect;
  final VoidCallback? onFullscreenToggle;

  const AdaptiveIptvUI({
    super.key,
    required this.onChannelSelect,
    this.onFullscreenToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTv = ref.watch(isTvModeProvider(context));

    if (isTv) {
      return TvChannelGrid(onChannelSelect: onChannelSelect);
    }

    return ChannelListWidget(
      onChannelTap: onChannelSelect,
      showCategories: true,
    );
  }
}

/// Adaptive player controls that render TV or mobile UI
///
/// On TV: Uses [TvPlayerControls] with D-pad support
/// On mobile: Uses standard player controls from [VideoPlayerWidget]
class AdaptivePlayerControls extends ConsumerWidget {
  final VideoPlayerStreamingService service;
  final StreamingState state;
  final VoidCallback? onFullscreenToggle;

  const AdaptivePlayerControls({
    super.key,
    required this.service,
    required this.state,
    this.onFullscreenToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTv = ref.watch(isTvModeProvider(context));

    if (isTv) {
      return TvPlayerControls(
        service: service,
        state: state,
        onFullscreenToggle: onFullscreenToggle,
      );
    }

    // Mobile uses the standard VideoPlayerWidget controls
    // This widget is designed to be used within VideoPlayerWidget's existing overlay
    // Return null/empty to let VideoPlayerWidget use its built-in controls
    return const SizedBox.shrink();
  }
}

/// Mixin to add TV awareness to IPTV screens
mixin TvAwareMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// Check if currently on TV
  bool get isTvMode => ref.watch(isTvModeProvider(context));

  /// Get TV UI dimensions (or mobile defaults)
  TvUiDimensions get tvDimensions => ref.watch(tvDimensionsProvider(context));

  /// Get the TV focus manager
  TvFocusManager get tvFocusManager => ref.watch(tvFocusManagerProvider);

  /// Save focus state for later restoration
  void saveTvFocusState({
    required String screenId,
    String? itemId,
    int? index,
  }) {
    if (isTvMode) {
      tvFocusManager.saveFocusState(
        screenId: screenId,
        itemId: itemId,
        index: index,
      );
    }
  }

  /// Restore focus state if available
  FocusMemoryEntry? getTvFocusState(String screenId) {
    if (isTvMode) {
      return tvFocusManager.getFocusState(screenId);
    }
    return null;
  }
}
