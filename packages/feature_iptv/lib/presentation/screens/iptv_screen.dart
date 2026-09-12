import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_ui/core_ui.dart';
import '../../application/iptv_deep_link.dart';
import '../../application/player_backgrounding_coordinator.dart';
import '../../application/providers/channel_filters_provider.dart';
import '../../application/providers/iptv_providers.dart';
import '../../application/providers/multiview_provider.dart'
    show multiviewDecoderBudgetProvider, multiviewProvider, MultiviewState;
import '../../application/wakelock_playback_coordinator.dart';
import '../tv_ux/sections/bottom_nav_bar.dart';
import '../tv_ux/sections/multiview_layout_picker.dart';
import '../tv_ux/sections/multiview_stage.dart';
import '../tv_ux/sections/shell_help_dialog.dart';
import '../tv_ux/sections/shell_settings_dialog.dart';
import "package:platform_channels/platform_channels.dart";
import "package:platform_media/platform_media.dart";
import "package:platform_player/platform_player.dart";
import '../widgets/adaptive_iptv_sheet.dart';
import '../widgets/cast_device_picker_sheet.dart';
import '../widgets/iptv_cast_mini_controller.dart';
import '../widgets/offline_playback_banner.dart';
import '../widgets/phone_media_play_on_tv_sheet.dart';
import '../widgets/playlist_source_manager_sheet.dart';
import '../widgets/tv_playlist_qr_dialog.dart';
import '../widgets/video_player_widget.dart';
import '../widgets/xmltv_source_sheet.dart';
import '../tv_ux/airo_tv_shell.dart';
import '../tv_ux/iptv_resume_gate.dart';
import '../tv_ux/sections/ways_to_watch_dialog.dart';
import 'cast_multiview_screen.dart';
import '../tv_ux/tv_loading_screen.dart';
import 'mobile_favorites_screen.dart';
import 'shared_channel_import_screen.dart';

/// IPTV Screen with YouTube-like streaming experience
class IPTVScreen extends ConsumerStatefulWidget {
  const IPTVScreen({
    this.onOpenVod,
    this.onSettings,
    this.onPickLocalMediaForTv,
    this.deepLinkIntent,
    this.deepLinkChannelId,
    this.onShareVideoFrame,
    this.tenFootMode = false,
    super.key,
  });

  /// When true (a detected TV behind the app's TvShell sidebar), the phone
  /// chrome — app bar, bottom nav, cast entry — is suppressed: the sidebar
  /// already owns navigation, TVs are receivers not cast senders, and
  /// browse-level actions live in the 10-foot shell itself. Touch devices
  /// keep the full phone chrome.
  final bool tenFootMode;

  /// Invoked when the user taps the "Movies & Shows" entry in the "My Aika"
  /// sheet to navigate to the VOD screen. Left as an optional callback
  /// (rather than a direct `go_router` dependency) so this feature package
  /// doesn't need to depend on the app's routing package; the app wires this
  /// in when constructing [IPTVScreen] for the `/iptv` route.
  final VoidCallback? onOpenVod;

  /// Invoked when the "My Aika" sheet's Settings entry is tapped. App-owned
  /// because the feature package does not depend on go_router or app routes.
  final VoidCallback? onSettings;

  /// Resolves a phone-local file into a [PhoneLocalMediaItem], or null if the
  /// user cancelled. Left as an optional callback so this package does not
  /// depend on `file_picker`; the host app owns the native file-picker wiring.
  final Future<PhoneLocalMediaItem?> Function()? onPickLocalMediaForTv;

  /// Parsed link intent supplied by the host router. Includes the channel and
  /// optional Explorer filters without coupling this package to go_router.
  final IptvDeepLinkIntent? deepLinkIntent;

  /// Host-owned image delivery for frame-only screenshots.
  final Future<void> Function(Uint8List pngBytes)? onShareVideoFrame;

  /// Channel id resolved from a deep link (universal link, home-screen
  /// widget, or "continue watching" notification tap) or the app's
  /// resume-last-channel affordance. When set, playback starts immediately
  /// in [initState] instead of waiting for a tap on the browse grid, and
  /// the browse grid is not the first frame rendered.
  final String? deepLinkChannelId;

  String? get effectiveDeepLinkChannelId =>
      deepLinkIntent?.channelId ?? deepLinkChannelId;

  @override
  ConsumerState<IPTVScreen> createState() => _IPTVScreenState();
}

