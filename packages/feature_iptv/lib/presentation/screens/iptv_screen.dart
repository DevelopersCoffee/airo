import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/iptv_providers.dart';
import "package:platform_channels/platform_channels.dart";
import "package:platform_player/platform_player.dart";
import '../widgets/cast_device_picker_sheet.dart';
import '../widgets/channel_list_widget.dart';
import '../widgets/iptv_cast_mini_controller.dart';
import '../widgets/iptv_mini_player.dart';
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
    final castState = ref.read(iptvCastProvider);
    if (castState.activeDevice != null) {
      ref
          .read(iptvCastProvider.notifier)
          .castChannelToActiveDevice(
            channel: channel,
            selectedQuality: ref
                .read(iptvStreamingServiceProvider)
                .currentState
                .selectedQuality,
          );
      ref.read(addToRecentlyWatchedProvider(channel));
      return;
    }

    ref.read(iptvStreamingServiceProvider).playChannel(channel);
    // Track recently watched for easy access
    ref.read(addToRecentlyWatchedProvider(channel));
  }

  Future<void> _showSearchSheet() async {
    final controller = TextEditingController(
      text: ref.read(channelSearchQueryProvider),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              12,
              24,
              24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Search channels',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text('Find live channels by name or group.'),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'News, sports, music...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              controller.clear();
                              ref
                                      .read(channelSearchQueryProvider.notifier)
                                      .state =
                                  '';
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) =>
                      ref.read(channelSearchQueryProvider.notifier).state =
                          value,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        controller.clear();
                        ref.read(channelSearchQueryProvider.notifier).state =
                            '';
                      },
                      child: const Text('Clear'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCastSheet() async {
    final streamingService = ref.read(iptvStreamingServiceProvider);
    final channel = streamingService.currentState.currentChannel;
    if (channel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a channel before casting.')),
      );
      return;
    }

    await showIptvCastDevicePicker(
      context: context,
      onDeviceSelected: (device) {
        ref
            .read(iptvCastProvider.notifier)
            .castChannelToDevice(
              channel: channel,
              device: device,
              selectedQuality: streamingService.currentState.selectedQuality,
            );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFullscreen = ref.watch(isFullscreenModeProvider);

    // Hand playback off cleanly between the device and the TV. Without this the
    // local player keeps running while casting, so the same stream plays on
    // both the iPad and the TV slightly out of sync -- heard as muddy, unclear
    // TV audio. Pause local playback while a Cast session is active; resume it
    // when casting ends.
    ref.listen<bool>(iptvCastProvider.select((state) => state.isCasting), (
      wasCasting,
      isCasting,
    ) {
      final streaming = ref.read(iptvStreamingServiceProvider);
      if (isCasting) {
        streaming.pause();
      } else if (wasCasting == true) {
        streaming.resume();
      }
    });

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
        title: const Text('Stream'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search channels',
            onPressed: _showSearchSheet,
          ),
          IconButton(
            icon: const Icon(Icons.cast_connected),
            tooltip: 'Cast',
            onPressed: _showCastSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _StreamTabContent(
              onChannelTap: _playChannel,
              onFullscreenToggle: _toggleFullscreen,
            ),
          ),
          const IptvCastMiniController(),
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
    final castState = ref.read(iptvCastProvider);
    if (castState.activeDevice != null) {
      ref
          .read(iptvCastProvider.notifier)
          .castChannelToActiveDevice(
            channel: channel,
            selectedQuality: ref
                .read(iptvStreamingServiceProvider)
                .currentState
                .selectedQuality,
          );
      return;
    }

    ref.read(iptvStreamingServiceProvider).playChannel(channel);
  }

  @override
  Widget build(BuildContext context) {
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
              child: Column(
                children: [
                  Expanded(
                    child: _StreamTabContent(
                      onChannelTap: _playChannel,
                      onFullscreenToggle: _toggleFullscreen,
                    ),
                  ),
                  const IptvCastMiniController(),
                ],
              ),
            ),
    );
  }
}

class _StreamTabContent extends ConsumerWidget {
  const _StreamTabContent({
    required this.onChannelTap,
    required this.onFullscreenToggle,
  });

