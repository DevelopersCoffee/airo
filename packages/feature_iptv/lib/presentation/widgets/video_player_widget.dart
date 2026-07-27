import 'dart:async';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, KeyDownEvent, KeyUpEvent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_channels/platform_channels.dart';
import '../../application/player_backgrounding_coordinator.dart';
import '../../application/channel_warmup_policy.dart';
import '../../application/providers/caption_preference_provider.dart';
import '../../application/providers/channel_auto_scan_providers.dart';
import '../../application/providers/dead_link_report_provider.dart';
import '../../application/providers/iptv_providers.dart';
import '../../application/providers/recently_watched_recorder.dart';
import '../../application/providers/video_aspect_ratio_provider.dart';
import '../../domain/vod_resume_coordinator.dart';
import 'playback_diagnostic_overlay.dart';
import "package:platform_player/platform_player.dart";
import "package:platform_media/platform_media.dart";
import '../utils/web_fullscreen.dart' as web_fullscreen;
import 'iptv_icon_placeholder.dart';
import 'player_brightness_controller.dart';
import 'player_gesture_overlay.dart';
import 'player_lock_button.dart';
import 'player_overlay.dart';
import '../tv_ux/sections/remote_overlay.dart';

/// Video player widget with YouTube-like controls
class VideoPlayerWidget extends ConsumerStatefulWidget {
  final bool showControls;
  final VoidCallback? onFullscreenToggle;
  final bool enableSwipeChannelChange;
  final bool initiallyFullscreen;
  final bool enableTouchGestures;
  final PlayerBrightnessController? brightnessController;

  /// Whether to offer system Picture-in-Picture (the floating-window
  /// control and the TV settings toggle). PiP is a phone/tablet
  /// multitasking concept -- Android TV and Fire TV don't have a
  /// multi-window model for it to floated into, so TV callers pass
  /// `false`. Defaults to `true` for phone/tablet callers.
  final bool showPictureInPicture;

  /// Renders the AiroTV D-pad design's TRANSPORT control bar (metadata row
  /// + Play/Pause, Restart, Audio, Subtitles, Favourite, Info) instead of
  /// the touch-oriented VOL/CH pillar layout. TV callers pass `true`; phone
  /// and tablet callers default to the existing touch layout unchanged.
  final bool useTvTransportBar;

  /// Invoked when the new [PlayerOverlay] chrome's back button is tapped.
  /// Defaults to [onFullscreenToggle] when not supplied, since today's only
  /// callers mount this widget full-screen and treat "back" as "exit
  /// fullscreen."
  final VoidCallback? onBack;

  /// Test seam for the manual audio-only toggle's platform call. Defaults to
  /// [AiroBackgroundAudioMode.setEnabled], which by design never throws (it
  /// swallows platform failures so local state always reflects user intent —
  /// see platform_player's background_audio_mode_test.dart). Injecting a
  /// throwing function here is the only way to exercise this widget's
  /// revert-on-failure path in tests.
  final Future<void> Function(bool enabled)? setAudioOnlyMode;

  /// Test seam for explicit system PiP. Defaults to the native PiP channel.
  final Future<bool> Function()? requestPictureInPicture;

  const VideoPlayerWidget({
    super.key,
    this.showControls = true,
    this.onFullscreenToggle,
    this.enableSwipeChannelChange = false,
    this.initiallyFullscreen = false,
    this.enableTouchGestures = true,
    this.showPictureInPicture = true,
    this.useTvTransportBar = false,
    this.brightnessController,
    this.onBack,
    this.setAudioOnlyMode,
    this.requestPictureInPicture,
  });

  @override
  ConsumerState<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends ConsumerState<VideoPlayerWidget> {
  bool _showControlsOverlay = true;
  bool _isFullscreen = false;
  bool _isCinemaMode = false;
  Timer? _hideControlsTimer;
  static const _controlsHideDelay = Duration(seconds: 4);

  /// Default focus holder for the player surface. While it has focus the
  /// D-pad channel-surfs; revealing the controls moves focus onto them.
  final FocusNode _playerFocusNode = FocusNode(
    debugLabel: 'player surface',
    skipTraversal: true,
  );

  /// The center play/pause button — first focus target when the remote
  /// reveals the controls overlay.
  final FocusNode _centerControlFocusNode = FocusNode(
    debugLabel: 'player center control',
  );
  final FocusNode _moreActionsFocusNode = FocusNode(
    debugLabel: 'player more actions',
  );
  final FocusNode _infoFocusNode = FocusNode(debugLabel: 'player channel info');
  final FocusNode _audioTransportFocusNode = FocusNode(
    debugLabel: 'player audio track',
  );
  final FocusNode _subtitleTransportFocusNode = FocusNode(
    debugLabel: 'player subtitles',
  );
  final FocusNode _playerActionsAudioFocusNode = FocusNode(
    debugLabel: 'player action Listen only',
  );
  final FocusNode _playerActionsQualityFocusNode = FocusNode(
    debugLabel: 'player action Quality',
  );
  final FocusNode _playerActionsSubtitleFocusNode = FocusNode(
    debugLabel: 'player action Subtitles',
  );
  final FocusNode _contextMenuFirstFocusNode = FocusNode(
    debugLabel: 'channel action Favorite',
  );
  final FocusNode _diagnosticRetryFocusNode = FocusNode(
    debugLabel: 'player recovery Try Again',
  );
  final FocusNode _diagnosticSkipFocusNode = FocusNode(
    debugLabel: 'player recovery Skip channel',
  );
  final FocusNode _diagnosticReportFocusNode = FocusNode(
    debugLabel: 'player recovery Report dead link',
  );
  final FocusNode _genericRetryFocusNode = FocusNode(
    debugLabel: 'player recovery Try Again',
  );
  FocusNode? _contextMenuRestoreFocusNode;
  bool _playerModalOpen = false;
  String? _lastRecoveryFocusToken;

  // Channel change overlay state
  String? _channelChangeOverlayText;
  Timer? _channelChangeOverlayTimer;
  Timer? _adjacentChannelWarmupDebounce;
  String _adjacentChannelWarmupSignature = '';

  // Channel-actions overlay opened from Info or a CENTER long-press.
  //
  // On real Fire TV hardware, KEYCODE_MENU never reaches the app -- Fire OS
  // intercepts it at the system level for its own overlay (confirmed via
  // on-device logcat: com.amazon.device.controller consumes it before
  // Flutter's embedding sees it). Long-press Select/OK is the standard Fire
  // TV convention for "more options" (Prime Video, Netflix, etc. all use
  // it), and unlike Menu it's guaranteed to reach the app, so it's wired
  // as the real-world trigger; TvInputKey.menu stays wired too for
  // Android TV remotes that do have a working menu key.
  bool _showContextMenu = false;
  Timer? _selectLongPressTimer;
  bool _selectConsumedByLongPress = false;

  // UP/DOWN quick-browse overlays (AiroTV D-pad design "MINI GUIDE (UP)" /
  // "RECENT CHANNELS (DOWN)"). Replaces the previous instant channel-surf
  // on up/down: browsing now stops on a channel instead of committing to
  // it, and OK is what actually switches.
  _TvQuickBrowse? _quickBrowse;

  // Netflix-style gesture controls (CV-PLAYER-GESTURES) + lock button.
  bool _isLocked = false;
  double _brightness = 0.5;
  late final PlayerBrightnessController _brightnessController;
  late final Future<void> Function(bool enabled) _setAudioOnlyMode;

  // VOD seek bar drag state — null when the user isn't actively dragging,
  // so the slider tracks live playback position between drags.
  Duration? _vodSeekDragPosition;

  // Manual audio-only toggle (Task 5): mirrors the native background-audio
  // mode so the icon reflects state set before this widget mounted (e.g. a
  // toggle left on from a previous session).
  bool _isAudioOnly = AiroBackgroundAudioMode.isEnabled;

  @override
  void initState() {
    super.initState();
    _isFullscreen = widget.initiallyFullscreen;
    _brightnessController =
        widget.brightnessController ?? SystemPlayerBrightnessController();
    _setAudioOnlyMode =
        widget.setAudioOnlyMode ?? AiroBackgroundAudioMode.setEnabled;
    _loadInitialBrightness();
    _startHideControlsTimer();
    // Wakelock is managed by WakelockPlaybackCoordinator at screen scope,
    // not by this widget's lifetime. PiP state comes from
    // pictureInPictureActiveProvider (owned at session scope by
    // playerBackgroundingCoordinatorProvider), watched in build().
  }

  Future<void> _loadInitialBrightness() async {
    try {
      final value = await _brightnessController.currentBrightness();
      if (!mounted) return;
      setState(() => _brightness = value);
    } catch (e) {
      debugPrint('Failed to read initial brightness: $e');
    }
  }

  @override
  void dispose() {
    _cancelHideControlsTimer();
    _channelChangeOverlayTimer?.cancel();
    _adjacentChannelWarmupDebounce?.cancel();
    _selectLongPressTimer?.cancel();
    _playerFocusNode.dispose();
    _centerControlFocusNode.dispose();
    _moreActionsFocusNode.dispose();
    _infoFocusNode.dispose();
    _audioTransportFocusNode.dispose();
    _subtitleTransportFocusNode.dispose();
    _playerActionsAudioFocusNode.dispose();
    _playerActionsQualityFocusNode.dispose();
    _playerActionsSubtitleFocusNode.dispose();
    _contextMenuFirstFocusNode.dispose();
    _diagnosticRetryFocusNode.dispose();
    _diagnosticSkipFocusNode.dispose();
    _diagnosticReportFocusNode.dispose();
    _genericRetryFocusNode.dispose();
    unawaited(_resetBrightnessSafely());
    super.dispose();
  }

  // screen_brightness has no Linux implementation and limited web support;
  // platforms without it throw on every call, so failures here are expected
  // on some desktop/web targets and must never crash the widget.
  Future<void> _resetBrightnessSafely() async {
    try {
      await _brightnessController.resetBrightness();
    } catch (e) {
      debugPrint('Failed to reset brightness: $e');
    }
  }

  Future<void> _setBrightnessSafely(double value) async {
    try {
      await _brightnessController.setBrightness(value);
    } catch (e) {
      debugPrint('Failed to set brightness: $e');
    }
  }

  void _startHideControlsTimer() {
    _cancelHideControlsTimer();
    _hideControlsTimer = Timer(_controlsHideDelay, () {
      if (mounted) {
        setState(() => _showControlsOverlay = false);
        // If the D-pad had moved focus onto a control, don't leave it on a
        // now-invisible button — return it to the surface so arrow keys go
        // back to channel surfing instead of traversing hidden controls.
        if (_playerFocusNode.canRequestFocus) {
          _playerFocusNode.requestFocus();
        }
      }
    });
  }

  void _cancelHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = null;
  }