class _IPTVScreenState extends ConsumerState<IPTVScreen>
    with WidgetsBindingObserver {
  final FocusNode _fullscreenFocusNode = FocusNode(
    debugLabel: 'IPTV fullscreen back handler',
  );
  DateTime? _lastFullscreenBackAt;
  Timer? _macosFullscreenSyncTimer;

  /// True while local playback is paused because [_syncLocalPlaybackWithCast]
  /// paused it for a device that can't sustain a second concurrent decoder.
  /// Only set true by that guard, so ending the cast session resumes local
  /// playback solely when this guard was the one that paused it.
  bool _localPausedForCast = false;

  /// True once the cast-session default mute (see [_playChannel]) has been
  /// applied for the current cast session, so switching local channels
  /// mid-session doesn't re-mute a stream the user explicitly unmuted.
  bool _mutedDefaultAppliedForCast = false;

  /// Guards the postFrameCallback below to fire once per fullscreen entry,
  /// not on every rebuild. Live playback rebuilds constantly (buffering,
  /// position, cast state); requesting focus on every one of those was
  /// yanking focus back to this Back-only node from the player's own
  /// TvInputHandler after it had already (correctly) taken over, leaving
  /// every D-pad key except Back permanently dead in fullscreen.
  bool _fullscreenFocusClaimed = false;

  /// True while a [IPTVScreen.deepLinkChannelId] is set and its resolution
  /// (in the post-frame callback below) hasn't yet either started playback
  /// or determined the channel doesn't exist. Gates the first frame so the
  /// browse grid never flashes before deep-linked playback begins.
  late bool _deepLinkPending = widget.effectiveDeepLinkChannelId != null;
  late bool _sharedImportPending = widget.deepLinkIntent?.canImport ?? false;

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
    AiroNativeFullscreen.setMacosFullscreenExitHandler(
      _handleNativeFullscreenExit,
    );
    AiroNativeFullscreen.setMacosFullscreenEnterHandler(
      _handleNativeFullscreenEnter,
    );
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_synchronizeMacosFullscreenState());
      });
      _macosFullscreenSyncTimer = Timer(
        const Duration(milliseconds: 750),
        () => unawaited(_synchronizeMacosFullscreenState()),
      );
    }

    final deepLinkId = widget.effectiveDeepLinkChannelId;
    if (deepLinkId != null && !_sharedImportPending) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final deepLinkFilters = widget.deepLinkIntent?.filters;
        if (deepLinkFilters != null) {
          ref.read(channelFiltersProvider.notifier).restore(deepLinkFilters);
        }
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
          setState(() => _deepLinkPending = false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text(
                    'That shared channel is no longer available. Browse to choose another.',
                  ),
                ),
              );
          });
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

  IPTVChannel _buildSharedChannel() {
    final intent = widget.deepLinkIntent!;
    return ref
        .read(personalChannelRepositoryProvider)
        .buildChannel(
          name: intent.channelName!,
          streamUrl: intent.streamUrl.toString(),
        );
  }

  void _playSharedChannelOnce() {
    final channel = _buildSharedChannel();
    ref.read(isFullscreenModeProvider.notifier).state = true;
    _playChannel(channel);
    setState(() {
      _sharedImportPending = false;
      _deepLinkPending = false;
    });
  }

  Future<void> _saveAndPlaySharedChannel() async {
    final intent = widget.deepLinkIntent!;
    final channel = await ref
        .read(personalChannelRepositoryProvider)
        .upsert(
          name: intent.channelName!,
          streamUrl: intent.streamUrl.toString(),
        );
    ref.invalidate(personalChannelsProvider);
    ref.invalidate(iptvChannelsProvider);
    if (!mounted) return;
    ref.read(isFullscreenModeProvider.notifier).state = true;
    _playChannel(channel);
    setState(() {
      _sharedImportPending = false;
      _deepLinkPending = false;
    });
  }

  void _cancelSharedChannelImport() {
    _deepLinkCancelled = true;
    setState(() {
      _sharedImportPending = false;
      _deepLinkPending = false;
    });
  }

  @override
  void dispose() {
    // Don't reset orientation here - it causes issues during widget rebuilds
    // Orientation is reset in:
    // 1. _toggleFullscreen() when user explicitly exits fullscreen
    // 2. AppShell when navigating to a different tab
    WidgetsBinding.instance.removeObserver(this);
    AiroNativeFullscreen.setMacosFullscreenExitHandler(null);
    AiroNativeFullscreen.setMacosFullscreenEnterHandler(null);
    _macosFullscreenSyncTimer?.cancel();
    unawaited(AiroNativeFullscreen.exitMacosFullscreen());
    _fullscreenFocusNode.dispose();
    AiroNativePictureInPicture.setStateChangeHandler(null);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(appLifecycleStateProvider.notifier).state = state;
  }

  @override
  Future<bool> didPopRoute() async {
    if (ref.read(isFullscreenModeProvider)) {
      _lastFullscreenBackAt = DateTime.now();
      _exitFullscreen();
      return true;
    }
    final lastFullscreenBackAt = _lastFullscreenBackAt;
    if (lastFullscreenBackAt != null &&
        (widget.tenFootMode ||
            DateTime.now().difference(lastFullscreenBackAt) <
                const Duration(seconds: 1))) {
      // Fire OS can dispatch one remote BACK as two pop-route callbacks.
      // Consume the duplicate so returning to browse never closes the app.
      if (!widget.tenFootMode) {
        _lastFullscreenBackAt = null;
      }
      return true;
    }
    return false;
  }

  KeyEventResult _handleFullscreenKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !ref.read(isFullscreenModeProvider)) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    // Android/Fire OS also sends BACK through didPopRoute. Consuming GoBack
    // here exits fullscreen on key-down, then the platform pop-route closes
    // the newly exposed browse route. Escape remains useful for desktop/web;
    // Android BACK is handled exactly once by didPopRoute/PopScope.
    if (key == LogicalKeyboardKey.escape) {
      _exitFullscreen();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _handleNativeFullscreenExit() {
    _macosFullscreenSyncTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(isFullscreenModeProvider)) {
        _lastFullscreenBackAt = DateTime.now();
        _toggleFullscreen(updateNativeWindow: false);
      }
    });
  }

  void _handleNativeFullscreenEnter() {
    _macosFullscreenSyncTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !ref.read(isFullscreenModeProvider)) {
        _toggleFullscreen(updateNativeWindow: false);
      }
    });
  }

  Future<void> _synchronizeMacosFullscreenState() async {
    final nativeFullscreen = await AiroNativeFullscreen.isMacosFullscreen();
    if (!mounted) return;
    if (nativeFullscreen) {
      _macosFullscreenSyncTimer?.cancel();
    }
    final appFullscreen = ref.read(isFullscreenModeProvider);
    if (nativeFullscreen != appFullscreen) {
      _toggleFullscreen(updateNativeWindow: false);
    }
  }

  void _toggleFullscreen({bool updateNativeWindow = true}) {
    final isFullscreen = ref.read(isFullscreenModeProvider);
    ref.read(isFullscreenModeProvider.notifier).state = !isFullscreen;
    if (isFullscreen) {
      // Leaving fullscreen -- let the next entry claim focus fresh.
      _fullscreenFocusClaimed = false;
    }

    if (updateNativeWindow) {
      _macosFullscreenSyncTimer?.cancel();
      if (!isFullscreen) {
        unawaited(AiroNativeFullscreen.setMacosFullscreen(true));
      } else {
        unawaited(AiroNativeFullscreen.exitMacosFullscreen());
      }
    }

    // TV chrome is fixed: always landscape, always immersive (set once at
    // startup by the app's configureTvSystemChrome). The phone-style
    // portrait restore below rotated the whole Fire TV display to
    // 1080x1920 on fullscreen exit.
    if (widget.tenFootMode) return;

    if (!isFullscreen) {
      // Entering fullscreen
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      // Exiting fullscreen -- restore system-default orientation instead of
      // forcing portrait, so tablets/foldables already using landscape as
      // their default layout aren't rotated out of it.
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([]);
    }
  }

  void _exitFullscreen() {
    if (!ref.read(isFullscreenModeProvider)) return;
    _lastFullscreenBackAt = DateTime.now();
    _toggleFullscreen();
  }

  /// TV selection: open the full player directly. On a 10-foot UI the
  /// browse shell's small preview stage is a poor first playback surface —
  /// choosing a channel means "watch it now". Back returns to browse via
  /// the existing fullscreen back handling.
  void _playChannelFullscreen(IPTVChannel channel) {
    ref.read(isFullscreenModeProvider.notifier).state = true;
    _playChannel(channel);
  }

  /// A plain channel tap always targets the local player, whether or not a
  /// Cast session is active — casting a channel is now a separate, explicit
  /// action ([_showCastSheet]/[_showWaysToWatch]), not a side effect of
  /// tapping while connected. See #1047.
  void _playChannel(IPTVChannel channel) {
    final castState = ref.read(iptvCastProvider);
    if (castState.isCasting && !_canRunLocalWhileCasting()) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              "This device can't play a second stream while casting.",
            ),
          ),
        );
      return;
    }

    final streaming = ref.read(iptvStreamingServiceProvider);
    streaming.playChannel(channel);
    ref.read(addToRecentlyWatchedProvider(channel));
    _applyCastDefaultMuteIfNeeded(castState, streaming);
  }

  /// #829 has no admission-control API yet (deferred). Conservative static
  /// bound in the meantime: reuse the same per-platform decoder budget
  /// signal MultiView already sizes itself against — a second concurrent
  /// local decoder (this local stream, on top of the normal single-stream
  /// budget of 1) is only allowed on devices with headroom for at least 2.
  bool _canRunLocalWhileCasting() =>
      ref.read(multiviewDecoderBudgetProvider) >= 2;

  /// Default local playback to muted the first time it starts during a cast
  /// session, so the user isn't hearing two audio sources at once; the
  /// existing mute/unmute control is the explicit opt-out.
  void _applyCastDefaultMuteIfNeeded(
    IptvCastState castState,
    VideoPlayerStreamingService streaming,
  ) {
    if (!castState.isCasting || _mutedDefaultAppliedForCast) return;
    _mutedDefaultAppliedForCast = true;
    if (!streaming.currentState.isMuted) {
      streaming.toggleMute();
    }
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
    if (item == null) return;
    if (!mounted) {
      await item.sourceLease?.release();
      return;
    }

    final castController = ref.read(airoCastControllerProvider);
    final handoff = PhoneMediaCastHandoff(castController: castController);
    await showAdaptiveIptvSheet<void>(
      context: context,
      maxWidth: 600,
      builder: (context) => PhoneMediaPlayOnTvSheet(
        item: item,
        handoff: handoff,
        castController: castController,
      ),
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
    if (!isGoogleCastSenderPlatform) {
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

  Future<void> _showWaysToWatch() async {
    final pictureInPictureSupported =
        !widget.tenFootMode && await AiroNativePictureInPicture.isSupported();
    if (!mounted) return;

    if (!widget.tenFootMode && isGoogleCastSenderPlatform) {
      unawaited(ref.read(iptvCastProvider.notifier).startDiscovery());
    }

    await _showWaysToWatchDialog(
      context: context,
      pictureInPictureSupported: pictureInPictureSupported,
      showCast: !widget.tenFootMode,
      onExitFullscreen: _exitFullscreen,
      onEnterFullscreen: () {
        if (!ref.read(isFullscreenModeProvider)) _toggleFullscreen();
      },
      onShowCast: _showCastSheet,
      onShowCastMultiview: _showCastMultiviewScreen,
    );
  }

  void _showCastMultiviewScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CastMultiviewScreen()),
    );
  }

  Future<void> _showPlaylistSheet() async {
    await showPlaylistSourceSheet(context, ref);
  }

  Future<void> _showGuideSourceSheet() async {
    await showXmltvSourceSheet(context);
  }

  Future<void> _showQrPlaylist() async {
    final url = await showDialog<String>(
      context: context,
      builder: (_) => const TvPlaylistQrDialog(),
    );
    if (!mounted || url == null) return;
    await showPlaylistSourceSheet(context, ref, initialUrl: url);
  }

  /// The bottom nav's Home destination: returns the browse grid to its
  /// unfiltered state, mirroring the same "clear filters" affordance
  /// `_NoMatchesView` already exposes when a filter empties the results
  /// (see `airo_tv_shell.dart`'s identical `channelFiltersProvider.notifier
  /// .clear()` call).
  void _resetToTop() {
    ref.read(channelFiltersProvider.notifier).clear();
  }

  /// The bottom nav's "My Aika" destination: an overflow sheet for the
  /// destinations that used to live in the (now-deleted) hamburger drawer —
  /// Home and Guide are gone from the set (Home is now its own bottom-nav
  /// destination and Guide is not part of this revamp's navigation), but
  /// Settings, Movies & Shows, Favorites, and Play local file on TV keep
  /// the same conditional-null-hides-item visibility the drawer had.
  Future<void> _showMyAikaSheet() {
    return showAdaptiveIptvSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.onSettings != null)
              ListTile(
                key: const ValueKey('iptv-my-aika-settings'),
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  widget.onSettings?.call();
                },
              ),
            if (widget.onOpenVod != null)
              ListTile(
                key: const ValueKey('iptv-my-aika-movies'),
                leading: const Icon(Icons.movie_outlined),
                title: const Text('Movies & Shows'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  widget.onOpenVod?.call();
                },
              ),
            ListTile(
              key: const ValueKey('iptv-my-aika-favorites'),
              leading: const Icon(Icons.favorite_border),
              title: const Text('Favorites'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openFavorites();
              },
            ),
            if (widget.onPickLocalMediaForTv != null)
              ListTile(
                key: const ValueKey('iptv-my-aika-play-on-tv'),
                leading: const Icon(Icons.folder_open_outlined),
                title: const Text('Play local file on TV'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _playLocalFileOnTv();
                },
              ),
          ],
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

  /// Casting no longer unconditionally pauses local playback (#1047) — it
  /// only pauses when [_canRunLocalWhileCasting] says this device can't
  /// sustain the second decoder, and only resumes what it paused.
  void _syncLocalPlaybackWithCast(bool? wasCasting, bool isCasting) {
    final streaming = ref.read(iptvStreamingServiceProvider);
    if (isCasting) {
      if (_canRunLocalWhileCasting()) {
        _mutedDefaultAppliedForCast = true;
        if (!streaming.currentState.isMuted) {
          streaming.toggleMute();
        }
      } else {
        streaming.pause();
        _localPausedForCast = true;
      }
    } else {
      if (_localPausedForCast) {
        streaming.resume();
      }
      _localPausedForCast = false;
      _mutedDefaultAppliedForCast = false;
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
    Widget guardRouteBack(Widget child) {
      final lastFullscreenBackAt = _lastFullscreenBackAt;
      final suppressDuplicateBack =
          lastFullscreenBackAt != null &&
          (widget.tenFootMode ||
              DateTime.now().difference(lastFullscreenBackAt) <
                  const Duration(seconds: 1));
      final guardedChild =
          widget.tenFootMode && !isFullscreen && suppressDuplicateBack
          ? CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): () {
                  setState(() => _lastFullscreenBackAt = null);
                },
                const SingleActivator(LogicalKeyboardKey.goBack): () {
                  setState(() => _lastFullscreenBackAt = null);
                },
                const SingleActivator(LogicalKeyboardKey.browserBack): () {
                  setState(() => _lastFullscreenBackAt = null);
                },
              },
              child: child,
            )
          : child;
      return PopScope<void>(
        canPop: !isFullscreen && !suppressDuplicateBack,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          // On a ten-foot host the full-screen player owns BACK outright and
          // absorbs Fire OS's duplicate platform callbacks. Exiting here as
          // well would undo the raw key the player just handled. Blocking the
          // pop (canPop above) still keeps the callback from closing the app.
          if (isFullscreen && !widget.tenFootMode) {
            _exitFullscreen();
          } else if (suppressDuplicateBack && !widget.tenFootMode) {
            _lastFullscreenBackAt = null;
          }
        },
        child: guardedChild,
      );
    }

    if (_isPictureInPicture) {
      return guardRouteBack(
        AiroResponsiveScaffold(
          padding: EdgeInsets.zero,
          backgroundColor: Colors.black,
          body: VideoPlayerWidget(
            showControls: true,
            initiallyFullscreen: true,
            enableTouchGestures: !widget.tenFootMode,
            onFullscreenToggle: _toggleFullscreen,
          ),
        ),
      );
    }

    if (_sharedImportPending) {
      final intent = widget.deepLinkIntent!;
      return SharedChannelImportScreen(
        channelName: intent.channelName!,
        sourceHost: intent.streamUrl!.host,
        onSaveAndPlay: _saveAndPlaySharedChannel,
        onPlayOnce: _playSharedChannelOnce,
        onCancel: _cancelSharedChannelImport,
      );
    }

    // A deep link is "pending" until its resolution (in initState's
    // post-frame callback) either starts playback or determines the
    // channel doesn't exist (which clears _deepLinkPending). While
    // pending, the browse grid must never be the first frame rendered.
    final isWaitingForDeepLink =
        widget.effectiveDeepLinkChannelId != null &&
        _deepLinkPending &&
        !isPlaying;

    if (isWaitingForDeepLink) {
      return guardRouteBack(
        Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF05060F), Color(0xFF141B33)],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Starting channel...',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 32),
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
    final multiview = ref.watch(multiviewProvider);

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
      if (!_fullscreenFocusClaimed) {
        _fullscreenFocusClaimed = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && ref.read(isFullscreenModeProvider)) {
            _fullscreenFocusNode.requestFocus();
          }
        });
      }
      // MultiView sessions were being silently dropped on entering
      // fullscreen: this branch previously always rendered a single-channel
      // VideoPlayerWidget bound to the primary streaming service, which
      // multiview_provider.dart's toggle() pauses the moment a MultiView
      // session starts — so "activeChannel" itself is likely null here.
      // Render the same MultiviewStage the browse grid uses instead,
      // whenever there is a live session to show.
      final fullscreenBody = multiview.sessions.isNotEmpty
          ? _FullscreenMultiviewStage(
              multiview: multiview,
              onExit: _exitFullscreen,
            )
          : VideoPlayerWidget(
              showControls: true,
              initiallyFullscreen: true,
              handleNativeFullscreen: false,
              // Brightness/volume drag zones and the lock button are
              // touch-only concepts with no remote equivalent.
              enableTouchGestures: !widget.tenFootMode,
              // Only the ten-foot host hands BACK to the player, because only
              // Fire OS duplicates the platform half. On touch, guardRouteBack
              // below answers that pop; letting the player answer it too would
              // exit fullscreen and immediately re-enter it.
              ownsPlatformBack: widget.tenFootMode,
              // The guarded exit, not the raw toggle: it is a no-op once
              // fullscreen is already off, so a second handler does nothing.
              onBack: _exitFullscreen,
              onFullscreenToggle: _toggleFullscreen,
              enableSwipeChannelChange: true,
              // PiP is a phone/tablet multitasking action. Keep it out of
              // the remote-only Android TV and Fire TV player surfaces.
              showPictureInPicture: !widget.tenFootMode,
              useTvTransportBar: widget.tenFootMode,
              onOpenSettings: () => showAiroTvShellSettingsDialog(
                context,
                onPlaylistSourceTap: _showPlaylistSheet,
                onGuideSourceTap: _showGuideSourceSheet,
              ),
              onShowHelp: () => showAiroTvShellHelpDialog(context),
            );
      return guardRouteBack(
        Focus(
          focusNode: _fullscreenFocusNode,
          autofocus: true,
          onKeyEvent: _handleFullscreenKey,
          child: AiroResponsiveScaffold(
            padding: EdgeInsets.zero,
            backgroundColor: Colors.black,
            body: fullscreenBody,
          ),
        ),
      );
    }

    if (widget.tenFootMode) {
      return guardRouteBack(
        AiroResponsiveScaffold(
          padding: EdgeInsets.zero,
          body: IptvResumeGate(
            enabled: widget.effectiveDeepLinkChannelId == null,
            child: _StreamTabContent(
              key: const ValueKey('iptv-browse-grid'),
              onChannelTap: _playChannelFullscreen,
              onFullscreenToggle: _toggleFullscreen,
              onPlaylistSourceTap: _showPlaylistSheet,
              onGuideSourceTap: _showGuideSourceSheet,
              onScanWithPhoneTap: _showQrPlaylist,
              onWaysToWatchTap: _showWaysToWatch,
              onShareVideoFrame: widget.onShareVideoFrame,
              playlistSourceInInfoBar: true,
            ),
          ),
        ),
      );
    }

    return guardRouteBack(
      AiroResponsiveScaffold(
        padding: EdgeInsets.zero,
        appBar: AppBar(
          title: const Text('Aika Stream'),
          actions: [
            if (isGoogleCastSenderPlatform)
              IconButton(
                icon: const Icon(Icons.cast_connected),
                tooltip: 'Cast',
                onPressed: _showCastSheet,
              ),
          ],
        ),
        bottomNavigationBar: IptvBottomNavBar(
          onHome: _resetToTop,
          onSearch: _showSearchSheet,
          onMyAika: _showMyAikaSheet,
        ),
        body: IptvResumeGate(
          enabled: widget.effectiveDeepLinkChannelId == null,
          child: Column(
            children: [
              Expanded(
                child: _StreamTabContent(
                  key: const ValueKey('iptv-browse-grid'),
                  onChannelTap: _playChannel,
                  onFullscreenToggle: _toggleFullscreen,
                  onPlaylistSourceTap: _showPlaylistSheet,
                  onGuideSourceTap: _showGuideSourceSheet,
                  onScanWithPhoneTap: _showQrPlaylist,
                  onWaysToWatchTap: _showWaysToWatch,
                  onShareVideoFrame: widget.onShareVideoFrame,
                ),
              ),
              const IptvCastMiniController(),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showWaysToWatchDialog({
  required BuildContext context,
  required bool pictureInPictureSupported,
  required bool showCast,
  required VoidCallback onExitFullscreen,
  required VoidCallback onEnterFullscreen,
  required VoidCallback onShowCast,
  required VoidCallback onShowCastMultiview,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Consumer(
      builder: (context, dialogRef, _) {
        final castState = dialogRef.watch(iptvCastProvider);
        final castAvailable =
            isGoogleCastSenderPlatform &&
            castState.discovery.devices.isNotEmpty;
        return WaysToWatchDialog(
          pictureInPictureSupported: pictureInPictureSupported,
          showCast: showCast,
          castAvailable: castAvailable,
          onFitScreen: () {
            Navigator.of(dialogContext).pop();
            onExitFullscreen();
          },
          onFullScreen: () {
            Navigator.of(dialogContext).pop();
            onEnterFullscreen();
          },
          onPictureInPicture: () async {
            Navigator.of(dialogContext).pop();
            final entered = await AiroNativePictureInPicture.requestEnter();
            if (!context.mounted || entered) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Floating Window could not be started.'),
              ),
            );
          },
          onCast: () {
            Navigator.of(dialogContext).pop();
            onShowCast();
          },
          onCastMultiview: () {
            Navigator.of(dialogContext).pop();
            onShowCastMultiview();
          },
        );
      },
    ),
  );
}

/// IPTV Screen body content (without AppBar) for embedding in MediaHubScreen
class IPTVScreenBody extends ConsumerStatefulWidget {
  const IPTVScreenBody({super.key});

  @override
  ConsumerState<IPTVScreenBody> createState() => _IPTVScreenBodyState();
}

class _IPTVScreenBodyState extends ConsumerState<IPTVScreenBody>
    with WidgetsBindingObserver {
  final FocusNode _fullscreenFocusNode = FocusNode(
    debugLabel: 'IPTV body fullscreen back handler',
  );
  DateTime? _lastFullscreenBackAt;
  Timer? _macosFullscreenSyncTimer;

  /// See _IPTVScreenState's identical fields.
  bool _localPausedForCast = false;
  bool _mutedDefaultAppliedForCast = false;

  /// See _IPTVScreenState's identical field: guards the postFrameCallback
  /// below to fire once per fullscreen entry, not on every rebuild.
  bool _fullscreenFocusClaimed = false;

  @override
  void initState() {
    super.initState();
    // Initialize streaming service
    ref.read(iptvStreamingServiceProvider).initialize();
    // Screen-level wakelock: survives the featured player widget being
    // scrolled out of the viewport or playback moving to the mini player.
    ref.read(wakelockPlaybackCoordinatorProvider);
    WidgetsBinding.instance.addObserver(this);
    AiroNativeFullscreen.setMacosFullscreenExitHandler(
      _handleNativeFullscreenExit,
    );
    AiroNativeFullscreen.setMacosFullscreenEnterHandler(
      _handleNativeFullscreenEnter,
    );
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_synchronizeMacosFullscreenState());
      });
      _macosFullscreenSyncTimer = Timer(
        const Duration(milliseconds: 750),
        () => unawaited(_synchronizeMacosFullscreenState()),
      );
    }
  }

  @override
  void dispose() {
    // Don't reset orientation here - it causes issues during widget rebuilds
    // Orientation is reset in:
    // 1. _toggleFullscreen() when user explicitly exits fullscreen
    // 2. AppShell when navigating to a different tab
    WidgetsBinding.instance.removeObserver(this);
    AiroNativeFullscreen.setMacosFullscreenExitHandler(null);
    AiroNativeFullscreen.setMacosFullscreenEnterHandler(null);
    _macosFullscreenSyncTimer?.cancel();
    unawaited(AiroNativeFullscreen.exitMacosFullscreen());
    _fullscreenFocusNode.dispose();
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async {
    if (ref.read(isFullscreenModeProvider)) {
      _lastFullscreenBackAt = DateTime.now();
      _exitFullscreen();
      return true;
    }
    final lastFullscreenBackAt = _lastFullscreenBackAt;
    if (lastFullscreenBackAt != null &&
        DateTime.now().difference(lastFullscreenBackAt) <
            const Duration(seconds: 1)) {
      _lastFullscreenBackAt = null;
      return true;
    }
    return false;
  }

  KeyEventResult _handleFullscreenKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !ref.read(isFullscreenModeProvider)) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _exitFullscreen();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _handleNativeFullscreenExit() {
    _macosFullscreenSyncTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(isFullscreenModeProvider)) {
        _lastFullscreenBackAt = DateTime.now();
        _toggleFullscreen(updateNativeWindow: false);
      }
    });
  }

  void _handleNativeFullscreenEnter() {
    _macosFullscreenSyncTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !ref.read(isFullscreenModeProvider)) {
        _toggleFullscreen(updateNativeWindow: false);
      }
    });
  }

  Future<void> _synchronizeMacosFullscreenState() async {
    final nativeFullscreen = await AiroNativeFullscreen.isMacosFullscreen();
    if (!mounted) return;
    if (nativeFullscreen) {
      _macosFullscreenSyncTimer?.cancel();
    }
    final appFullscreen = ref.read(isFullscreenModeProvider);
    if (nativeFullscreen != appFullscreen) {
      _toggleFullscreen(updateNativeWindow: false);
    }
  }

  void _toggleFullscreen({bool updateNativeWindow = true}) {
    final isFullscreen = ref.read(isFullscreenModeProvider);
    ref.read(isFullscreenModeProvider.notifier).state = !isFullscreen;
    if (isFullscreen) {
      // Leaving fullscreen -- let the next entry claim focus fresh.
      _fullscreenFocusClaimed = false;
    }

    if (updateNativeWindow) {
      _macosFullscreenSyncTimer?.cancel();
    }

    if (!isFullscreen) {
      // Entering fullscreen
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      if (updateNativeWindow) {
        unawaited(AiroNativeFullscreen.setMacosFullscreen(true));
      }
    } else {
      // Exiting fullscreen -- restore system-default orientation instead of
      // forcing portrait, so tablets/foldables already using landscape as
      // their default layout aren't rotated out of it.
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([]);
      if (updateNativeWindow) {
        unawaited(AiroNativeFullscreen.exitMacosFullscreen());
      }
    }
  }

  void _exitFullscreen() {
    if (!ref.read(isFullscreenModeProvider)) return;
    _lastFullscreenBackAt = DateTime.now();
    _toggleFullscreen();
  }

  /// See _IPTVScreenState's identical method: a plain tap always targets the
  /// local player now, casting a channel is a separate explicit action.
  void _playChannel(IPTVChannel channel) {
    final castState = ref.read(iptvCastProvider);
    if (castState.isCasting && !_canRunLocalWhileCasting()) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              "This device can't play a second stream while casting.",
            ),
          ),
        );
      return;
    }

    final streaming = ref.read(iptvStreamingServiceProvider);
    streaming.playChannel(channel);
    _applyCastDefaultMuteIfNeeded(castState, streaming);
  }

  bool _canRunLocalWhileCasting() =>
      ref.read(multiviewDecoderBudgetProvider) >= 2;

  void _applyCastDefaultMuteIfNeeded(
    IptvCastState castState,
    VideoPlayerStreamingService streaming,
  ) {
    if (!castState.isCasting || _mutedDefaultAppliedForCast) return;
    _mutedDefaultAppliedForCast = true;
    if (!streaming.currentState.isMuted) {
      streaming.toggleMute();
    }
  }

  Future<void> _showPlaylistSheet() async {
    await showPlaylistSourceSheet(context, ref);
  }

  Future<void> _showQrPlaylist() async {
    final url = await showDialog<String>(
      context: context,
      builder: (_) => const TvPlaylistQrDialog(),
    );
    if (!mounted || url == null) return;
    await showPlaylistSourceSheet(context, ref, initialUrl: url);
  }

  Future<void> _showCastSheet() async {
    final channel = ref
        .read(iptvStreamingServiceProvider)
        .currentState
        .currentChannel;
    if (channel == null) return;
    await showIptvCastDevicePicker(
      context: context,
      onDeviceSelected: (device) {
        ref
            .read(iptvCastProvider.notifier)
            .castChannelToDevice(
              channel: channel,
              device: device,
              selectedQuality: ref
                  .read(iptvStreamingServiceProvider)
                  .currentState
                  .selectedQuality,
            );
      },
    );
  }

  Future<void> _showWaysToWatch() async {
    final pictureInPictureSupported =
        await AiroNativePictureInPicture.isSupported();
    if (!mounted) return;
    unawaited(ref.read(iptvCastProvider.notifier).startDiscovery());
    await _showWaysToWatchDialog(
      context: context,
      pictureInPictureSupported: pictureInPictureSupported,
      showCast: true,
      onExitFullscreen: _exitFullscreen,
      onEnterFullscreen: () {
        if (!ref.read(isFullscreenModeProvider)) _toggleFullscreen();
      },
      onShowCast: _showCastSheet,
      onShowCastMultiview: _showCastMultiviewScreen,
    );
  }

  void _showCastMultiviewScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CastMultiviewScreen()),
    );
  }

  /// See _IPTVScreenState's identical method.
  void _syncLocalPlaybackWithCast(bool? wasCasting, bool isCasting) {
    final streaming = ref.read(iptvStreamingServiceProvider);
    if (isCasting) {
      if (_canRunLocalWhileCasting()) {
        _mutedDefaultAppliedForCast = true;
        if (!streaming.currentState.isMuted) {
          streaming.toggleMute();
        }
      } else {
        streaming.pause();
        _localPausedForCast = true;
      }
    } else {
      if (_localPausedForCast) {
        streaming.resume();
      }
      _localPausedForCast = false;
      _mutedDefaultAppliedForCast = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      iptvCastProvider.select((state) => state.isCasting),
      _syncLocalPlaybackWithCast,
    );
    final isFullscreen = ref.watch(isFullscreenModeProvider);
    if (isFullscreen && !_fullscreenFocusClaimed) {
      _fullscreenFocusClaimed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(isFullscreenModeProvider)) {
          _fullscreenFocusNode.requestFocus();
        }
      });
    }

    // Use AnimatedSwitcher with fade to black for seamless fullscreen transition
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) {
        // Fade transition with black background to prevent channel list flash
        return FadeTransition(opacity: animation, child: child);
      },
      child: isFullscreen
          ? PopScope<void>(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) {
                // The fullscreen VideoPlayerWidget owns raw BACK: it either
                // dismisses its active overlay or leaves fullscreen.
                // Android/Fire OS follows that raw event with a platform pop;
                // this inner scope only absorbs the paired callback.
              },
              child: Focus(
                focusNode: _fullscreenFocusNode,
                autofocus: true,
                onKeyEvent: _handleFullscreenKey,
                child: AiroResponsiveScaffold(
                  key: const ValueKey('fullscreen'),
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.black,
                  body: VideoPlayerWidget(
                    showControls: true,
                    initiallyFullscreen: true,
                    handleNativeFullscreen: false,
                    // Deliberately the guarded exit rather than the raw
                    // toggle. guardRouteBack() above also answers this same
                    // pop, and two unguarded toggles would leave fullscreen
                    // and immediately re-enter it. _exitFullscreen is a no-op
                    // once fullscreen is already off, so whichever handler
                    // runs second does nothing.
                    onBack: _exitFullscreen,
                    onFullscreenToggle: _toggleFullscreen,
                    enableSwipeChannelChange: true,
                    onOpenSettings: () => showAiroTvShellSettingsDialog(
                      context,
                      onPlaylistSourceTap: _showPlaylistSheet,
                    ),
                    onShowHelp: () => showAiroTvShellHelpDialog(context),
                  ),
                ),
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
                      onScanWithPhoneTap: _showQrPlaylist,
                      onWaysToWatchTap: _showWaysToWatch,
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
    this.onGuideSourceTap,
    required this.onScanWithPhoneTap,
    required this.onWaysToWatchTap,
    this.onShareVideoFrame,
    this.playlistSourceInInfoBar = false,
  });

  final ValueChanged<IPTVChannel> onChannelTap;
  final VoidCallback onFullscreenToggle;
  final VoidCallback onPlaylistSourceTap;

  /// Opens the XMLTV guide-source sheet from the video stage's settings
  /// dialog. Null hides that row — not every host (e.g. `IPTVScreenBody`)
  /// has a guide-source entry point of its own.
  final VoidCallback? onGuideSourceTap;
  final VoidCallback onScanWithPhoneTap;
  final VoidCallback onWaysToWatchTap;
  final Future<void> Function(Uint8List pngBytes)? onShareVideoFrame;

  /// True on TV (no app bar): surfaces the playlist-source entry in the
  /// shell's LIVE bar instead. Phones keep it in the app bar only.
  final bool playlistSourceInInfoBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelsAsync = ref.watch(iptvChannelsProvider);
    final streamingState = ref.watch(streamingStateProvider);

    return channelsAsync.when(
      // iptvChannelsProvider re-runs whenever any of its watched
      // dependencies changes (auto-scan availability, favorites, personal
      // channels, ...) -- Riverpod calls that a "reload", distinct from an
      // explicit invalidate/refresh, and `when()` does NOT skip the loading
      // branch for a reload by default. Without this flag, any such
      // dependency change -- triggerable by almost any interaction on this
      // screen -- replaced this whole subtree with TvLoadingScreen and back,
      // tearing down and recreating AiroTvShellState (and therefore
      // invalidating any `ref` a caller had captured, e.g. mid-flight in
      // _toggleMultiview) even though cached channel data was already on
      // screen. See AsyncValue.when's skipLoadingOnReload/isReloading docs.
      skipLoadingOnReload: true,
      data: (channels) => _buildContent(context, ref, channels, streamingState),
      loading: () =>
          const TvLoadingScreen(message: 'Loading channels...', channel: null),
      error: (error, stack) => _buildError(context, ref, error.toString()),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<IPTVChannel> channels,
    AsyncValue<StreamingState> streamingState,
  ) {
    final activeChannel = streamingState.asData?.value.currentChannel;

    if (channels.isEmpty) {
      return _BringYourOwnPlaylistView(
        onPlaylistSourceTap: onPlaylistSourceTap,
        onScanWithPhoneTap: onScanWithPhoneTap,
        onLocalMediaSelected: onChannelTap,
        tenFootMode: playlistSourceInInfoBar,
      );
    }

    return AiroTvShell(
      channels: channels,
      enrichMetadata: true,
      currentChannel: activeChannel,
      showVideoStage: !playlistSourceInInfoBar,
      focusPlayDelay: playlistSourceInInfoBar
          ? const Duration(milliseconds: 1200)
          : null,
      onChannelSelected: onChannelTap,
      onPlaylistSourceTap: playlistSourceInInfoBar ? onPlaylistSourceTap : null,
      onWaysToWatchTap: onWaysToWatchTap,
      onShareVideoFrame: onShareVideoFrame,
      onFullscreenToggle: onFullscreenToggle,
      // Only true once there's an actual channel playing: that's the only
      // state where `videoStage` below is a real `VideoPlayerWidget` with
      // Help/Settings wired into its own sheet. The "select a channel"
      // placeholder has no sheet to fold into, so the shell keeps its own
      // row for that state (and it's also how Settings stays reachable to
      // turn hidden rows back on before any channel has ever played).
      videoStageHasOwnActions: activeChannel != null,
      videoStage: AspectRatio(
        aspectRatio: 16 / 9,
        child: activeChannel == null
            ? const Center(child: Text('Select a channel to start watching'))
            : Stack(
                fit: StackFit.expand,
                children: [
                  VideoPlayerWidget(
                    showControls: true,
                    enableSwipeChannelChange: true,
                    handleNativeFullscreen: false,
                    // `playlistSourceInInfoBar` is this widget's ten-foot
                    // signal — it is what it forwards as `tenFootMode`
                    // below. Brightness/volume drag zones and the lock
                    // button have no remote equivalent.
                    enableTouchGestures: !playlistSourceInInfoBar,
                    onFullscreenToggle: onFullscreenToggle,
                    showPictureInPicture: !playlistSourceInInfoBar,
                    showFullscreenButton: true,
                    onOpenSettings: () => showAiroTvShellSettingsDialog(
                      context,
                      onPlaylistSourceTap: onPlaylistSourceTap,
                      onGuideSourceTap: onGuideSourceTap,
                    ),
                    onShowHelp: () => showAiroTvShellHelpDialog(context),
                  ),
                  const Positioned(
                    top: 60,
                    left: 8,
                    right: 8,
                    child: OfflinePlaybackBanner(),
                  ),
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
            onPressed: () => invalidateChannelLibraries(ref),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// The fullscreen player's MultiView view -- shares [MultiviewStage] with
/// the browse grid rather than a bespoke fullscreen mosaic, so tapping
/// fullscreen never drops or re-arranges live sessions. Exit/layout controls
/// live in a top action row instead of on the tiles themselves, since
/// fullscreen has no info bar to host them.
class _FullscreenMultiviewStage extends ConsumerWidget {
  const _FullscreenMultiviewStage({
    required this.multiview,
    required this.onExit,
  });

  final MultiviewState multiview;
  final VoidCallback onExit;

  Future<void> _showLayoutPicker(BuildContext context, WidgetRef ref) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('fullscreen-multiview-layout-dialog'),
        title: const Text('MultiView layout'),
        content: MultiviewLayoutPicker(
          selected: resolveMultiviewLayout(
            preferred: multiview.layout,
            sessionCount: multiview.sessions.length,
          ),
          capacity: multiview.capacity,
          onSelected: (kind) {
            ref.read(multiviewProvider.notifier).setLayout(kind);
            Navigator.of(dialogContext).pop();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MultiviewStage(
          sessions: multiview.sessions,
          featuredChannelId: multiview.featuredChannelId,
          layout: multiview.layout,
          onPromote: (channelId) =>
              ref.read(multiviewProvider.notifier).promote(channelId),
          onSwap: (firstId, secondId) =>
              ref.read(multiviewProvider.notifier).swap(firstId, secondId),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FullscreenStageAction(
                key: const ValueKey('fullscreen-multiview-layout-action'),
                icon: Icons.grid_view,
                tooltip: 'MultiView layout',
                onPressed: () => _showLayoutPicker(context, ref),
              ),
              const SizedBox(width: 4),
              _FullscreenStageAction(
                key: const ValueKey('fullscreen-multiview-exit-action'),
                icon: Icons.fullscreen_exit,
                tooltip: 'Exit full screen',
                onPressed: onExit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FullscreenStageAction extends StatelessWidget {
  const _FullscreenStageAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.56),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }
}

Future<void> showPlaylistSourceSheet(
  BuildContext context,
  WidgetRef ref, {
  String? initialUrl,
  bool absorbAndroidTvRawBack = false,
}) async {
  await showAdaptiveIptvSheet<void>(
    context: context,
    maxWidth: 640,
    absorbAndroidTvRawBack: absorbAndroidTvRawBack,
    builder: (_) => PlaylistSourceManagerSheet(initialUrl: initialUrl),
  );
}

class _BringYourOwnPlaylistView extends ConsumerWidget {
  const _BringYourOwnPlaylistView({
    required this.onPlaylistSourceTap,
    required this.onScanWithPhoneTap,
    required this.onLocalMediaSelected,
    required this.tenFootMode,
  });

  final VoidCallback onPlaylistSourceTap;
  final VoidCallback onScanWithPhoneTap;
  final ValueChanged<IPTVChannel> onLocalMediaSelected;
  final bool tenFootMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final capabilities = ref
        .watch(localMediaLibraryCapabilitiesProvider)
        .asData
        ?.value;

    final content = Column(
      crossAxisAlignment: tenFootMode
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/aika_stream_mark.png',
          package: 'feature_iptv',
          width: tenFootMode ? 56 : 72,
          height: tenFootMode ? 56 : 72,
        ),
        SizedBox(height: tenFootMode ? 12 : 20),
        Text(
          'Add your playlist',
          textAlign: tenFootMode ? TextAlign.start : TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Aika Stream is a media player. It does not provide channels, playlists, or program guide data. Add an M3U URL for media you own or are authorized to watch.',
          textAlign: tenFootMode ? TextAlign.start : TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: tenFootMode ? WrapAlignment.start : WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            Semantics(
              button: true,
              label: 'Add a playlist URL',
              hint: 'Opens playlist source setup.',
              child: tenFootMode
                  ? TvFocusable(
                      key: const ValueKey('iptv-empty-add-playlist'),
                      autofocus: true,
                      semanticLabel: 'Add a playlist URL',
                      onSelect: onPlaylistSourceTap,
                      borderRadius: 20,
                      child: Material(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          onTap: onPlaylistSourceTap,
                          canRequestFocus: false,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.link,
                                  color: theme.colorScheme.onPrimary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Add playlist URL',
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: onPlaylistSourceTap,
                      icon: const Icon(Icons.link),
                      label: const Text('Add playlist URL'),
                    ),
            ),
            if (tenFootMode)
              TvFocusable(
                key: const ValueKey('iptv-empty-scan-phone'),
                semanticLabel: 'Scan with phone',
                onSelect: onScanWithPhoneTap,
                borderRadius: 20,
                child: ExcludeFocus(
                  child: OutlinedButton.icon(
                    onPressed: onScanWithPhoneTap,
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('Scan with phone'),
                  ),
                ),
              ),
            if (tenFootMode && capabilities?.removableStorage == true)
              TvFocusable(
                key: const ValueKey('iptv-empty-browse-usb'),
                semanticLabel: 'Browse USB',
                onSelect: () => _browseRemovableMedia(context, ref),
                borderRadius: 20,
                child: ExcludeFocus(
                  child: OutlinedButton.icon(
                    onPressed: () => _browseRemovableMedia(context, ref),
                    icon: const Icon(Icons.usb),
                    label: const Text('Browse USB'),
                  ),
                ),
              ),
            if (tenFootMode && capabilities?.dlnaUpnp == true)
              TvFocusable(
                key: const ValueKey('iptv-empty-browse-network'),
                semanticLabel: 'Browse network media',
                onSelect: () => _browseDlnaMedia(context, ref),
                borderRadius: 20,
                child: ExcludeFocus(
                  child: OutlinedButton.icon(
                    onPressed: () => _browseDlnaMedia(context, ref),
                    icon: const Icon(Icons.devices_other),
                    label: const Text('Browse network'),
                  ),
                ),
              ),
          ],
        ),
      ],
    );

    // No extra Center/ConstrainedBox wrapper here: content's own
    // crossAxisAlignment already centers everything within the full-width
    // scroll view. An earlier version wrapped this conditionally on
    // tenFootMode (bare `content` vs. `Center(ConstrainedBox(...))`), which
    // let Flutter's element reconciliation duplicate the "Add playlist URL"
    // button's internal Material _InkFeatures GlobalKey on a rebuild
    // (reproduced by an Android system theme change) -- "GlobalKey was used
    // multiple times". Keeping this a single, unwrapped child avoids that
    // class of bug entirely.
    final scrollView = SingleChildScrollView(
      padding: tenFootMode
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
      child: content,
    );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Playlist setup',
      hint: 'Add a playlist URL to browse your channels.',
      child: tenFootMode ? TvOverscanSafeArea(child: scrollView) : scrollView,
    );
  }

  Future<void> _browseRemovableMedia(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final adapter = ref.read(localMediaLibraryAdapterProvider);
    String? root;
    try {
      root = await adapter.requestRemovableStorageRoot();
    } on LocalMediaAccessException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The selected media folder could not be opened. '
            'Choose the folder again and allow read access.',
          ),
        ),
      );
      return;
    }
    if (!context.mounted || root == null) return;
    final selected = await _selectLocalMedia(
      context,
      initialRoot: root,
      title: 'Choose USB media',
      browse: adapter.browse,
    );
    if (!context.mounted || selected == null) return;
    _playLocalMedia(ref, selected);
  }

  Future<void> _browseDlnaMedia(BuildContext context, WidgetRef ref) async {
    final adapter = ref.read(dlnaUpnpLibraryAdapterProvider);
    const discoveryRoot = 'dlna://discover';
    final selected = await _selectLocalMedia(
      context,
      initialRoot: discoveryRoot,
      title: 'Choose network media',
      browse: (root) =>
          root == discoveryRoot ? adapter.discover() : adapter.browse(root),
    );
    if (!context.mounted || selected == null) return;
    _playLocalMedia(ref, selected);
  }

  Future<LocalMediaEntry?> _selectLocalMedia(
    BuildContext context, {
    required String initialRoot,
    required String title,
    required Future<List<LocalMediaEntry>> Function(String root) browse,
  }) async {
    var currentRoot = initialRoot;
    while (context.mounted) {
      final selected = await showDialog<LocalMediaEntry>(
        context: context,
        builder: (_) => _LocalMediaBrowserDialog(
          title: title,
          loadEntries: () => browse(currentRoot),
          tenFootMode: tenFootMode,
        ),
      );
      if (!context.mounted || selected == null) return null;
      if (selected.kind == LocalMediaEntryKind.folder) {
        final nextRoot = selected.childrenUri;
        if (nextRoot == null) return null;
        currentRoot = nextRoot;
        continue;
      }
      return selected;
    }
    return null;
  }

  void _playLocalMedia(WidgetRef ref, LocalMediaEntry selected) {
    final channelId = stableLocalMediaChannelId(selected.id);
    final subtitleUri = selected.subtitleUri;
    if (subtitleUri != null) {
      ref
          .read(iptvStreamingServiceProvider)
          .attachExternalSubtitle(
            channelId,
            AiroPlaybackExternalSubtitle(
              handle: AiroPlaybackSourceHandle.direct(subtitleUri),
              label: 'Local sidecar subtitle',
            ),
          );
    }
    onLocalMediaSelected(
      IPTVChannel(
        id: channelId,
        name: selected.name,
        streamUrl: selected.accessUri,
        group: 'Local media',
        isAudioOnly: selected.kind == LocalMediaEntryKind.audio,
      ),
    );
  }
}

