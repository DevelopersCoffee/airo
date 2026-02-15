import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/iptv_providers.dart';
import '../../domain/models/iptv_channel.dart';
import '../../domain/models/streaming_state.dart';
import '../widgets/channel_list_widget.dart';
import '../widgets/video_player_widget.dart';

/// IPTV Screen with YouTube-like streaming experience
class IPTVScreen extends ConsumerStatefulWidget {
  const IPTVScreen({super.key});

  @override
  ConsumerState<IPTVScreen> createState() => _IPTVScreenState();
}

class _IPTVScreenState extends ConsumerState<IPTVScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize streaming service
    ref.read(iptvStreamingServiceProvider).initialize();
  }

  @override
  void dispose() {
    // Don't reset orientation here - it causes issues during widget rebuilds
    // Orientation is reset in:
    // 1. _toggleFullscreen() when user explicitly exits fullscreen
    // 2. AppShell when navigating to a different tab
    super.dispose();
  }

  void _toggleFullscreen() {
    final isFullscreen = ref.read(isFullscreenModeProvider);
    ref.read(isFullscreenModeProvider.notifier).state = !isFullscreen;

    if (!isFullscreen) {
      // Entering fullscreen
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      // Exiting fullscreen
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  void _playChannel(IPTVChannel channel) {
    ref.read(iptvStreamingServiceProvider).playChannel(channel);
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(iptvChannelsProvider);
    final streamingState = ref.watch(streamingStateProvider);
    final isFullscreen = ref.watch(isFullscreenModeProvider);

    if (isFullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: VideoPlayerWidget(
          showControls: true,
          onFullscreenToggle: _toggleFullscreen,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('IPTV'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(iptvChannelsProvider),
            tooltip: 'Refresh channels',
          ),
        ],
      ),
      body: channelsAsync.when(
        data: (channels) => _buildContent(context, channels, streamingState),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildError(error.toString()),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<IPTVChannel> channels,
    AsyncValue<StreamingState> streamingState,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 800;

    if (isWideScreen) {
      // Web/Desktop: Side-by-side layout
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Video player and info - constrain width and align to top
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Video player section with constrained height
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: streamingState.when(
                        data: (state) => state.currentChannel != null
                            ? VideoPlayerWidget(
                                showControls: true,
                                onFullscreenToggle: _toggleFullscreen,
                              )
                            : _buildPlayerPlaceholder(),
                        loading: () => _buildPlayerPlaceholder(),
                        error: (_, _) => _buildPlayerPlaceholder(),
                      ),
                    ),
                  ),
                  // Quality selector and info bar
                  _buildInfoBar(streamingState),
                ],
              ),
            ),
          ),
          // Right: Channel list
          Expanded(
            flex: 2,
            child: ChannelListWidget(
              onChannelTap: _playChannel,
              showCategories: true,
            ),
          ),
        ],
      );
    }

    // Mobile: Vertical layout
    return Column(
      children: [
        // Video player section
        AspectRatio(
          aspectRatio: 16 / 9,
          child: streamingState.when(
            data: (state) => state.currentChannel != null
                ? VideoPlayerWidget(
                    showControls: true,
                    onFullscreenToggle: _toggleFullscreen,
                  )
                : _buildPlayerPlaceholder(),
            loading: () => _buildPlayerPlaceholder(),
            error: (_, _) => _buildPlayerPlaceholder(),
          ),
        ),

        // Quality selector and info bar
        _buildInfoBar(streamingState),

        // Channel list
        Expanded(
          child: ChannelListWidget(
            onChannelTap: _playChannel,
            showCategories: true,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blueGrey.shade800, Colors.blueGrey.shade900],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.live_tv,
              size: 64,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Select a channel to start watching',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBar(AsyncValue<StreamingState> streamingState) {
    return streamingState.when(
      data: (state) {
        if (state.currentChannel == null) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey[100],
          child: Row(
            children: [
              Expanded(
                child: Text(
                  state.currentChannel!.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildQualityDropdown(state),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildQualityDropdown(StreamingState state) {
    return PopupMenuButton<VideoQuality>(
      initialValue: state.selectedQuality,
      onSelected: (quality) {
        ref.read(iptvStreamingServiceProvider).setQuality(quality);
      },
      itemBuilder: (context) => VideoQuality.values
          .map(
            (q) => PopupMenuItem(
              value: q,
              child: Row(
                children: [
                  if (q == state.selectedQuality)
                    const Icon(Icons.check, size: 16)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 8),
                  Text(q.label),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              state.currentQuality.label,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref.refresh(iptvChannelsProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// IPTV Screen body content (without AppBar) for embedding in MediaHubScreen
class IPTVScreenBody extends ConsumerStatefulWidget {
  const IPTVScreenBody({super.key});

  @override
  ConsumerState<IPTVScreenBody> createState() => _IPTVScreenBodyState();
}

class _IPTVScreenBodyState extends ConsumerState<IPTVScreenBody> {
  @override
  void initState() {
    super.initState();
    // Initialize streaming service
    ref.read(iptvStreamingServiceProvider).initialize();
  }

  @override
  void dispose() {
    // Don't reset orientation here - it causes issues during widget rebuilds
    // Orientation is reset in:
    // 1. _toggleFullscreen() when user explicitly exits fullscreen
    // 2. AppShell when navigating to a different tab
    super.dispose();
  }

  void _toggleFullscreen() {
    final isFullscreen = ref.read(isFullscreenModeProvider);
    ref.read(isFullscreenModeProvider.notifier).state = !isFullscreen;

    if (!isFullscreen) {
      // Entering fullscreen
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      // Exiting fullscreen
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  void _playChannel(IPTVChannel channel) {
    ref.read(iptvStreamingServiceProvider).playChannel(channel);
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(iptvChannelsProvider);
    final streamingState = ref.watch(streamingStateProvider);
    final isFullscreen = ref.watch(isFullscreenModeProvider);

    // Use AnimatedSwitcher with fade to black for seamless fullscreen transition
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) {
        // Fade transition with black background to prevent channel list flash
        return FadeTransition(opacity: animation, child: child);
      },
      child: isFullscreen
          ? Scaffold(
              key: const ValueKey('fullscreen'),
              backgroundColor: Colors.black,
              body: VideoPlayerWidget(
                showControls: true,
                onFullscreenToggle: _toggleFullscreen,
                enableSwipeChannelChange: true,
              ),
            )
          : KeyedSubtree(
              key: const ValueKey('normal'),
              child: channelsAsync.when(
                data: (channels) =>
                    _buildContent(context, channels, streamingState),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => _buildError(error.toString()),
              ),
            ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<IPTVChannel> channels,
    AsyncValue<StreamingState> streamingState,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 800;

    if (isWideScreen) {
      // Web/Desktop: Side-by-side layout
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Video player and info - constrain width and align to top
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Video player section with constrained height
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: streamingState.when(
                        data: (state) => state.currentChannel != null
                            ? VideoPlayerWidget(
                                showControls: true,
                                onFullscreenToggle: _toggleFullscreen,
                              )
                            : _buildPlayerPlaceholder(),
                        loading: () => _buildPlayerPlaceholder(),
                        error: (_, _) => _buildPlayerPlaceholder(),
                      ),
                    ),
                  ),
                  // Quality selector and info bar
                  _buildInfoBar(streamingState),
                ],
              ),
            ),
          ),
          // Right: Channel list
          Expanded(
            flex: 2,
            child: ChannelListWidget(
              onChannelTap: _playChannel,
              showCategories: true,
            ),
          ),
        ],
      );
    }

    // Mobile: Vertical layout - always show channel list
    return Column(
      children: [
        // Video player section
        AspectRatio(
          aspectRatio: 16 / 9,
          child: streamingState.when(
            data: (state) => state.currentChannel != null
                ? VideoPlayerWidget(
                    showControls: true,
                    onFullscreenToggle: _toggleFullscreen,
                  )
                : _buildPlayerPlaceholder(),
            loading: () => _buildPlayerPlaceholder(),
            error: (_, _) => _buildPlayerPlaceholder(),
          ),
        ),

        // Quality selector and info bar
        _buildInfoBar(streamingState),

        // Channel list - always visible
        Expanded(
          child: ChannelListWidget(
            onChannelTap: _playChannel,
            showCategories: true,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blueGrey.shade800, Colors.blueGrey.shade900],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.live_tv,
              size: 64,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Select a channel to start watching',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBar(AsyncValue<StreamingState> streamingState) {
    return streamingState.when(
      data: (state) {
        if (state.currentChannel == null) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey[100],
          child: Row(
            children: [
              Expanded(
                child: Text(
                  state.currentChannel!.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildQualityDropdown(state),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildQualityDropdown(StreamingState state) {
    return PopupMenuButton<VideoQuality>(
      initialValue: state.selectedQuality,
      onSelected: (quality) {
        ref.read(iptvStreamingServiceProvider).setQuality(quality);
      },
      itemBuilder: (context) => VideoQuality.values
          .map(
            (q) => PopupMenuItem(
              value: q,
              child: Row(
                children: [
                  if (q == state.selectedQuality)
                    const Icon(Icons.check, size: 16)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 8),
                  Text(q.label),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              state.currentQuality.label,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref.refresh(iptvChannelsProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
