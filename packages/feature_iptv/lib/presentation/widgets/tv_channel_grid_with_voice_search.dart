import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/tv/tv.dart';
import "package:platform_channels/platform_channels.dart";
import 'tv_channel_grid.dart';
import 'voice_search_overlay.dart';

/// TV Channel Grid with integrated voice search support for Fire TV
///
/// This widget wraps [TvChannelGrid] and adds voice search overlay support.
/// When the Fire TV voice button is pressed, the voice search overlay appears
/// and the recognized speech is used to filter channels.
///
/// Usage:
/// ```dart
/// TvChannelGridWithVoiceSearch(
///   onChannelSelect: (channel) => _playChannel(channel),
/// )
/// ```
class TvChannelGridWithVoiceSearch extends ConsumerStatefulWidget {
  /// Callback when a channel is selected
  final Function(IPTVChannel) onChannelSelect;

  /// Initial channel to focus
  final String? initialFocusChannelId;

  /// Grid configuration for lazy loading
  final TvChannelGridConfig config;

  const TvChannelGridWithVoiceSearch({
    super.key,
    required this.onChannelSelect,
    this.initialFocusChannelId,
    this.config = const TvChannelGridConfig(),
  });

  @override
  ConsumerState<TvChannelGridWithVoiceSearch> createState() =>
      _TvChannelGridWithVoiceSearchState();
}

class _TvChannelGridWithVoiceSearchState
    extends ConsumerState<TvChannelGridWithVoiceSearch> {
  bool _showVoiceSearchOverlay = false;

  void _handleVoiceSearch() {
    setState(() {
      _showVoiceSearchOverlay = true;
    });
  }

  void _hideVoiceSearchOverlay() {
    setState(() {
      _showVoiceSearchOverlay = false;
    });
  }

  TvInputResult _handleTvInput(TvInputKey key) {
    if (key == TvInputKey.voiceSearch) {
      _handleVoiceSearch();
      return TvInputResult.handled;
    }
    return TvInputResult.notHandled;
  }

  @override
  Widget build(BuildContext context) {
    return TvInputHandler(
      onInput: _handleTvInput,
      child: Stack(
        children: [
          // Main channel grid
          TvChannelGrid(
            onChannelSelect: widget.onChannelSelect,
            initialFocusChannelId: widget.initialFocusChannelId,
            config: widget.config,
          ),

          // Voice search overlay
          if (_showVoiceSearchOverlay)
            VoiceSearchOverlay(
              onDismiss: _hideVoiceSearchOverlay,
              onSearchComplete: (query) {
                // Overlay will update channelSearchQueryProvider
                // and then dismiss itself
              },
            ),
        ],
      ),
    );
  }
}

/// Mixin for adding voice search capability to any TV widget
///
/// Add this mixin to a StatefulWidget that needs voice search support:
/// ```dart
/// class MyTvWidget extends ConsumerStatefulWidget {
///   @override
///   ConsumerState<MyTvWidget> createState() => _MyTvWidgetState();
/// }
///
/// class _MyTvWidgetState extends ConsumerState<MyTvWidget>
///     with TvVoiceSearchMixin {
///   @override
///   Widget build(BuildContext context) {
///     return buildWithVoiceSearch(
///       context,
///       child: MyContent(),
///     );
///   }
/// }
/// ```
mixin TvVoiceSearchMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool _voiceSearchVisible = false;

  /// Whether voice search overlay is currently visible
  bool get isVoiceSearchVisible => _voiceSearchVisible;

  /// Show the voice search overlay
  void showVoiceSearch() {
    setState(() {
      _voiceSearchVisible = true;
    });
  }

  /// Hide the voice search overlay
  void hideVoiceSearch() {
    setState(() {
      _voiceSearchVisible = false;
    });
  }

  /// Handle TV input, returning true if voice search was triggered
  bool handleVoiceSearchInput(TvInputKey key) {
    if (key == TvInputKey.voiceSearch) {
      showVoiceSearch();
      return true;
    }
    return false;
  }

  /// Build widget with voice search overlay support
  Widget buildWithVoiceSearch(BuildContext context, {required Widget child}) {
    return Stack(
      children: [
        child,
        if (_voiceSearchVisible) VoiceSearchOverlay(onDismiss: hideVoiceSearch),
      ],
    );
  }
}
