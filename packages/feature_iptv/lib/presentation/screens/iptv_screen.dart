import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:core_ui/core_ui.dart';
import '../../application/providers/iptv_providers.dart';
import "package:platform_channels/platform_channels.dart";
import "package:platform_player/platform_player.dart";
import '../widgets/adaptive_iptv_sheet.dart';
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

  Future<bool> _playNaturalLanguageQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    try {
      final resolution = await ref
          .read(edgeIptvAssistantProvider)
          .resolveNaturalLanguage(trimmed);
      final channel = resolution.channel;
      if (channel == null) {
        if (mounted && resolution.message != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(resolution.message!)));
        }
        return false;
      }

      _playChannel(channel);
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not play: $error')));
      }
      return false;
    }
  }

  Future<bool> _playSearchAction(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    ref.read(channelSearchQueryProvider.notifier).state = trimmed;
    final filteredChannels = ref.read(filteredChannelsProvider);
    if (filteredChannels.length == 1) {
      _playChannel(filteredChannels.single);
      return true;
    }

    return _playNaturalLanguageQuery(trimmed);
  }

  Future<void> _showSearchSheet() async {
    final controller = TextEditingController(
      text: ref.read(channelSearchQueryProvider),
    );

    await showAdaptiveIptvSheet<void>(
      context: context,
      maxWidth: 600,
      builder: (context) {
        final viewInsets = MediaQuery.of(context).viewInsets;
        final size = MediaQuery.sizeOf(context);
        final isDialogSheet = size.width >= 720;
        final keyboardVisible = viewInsets.bottom > 0;
        final keyboardInset = isDialogSheet ? 0.0 : viewInsets.bottom;
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              keyboardVisible ? 6 : 12,
              20,
              (keyboardVisible ? 12 : 24) + keyboardInset,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Search channels',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (!keyboardVisible) ...[
                  const SizedBox(height: 8),
                  const Text('Find live channels by name, group, or request.'),
                ],
                const SizedBox(height: 12),
                Semantics(
                  label: 'Search channels',
                  textField: true,
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Channel or request',
                      hintText: 'Music India or Aaj Tak',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: controller.text.isNotEmpty
                          ? IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                controller.clear();
                                ref
                                        .read(
                                          channelSearchQueryProvider.notifier,
                                        )
                                        .state =
                                    '';
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) =>
                        ref.read(channelSearchQueryProvider.notifier).state =
                            value,
                    onSubmitted: (value) async {
                      final played = await _playSearchAction(value);
                      if (!context.mounted) return;
                      if (played) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
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
                    FilledButton.icon(
                      onPressed: () async {
                        final played = await _playSearchAction(controller.text);
                        if (!context.mounted) return;
                        if (played) {
                          Navigator.of(context).pop();
                        }
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Play'),
                    ),
                    const SizedBox(width: 8),
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
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cast is available in the mobile app.')),
      );
      return;
    }

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

  Future<void> _showPlaylistSheet() async {
    await showPlaylistSourceSheet(context, ref);
  }

  void _syncLocalPlaybackWithCast(bool? wasCasting, bool isCasting) {
    final streaming = ref.read(iptvStreamingServiceProvider);
    if (isCasting) {
      streaming.pause();
    } else if (wasCasting == true) {
      streaming.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      iptvCastProvider.select((state) => state.isCasting),
      _syncLocalPlaybackWithCast,
    );
    final isFullscreen = ref.watch(isFullscreenModeProvider);

    if (isFullscreen) {
      return AiroResponsiveScaffold(
        padding: EdgeInsets.zero,
        backgroundColor: Colors.black,
        body: VideoPlayerWidget(
          showControls: true,
          onFullscreenToggle: _toggleFullscreen,
        ),
      );
    }

    return AiroResponsiveScaffold(
      padding: EdgeInsets.zero,
      appBar: AppBar(
        title: const Text('Stream'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search channels',
            onPressed: _showSearchSheet,
          ),
          IconButton(
            icon: const Icon(Icons.link),
            tooltip: 'Playlist source',
            onPressed: _showPlaylistSheet,
          ),
          if (!kIsWeb)
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
              onPlaylistSourceTap: _showPlaylistSheet,
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

  Future<void> _showPlaylistSheet() async {
    await showPlaylistSourceSheet(context, ref);
  }

  void _syncLocalPlaybackWithCast(bool? wasCasting, bool isCasting) {
    final streaming = ref.read(iptvStreamingServiceProvider);
    if (isCasting) {
      streaming.pause();
    } else if (wasCasting == true) {
      streaming.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      iptvCastProvider.select((state) => state.isCasting),
      _syncLocalPlaybackWithCast,
    );
    final isFullscreen = ref.watch(isFullscreenModeProvider);

    // Use AnimatedSwitcher with fade to black for seamless fullscreen transition
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) {
        // Fade transition with black background to prevent channel list flash
        return FadeTransition(opacity: animation, child: child);
      },
      child: isFullscreen
          ? AiroResponsiveScaffold(
              key: const ValueKey('fullscreen'),
              padding: EdgeInsets.zero,
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
                      onPlaylistSourceTap: _showPlaylistSheet,
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
    required this.onPlaylistSourceTap,
  });

  final ValueChanged<IPTVChannel> onChannelTap;
  final VoidCallback onFullscreenToggle;
  final VoidCallback onPlaylistSourceTap;

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

    if (channels.isEmpty) {
      return _BringYourOwnPlaylistView(
        onPlaylistSourceTap: onPlaylistSourceTap,
      );
    }

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
      tooltip: 'Playback quality',
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
      child: Semantics(
        button: true,
        label: 'Playback quality ${state.currentQuality.label}',
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

Future<void> showPlaylistSourceSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  await showAdaptiveIptvSheet<void>(
    context: context,
    maxWidth: 640,
    builder: (_) => const _PlaylistSourceSheet(),
  );
}

class _PlaylistSourceSheet extends ConsumerStatefulWidget {
  const _PlaylistSourceSheet();

  @override
  ConsumerState<_PlaylistSourceSheet> createState() =>
      _PlaylistSourceSheetState();
}

class _PlaylistSourceSheetState extends ConsumerState<_PlaylistSourceSheet> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final parser = ref.read(m3uParserProvider);
    _controller = TextEditingController(text: parser.getPlaylistUrl() ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final parser = ref.read(m3uParserProvider);
    try {
      await parser.setPlaylistUrl(_controller.text);
      ref.invalidate(userPlaylistUrlProvider);
      ref.invalidate(iptvChannelsProvider);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on ArgumentError catch (error) {
      setState(() => _errorText = error.message.toString());
    }
  }

  Future<void> _remove() async {
    final parser = ref.read(m3uParserProvider);
    await parser.clearPlaylist();
    ref.invalidate(userPlaylistUrlProvider);
    ref.invalidate(iptvChannelsProvider);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final size = MediaQuery.sizeOf(context);
    final isDialogSheet = size.width >= 720;
    final keyboardVisible = viewInsets.bottom > 0;
    final keyboardInset = isDialogSheet ? 0.0 : viewInsets.bottom;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          keyboardVisible ? 6 : 12,
          20,
          (keyboardVisible ? 12 : 24) + keyboardInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Playlist source',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (!keyboardVisible) ...[
              const SizedBox(height: 8),
              const Text(
                'Add an M3U playlist URL for content you are authorized to use.',
              ),
            ],
            const SizedBox(height: 12),
            Semantics(
              label: 'M3U playlist URL',
              textField: true,
              child: TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'M3U playlist URL',
                  hintText: 'https://example.com/playlist.m3u',
                  prefixIcon: const Icon(Icons.link),
                  errorText: _errorText,
                ),
                onSubmitted: (_) => _save(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(onPressed: _remove, child: const Text('Remove')),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BringYourOwnPlaylistView extends StatelessWidget {
  const _BringYourOwnPlaylistView({required this.onPlaylistSourceTap});

  final VoidCallback onPlaylistSourceTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final placeholderHeight = constraints.maxHeight < 560 ? 180.0 : 240.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SizedBox(
                height: placeholderHeight,
                width: double.infinity,
                child: const _PlayerPlaceholder(
                  message: 'Add a playlist to start watching',
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Add your playlist',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Airo is a media player. It does not provide channels, playlists, or program guide data. Add an M3U URL for media you own or are authorized to watch.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: onPlaylistSourceTap,
                  icon: const Icon(Icons.link),
                  label: const Text('Add playlist URL'),
                ),
              ),
            ],
          ),
        );
      },
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
    final player = AspectRatio(
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
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final boundedHeight = constraints.hasBoundedHeight;

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
                'Play media from your saved playlist.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (boundedHeight) Flexible(fit: FlexFit.loose, child: player),
              if (!boundedHeight) player,
              const SizedBox(height: 12),
              streamingState.when(
                data: (state) {
                  if (state.currentChannel == null) {
                    return const Text(
                      'Choose a channel from your playlist to begin streaming.',
                    );
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
      },
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
                  'Playlist Channels',
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
  const _PlayerPlaceholder({
    this.message = 'Select a channel to start watching',
  });

  final String message;

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
              message,
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