  // No-op while locked: the controls layer is unrendered in that state (see
  // `_buildPlayer`), so revealing it would be dead code with no visible
  // effect today — but tap/hover should never behave as an interactive
  // surface while locked, regardless of how the render-gating evolves.
  void _showControls() {
    if (_isLocked) return;
    setState(() => _showControlsOverlay = true);
    _startHideControlsTimer();
  }

  void _toggleLocked() {
    setState(() {
      _isLocked = !_isLocked;
      _showControlsOverlay = true;
    });
    // Keep controls visible right after toggling so the lock/unlock state
    // change itself is visible, then resume the normal auto-hide behavior.
    _startHideControlsTimer();
  }

  void _onBrightnessGestureChanged(double value) {
    setState(() => _brightness = value);
    unawaited(_setBrightnessSafely(value));
  }

  void _toggleFullscreen() {
    final enteringFullscreen = !_isFullscreen;
    if (kIsWeb) {
      _toggleWebFullscreen();
    }
    setState(() => _isFullscreen = enteringFullscreen);
    unawaited(AiroNativeFullscreen.setMacosFullscreen(enteringFullscreen));
    widget.onFullscreenToggle?.call();
  }

  // Manual audio-only toggle (Task 5, spec Goal 5): lets the user opt into
  // audio-only playback ahead of backgrounding, which
  // PlayerBackgroundingCoordinator then treats as always-win over the PiP
  // attempt (see manualAudioOnlyToggled).
  Future<void> _toggleAudioOnly() async {
    final next = !_isAudioOnly;
    final previous = _isAudioOnly;
    setState(() => _isAudioOnly = next);
    try {
      await _setAudioOnlyMode(next);
    } catch (e) {
      debugPrint('Failed to set audio-only mode: $e');
      if (!mounted) return;
      setState(() => _isAudioOnly = previous);
      return;
    }
    if (!mounted) return;
    ref
        .read(playerBackgroundingCoordinatorProvider)
        .manualAudioOnlyToggled(next);
  }