class _LocalMediaBrowserDialog extends StatefulWidget {
  const _LocalMediaBrowserDialog({
    required this.title,
    required this.loadEntries,
    required this.tenFootMode,
  });

  final String title;
  final Future<List<LocalMediaEntry>> Function() loadEntries;
  final bool tenFootMode;

  @override
  State<_LocalMediaBrowserDialog> createState() =>
      _LocalMediaBrowserDialogState();
}

class _LocalMediaBrowserDialogState extends State<_LocalMediaBrowserDialog> {
  late Future<List<LocalMediaEntry>> _entries;

  @override
  void initState() {
    super.initState();
    _entries = widget.loadEntries();
  }

  void _retry() {
    setState(() {
      _entries = widget.loadEntries();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: (screenSize.width * 0.72).clamp(280.0, 720.0).toDouble(),
        height: (screenSize.height * 0.64).clamp(240.0, 480.0).toDouble(),
        child: FutureBuilder<List<LocalMediaEntry>>(
          future: _entries,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              final retryButton = OutlinedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              );
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'This media library could not be reached. Check the '
                    'connection or permission, then try again.',
                  ),
                  const SizedBox(height: 16),
                  if (widget.tenFootMode)
                    TvFocusable(
                      autofocus: true,
                      semanticLabel: 'Try network media again',
                      onSelect: _retry,
                      child: ExcludeFocus(child: retryButton),
                    )
                  else
                    retryButton,
                ],
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final entries = snapshot.data!;
            if (entries.isEmpty) {
              return const Text('No supported media was found here.');
            }
            return ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final tile = ListTile(
                  leading: Icon(
                    entry.kind == LocalMediaEntryKind.folder
                        ? Icons.folder
                        : entry.kind == LocalMediaEntryKind.audio
                        ? Icons.audio_file
                        : Icons.video_file,
                  ),
                  title: Text(entry.name),
                  trailing: entry.kind == LocalMediaEntryKind.folder
                      ? const Icon(Icons.chevron_right)
                      : null,
                  onTap: () => Navigator.of(context).pop(entry),
                );
                if (!widget.tenFootMode) return tile;
                return TvFocusable(
                  key: ValueKey('local-media-entry-${entry.id}'),
                  autofocus: index == 0,
                  semanticLabel: entry.name,
                  onSelect: () => Navigator.of(context).pop(entry),
                  child: ExcludeFocus(child: tile),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
