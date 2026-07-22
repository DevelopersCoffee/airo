import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_ui/core_ui.dart';
import '../../application/player_backgrounding_coordinator.dart';
import '../../application/providers/iptv_providers.dart';
import '../../application/wakelock_playback_coordinator.dart';
import '../../application/providers/rails_provider.dart';
import "package:platform_channels/platform_channels.dart";
import "package:platform_player/platform_player.dart";
import '../widgets/adaptive_iptv_sheet.dart';
import '../widgets/cast_device_picker_sheet.dart';
import '../widgets/channel_list_widget.dart';
import '../widgets/iptv_cast_mini_controller.dart';
import '../widgets/iptv_mini_player.dart';
import '../widgets/iptv_navigation_drawer.dart';
import '../widgets/phone_media_play_on_tv_sheet.dart';
import '../widgets/video_player_widget.dart';
import '../tv/iptv_guide_screen.dart';
import '../tv_ux/iptv_resume_gate.dart';
import 'browse_screen.dart';
import 'mobile_favorites_screen.dart';

/// IPTV Screen with YouTube-like streaming experience
class IPTVScreen extends ConsumerStatefulWidget {
  const IPTVScreen({
    this.onOpenVod,
    this.onPickLocalMediaForTv,
    this.deepLinkChannelId,
    super.key,
  });

  /// Invoked when the user taps the "Movies & Shows" action to navigate to
  /// the VOD screen. Left as an optional callback (rather than a direct
  /// `go_router` dependency) so this feature package doesn't need to depend
  /// on the app's routing package; the app wires this in when constructing
  /// [IPTVScreen] for the `/iptv` route (see [IptvGuideScreen.onChannelSelected]
  /// for the same pattern).
  final VoidCallback? onOpenVod;

  /// CV-033 debug entry point: resolves a phone-local file into a
  /// [PhoneLocalMediaItem], or null if the user cancelled. Left as an
  /// optional callback so this package doesn't depend on `file_picker`; the
  /// app wires this in only for debug builds while the end-user surface for
  /// "Play on TV" is undecided. Null hides the drawer entry entirely.
  final Future<PhoneLocalMediaItem?> Function()? onPickLocalMediaForTv;

  /// Channel id resolved from a deep link (universal link, home-screen
  /// widget, or "continue watching" notification tap) or the app's
  /// resume-last-channel affordance. When set, playback starts immediately
  /// in [initState] instead of waiting for a tap on the browse grid, and
  /// the browse grid is not the first frame rendered.
  final String? deepLinkChannelId;

  @override
  ConsumerState<IPTVScreen> createState() => _IPTVScreenState();
}