  Future<void> _requestPictureInPicture() async {
    final request =
        widget.requestPictureInPicture ??
        AiroNativePictureInPicture.requestEnter;
    final entered = await request();
    if (!mounted || entered) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Picture-in-picture is not available.')),
      );
  }

  void _toggleWebFullscreen() {
    if (kIsWeb) {
      try {
        web_fullscreen.toggleFullscreen();
      } catch (e) {
        debugPrint('Fullscreen error: $e');
      }
    }
  }

  // Channel navigation button handlers
  void _goToNextChannel() {
    final streamingService = ref.read(iptvStreamingServiceProvider);
    final nextChannel = ref.read(nextSelectableChannelProvider);
    if (nextChannel != null) {
      streamingService.playChannel(nextChannel);
      _showChannelChangeOverlay(nextChannel.name);
      _scheduleAdjacentChannelWarmupFor(nextChannel);
    }
  }

  void _goToPreviousChannel() {
    final streamingService = ref.read(iptvStreamingServiceProvider);
    final prevChannel = ref.read(previousSelectableChannelProvider);
    if (prevChannel != null) {
      streamingService.playChannel(prevChannel);
      _showChannelChangeOverlay(prevChannel.name);
      _scheduleAdjacentChannelWarmupFor(prevChannel);
    }
  }

  void _playRandomFilteredChannel(VideoPlayerStreamingService service) {
    final channel = randomFilteredChannel(ref.read(filteredChannelsProvider));
    if (channel == null) return;
    service.playChannel(channel);
    _showChannelChangeOverlay(channel.name);
    _scheduleAdjacentChannelWarmupFor(channel);
  }

  void _scheduleAdjacentChannelWarmup(StreamingState state) {
    final currentChannel = state.currentChannel;
    if (currentChannel == null) return;
    _scheduleAdjacentChannelWarmupFor(currentChannel);
  }

  void _scheduleAdjacentChannelWarmupFor(IPTVChannel currentChannel) {
    final channels = ref.read(filteredChannelsProvider);
    if (channels.isEmpty) return;
    final candidates = channelWarmupWindowAround(
      currentChannel: currentChannel,
      channels: channels,
    );
    if (candidates.isEmpty) return;

    final autoScanState = ref.read(channelAutoScanProvider);
    final plan = planChannelWarmup(
      totalChannelCount: channels.length,
      candidateCount: candidates.length,
      cachedChannelCount: autoScanState.availabilityByChannelId.length,
      playbackState: ref.read(playbackStateProvider),
      interactionCritical: true,
    );
    if (plan.isEmpty) return;

    final warmupChannels = candidates.take(plan.limit).toList(growable: false);
    final signature = warmupChannels.map((channel) => channel.id).join(',');
    if (signature.isEmpty || signature == _adjacentChannelWarmupSignature) {
      return;
    }
    _adjacentChannelWarmupSignature = signature;
    _adjacentChannelWarmupDebounce?.cancel();
    _adjacentChannelWarmupDebounce = Timer(plan.debounce, () {
      if (!mounted) return;
      ref
          .read(channelAutoScanProvider.notifier)
          .start(
            scopeId: 'airo-tv-player-nearby|$signature',
            channels: warmupChannels,
            maxConcurrentRequests: plan.maxConcurrentRequests,
            currentPlayingChannelId: ref
                .read(iptvStreamingServiceProvider)
                .currentState
                .currentChannel
                ?.id,
          );
    });
  }

  void _seekBackward10(
    VideoPlayerStreamingService service,
    StreamingState state,
  ) {
    var target = state.position - const Duration(seconds: 10);
    if (state.isLiveStream && state.dvrWindowStart != null) {
      target = target < state.dvrWindowStart! ? state.dvrWindowStart! : target;
    }
    service.seek(target.isNegative ? Duration.zero : target);
  }

  void _stepVolume(
    VideoPlayerStreamingService service,
    StreamingState state,
    double step,
  ) {
    final next = (state.volume + step).clamp(0.0, 1.0);
    if (state.isMuted && next > 0) {
      service.toggleMute();
    }
    service.setVolume(next);
  }

  // CV-008 UC-002: D-pad surf mode. Up/Down changes channel while playback
  // stays primary; boundary channels are a no-op via
  // nextChannelProvider/previousChannelProvider already returning null there.
  // Gated on !_isLocked, matching every other in-player interaction.
  TvInputResult _handleSurfInput(TvInputKey key) {
    if (_isLocked) return TvInputResult.notHandled;
    final remoteResult = handleRemoteOverlayInput(
      key,
      onChannelPrevious: _goToPreviousChannel,
      onChannelNext: _goToNextChannel,
    );
    if (remoteResult == TvInputResult.handled) return remoteResult;

    final streamingState = ref.read(streamingStateProvider).asData?.value;
    final recoveryOwnsFocus =
        streamingState?.hasError == true && streamingState?.diagnostic != null;
    final controlsVisible = _showControlsOverlay && widget.showControls;
    if (controlsVisible && !recoveryOwnsFocus) {
      // Keep the overlay alive while the remote is being used.
      _startHideControlsTimer();
    }

    switch (key) {
      // UP opens the Mini Guide, DOWN opens Recent Channels — browsing
      // stops on a channel instead of committing to it; OK inside the
      // overlay is what actually switches (AiroTV D-pad design).
      case TvInputKey.up:
        if (ref.read(streamingStateProvider).asData?.value.currentChannel ==
            null) {
          return TvInputResult.notHandled;
        }
        setState(() => _quickBrowse = _TvQuickBrowse.miniGuide);
        return TvInputResult.handled;
      case TvInputKey.down:
        setState(() => _quickBrowse = _TvQuickBrowse.recent);
        return TvInputResult.handled;
      case TvInputKey.menu:
        final state = ref.read(streamingStateProvider).asData?.value;
        if (state?.currentChannel == null) {
          return TvInputResult.notHandled;
        }
        unawaited(
          _showPlayerActionsSheet(
            context,
            ref.read(iptvStreamingServiceProvider),
            state!,
            restoreFocusNode: _centerControlFocusNode,
          ),
        );
        return TvInputResult.handled;
      case TvInputKey.back:
        if (_showContextMenu) {
          _closeContextMenu();
          return TvInputResult.handled;
        }
        if (_quickBrowse != null) {
          setState(() => _quickBrowse = null);
          return TvInputResult.handled;
        }
        return TvInputResult.notHandled;
      // Left/right walk the visible controls via normal focus traversal
      // (the buttons are TvFocusable); with the overlay hidden there are
      // no focus candidates (ExcludeFocus), so the keys are inert.
      //
      // Select is deliberately NOT handled here: TvInputHandler fires on
      // every key-down, which would reveal controls the instant Select is
      // pressed -- including the down-stroke of what turns out to be a
      // long-press. That doubled the short-press action on top of the
      // context menu opening (issues/01-remote-focus-contract.md
      // acceptance criterion 5: "Holding Select does not also trigger the
      // short-press action"). _detectSelectLongPress below owns Select
      // entirely and only fires the short-press reveal on a clean key-up.
      default:
        return TvInputResult.notHandled;
    }
  }

  /// The short-press Select action: reveal controls (or move focus onto
  /// them if already visible). Only invoked from [_detectSelectLongPress]
  /// on a key-up that wasn't consumed by the long-press timer.
  void _revealControlsForSelect() {
    if (_showControlsOverlay && widget.showControls) {
      // A focused control's own TvFocusable consumes select before this
      // listener; reaching here means nothing was focused yet.
      if (_centerControlFocusNode.canRequestFocus) {
        _centerControlFocusNode.requestFocus();
      }
      return;
    }
    // Controls hidden: OK reveals them with focus on play/pause, the same
    // pattern as every mainstream TV player.
    _showControls();
    if (_centerControlFocusNode.canRequestFocus) {
      _centerControlFocusNode.requestFocus();
    }
  }

  static const _miniGuideWindowSize = 12;

  List<IPTVChannel> _miniGuideChannels(IPTVChannel current) {
    final all = ref.read(filteredChannelsProvider);
    if (all.isEmpty) return const [];
    final currentIndex = all.indexWhere((c) => c.id == current.id);
    if (currentIndex < 0) {
      return all.take(_miniGuideWindowSize).toList(growable: false);
    }
    final start = (currentIndex - _miniGuideWindowSize ~/ 2).clamp(
      0,
      all.length,
    );
    final end = (start + _miniGuideWindowSize).clamp(0, all.length);
    return all.sublist(start, end);
  }

  static const _selectLongPressDuration = Duration(milliseconds: 500);

  /// Owns Select/OK end to end: starts the long-press timer on key-down,
  /// and on key-up either leaves it to the context menu it already opened
  /// (long-press) or fires the short-press reveal-controls action (clean
  /// tap) -- never both, per issues/01-remote-focus-contract.md acceptance
  /// criterion 5. Always returns `ignored` since nothing else needs this
  /// key event once decided.
  KeyEventResult _detectSelectLongPress(FocusNode node, KeyEvent event) {
    final key = TvInputHandler.mapLogicalKeyToTvInput(event.logicalKey);
    if (key != TvInputKey.select) return KeyEventResult.ignored;

    if (event is KeyDownEvent) {
      _selectLongPressTimer ??= Timer(_selectLongPressDuration, () {
        _selectLongPressTimer = null;
        if (ref.read(streamingStateProvider).asData?.value.currentChannel !=
            null) {
          _selectConsumedByLongPress = true;
          _openContextMenu(restoreFocusNode: _centerControlFocusNode);
        }
      });
    } else if (event is KeyUpEvent) {
      final wasStillPending = _selectLongPressTimer != null;
      _selectLongPressTimer?.cancel();
      _selectLongPressTimer = null;
      if (_selectConsumedByLongPress) {
        _selectConsumedByLongPress = false;
      } else if (wasStillPending) {
        _revealControlsForSelect();
      }
    }
    return KeyEventResult.ignored;
  }

  void _playChannelFromQuickBrowse(IPTVChannel channel) {
    final streamingService = ref.read(iptvStreamingServiceProvider);
    streamingService.playChannel(channel);
    _showChannelChangeOverlay(channel.name);
    _scheduleAdjacentChannelWarmupFor(channel);
    setState(() => _quickBrowse = null);
  }

  void _openContextMenu({required FocusNode restoreFocusNode}) {
    _contextMenuRestoreFocusNode = restoreFocusNode;
    setState(() => _showContextMenu = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_showContextMenu) return;
      _contextMenuFirstFocusNode.requestFocus();
    });
  }

  void _closeContextMenu({bool restoreFocus = true}) {
    if (!_showContextMenu) return;
    setState(() => _showContextMenu = false);
    final target = _contextMenuRestoreFocusNode;
    _contextMenuRestoreFocusNode = null;
    if (!restoreFocus || target == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && target.canRequestFocus) target.requestFocus();
    });
  }

  Future<void> _toggleFavoriteForCurrentChannel() async {
    final channel = ref
        .read(streamingStateProvider)
        .asData
        ?.value
        .currentChannel;
    if (channel == null) return;
    final toggle = ref.read(channelFavoriteTogglerProvider);
    final isNowFavorite = await toggle(channel.id);
    if (!mounted) return;
    _closeContextMenu();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            isNowFavorite
                ? '${channel.name} added to favorites'
                : '${channel.name} removed from favorites',
          ),
        ),
      );
  }

  Future<void> _refreshPlaylistFromContextMenu() async {
    _closeContextMenu();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Refreshing playlist…')));
    try {
      await ref.read(refreshChannelsProvider(true).future);
      ref.invalidate(iptvChannelsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Playlist refreshed')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Playlist refresh failed')),
        );
    }
  }

  void _selectAudioTrackFromContextMenu(
    VideoPlayerStreamingService service,
    StreamingState state,
  ) {
    _closeContextMenu(restoreFocus: false);
    unawaited(
      _showTrackSelectorFor(
        context,
        service,
        state,
        kind: AiroPlaybackTrackKind.audio,
        restoreFocusNode: _infoFocusNode,
      ),
    );
  }

  void _selectSubtitlesFromContextMenu(
    VideoPlayerStreamingService service,
    StreamingState state,
  ) {
    _closeContextMenu(restoreFocus: false);
    unawaited(
      _showTrackSelector(
        context,
        service,
        state,
        restoreFocusNode: _infoFocusNode,
      ),
    );
  }

  void _showChannelInfoFromContextMenu(StreamingState state) {
    _closeContextMenu();
    final channel = state.currentChannel;
    if (channel == null) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(channel.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (channel.group.isNotEmpty) Text('Group: ${channel.group}'),
            Text('Quality: ${state.currentQuality.label}'),
            Text(state.isLiveStream ? 'Live' : 'On demand'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDiagnosticsFromContextMenu(StreamingState state) {
    _closeContextMenu();
    final channel = state.currentChannel;
    final metrics = state.metrics;
    final playback = state.playbackStats;
    final redactedSource = redactedUriForLog(
      channel == null ? null : Uri.tryParse(channel.streamUrl),
    );
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Diagnostics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Source: $redactedSource'),
            Text('Quality: ${state.currentQuality.label}'),
            if (metrics != null) ...[
              Text('Bitrate: ${metrics.currentBitrate} kbps'),
              Text('Network: ${metrics.networkQuality.label}'),
            ],
            if (playback?.codec != null)
              Text('Video codec: ${playback!.codec}'),
            if (playback?.resolution != null)
              Text('Resolution: ${playback!.resolution}'),
            if (playback?.framesPerSecond != null)
              Text(
                'Frame rate: '
                '${playback!.framesPerSecond!.toStringAsFixed(2)} fps',
              ),
            if (playback?.droppedFrames != null)
              Text('Dropped frames: ${playback!.droppedFrames}'),
            if (playback?.audioCodec != null)
              Text('Audio codec: ${playback!.audioCodec}'),
            if (playback?.audioBitrateKbps != null)
              Text('Audio bitrate: ${playback!.audioBitrateKbps} kbps'),
            if (playback?.audioChannels != null)
              Text('Audio channels: ${playback!.audioChannels}'),
            if (playback?.cacheDuration != null)
              Text(
                'Cache: '
                '${playback!.cacheDuration!.inMilliseconds / 1000} seconds',
              ),
            if (playback?.failoverSuggested == true)
              const Text(
                'Playback is degraded. Try the next healthy stream source.',
              ),
            Text('Buffer health: ${state.bufferStatus.bufferHealth}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyStreamLinkFromContextMenu(StreamingState state) async {
    _closeContextMenu();
    final channel = state.currentChannel;
    final redacted = redactedUriForLog(
      channel == null ? null : Uri.tryParse(channel.streamUrl),
    );
    await Clipboard.setData(ClipboardData(text: redacted));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Stream link copied')));
  }

  void _showChannelChangeOverlay(String text) {
    _channelChangeOverlayTimer?.cancel();
    setState(() {
      _channelChangeOverlayText = text;
    });
    _channelChangeOverlayTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _channelChangeOverlayText = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(recentlyWatchedRecorderProvider);
    final streamingService = ref.watch(iptvStreamingServiceProvider);
    final streamingState = ref.watch(streamingStateProvider);
    final aspectRatioFit = ref.watch(videoAspectRatioProvider);
    // System PiP shows only the video surface: all chrome (controls
    // overlay, lock button, swipe buttons, PlayerOverlay) stays out of the
    // floating window (#1002).
    final isPipActive = ref.watch(pictureInPictureActiveProvider);

    return streamingState.when(
      data: (state) => _buildPlayer(
        context,
        streamingService,
        state,
        aspectRatioFit,
        isPipActive: isPipActive,
      ),
      loading: () => _buildLoading(),
      error: (err, _) => _buildError(err.toString()),
    );
  }

  Widget _buildPlayer(
    BuildContext context,
    VideoPlayerStreamingService service,
    StreamingState state,
    AiroPlaybackViewFit aspectRatioFit, {
    required bool isPipActive,
  }) {
    _scheduleRecoveryFocus(state);
    // Update wakelock based on current playback state
    // This is called on every build when state changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleVodResume(service, state);
      _applyCaptionPreferenceIfNeeded(service, state);
      _scheduleAdjacentChannelWarmup(state);
    });

    final videoView = service.buildVideoView();
    final compactInlinePlayer = _usesCompactInlinePlayer(context);

    // Shared player surface: video view + cinema-mode vignette + buffering indicator
    // Built once and reused in both enableTouchGestures branches to reduce duplication.
    final playerSurface = Stack(
      alignment: Alignment.center,
      children: [
        // Video display (engine-driven view surface).
        if (videoView != null)
          SizedBox.expand(
            child: FittedBox(fit: _boxFitFor(aspectRatioFit), child: videoView),
          )
        else if (state.playbackState == PlaybackState.loading)
          _buildLoading()
        else if (state.hasError && state.diagnostic != null)
          _buildDiagnosticError(state)
        else
          _buildPlaceholder(state),

        // Cinema mode vignette overlay
        if (_isCinemaMode)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.15,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                    stops: const [0.6, 1.0],
                  ),
                ),
              ),
            ),
          ),

        // Buffering indicator
        if (state.isBuffering)
          Container(
            color: Colors.black45,
            child: const CircularProgressIndicator(color: Colors.white),
          ),
      ],
    );

    // TvInputHandler observes raw key events via a KeyboardListener, which
    // is passive -- it cannot consume/stop the platform BACK button. So
    // even though _handleSurfInput's TvInputKey.back case closes the
    // context menu / quick-browse overlay via setState, the real Android
    // back press keeps propagating past it and exits the Activity (there's
    // no route to pop). PopScope is what actually intercepts the platform
    // back button; block it exactly when an overlay needs BACK to close it
    // instead of leaving the app.
    return PopScope(
      canPop: !_showContextMenu && _quickBrowse == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_showContextMenu) {
          _closeContextMenu();
        } else {
          setState(() => _quickBrowse = null);
        }
      },
      child: TvInputHandler(
        enabled: !_playerModalOpen && !_showContextMenu,
        onInput: _handleSurfInput,
        // Focus.onKeyEvent always ignores so the event bubbles up to
        // TvInputHandler's own listener above -- this node exists purely to
        // hold primary focus by default, since nothing else in the player
        // (controls auto-hide) reliably claims it otherwise. The state-owned
        // node lets the hide timer reclaim focus from on-screen controls.
        child: Focus(
          focusNode: _playerFocusNode,
          autofocus: true,
          onKeyEvent: _detectSelectLongPress,
          child: MouseRegion(
            onHover: (_) => _showControls(),
            onEnter: (_) => _showControls(),
            child: GestureDetector(
              onTap: _showControls,
              child: Container(
                color: Colors.black,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Video display + Netflix-style brightness/volume drag
                    // gestures. Left half of the video area adjusts brightness,
                    // right half adjusts volume; disabled while locked. The video
                    // surface itself is the engine-driven view (CV-016 migration);
                    // when it's null we fall through to loading/placeholder
                    // inside the same gesture-enabled stack -- except a
                    // diagnostic error, whose own recovery buttons need to
                    // win every tap outright rather than compete with this
                    // overlay's translucent drag detector for the same
                    // gesture arena.
                    widget.enableTouchGestures &&
                            !(state.hasError && state.diagnostic != null)
                        ? PlayerGestureOverlay(
                            locked: _isLocked,
                            brightness: _brightness,
                            volume: state.isMuted ? 0.0 : state.volume,
                            onTap: _showControls,
                            onBrightnessChanged: _onBrightnessGestureChanged,
                            onVolumeChanged: (value) {
                              if (state.isMuted) service.toggleMute();
                              service.setVolume(value);
                            },
                            child: playerSurface,
                          )
                        : playerSurface,

                    // Failover toast only. Airo TV owns one visible control
                    // system below; keeping PlayerOverlay's old back/title layer
                    // mounted here caused a second set of controls to reappear
                    // after the floating controls faded.
                    if (!_isLocked && !isPipActive && !compactInlinePlayer)
                      PlayerOverlay(
                        state: _toPlayerViewState(state),
                        onBack:
                            widget.onBack ?? widget.onFullscreenToggle ?? () {},
                        onPlayPause: () {
                          if (state.isPlaying) {
                            service.pause();
                          } else {
                            service.resume();
                          }
                        },
                        onReveal: _showControls,
                        showTopChrome: false,
                        showCenterControls: false,
                        showBottomBar: false,
                      ),

                    // Controls overlay with fade animation — hidden entirely while
                    // locked so only the lock button remains interactive, and
                    // while a diagnostic error owns the screen (there's no
                    // video to control, and its own recovery buttons occupy
                    // the same vertical band the center play/pause button
                    // would otherwise sit in and silently swallow taps for).
                    if (!_isLocked &&
                        !isPipActive &&
                        !(state.hasError && state.diagnostic != null))
                      AnimatedOpacity(
                        opacity: (widget.showControls && _showControlsOverlay)
                            ? 1.0
                            : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: IgnorePointer(
                          ignoring:
                              !widget.showControls || !_showControlsOverlay,
                          // Hidden controls must be invisible to D-pad focus
                          // too, or arrow keys traverse buttons nobody can see
                          // while the surface expects channel-surf input.
                          child: ExcludeFocus(
                            excluding:
                                !widget.showControls || !_showControlsOverlay,
                            child: _buildControlsOverlay(
                              context,
                              service,
                              state,
                            ),
                          ),
                        ),
                      ),

                    // Lock button: touch-only concept, hidden entirely when
                    // enableTouchGestures is false (e.g. TV/remote input).
                    if (widget.enableTouchGestures && !isPipActive)
                      Positioned(
                        top: 8,
                        right: 56,
                        child: AnimatedOpacity(
                          opacity: (_isLocked || _showControlsOverlay)
                              ? 1.0
                              : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: PlayerLockButton(
                              key: const ValueKey('iptv-player-lock-button'),
                              locked: _isLocked,
                              onToggle: _toggleLocked,
                            ),
                          ),
                        ),
                      ),

                    // Channel change overlay
                    if (_channelChangeOverlayText != null)
                      Positioned(
                        child: AnimatedOpacity(
                          opacity: _channelChangeOverlayText != null
                              ? 1.0
                              : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _channelChangeOverlayText!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Channel actions — right-side overlay opened from Info
                    // or a CENTER long-press. It does not affect layout while
                    // closed.
                    if (_showContextMenu && state.currentChannel != null)
                      _ContextMenuOverlay(
                        channel: state.currentChannel!,
                        firstFocusNode: _contextMenuFirstFocusNode,
                        onToggleFavorite: _toggleFavoriteForCurrentChannel,
                        onRefreshPlaylist: _refreshPlaylistFromContextMenu,
                        onSelectAudioTrack: () =>
                            _selectAudioTrackFromContextMenu(service, state),
                        onSelectSubtitles: () =>
                            _selectSubtitlesFromContextMenu(service, state),
                        onShowChannelInfo: () =>
                            _showChannelInfoFromContextMenu(state),
                        onShowDiagnostics: () =>
                            _showDiagnosticsFromContextMenu(state),
                        onCopyStreamLink: () =>
                            _copyStreamLinkFromContextMenu(state),
                        onClose: _closeContextMenu,
                      ),

                    // UP/DOWN quick-browse overlays.
                    if (_quickBrowse == _TvQuickBrowse.miniGuide &&
                        state.currentChannel != null)
                      _QuickBrowseOverlay(
                        title: 'Mini guide',
                        channels: _miniGuideChannels(state.currentChannel!),
                        currentChannelId: state.currentChannel!.id,
                        onSelected: _playChannelFromQuickBrowse,
                      ),
                    if (_quickBrowse == _TvQuickBrowse.recent)
                      Consumer(
                        builder: (context, ref, _) {
                          final recent = ref.watch(
                            recentlyWatchedChannelsProvider,
                          );
                          return recent.when(
                            data: (channels) => channels.isEmpty
                                ? const SizedBox.shrink()
                                : _QuickBrowseOverlay(
                                    title: 'Recently watched',
                                    channels: channels,
                                    currentChannelId: state.currentChannel?.id,
                                    onSelected: _playChannelFromQuickBrowse,
                                  ),
                            loading: () => const SizedBox.shrink(),
                            error: (_, _) => const SizedBox.shrink(),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            Text(
              AiroVoice.buffering.pick(),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  String? _recoveryFocusToken(StreamingState state) {
    final diagnostic = state.diagnostic;
    if (!state.hasError || diagnostic == null) return null;
    return '${state.currentChannel?.id}|${diagnostic.code}|${state.retryCount}';
  }

  void _scheduleRecoveryFocus(StreamingState state) {
    final token = _recoveryFocusToken(state);
    if (token == null) {
      final wasShowingRecovery = _lastRecoveryFocusToken != null;
      _lastRecoveryFocusToken = null;
      if (wasShowingRecovery && _hideControlsTimer == null) {
        _startHideControlsTimer();
      }
      return;
    }
    _cancelHideControlsTimer();
    if (_lastRecoveryFocusToken == token) return;
    _lastRecoveryFocusToken = token;
    final diagnostic = state.diagnostic!;
    final target = !diagnostic.retryEligible || state.retryCount == 0
        ? _diagnosticRetryFocusNode
        : _diagnosticSkipFocusNode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _lastRecoveryFocusToken != token) return;
      if (target.canRequestFocus) target.requestFocus();
    });
  }

  void _scheduleGenericRecoveryFocus(String message) {
    final token = 'generic|$message';
    if (_lastRecoveryFocusToken == token) return;
    _lastRecoveryFocusToken = token;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _lastRecoveryFocusToken != token) return;
      if (_genericRetryFocusNode.canRequestFocus) {
        _genericRetryFocusNode.requestFocus();
      }
    });
  }

  /// CV-001 structured failure state: user-safe copy plus bounded-retry
  /// progress from [StreamingState.diagnostic], with the legacy retry button.
  Widget _buildDiagnosticError(StreamingState state) {
    final diagnostic = state.diagnostic!;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blueGrey.shade900, Colors.black87],
        ),
      ),
      // The transport controls overlay (play/pause, scrub bar) is always
      // present in the same Stack, faded in/out by opacity rather than
      // removed — a vertically-centered error message can grow tall enough
      // to sit under the bottom control bar. Anchoring to the upper band
      // guarantees no collision regardless of message length.
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PlaybackDiagnosticOverlay(
                diagnostic: diagnostic,
                retryAttempt: state.retryCount > 0 ? state.retryCount : null,
                maxRetryAttempts: 3,
              ),
              const SizedBox(height: 16),
              // issues/04-recovery-states.md acceptance criterion 1: three
              // distinct outcomes, not just retry -- and every one of them
              // must be D-pad reachable (the old ElevatedButton had no
              // TvFocusable, so a remote-only viewer could never reach it).
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (!diagnostic.retryEligible || state.retryCount == 0)
                    _RecoveryActionButton(
                      key: const ValueKey('diagnostic-error-retry'),
                      focusNode: _diagnosticRetryFocusNode,
                      icon: Icons.refresh_rounded,
                      label: 'Try Again',
                      autofocus: true,
                      onSelect: () =>
                          ref.read(iptvStreamingServiceProvider).retry(),
                    ),
                  _RecoveryActionButton(
                    key: const ValueKey('diagnostic-error-skip'),
                    focusNode: _diagnosticSkipFocusNode,
                    icon: Icons.skip_next_rounded,
                    label: 'Skip channel',
                    autofocus: diagnostic.retryEligible && state.retryCount > 0,
                    onSelect: _goToNextChannel,
                  ),
                  _RecoveryActionButton(
                    key: const ValueKey('diagnostic-error-report'),
                    focusNode: _diagnosticReportFocusNode,
                    icon: Icons.flag_outlined,
                    label: 'Report dead link',
                    onSelect: () => _saveDeadLinkReport(state, diagnostic),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveDeadLinkReport(
    StreamingState state,
    AiroPlaybackDiagnostic diagnostic,
  ) async {
    final channel = state.currentChannel;
    if (channel == null) return;
    await ref
        .read(deadLinkReportStorageProvider)
        .save(
          DeadLinkReport(
            channelName: channel.name,
            diagnosticCode: diagnostic.code.name,
            userMessage: diagnostic.userMessage,
            technicalDetail: diagnostic.technicalDetail,
            reportedAt: DateTime.now(),
          ),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Saved locally — nothing was sent')),
      );
  }

  Widget _buildError(String message) {
    _scheduleGenericRecoveryFocus(message);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blueGrey.shade900, Colors.black87],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Error icon with subtle animation effect
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.redAccent,
                  size: 56,
                ),
              ),
              const SizedBox(height: 20),
              // Primary error message
              const Text(
                'Unable to play this channel',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // Secondary message (technical details)
              Text(
                message,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              // TvFocusable-wrapped so a remote-only viewer can reach it --
              // the bare ElevatedButton this replaced was the same class of
              // bug already fixed for the diagnostic error screen below.
              _RecoveryActionButton(
                key: const ValueKey('iptv-player-error-retry'),
                focusNode: _genericRetryFocusNode,
                icon: Icons.refresh_rounded,
                label: 'Try Again',
                autofocus: true,
                onSelect: () => ref.read(iptvStreamingServiceProvider).retry(),
              ),
              const SizedBox(height: 12),
              // Hint text
              Text(
                'The stream may be temporarily unavailable',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(StreamingState state) {
    final channel = state.currentChannel;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blueGrey.shade900, Colors.black],
        ),
      ),
      child: Center(
        child: channel != null && channel.hasLogo
            ? AiroNetworkImage(
                url: channel.logoUrl!,
                width: 120,
                height: 120,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    _buildDefaultPlaceholder(),
              )
            : _buildDefaultPlaceholder(),
      ),
    );
  }

  Widget _buildDefaultPlaceholder() {
    return IptvIconPlaceholder.videoPlayer();
  }

  Widget _buildControlsOverlay(
    BuildContext context,
    VideoPlayerStreamingService service,
    StreamingState state,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Decorative gradient backdrop only — wrapped in IgnorePointer so it
        // never hit-tests. The real controls live in `_buildControlButtons`
        // below as separate hit-testable siblings.
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black54,
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black54,
                ],
              ),
            ),
          ),
        ),
        _buildControlButtons(context, service, state),
      ],
    );
  }

  Widget _buildControlButtons(
    BuildContext context,
    VideoPlayerStreamingService service,
    StreamingState state,
  ) {
    if (_usesCompactInlinePlayer(context)) {
      return _buildCompactControlButtons(context, service, state);
    }
    if (widget.useTvTransportBar) {
      return _buildTvTransportBar(context, service, state);
    }
    return _buildExpandedControlButtons(context, service, state);
  }

  Widget _buildExpandedControlButtons(
    BuildContext context,
    VideoPlayerStreamingService service,
    StreamingState state,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Channel logo/name row removed (CV-017 PlayerOverlay migration):
        // the PlayerOverlay layer mounted above this one now owns the
        // title/subtitle chrome, built from the same StreamingState via
        // _toPlayerViewState.
        Positioned(
          top: 76,
          left: 16,
          child: SafeArea(
            bottom: false,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PlayerRoundControlButton(
                  key: const ValueKey('iptv-player-fullscreen-button'),
                  icon: _isFullscreen
                      ? Icons.fullscreen_exit
                      : Icons.fullscreen,
                  tooltip: _isFullscreen ? 'Exit fullscreen' : 'Fullscreen',
                  onPressed: _toggleFullscreen,
                  diameter: 44,
                  iconSize: 24,
                  backgroundAlpha: 0.48,
                ),
                if (widget.showPictureInPicture) ...[
                  const SizedBox(width: 10),
                  _PlayerRoundControlButton(
                    key: const ValueKey('iptv-player-pip-button'),
                    icon: Icons.picture_in_picture_alt_outlined,
                    tooltip: 'Picture-in-picture',
                    onPressed: _requestPictureInPicture,
                    diameter: 44,
                    iconSize: 22,
                    backgroundAlpha: 0.48,
                  ),
                ],
                const SizedBox(width: 10),
                _PlayerRoundControlButton(
                  key: const ValueKey('iptv-player-random-channel-button'),
                  icon: Icons.casino_outlined,
                  tooltip: 'Random channel',
                  onPressed: () => _playRandomFilteredChannel(service),
                  diameter: 44,
                  iconSize: 22,
                  backgroundAlpha: 0.48,
                ),
              ],
            ),
          ),
        ),
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _PlayerRoundControlButton(
                    key: const ValueKey('iptv-player-dvr-rewind-button'),
                    icon: Icons.replay_10,
                    tooltip: state.isLiveStream
                        ? 'Rewind 10 seconds'
                        : 'Back 10 seconds',
                    onPressed:
                        state.canSeekBack ||
                            (!state.isLiveStream &&
                                state.position > Duration.zero)
                        ? () => _seekBackward10(service, state)
                        : null,
                    diameter: 72,
                    iconSize: 34,
                  ),
                  const SizedBox(width: 22),
                  _buildCenterButton(service, state),
                  const SizedBox(width: 22),
                  _PlayerRoundControlButton(
                    key: const ValueKey('iptv-player-mute-button'),
                    icon: state.isMuted || state.volume == 0
                        ? Icons.volume_off
                        : state.volume < 0.5
                        ? Icons.volume_down
                        : Icons.volume_up,
                    tooltip: state.isMuted ? 'Unmute' : 'Mute',
                    onPressed: () => service.toggleMute(),
                    diameter: 64,
                    iconSize: 28,
                    backgroundColor: state.isMuted || state.volume == 0
                        ? Colors.green
                        : null,
                  ),
                  const SizedBox(width: 24),
                  _PlayerStepperPillar(
                    label: 'VOL',
                    topKey: const ValueKey('iptv-player-volume-up-button'),
                    bottomKey: const ValueKey('iptv-player-volume-down-button'),
                    topIcon: Icons.add,
                    bottomIcon: Icons.remove,
                    topTooltip: 'Volume up',
                    bottomTooltip: 'Volume down',
                    onTopPressed: () => _stepVolume(service, state, 0.1),
                    onBottomPressed: () => _stepVolume(service, state, -0.1),
                  ),
                  if (widget.enableSwipeChannelChange) ...[
                    const SizedBox(width: 22),
                    _PlayerStepperPillar(
                      label: 'CH',
                      topKey: const ValueKey('iptv-player-channel-next-button'),
                      bottomKey: const ValueKey(
                        'iptv-player-channel-previous-button',
                      ),
                      topIcon: Icons.keyboard_arrow_up,
                      bottomIcon: Icons.keyboard_arrow_down,
                      topTooltip: 'Next channel',
                      bottomTooltip: 'Previous channel',
                      onTopPressed: _goToNextChannel,
                      onBottomPressed: _goToPreviousChannel,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTimelineAndMoreButton(context, service, state),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// AiroTV D-pad design's TRANSPORT (OK) screen: a metadata row that never
  /// overlaps the button row below it, six action buttons matching the
  /// prototype exactly (Pause, Restart, Audio, Subtitles, Favourite, Info),
  /// and a "MENU for more actions" hint. Every button is wired to a real,
  /// already-existing capability -- Info opens channel actions, rather than
  /// a new stub panel.
  Widget _buildTvTransportBar(
    BuildContext context,
    VideoPlayerStreamingService service,
    StreamingState state,
  ) {
    final channel = state.currentChannel;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Metadata row — sits above the buttons, never overlaps them.
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      (channel?.name.trim().isNotEmpty ?? false)
                          ? channel!.name.trim()[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            if (state.isLiveStream)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            if (state.isLiveStream) const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                [
                                  if (channel?.group.trim().isNotEmpty ?? false)
                                    channel!.group,
                                  state.currentQuality.label,
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          channel?.name ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Buttons row. The button group scrolls horizontally instead
              // of being a fixed Row -- six buttons (two labeled with
              // longer strings than the prototype's placeholder text) plus
              // the MENU hint don't reliably fit the safe-area width on
              // every real panel size, and overflowing here would crash
              // the frame rather than just clip.
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  ..._buildTvTransportButtons(context, service, state),
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Text(
                      'MENU for more actions',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTvTransportButtons(
    BuildContext context,
    VideoPlayerStreamingService service,
    StreamingState state,
  ) {
    final channel = state.currentChannel;
    final favoriteIds = ref.watch(favoriteChannelIdsProvider).asData?.value;
    final isFavorite =
        channel != null && (favoriteIds?.contains(channel.id) ?? false);
    final canRewind =
        state.canSeekBack ||
        (!state.isLiveStream && state.position > Duration.zero);

    return [
      TvFocusable(
        key: const ValueKey('iptv-tv-transport-play-pause'),
        focusNode: _centerControlFocusNode,
        autofocus: true,
        onSelect: () {
          if (state.isLiveStream && state.isBehindLive && state.isPlaying) {
            service.goLive();
          } else if (state.isPlaying) {
            service.pause();
          } else {
            service.resume();
          }
        },
        borderRadius: 10,
        semanticLabel: state.isPlaying ? 'Pause' : 'Play',
        child: _TvTransportButton(
          icon: state.isPlaying
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
        ),
      ),
      TvFocusable(
        key: const ValueKey('iptv-tv-transport-restart'),
        onSelect: canRewind ? () => _seekBackward10(service, state) : null,
        borderRadius: 10,
        semanticLabel: state.isLiveStream
            ? 'Rewind 10 seconds'
            : 'Back 10 seconds',
        child: const _TvTransportButton(icon: Icons.skip_previous_rounded),
      ),
      TvFocusable(
        key: const ValueKey('iptv-tv-transport-audio'),
        focusNode: _audioTransportFocusNode,
        onSelect: () => unawaited(
          _showTrackSelectorFor(
            context,
            service,
            state,
            kind: AiroPlaybackTrackKind.audio,
            restoreFocusNode: _audioTransportFocusNode,
          ),
        ),
        borderRadius: 10,
        semanticLabel: 'Audio',
        child: const _TvTransportButton(
          icon: Icons.volume_up_outlined,
          label: 'Audio',
        ),
      ),
      TvFocusable(
        key: const ValueKey('iptv-tv-transport-subtitles'),
        focusNode: _subtitleTransportFocusNode,
        onSelect: () => unawaited(
          _showTrackSelector(
            context,
            service,
            state,
            restoreFocusNode: _subtitleTransportFocusNode,
          ),
        ),
        borderRadius: 10,
        semanticLabel: 'Subtitles',
        child: const _TvTransportButton(
          icon: Icons.subtitles_outlined,
          label: 'Subtitles',
        ),
      ),
      TvFocusable(
        key: const ValueKey('iptv-tv-transport-favourite'),
        onSelect: channel == null ? null : _toggleFavoriteForCurrentChannel,
        borderRadius: 10,
        semanticLabel: isFavorite
            ? 'Remove from favourites'
            : 'Add to favourites',
        child: _TvTransportButton(
          icon: isFavorite
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          label: 'Favourite',
        ),
      ),
      TvFocusable(
        key: const ValueKey('iptv-tv-transport-info'),
        focusNode: _infoFocusNode,
        onSelect: channel == null
            ? null
            : () => _openContextMenu(restoreFocusNode: _infoFocusNode),
        borderRadius: 10,
        semanticLabel: 'Info',
        child: const _TvTransportButton(
          icon: Icons.info_outline_rounded,
          label: 'Info',
        ),
      ),
      TvFocusable(
        key: const ValueKey('iptv-player-more-button'),
        focusNode: _moreActionsFocusNode,
        onSelect: () => _showPlayerActionsSheet(
          context,
          service,
          state,
          restoreFocusNode: _moreActionsFocusNode,
        ),
        borderRadius: 10,
        semanticLabel: 'More player actions',
        child: const _TvTransportButton(
          icon: Icons.more_horiz_rounded,
          label: 'More',
        ),
      ),
    ];
  }

  Widget _buildCompactControlButtons(
    BuildContext context,
    VideoPlayerStreamingService service,
    StreamingState state,
  ) {
    final canRewind =
        state.canSeekBack ||
        (!state.isLiveStream && state.position > Duration.zero);
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(child: _buildCenterButton(service, state)),
        Positioned(
          left: 12,
          bottom: 8,
          child: SafeArea(
            top: false,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canRewind)
                  _PlayerFloatingControlButton(
                    key: const ValueKey('iptv-player-dvr-rewind-button'),
                    icon: Icons.replay_10,
                    tooltip: state.isLiveStream
                        ? 'Rewind 10 seconds'
                        : 'Back 10 seconds',
                    onPressed: () => _seekBackward10(service, state),
                  ),
                _PlayerFloatingControlButton(
                  key: const ValueKey('iptv-player-mute-button'),
                  icon: state.isMuted || state.volume == 0
                      ? Icons.volume_off
                      : state.volume < 0.5
                      ? Icons.volume_down
                      : Icons.volume_up,
                  tooltip: state.isMuted ? 'Unmute' : 'Mute',
                  onPressed: () => service.toggleMute(),
                ),
                _PlayerFloatingControlButton(
                  key: const ValueKey('iptv-player-volume-down-button'),
                  icon: Icons.remove,
                  tooltip: 'Volume down',
                  onPressed: () => _stepVolume(service, state, -0.1),
                ),
                _PlayerFloatingControlButton(
                  key: const ValueKey('iptv-player-volume-up-button'),
                  icon: Icons.add,
                  tooltip: 'Volume up',
                  onPressed: () => _stepVolume(service, state, 0.1),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 8,
          child: SafeArea(
            top: false,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (widget.enableSwipeChannelChange) ...[
                  _PlayerFloatingControlButton(
                    key: const ValueKey('iptv-player-channel-previous-button'),
                    icon: Icons.keyboard_arrow_down,
                    tooltip: 'Previous channel',
                    onPressed: _goToPreviousChannel,
                  ),
                  _PlayerFloatingControlButton(
                    key: const ValueKey('iptv-player-channel-next-button'),
                    icon: Icons.keyboard_arrow_up,
                    tooltip: 'Next channel',
                    onPressed: _goToNextChannel,
                  ),
                ],
                _PlayerFloatingControlButton(
                  key: const ValueKey('iptv-player-random-channel-button'),
                  icon: Icons.casino_outlined,
                  tooltip: 'Random channel',
                  onPressed: () => _playRandomFilteredChannel(service),
                ),
                _PlayerFloatingControlButton(
                  key: const ValueKey('iptv-player-more-button'),
                  icon: Icons.settings_outlined,
                  tooltip: 'Player settings',
                  onPressed: () => _showPlayerActionsSheet(
                    context,
                    service,
                    state,
                    restoreFocusNode: _centerControlFocusNode,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  bool _usesCompactInlinePlayer(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return !_isFullscreen && size.shortestSide < 600;
  }

  Widget _buildTimelineAndMoreButton(
    BuildContext context,
    VideoPlayerStreamingService service,
    StreamingState state,
  ) {
    final isVod = !state.isLiveStream && state.duration > Duration.zero;
    final displayPosition = _vodSeekDragPosition ?? state.position;
    final remaining = isVod
        ? state.duration - displayPosition
        : state.liveDelay;
    final rightLabel = isVod
        ? '-${_formatDuration(_nonNegativeDuration(remaining))}'
        : state.liveDelay > Duration.zero
        ? '-${_formatDuration(state.liveDelay)}'
        : 'LIVE';

    return Row(
      children: [
        Text(
          _formatDuration(displayPosition),
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: isVod
              ? Material(
                  type: MaterialType.transparency,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 5,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                    ),
                    child: Slider(
                      key: const ValueKey('iptv-player-vod-seek-bar'),
                      value: displayPosition.inMilliseconds.toDouble().clamp(
                        0.0,
                        state.duration.inMilliseconds.toDouble(),
                      ),
                      min: 0,
                      max: state.duration.inMilliseconds.toDouble(),
                      activeColor: Colors.white,
                      inactiveColor: Colors.white38,
                      onChanged: (value) {
                        setState(() {
                          _vodSeekDragPosition = Duration(
                            milliseconds: value.round(),
                          );
                        });
                      },
                      onChangeEnd: (value) {
                        final target = Duration(milliseconds: value.round());
                        service.seek(target);
                        setState(() => _vodSeekDragPosition = null);
                      },
                    ),
                  ),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 5,
                    value: _liveProgressValue(state),
                    backgroundColor: Colors.white38,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Text(
          rightLabel,
          style: TextStyle(
            color: rightLabel == 'LIVE' ? Colors.redAccent : Colors.white,
            fontSize: 18,
            fontWeight: rightLabel == 'LIVE' ? FontWeight.w700 : null,
          ),
        ),
        const SizedBox(width: 14),
        _PlayerRoundControlButton(
          key: const ValueKey('iptv-player-more-button'),
          icon: Icons.settings_outlined,
          tooltip: 'Player settings',
          onPressed: () => _showPlayerActionsSheet(
            context,
            service,
            state,
            restoreFocusNode: _centerControlFocusNode,
          ),
          diameter: 44,
          iconSize: 24,
          backgroundAlpha: 0.48,
        ),
      ],
    );
  }

  double? _liveProgressValue(StreamingState state) {
    if (!state.hasDvrSupport) return null;
    final window = state.dvrWindowDuration;
    if (window == null || window <= Duration.zero) return null;

    final positionInWindow = state.dvrWindowStart == null
        ? window - state.liveDelay
        : state.position - state.dvrWindowStart!;
    return positionInWindow.inMilliseconds.toDouble().clamp(
          0.0,
          window.inMilliseconds.toDouble(),
        ) /
        window.inMilliseconds;
  }

  Duration _nonNegativeDuration(Duration duration) {
    return duration.isNegative ? Duration.zero : duration;
  }

  Future<void> _showPlayerActionsSheet(
    BuildContext context,
    VideoPlayerStreamingService service,
    StreamingState state, {
    required FocusNode restoreFocusNode,
  }) async {
    if (_playerModalOpen) return;
    final hasQualityChoices = _qualityOptionsFor(state).length > 1;
    final hasSubtitles = _subtitleTracksFor(state).isNotEmpty;
    _cancelHideControlsTimer();
    setState(() => _playerModalOpen = true);
    try {
      await showModalBottomSheet<void>(
        context: context,
        requestFocus: true,
        builder: (sheetContext) {
          Future<void> afterSheet(VoidCallback action) async {
            Navigator.of(sheetContext).pop();
            await Future<void>.delayed(const Duration(milliseconds: 250));
            if (!mounted) return;
            action();
          }

          return _TvModalFocusScope(
            initialFocusNode: _playerActionsAudioFocusNode,
            child: SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  const ListTile(
                    title: Text('Player actions'),
                    subtitle: Text('Secondary controls for this stream'),
                  ),
                  if (widget.showPictureInPicture)
                    _TvSheetListTile(
                      itemKey: const ValueKey('iptv-player-pip-menu-action'),
                      leading: const Icon(
                        Icons.picture_in_picture_alt_outlined,
                      ),
                      title: const Text('Picture-in-picture'),
                      onSelect: () =>
                          unawaited(afterSheet(_requestPictureInPicture)),
                    ),
                  if (hasQualityChoices)
                    _TvSheetListTile(
                      itemKey: const ValueKey(
                        'iptv-player-quality-menu-action',
                      ),
                      focusNode: _playerActionsQualityFocusNode,
                      leading: const Icon(Icons.hd_outlined),
                      title: const Text('Quality'),
                      subtitle: Text(state.currentQuality.label),
                      onSelect: () => unawaited(
                        _showQualitySelector(
                          sheetContext,
                          service,
                          state,
                          restoreFocusNode: _playerActionsQualityFocusNode,
                        ),
                      ),
                    ),
                  if (hasSubtitles)
                    _TvSheetListTile(
                      itemKey: const ValueKey(
                        'iptv-player-subtitle-menu-action',
                      ),
                      focusNode: _playerActionsSubtitleFocusNode,
                      leading: Icon(
                        state.selectedTrackIds.containsKey(
                              AiroPlaybackTrackKind.subtitle,
                            )
                            ? Icons.subtitles
                            : Icons.subtitles_off_outlined,
                      ),
                      title: const Text('Subtitles'),
                      onSelect: () => unawaited(
                        _showTrackSelector(
                          sheetContext,
                          service,
                          state,
                          restoreFocusNode: _playerActionsSubtitleFocusNode,
                        ),
                      ),
                    ),
                  _TvSheetListTile(
                    itemKey: const ValueKey(
                      'iptv-player-audio-only-menu-action',
                    ),
                    focusNode: _playerActionsAudioFocusNode,
                    leading: Icon(
                      _isAudioOnly ? Icons.hearing : Icons.hearing_disabled,
                    ),
                    title: Text(
                      _isAudioOnly ? 'Exit audio-only' : 'Listen only',
                    ),
                    onSelect: () => unawaited(afterSheet(_toggleAudioOnly)),
                  ),
                  _TvSheetListTile(
                    itemKey: const ValueKey(
                      'iptv-player-aspect-ratio-menu-action',
                    ),
                    leading: const Icon(Icons.aspect_ratio),
                    title: const Text('Aspect ratio'),
                    onSelect: () => unawaited(
                      afterSheet(
                        () => ref
                            .read(videoAspectRatioProvider.notifier)
                            .cycleToNext(),
                      ),
                    ),
                  ),
                  _TvSheetListTile(
                    itemKey: const ValueKey('iptv-player-cinema-menu-action'),
                    leading: Icon(
                      _isCinemaMode ? Icons.wb_sunny : Icons.theaters,
                    ),
                    title: Text(
                      _isCinemaMode ? 'Standard mode' : 'Cinema mode',
                    ),
                    onSelect: () => unawaited(
                      afterSheet(
                        () => setState(() => _isCinemaMode = !_isCinemaMode),
                      ),
                    ),
                  ),
                  _TvSheetListTile(
                    itemKey: const ValueKey(
                      'iptv-player-fullscreen-menu-action',
                    ),
                    leading: Icon(
                      _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    ),
                    title: Text(
                      _isFullscreen ? 'Exit fullscreen' : 'Fullscreen',
                    ),
                    onSelect: () => unawaited(afterSheet(_toggleFullscreen)),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() => _playerModalOpen = false);
        _startHideControlsTimer();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && restoreFocusNode.canRequestFocus) {
            restoreFocusNode.requestFocus();
          }
        });
      }
    }
  }

  /// CV-016: VOD resume. Seeks to a saved position once per channel per
  /// session (never overriding a later user seek on rebuild), and
  /// periodically persists the current position so it survives a restart.
  /// A no-op for live streams -- see [VodResumeCoordinator].
  void _handleVodResume(
    VideoPlayerStreamingService service,
    StreamingState state,
  ) {
    final channel = state.currentChannel;
    if (channel == null) return;

    // Mirrors every other storage-backed provider's load/save pattern in
    // this package (e.g. VideoAspectRatioNotifier, CaptionPreferenceNotifier):
    // a storage failure must never crash the scheduler callback that runs
    // on every frame.
    try {
      final coordinator = ref.read(vodResumeCoordinatorProvider);
      unawaited(
        coordinator
            .maybeResumePosition(
              channelId: channel.id,
              isLiveStream: state.isLiveStream,
              duration: state.duration,
            )
            .then((resumePosition) {
              if (resumePosition != null && mounted) {
                service.seek(resumePosition);
              }
            }),
      );
      unawaited(
        coordinator.saveProgressIfDue(
          channelId: channel.id,
          isLiveStream: state.isLiveStream,
          position: state.position,
          duration: state.duration,
          now: DateTime.now(),
        ),
      );
    } catch (e) {
      debugPrint('Failed to check/save VOD resume position: $e');
    }
  }

  /// CV-008 handoff: when captions are enabled and a subtitle track matches
  /// the user's preferred language, select it automatically once the engine
  /// exposes tracks. A no-op when the preference is disabled (the engine's
  /// own default selection stands) or no track matches -- captions stay off
  /// rather than falling back to a language the user didn't ask for.
  void _applyCaptionPreferenceIfNeeded(
    VideoPlayerStreamingService service,
    StreamingState state,
  ) {
    final preference = ref.read(captionPreferenceProvider);
    if (!preference.enabled || preference.languageCode == null) return;

    final alreadySelected =
        state.selectedTrackIds[AiroPlaybackTrackKind.subtitle];
    for (final track in state.tracks) {
      if (track.kind == AiroPlaybackTrackKind.subtitle &&
          track.languageCode == preference.languageCode) {
        if (alreadySelected != track.id) {
          service.selectTrack(kind: track.kind, trackId: track.id);
        }
        return;
      }
    }
  }

  Future<void> _showTrackSelector(
    BuildContext context,
    VideoPlayerStreamingService service,
    StreamingState state, {
    FocusNode? restoreFocusNode,
  }) {
    return _showTrackSelectorFor(
      context,
      service,
      state,
      kind: AiroPlaybackTrackKind.subtitle,
      offLabel: 'Off',
      offIcon: Icons.subtitles_off_outlined,
      restoreFocusNode: restoreFocusNode,
    );
  }

  /// Shared by the subtitle picker (kept above for its existing call site)
  /// and the TV transport bar's Audio button -- same engine concept
  /// (`state.tracks`/`selectTrack`), just filtered to a different
  /// [AiroPlaybackTrackKind]. Audio has no "Off" row: unlike subtitles,
  /// there's no meaningful silent-track state to offer.
  Future<void> _showTrackSelectorFor(
    BuildContext context,
    VideoPlayerStreamingService service,
    StreamingState state, {
    required AiroPlaybackTrackKind kind,
    String? offLabel,
    IconData? offIcon,
    FocusNode? restoreFocusNode,
  }) async {
    final tracks = state.tracks
        .where((track) => track.kind == kind)
        .toList(growable: false);
    final selectedTrackId = state.selectedTrackIds[kind];
    final noneSelected = selectedTrackId == null;
    final options = <_TvSheetOption>[
      if (offLabel != null)
        _TvSheetOption(
          label: offLabel,
          leading: offIcon == null ? null : Icon(offIcon),
          selected: noneSelected,
          onSelect: () => service.clearTrackSelection(kind),
        ),
      for (final track in tracks)
        _TvSheetOption(
          label: track.label,
          subtitle: track.isExternal ? const Text('External') : null,
          selected: selectedTrackId == track.id,
          onSelect: () =>
              service.selectTrack(kind: track.kind, trackId: track.id),
        ),
    ];
    final selectedIndex = options.indexWhere((option) => option.selected);
    try {
      await showModalBottomSheet<void>(
        context: context,
        requestFocus: true,
        builder: (selectorContext) => _TvSelectionSheet(
          debugLabelPrefix: 'player ${kind.name} option',
          options: options,
          initialIndex: selectedIndex < 0 ? 0 : selectedIndex,
        ),
      );
    } finally {
      if (mounted && restoreFocusNode != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && restoreFocusNode.canRequestFocus) {
            restoreFocusNode.requestFocus();
          }
        });
      }
    }
  }

  Future<void> _showQualitySelector(
    BuildContext context,
    VideoPlayerStreamingService service,
    StreamingState state, {
    FocusNode? restoreFocusNode,
  }) async {
    final options = _qualityOptionsFor(state);
    final sheetOptions = [
      for (final quality in options)
        _TvSheetOption(
          label: quality.label,
          selected: state.selectedQuality == quality,
          onSelect: () => service.setQuality(quality),
        ),
    ];
    final selectedIndex = sheetOptions.indexWhere((option) => option.selected);
    try {
      await showModalBottomSheet<void>(
        context: context,
        requestFocus: true,
        builder: (selectorContext) => _TvSelectionSheet(
          debugLabelPrefix: 'player quality option',
          options: sheetOptions,
          initialIndex: selectedIndex < 0 ? 0 : selectedIndex,
        ),
      );
    } finally {
      if (mounted && restoreFocusNode != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && restoreFocusNode.canRequestFocus) {
            restoreFocusNode.requestFocus();
          }
        });
      }
    }
  }

  List<AiroPlaybackTrackOption> _subtitleTracksFor(StreamingState state) {
    return state.tracks
        .where((track) => track.kind == AiroPlaybackTrackKind.subtitle)
        .toList(growable: false);
  }

  List<VideoQuality> _qualityOptionsFor(StreamingState state) {
    final qualityUrls = state.currentChannel?.qualityUrls;
    if (qualityUrls == null || qualityUrls.isEmpty) {
      return const [VideoQuality.auto];
    }
    return VideoQuality.values
        .where(
          (quality) =>
              quality == VideoQuality.auto ||
              qualityUrls.containsKey(quality.name),
        )
        .toList(growable: false);
  }

  /// Builds the center button - either "Go Live" or play/pause based on state
  ///
  /// Behavior:
  /// - Behind live (delay > 3s): Shows "Go Live" button with red styling
  /// - At live edge & playing: Shows pause button
  /// - At live edge & paused: Shows play button
  Widget _buildCenterButton(
    VideoPlayerStreamingService service,
    StreamingState state,
  ) {
    // Check if we should show "Go Live" (behind live by more than 3 seconds)
    // But NOT when paused - paused should show play button
    final showGoLive =
        state.isLiveStream && state.isBehindLive && state.isPlaying;

    if (showGoLive) {
      // "Go Live" button - red themed to indicate user is behind
      return TvFocusable(
        focusNode: _centerControlFocusNode,
        onSelect: () => service.goLive(),
        semanticLabel: 'Go live',
        borderRadius: 40,
        child: GestureDetector(
          onTap: () => service.goLive(),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.red.shade700,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.skip_next_rounded, color: Colors.white, size: 32),
                Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Standard play/pause button — translucent white circle behind a dark
    // glyph, matching the design handoff's player chrome.
    void togglePlayPause() {
      if (state.isPlaying) {
        service.pause();
      } else {
        service.resume();
      }
    }

    return TvFocusable(
      focusNode: _centerControlFocusNode,
      onSelect: togglePlayPause,
      semanticLabel: state.isPlaying ? 'Pause' : 'Play',
      borderRadius: 35,
      child: GestureDetector(
        onTap: togglePlayPause,
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 24,
              ),
            ],
          ),
          child: Icon(
            state.isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.black,
            size: 32,
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final hours = d.inHours;
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  /// Builds the renderer-agnostic [PlayerViewState] the new [PlayerOverlay]
  /// chrome renders from — the only bridge between engine-facing
  /// [StreamingState] and the overlay, which must never see engine types.
  PlayerViewState _toPlayerViewState(StreamingState state) {
    return PlayerViewState(
      playback: state.playbackState,
      liveState: state.liveStreamState,
      networkQuality: state.metrics?.networkQuality ?? NetworkQuality.good,
      bufferSeconds: state.bufferStatus.bufferedAhead.inSeconds,
      qualityLabel: state.currentQuality.label,
      title: state.currentChannel?.name ?? '',
      subtitle: state.currentChannel?.group ?? '',
      // Live while a multi-source failover switch is in flight (see
      // VideoPlayerStreamingService's failover loop); null otherwise.
      failover: state.failover,
    );
  }

  /// Maps the view-layer [AiroPlaybackViewFit] contract to a concrete
  /// [BoxFit]. `fill` keeps the full frame (letterboxed on one axis only,
  /// matching the common TV "fill width" mode); `stretch` is Flutter's
  /// [BoxFit.fill] — a full non-uniform stretch to the edges.
  BoxFit _boxFitFor(AiroPlaybackViewFit fit) {
    switch (fit) {
      case AiroPlaybackViewFit.contain:
        return BoxFit.contain;
      case AiroPlaybackViewFit.cover:
        return BoxFit.cover;
      case AiroPlaybackViewFit.fill:
        return BoxFit.fitWidth;
      case AiroPlaybackViewFit.stretch:
        return BoxFit.fill;
    }
  }
}

/// Compact control-bar icon button for the phone inline player.
///
/// Keep the target at 44dp even when the row scrolls horizontally: the
/// controls are useless if they fit visually but are too small to hit on a
/// real phone.
class _PlayerControlButton extends StatelessWidget {
  const _PlayerControlButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = onPressed == null
        ? Colors.white.withValues(alpha: 0.38)
        : iconColor;
    return IconButton(
      icon: Icon(icon, color: effectiveColor, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
    );
  }
}

class _PlayerFloatingControlButton extends StatelessWidget {
  const _PlayerFloatingControlButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return _PlayerRoundControlButton(
      icon: icon,
      tooltip: tooltip,
      onPressed: onPressed,
      diameter: 44,
      iconSize: 20,
      backgroundAlpha: 0.54,
    );
  }
}

class _PlayerRoundControlButton extends StatelessWidget {
  const _PlayerRoundControlButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.backgroundColor,
    this.backgroundAlpha = 0.64,
    this.diameter = 64,
    this.iconSize = 28,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? backgroundColor;
  final double backgroundAlpha;
  final double diameter;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = onPressed == null
        ? Colors.white.withValues(alpha: 0.38)
        : Colors.white;
    return TvFocusable(
      enabled: onPressed != null,
      onSelect: onPressed,
      semanticLabel: tooltip,
      borderRadius: diameter / 2,
      child: Material(
        color:
            backgroundColor ?? Colors.black.withValues(alpha: backgroundAlpha),
        shape: const CircleBorder(),
        elevation: 8,
        shadowColor: Colors.black54,
        child: SizedBox.square(
          dimension: diameter,
          // The TvFocusable wrapper owns D-pad focus for this control;
          // letting the inner IconButton take focus too would create two
          // stops per button under the remote.
          child: ExcludeFocus(
            child: IconButton(
              icon: Icon(icon, color: effectiveColor, size: iconSize),
              tooltip: tooltip,
              onPressed: onPressed,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerStepperPillar extends StatelessWidget {
  const _PlayerStepperPillar({
    required this.label,
    required this.topKey,
    required this.bottomKey,
    required this.topIcon,
    required this.bottomIcon,
    required this.topTooltip,
    required this.bottomTooltip,
    required this.onTopPressed,
    required this.onBottomPressed,
  });

  final String label;
  final Key topKey;
  final Key bottomKey;
  final IconData topIcon;
  final IconData bottomIcon;
  final String topTooltip;
  final String bottomTooltip;
  final VoidCallback? onTopPressed;
  final VoidCallback? onBottomPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 18,
          ),
        ],
      ),
      child: SizedBox(
        width: 82,
        height: 210,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _PlayerControlButton(
              key: topKey,
              icon: topIcon,
              tooltip: topTooltip,
              onPressed: onTopPressed,
              iconColor: Colors.white,
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            _PlayerControlButton(
              key: bottomKey,
              icon: bottomIcon,
              tooltip: bottomTooltip,
              onPressed: onBottomPressed,
              iconColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

/// Right-side overlay panel for actions on the currently-playing channel.
enum _TvQuickBrowse { miniGuide, recent }

/// Bottom-docked horizontal browse strip for UP (Mini Guide) and DOWN
/// (Recent Channels). AiroTV D-pad design: "◀ ▶ browse · OK switch".
class _QuickBrowseOverlay extends StatelessWidget {
  const _QuickBrowseOverlay({
    required this.title,
    required this.channels,
    required this.currentChannelId,
    required this.onSelected,
  });

  final String title;
  final List<IPTVChannel> channels;
  final String? currentChannelId;
  final ValueChanged<IPTVChannel> onSelected;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.97),
              Colors.black.withValues(alpha: 0.0),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Text(
                  '◀ ▶ browse   OK switch',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: channels.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final channel = channels[index];
                  final isCurrent = channel.id == currentChannelId;
                  return TvFocusable(
                    key: ValueKey('quick-browse-${channel.id}'),
                    autofocus: isCurrent || index == 0,
                    semanticLabel: channel.name,
                    onSelect: () => onSelected(channel),
                    child: Container(
                      width: 130,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? Colors.white.withValues(alpha: 0.16)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isCurrent)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 6),
                              child: Text(
                                'ON NOW',
                                style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          Text(
                            channel.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContextMenuOverlay extends ConsumerWidget {
  const _ContextMenuOverlay({
    required this.channel,
    required this.firstFocusNode,
    required this.onToggleFavorite,
    required this.onRefreshPlaylist,
    required this.onSelectAudioTrack,
    required this.onSelectSubtitles,
    required this.onShowChannelInfo,
    required this.onShowDiagnostics,
    required this.onCopyStreamLink,
    required this.onClose,
  });

  final IPTVChannel channel;
  final FocusNode firstFocusNode;
  final VoidCallback onToggleFavorite;
  final VoidCallback onRefreshPlaylist;
  final VoidCallback onSelectAudioTrack;
  final VoidCallback onSelectSubtitles;
  final VoidCallback onShowChannelInfo;
  final VoidCallback onShowDiagnostics;
  final VoidCallback onCopyStreamLink;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteIds = ref.watch(favoriteChannelIdsProvider).asData?.value;
    final isFavorite = favoriteIds?.contains(channel.id) ?? false;

    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: 280,
      child: _TvModalFocusScope(
        initialFocusNode: firstFocusNode,
        onBack: onClose,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [
                Colors.black.withValues(alpha: 0.96),
                Colors.black.withValues(alpha: 0.0),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Actions for',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                channel.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TvFocusable(
                        key: const ValueKey('context-menu-favorite'),
                        focusNode: firstFocusNode,
                        autofocus: true,
                        semanticLabel: isFavorite
                            ? 'Remove from favorites'
                            : 'Add to favorites',
                        onSelect: onToggleFavorite,
                        child: _ContextMenuItem(
                          icon: isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          label: isFavorite
                              ? 'Remove from favorites'
                              : 'Add to favorites',
                          onTap: onToggleFavorite,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TvFocusable(
                        key: const ValueKey('context-menu-refresh-playlist'),
                        semanticLabel: 'Refresh playlist',
                        onSelect: onRefreshPlaylist,
                        child: _ContextMenuItem(
                          icon: Icons.refresh,
                          label: 'Refresh playlist',
                          onTap: onRefreshPlaylist,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TvFocusable(
                        key: const ValueKey('context-menu-audio-track'),
                        semanticLabel: 'Audio track',
                        onSelect: onSelectAudioTrack,
                        child: _ContextMenuItem(
                          icon: Icons.audiotrack_outlined,
                          label: 'Audio track',
                          onTap: onSelectAudioTrack,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TvFocusable(
                        key: const ValueKey('context-menu-subtitles'),
                        semanticLabel: 'Subtitles',
                        onSelect: onSelectSubtitles,
                        child: _ContextMenuItem(
                          icon: Icons.subtitles_outlined,
                          label: 'Subtitles',
                          onTap: onSelectSubtitles,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TvFocusable(
                        key: const ValueKey('context-menu-channel-info'),
                        semanticLabel: 'Channel info',
                        onSelect: onShowChannelInfo,
                        child: _ContextMenuItem(
                          icon: Icons.info_outline,
                          label: 'Channel info',
                          onTap: onShowChannelInfo,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TvFocusable(
                        key: const ValueKey('context-menu-diagnostics'),
                        semanticLabel: 'Diagnostics',
                        onSelect: onShowDiagnostics,
                        child: _ContextMenuItem(
                          icon: Icons.medical_information_outlined,
                          label: 'Diagnostics',
                          onTap: onShowDiagnostics,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TvFocusable(
                        key: const ValueKey('context-menu-copy-stream-link'),
                        semanticLabel: 'Copy stream link',
                        onSelect: onCopyStreamLink,
                        child: _ContextMenuItem(
                          icon: Icons.link,
                          label: 'Copy stream link',
                          onTap: onCopyStreamLink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TvFocusable(
                        key: const ValueKey('context-menu-close'),
                        semanticLabel: 'Close menu',
                        onSelect: onClose,
                        child: _ContextMenuItem(
                          icon: Icons.close,
                          label: 'Close',
                          onTap: onClose,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContextMenuItem extends StatelessWidget {
  const _ContextMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      canRequestFocus: false,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One button in the TV transport bar. Visual only -- focus, selection, and
/// the actual action live on the [TvFocusable] wrapping it; this just draws
/// the pill matching the AiroTV D-pad design's transport button style
/// (icon-only when unlabeled, icon+label otherwise).
/// A D-pad-reachable recovery action for [_buildDiagnosticError] --
/// TvFocusable-wrapped so remote-only viewers (no touch input) can actually
/// reach it, unlike a bare ElevatedButton.
/// A D-pad-reachable row for the player-actions / track-selector bottom
/// sheets -- wraps a [ListTile] in [TvFocusable] so a remote-only viewer
/// can actually reach it. Bare [ListTile]s in these sheets were previously
/// unreachable by D-pad despite the buttons that open them being focusable.
class _TvModalFocusScope extends StatefulWidget {
  const _TvModalFocusScope({
    required this.initialFocusNode,
    required this.child,
    this.onBack,
  });

  final FocusNode initialFocusNode;
  final Widget child;
  final VoidCallback? onBack;

  @override
  State<_TvModalFocusScope> createState() => _TvModalFocusScopeState();
}

class _TvModalFocusScopeState extends State<_TvModalFocusScope> {
  late final FocusScopeNode _scopeNode = FocusScopeNode(
    debugLabel: 'player modal focus scope',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.initialFocusNode.canRequestFocus) {
        widget.initialFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _scopeNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        TvInputHandler.mapLogicalKeyToTvInput(event.logicalKey) !=
            TvInputKey.back ||
        widget.onBack == null) {
      return KeyEventResult.ignored;
    }
    widget.onBack!.call();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      onKeyEvent: _handleKeyEvent,
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: FocusScope(node: _scopeNode, child: widget.child),
      ),
    );
  }
}

class _TvSheetOption {
  const _TvSheetOption({
    required this.label,
    required this.onSelect,
    this.leading,
    this.subtitle,
    this.selected = false,
  });

  final String label;
  final VoidCallback onSelect;
  final Widget? leading;
  final Widget? subtitle;
  final bool selected;
}

class _TvSelectionSheet extends StatefulWidget {
  const _TvSelectionSheet({
    required this.debugLabelPrefix,
    required this.options,
    required this.initialIndex,
  });

  final String debugLabelPrefix;
  final List<_TvSheetOption> options;
  final int initialIndex;

  @override
  State<_TvSelectionSheet> createState() => _TvSelectionSheetState();
}

class _TvSelectionSheetState extends State<_TvSelectionSheet> {
  late final List<FocusNode> _focusNodes = [
    for (final option in widget.options)
      FocusNode(debugLabel: '${widget.debugLabelPrefix} ${option.label}'),
  ];

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.options.isEmpty) return const SizedBox.shrink();
    final initialIndex = widget.initialIndex.clamp(
      0,
      widget.options.length - 1,
    );
    return _TvModalFocusScope(
      initialFocusNode: _focusNodes[initialIndex],
      child: SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (var i = 0; i < widget.options.length; i++)
              _TvSheetListTile(
                focusNode: _focusNodes[i],
                leading: widget.options[i].leading,
                title: Text(widget.options[i].label),
                subtitle: widget.options[i].subtitle,
                trailing: widget.options[i].selected
                    ? const Icon(Icons.check)
                    : null,
                onSelect: () {
                  widget.options[i].onSelect();
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _TvSheetListTile extends StatelessWidget {
  const _TvSheetListTile({
    this.itemKey,
    this.focusNode,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onSelect,
  });

  final Key? itemKey;
  final FocusNode? focusNode;
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      focusNode: focusNode,
      onSelect: onSelect,
      semanticLabel: title is Text ? (title as Text).data : null,
      child: InkWell(
        key: itemKey,
        onTap: onSelect,
        canRequestFocus: false,
        child: ListTile(
          leading: leading,
          title: title,
          subtitle: subtitle,
          trailing: trailing,
        ),
      ),
    );
  }
}

class _RecoveryActionButton extends StatelessWidget {
  const _RecoveryActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onSelect,
    required this.focusNode,
    this.autofocus = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onSelect;
  final FocusNode focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      focusNode: focusNode,
      autofocus: autofocus,
      onSelect: onSelect,
      semanticLabel: label,
      borderRadius: 8,
      child: Material(
        color: Colors.blueGrey.shade700,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: InkWell(
          onTap: onSelect,
          canRequestFocus: false,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TvTransportButton extends StatelessWidget {
  const _TvTransportButton({required this.icon, this.label});

  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: EdgeInsets.symmetric(horizontal: label == null ? 0 : 16),
      constraints: BoxConstraints(minWidth: label == null ? 48 : 0),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          if (label != null) ...[
            const SizedBox(width: 8),
            Text(
              label!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