  final ValueChanged<IPTVChannel> onChannelTap;
  final VoidCallback onFullscreenToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelsAsync = ref.watch(iptvChannelsProvider);
    final streamingState = ref.watch(streamingStateProvider);

    return channelsAsync.when(
      data: (channels) => _buildContent(context, ref, channels, streamingState),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildError(context, ref, error.toString()),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<IPTVChannel> channels,
    AsyncValue<StreamingState> streamingState,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 800;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const _PrimaryCategoryBar(),
        const SizedBox(height: 12),
        Expanded(
          child: isWideScreen
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16, right: 8),
                        child: _FeaturedPlayerPanel(
                          streamingState: streamingState,
                          onFullscreenToggle: onFullscreenToggle,
                          buildQualityDropdown: (state) =>
                              _buildQualityDropdown(context, ref, state),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8, right: 16),
                        child: _ChannelPanel(
                          channels: channels,
                          onChannelTap: onChannelTap,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Expanded(
                      child: CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: _FeaturedPlayerPanel(
                                streamingState: streamingState,
                                onFullscreenToggle: onFullscreenToggle,
                                buildQualityDropdown: (state) =>
                                    _buildQualityDropdown(context, ref, state),
                              ),
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 12)),
                          SliverFillRemaining(
                            hasScrollBody: true,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: _ChannelPanel(
                                channels: channels,
                                onChannelTap: onChannelTap,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildQualityDropdown(
    BuildContext context,
    WidgetRef ref,
    StreamingState state,
  ) {
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

  Widget _buildError(BuildContext context, WidgetRef ref, String message) {
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

class _PrimaryCategoryBar extends ConsumerWidget {
  const _PrimaryCategoryBar();

  static const _categories = [
    ChannelCategory.all,
    ChannelCategory.news,
    ChannelCategory.sports,
    ChannelCategory.entertainment,
    ChannelCategory.music,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final counts = ref.watch(categoryCounts);

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = _categories[index];
          return ChoiceChip(
            label: Text('${category.label} (${counts[category] ?? 0})'),
            selected: selectedCategory == category,
            onSelected: (_) =>
                ref.read(selectedCategoryProvider.notifier).state = category,
          );
        },
      ),
    );
  }
}

class _FeaturedPlayerPanel extends StatelessWidget {
  const _FeaturedPlayerPanel({
    required this.streamingState,
    required this.onFullscreenToggle,
    required this.buildQualityDropdown,
  });

  final AsyncValue<StreamingState> streamingState;
  final VoidCallback onFullscreenToggle;
  final Widget Function(StreamingState state) buildQualityDropdown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Featured Player', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Jump straight into live news, sports, entertainment, and music.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: streamingState.when(
              data: (state) => state.currentChannel != null
                  ? VideoPlayerWidget(
                      showControls: true,
                      onFullscreenToggle: onFullscreenToggle,
                    )
                  : const _PlayerPlaceholder(),
              loading: () => const _PlayerPlaceholder(),
              error: (_, _) => const _PlayerPlaceholder(),
            ),
          ),
          const SizedBox(height: 12),
          streamingState.when(
            data: (state) {
              if (state.currentChannel == null) {
                return const Text('Choose a live channel to begin streaming.');
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          state.currentChannel!.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      buildQualityDropdown(state),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    state.currentChannel!.group,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  const IPTVMiniPlayer(forceVisible: true),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _ChannelPanel extends ConsumerWidget {
  const _ChannelPanel({required this.channels, required this.onChannelTap});

  final List<IPTVChannel> channels;
  final ValueChanged<IPTVChannel> onChannelTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(channelSearchQueryProvider);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live Channels',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  searchQuery.isEmpty
                      ? '${channels.length} channels ready'
                      : 'Showing results for "$searchQuery"',
                ),
              ],
            ),
          ),
          Expanded(
            child: ChannelListWidget(
              onChannelTap: onChannelTap,
              showCategories: false,
              showSearchBar: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerPlaceholder extends StatelessWidget {
  const _PlayerPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.42),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.live_tv,
              size: 64,
              color: colorScheme.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Select a channel to start watching',
              style: TextStyle(
                color: colorScheme.primary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