class _IPTVScreenState extends ConsumerState<IPTVScreen>
    with WidgetsBindingObserver {
  /// True while a [IPTVScreen.deepLinkChannelId] is set and its resolution
  /// (in the post-frame callback below) hasn't yet either started playback
  /// or determined the channel doesn't exist. Gates the first frame so the
  /// browse grid never flashes before deep-linked playback begins.
  late bool _deepLinkPending = widget.deepLinkChannelId != null;

  /// True once the user has tapped Cancel on the deep-link loading screen.
  /// Sticky for the lifetime of this deep-link attempt: unlike
  /// [_deepLinkPending] (a transient UI flag), this must not be undone by a
  /// later event, so the in-flight resolution in [initState]'s post-frame
  /// callback can check it after its `await` resolves and refuse to act on
  /// a channel that arrives after the user already backed out.
  bool _deepLinkCancelled = false;

  /// Android PiP shrinks the whole activity by default. Keep this screen's
  /// presentation state in sync with the native callback so the PiP window
  /// contains only the active video rather than the app bar and browse UI.
  bool _isPictureInPicture = false;

  @override
  void initState() {
    super.initState();
    // Initialize streaming service
    ref.read(iptvStreamingServiceProvider).initialize();
    // Screen-level wakelock: survives the featured player widget being
    // scrolled out of the viewport or playback moving to the mini player.
    ref.read(wakelockPlaybackCoordinatorProvider);
    // Decides PiP vs. audio-only when the app backgrounds during playback.
    ref.read(playerBackgroundingCoordinatorProvider);
    // Publishes playback state to the OS media session (media notification
    // + lock-screen controls) when the host supplies a delegate (#980).
    ref.read(tvIptvIntegrationProvider);
    // Feeds real app lifecycle transitions into appLifecycleStateProvider,
    // which playerBackgroundingCoordinatorProvider listens to above.
    WidgetsBinding.instance.addObserver(this);
    AiroNativePictureInPicture.setStateChangeHandler((isActive) {
      if (mounted) setState(() => _isPictureInPicture = isActive);
    });

    final deepLinkId = widget.deepLinkChannelId;
    if (deepLinkId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        // Await the channel list rather than reading its current `.value`:
        // the list is almost never loaded yet by the very next frame (it's
        // usually still an in-flight fetch), so a synchronous read would
        // treat every deep link as "channel not found" and immediately fall
        // through to the browse grid -- defeating the point of this gate.
        // A timeout guards against the future hanging forever (e.g. a
        // stalled playlist fetch), which would otherwise strand the user on
        // the bare loading screen with no way to reach the grid.
        IPTVChannel? channel;
        try {
          final channels = await ref
              .read(iptvChannelsProvider.future)
              .timeout(const Duration(seconds: 10));
          channel = channels.firstWhereOrNull((c) => c.id == deepLinkId);
        } catch (e) {
          // Covers both a genuine provider error and a timeout — either
          // way this falls through to "channel not found" below. Logged so
          // a real provider failure is distinguishable from a normal miss.
          debugPrint('[IPTVScreen] deep-link channel resolution failed: $e');
          channel = null;
        }
        if (!mounted) return;
        // The user may have tapped Cancel while the await above was still
        // pending — that must be a permanent decision for this deep-link
        // attempt, not just a transient UI state a late-arriving match can
        // override. Without this check, a channel resolving after Cancel
        // would still flip into fullscreen playback on the next rebuild.
        if (_deepLinkCancelled) return;
        if (channel != null) {
          // Pre-seed fullscreen mode for this one-shot transition into
          // playback; after this, showFullscreenPlayer only tracks
          // isFullscreenModeProvider like any other playback, so the
          // player's own minimize/fullscreen toggle works normally.
          ref.read(isFullscreenModeProvider.notifier).state = true;
          _playChannel(channel);
          setState(() => _deepLinkPending = false);
        } else {
          // Missing (or unresolvable) channel: fall through to the normal
          // browse-grid landing (spec Error Handling) — no snackbar wiring
          // needed here since the grid is the existing default UI, not a
          // special error state.
          setState(() => _deepLinkPending = false);
        }
      });
    }
  }

  /// Cancels a pending deep-link resolution and falls back to the browse
  /// grid immediately — the escape hatch shown on the loading screen so a
  /// user is never stuck waiting on a slow/hung channel-list fetch.
  void _cancelDeepLinkWait() {
    _deepLinkCancelled = true;
    setState(() => _deepLinkPending = false);
  }

  @override
  void dispose() {
    // Don't reset orientation here - it causes issues during widget rebuilds
    // Orientation is reset in:
    // 1. _toggleFullscreen() when user explicitly exits fullscreen
    // 2. AppShell when navigating to a different tab
    WidgetsBinding.instance.removeObserver(this);
    AiroNativePictureInPicture.setStateChangeHandler(null);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(appLifecycleStateProvider.notifier).state = state;
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

  Future<void> _playLocalFileOnTv() async {
    final picker = widget.onPickLocalMediaForTv;
    if (picker == null) return;

    final item = await picker();
    if (item == null || !mounted) return;

    final handoff = PhoneMediaCastHandoff(
      castController: ref.read(airoCastControllerProvider),
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          PhoneMediaPlayOnTvSheet(item: item, handoff: handoff),
    );
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
                    onSubmitted: (value) {
                      // Submitting applies the filter and keeps the results
                      // list visible — playback stays behind an explicit
                      // result tap or the Play button so users can browse
                      // matches first.
                      ref.read(channelSearchQueryProvider.notifier).state =
                          value.trim();
                    },
                  ),
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final query = ref.watch(channelSearchQueryProvider);
                    if (query.trim().isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final matches = ref.watch(filteredChannelsProvider);
                    if (matches.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text('No channels match "$query"'),
                      );
                    }
                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: matches.length,
                        itemBuilder: (context, index) {
                          final channel = matches[index];
                          return ListTile(
                            leading: const Icon(Icons.live_tv),
                            title: Text(
                              channel.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              channel.group,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              _playChannel(channel);
                              Navigator.of(context).pop();
                            },
                          );
                        },
                      ),
                    );
                  },
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

  Future<void> _openGuide() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => IptvGuideScreen(
          onChannelSelected: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  Future<void> _openFavorites() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MobileFavoritesScreen(
          onChannelSelected: () => Navigator.of(context).pop(),
        ),
      ),
    );
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
    final isPlaying =
        ref.watch(streamingStateProvider).value?.isPlaying == true;

    if (_isPictureInPicture) {
      return AiroResponsiveScaffold(
        padding: EdgeInsets.zero,
        backgroundColor: Colors.black,
        body: VideoPlayerWidget(
          showControls: true,
          onFullscreenToggle: _toggleFullscreen,
        ),
      );
    }

    // A deep link is "pending" until its resolution (in initState's
    // post-frame callback) either starts playback or determines the
    // channel doesn't exist (which clears _deepLinkPending). While
    // pending, the browse grid must never be the first frame rendered.
    final isWaitingForDeepLink =
        widget.deepLinkChannelId != null && _deepLinkPending && !isPlaying;

    if (isWaitingForDeepLink) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              // Escape hatch: the user must never be stuck here indefinitely
              // even before the 10s timeout in initState fires.
              TextButton.icon(
                onPressed: _cancelDeepLinkWait,
                icon: const Icon(Icons.close),
                label: const Text('Cancel'),
              ),
            ],
          ),
        ),
      );
    }

    // showFullscreenPlayer just tracks isFullscreenModeProvider like any
    // other playback. The deep-link path pre-seeds that provider to `true`
    // the moment playback starts (see initState's post-frame callback)
    // instead of overriding this calculation permanently — otherwise the
    // player's own minimize/fullscreen-toggle button would never be able
    // to take a deep-linked channel back to the browse grid.
    final showFullscreenPlayer = isFullscreen;

    // System PiP: the floating window IS the whole app window, so render
    // only the video surface — no app bar, drawer, headers, or controls —
    // like YouTube/Netflix PiP (#1002). Playback continues uninterrupted:
    // the streaming service is provider-scoped, not widget-scoped, and the
    // bare widget re-attaches to the same engine's video view (same swap
    // the fullscreen toggle already does).
    if (ref.watch(pictureInPictureActiveProvider)) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.expand(child: VideoPlayerWidget(showControls: false)),
      );
    }

    if (showFullscreenPlayer) {
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
      drawer: IptvNavigationDrawer(
        showMovies: widget.onOpenVod != null,
        onHome: () {},
        onGuide: _openGuide,
        onMovies: () => widget.onOpenVod?.call(),
        onFavorites: _openFavorites,
        onPlayLocalFileOnTv: widget.onPickLocalMediaForTv == null
            ? null
            : _playLocalFileOnTv,
      ),
      appBar: AppBar(
        title: const Text('Airo TV'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search channels',
            onPressed: _showSearchSheet,
          ),
          if (widget.onOpenVod != null)
            IconButton(
              icon: const Icon(Icons.movie_outlined),
              tooltip: 'Movies & Shows',
              onPressed: widget.onOpenVod,
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
      body: IptvResumeGate(
        child: Column(
          children: [
            Expanded(
              child: _StreamTabContent(
                key: const ValueKey('iptv-browse-grid'),
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
    // Screen-level wakelock: survives the featured player widget being
    // scrolled out of the viewport or playback moving to the mini player.
    ref.read(wakelockPlaybackCoordinatorProvider);
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
    super.key,
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
    final hasActiveChannel =
        streamingState.asData?.value.currentChannel != null;

    if (channels.isEmpty) {
      return _BringYourOwnPlaylistView(
        onPlaylistSourceTap: onPlaylistSourceTap,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Expanded(
          child: isWideScreen
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasActiveChannel)
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
                      flex: hasActiveChannel ? 2 : 1,
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: hasActiveChannel ? 8 : 16,
                          right: 16,
                        ),
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
                          if (hasActiveChannel) ...[
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: _FeaturedPlayerPanel(
                                  streamingState: streamingState,
                                  onFullscreenToggle: onFullscreenToggle,
                                  buildQualityDropdown: (state) =>
                                      _buildQualityDropdown(
                                        context,
                                        ref,
                                        state,
                                      ),
                                ),
                              ),
                            ),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 12),
                            ),
                          ],
                          SliverFillRemaining(
                            hasScrollBody: true,
                            child: BrowseScreen(
                              onChannelSelected: onChannelTap,
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
  StreamSubscription<ImportProgress>? _importSubscription;
  ImportProgress? _importProgress;

  @override
  void initState() {
    super.initState();
    final parser = ref.read(m3uParserProvider);
    _controller = TextEditingController(text: parser.getPlaylistUrl() ?? '');
  }

  @override
  void dispose() {
    _importSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// True while a staged import is running (i.e. we're between the initial
  /// `import_` emission and either `ready` — which closes the sheet — or
  /// `failed`, which surfaces the retry panel and re-enables the form).
  bool get _isImporting =>
      _importProgress != null && _importProgress!.stage != ImportStage.failed;

  Future<void> _save() async {
    final parser = ref.read(m3uParserProvider);
    try {
      await parser.setPlaylistUrl(_controller.text);
    } on ArgumentError catch (error) {
      setState(() => _errorText = error.message.toString());
      return;
    }
    setState(() => _errorText = null);
    ref.invalidate(userPlaylistUrlProvider);
    _startImport();
  }

  /// Kicks off (or retries) the real production import — Task 11's
  /// [M3UParserService.fetchPlaylistWithProgress] — and renders each staged
  /// [ImportProgress] emission as it arrives (spec §4.4/§8).
  void _startImport() {
    _importSubscription?.cancel();
    final parser = ref.read(m3uParserProvider);
    setState(() {
      _importProgress = const ImportProgress(
        stage: ImportStage.import_,
        message: 'Starting playlist import',
      );
    });
    _importSubscription = parser
        .fetchPlaylistWithProgress(forceRefresh: true)
        .listen(_onImportProgress, onError: _onImportError);
  }

  void _onImportProgress(ImportProgress progress) {
    if (!mounted) return;
    setState(() => _importProgress = progress);
    if (progress.stage == ImportStage.ready) {
      // The staged import already persisted the new channels; refresh both
      // the channel list and the derived rails so BrowseScreen picks them
      // up immediately instead of waiting for the next cold read.
      ref.invalidate(iptvChannelsProvider);
      ref.invalidate(railsProvider);
      Navigator.of(context).pop();
    }
  }

  void _onImportError(Object error, StackTrace stackTrace) {
    if (!mounted) return;
    setState(() {
      _importProgress = ImportProgress(stage: ImportStage.failed, error: error);
    });
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
    final importing = _isImporting;

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
              'Add Playlist Source',
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
                enabled: !importing,
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
            if (!keyboardVisible) ...[
              const SizedBox(height: 12),
              _PlaylistSourceInfoCallout(),
            ],
            if (_importProgress != null) ...[
              const SizedBox(height: 12),
              _ImportProgressPanel(
                progress: _importProgress!,
                onRetry: _startImport,
              ),
            ],
            const SizedBox(height: 12),
            OverflowBar(
              alignment: MainAxisAlignment.spaceBetween,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: 8,
              overflowSpacing: 8,
              children: [
                TextButton(
                  onPressed: importing ? null : _remove,
                  child: const Text('Remove'),
                ),
                OverflowBar(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    FilledButton.icon(
                      onPressed: importing ? null : _save,
                      icon: const Icon(Icons.check),
                      label: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Staged-import progress (Task 11's [ImportProgress] stream) rendered
/// inside the playlist-source sheet: a stage label + progress bar while
/// importing, or a stage-specific error with a Retry action once the
/// pipeline reports [ImportStage.failed] (spec §8).
///
/// [ImportProgress.fraction] is emitted as a binary 0/1 per-stage signal
/// by [M3UParserService.fetchPlaylistWithProgress] (each stage is either
/// "not started" at its default `0.0` or "done" at `1`), not a continuous
/// value — so this renders an indeterminate bar rather than
/// `LinearProgressIndicator(value: progress.fraction)`, which would jump
/// between empty and full on every stage transition instead of animating
/// smoothly.
class _ImportProgressPanel extends StatelessWidget {
  const _ImportProgressPanel({required this.progress, required this.onRetry});

  final ImportProgress progress;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (progress.stage == ImportStage.failed) {
      final error = progress.error;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withValues(alpha: 0.28),
          border: Border.all(color: colorScheme.error.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, size: 16, color: colorScheme.error),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      error == null ? 'Import failed' : 'Import failed: $error',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onErrorContainer,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _importStageLabel(progress),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        const ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(4)),
          child: LinearProgressIndicator(minHeight: 4),
        ),
      ],
    );
  }
}

/// Human-readable label for an in-flight [ImportProgress] emission. Prefers
/// the stage's own [ImportProgress.message] (several stages already report
/// friendly copy, e.g. "Downloading playlist"); falls back to a per-stage
/// label for the stages that emit no message (deduplicate/indexing/
/// generateRails/persist — see `fetchPlaylistWithProgress`).
String _importStageLabel(ImportProgress progress) {
  final message = progress.message;
  if (message != null && message.isNotEmpty) {
    return message;
  }
  switch (progress.stage) {
    case ImportStage.import_:
      return 'Starting import…';
    case ImportStage.validate:
      return 'Validating playlist URL…';
    case ImportStage.download:
      return 'Downloading playlist…';
    case ImportStage.parse:
      return 'Parsing playlist…';
    case ImportStage.normalize:
      return 'Normalizing channels…';
    case ImportStage.deduplicate:
      return 'Removing duplicate channels…';
    case ImportStage.indexing:
      return 'Indexing channels…';
    case ImportStage.generateRails:
      return 'Building smart rails…';
    case ImportStage.persist:
      return 'Saving…';
    case ImportStage.ready:
      return 'Ready';
    case ImportStage.failed:
      return 'Import failed';
  }
}

/// Reassurance callout in the playlist-source sheet — matches the design
/// handoff's modal copy: "Airo TV will deduplicate channels, prune dead
/// links, and build smart rails."
class _PlaylistSourceInfoCallout extends StatelessWidget {
  const _PlaylistSourceInfoCallout();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.28),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 16, color: colorScheme.primary),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'Airo TV will deduplicate channels, prune dead links, and '
                'build smart rails.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
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
    if (streamingState.asData?.value.currentChannel == null) {
      return const SizedBox.shrink();
    }

    final player = AspectRatio(
      aspectRatio: 16 / 9,
      child: VideoPlayerWidget(
        showControls: true,
        onFullscreenToggle: onFullscreenToggle,
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
              if (boundedHeight) Flexible(fit: FlexFit.loose, child: player),
              if (!boundedHeight) player,
              const SizedBox(height: 12),
              streamingState.when(
                data: (state) {
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
