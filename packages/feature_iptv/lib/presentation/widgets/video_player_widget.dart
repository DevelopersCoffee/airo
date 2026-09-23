import 'dart:async';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb, setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show
        Clipboard,
        ClipboardData,
        KeyDownEvent,
        KeyEvent,
        KeyUpEvent,
        LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_channels/platform_channels.dart';
import '../../application/aika_haptics.dart';
import '../../application/player_backgrounding_coordinator.dart';
import '../../application/channel_warmup_policy.dart';
import '../../application/providers/aika_haptics_provider.dart';
import '../../application/providers/caption_preference_provider.dart';
import '../../application/providers/channel_auto_scan_providers.dart';
import '../../application/providers/dead_link_report_provider.dart';
import '../../application/providers/iptv_ad_placements.dart';
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
import 'tv_transport_bar.dart';
import 'tv_mini_guide_overlay.dart';
import 'watch_remote_contract.dart';
import '../tv_ux/sections/remote_overlay.dart';

/// Video player widget with YouTube-like controls
class VideoPlayerWidget extends ConsumerStatefulWidget {
  final bool showControls;
  final VoidCallback? onFullscreenToggle;
  final bool enableSwipeChannelChange;
  final bool initiallyFullscreen;
  final bool enableTouchGestures;
  final bool handleNativeFullscreen;
  final PlayerBrightnessController? brightnessController;

  /// Whether to offer system Picture-in-Picture (the floating-window
  /// control and the TV settings toggle). PiP is a phone/tablet
  /// multitasking concept -- Android TV and Fire TV don't have a
  /// multi-window model for it to floated into, so TV callers pass
  /// `false`. Defaults to `true` for phone/tablet callers.
  final bool showPictureInPicture;

  /// Whether to render this widget's own fullscreen toggle button in the
  /// hover/reveal chrome's top-left row. Defaults to `true`. Callers that
  /// already show their own persistent "open full player" affordance next
  /// to an embedded, non-fullscreen preview of this widget (see
  /// `iptv_screen.dart`) pass `false` so the two fullscreen buttons don't
  /// stack on top of each other (#1025, #1600).
  final bool showFullscreenButton;

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

  /// Whether this player owns the platform BACK request while full-screen.
  ///
  /// Fire OS dispatches BACK twice — a raw key, then a paired platform
  /// pop-route request — and repeats the second half on some devices. A
  /// ten-foot host sets this so the player answers the raw key and absorbs
  /// every paired callback itself.
  ///
  /// Touch hosts leave it false: they already answer the platform pop at the
  /// screen level, and two owners would exit full-screen and immediately
  /// re-enter it.
  final bool ownsPlatformBack;

  /// Test seam for the manual audio-only toggle's platform call. Defaults to
  /// [AiroBackgroundAudioMode.setEnabled], which by design never throws (it
  /// swallows platform failures so local state always reflects user intent —
  /// see platform_player's background_audio_mode_test.dart). Injecting a
  /// throwing function here is the only way to exercise this widget's
  /// revert-on-failure path in tests.
  final Future<void> Function(bool enabled)? setAudioOnlyMode;

  /// Test seam for explicit system PiP. Defaults to the native PiP channel.
  final Future<bool> Function()? requestPictureInPicture;

  /// Adds an "App help" entry to this widget's own player-actions sheet.
  /// Hosts that have a help surface of their own (see `AiroTvShell`) pass
  /// this instead of drawing a second, separately-visible icon over the
  /// video -- the touch-reveal chrome is the one overlay this widget shows,
  /// so anything else the host wants reachable belongs inside it (#1025).
  final VoidCallback? onShowHelp;

  /// Adds an "App settings" entry to this widget's own player-actions
  /// sheet, for the same reason as [onShowHelp].
  final VoidCallback? onOpenSettings;

  /// Adds a "MultiView layout" entry to this widget's own player-actions
  /// sheet. Hosts pass this only while a MultiView session is actually
  /// active; leave it null otherwise.
  final VoidCallback? onShowMultiviewLayout;

  /// Adds a "Ways to Watch" entry to this widget's own player-actions
  /// sheet, for the same reason as [onShowHelp] -- the ten-foot layout
  /// reaches that same dialog (fit/fullscreen/PiP/Cast/Cast MultiView) via
  /// [ChannelInfoBar]'s own "Ways to Watch" button, which only renders in
  /// that layout (`AiroTvShell.showInfoBar` is `!showVideoStage`, true only
  /// for the grid-first ten-foot case). The phone/compact layout renders no
  /// [ChannelInfoBar] at all, so without this entry Cast MultiView (reached
  /// through this same dialog) has no reachable UI on a phone screen.
  final VoidCallback? onShowWaysToWatch;

  const VideoPlayerWidget({
    super.key,
    this.showControls = true,
    this.onFullscreenToggle,
    this.enableSwipeChannelChange = false,
    this.initiallyFullscreen = false,
    this.enableTouchGestures = true,
    this.handleNativeFullscreen = true,
    this.showPictureInPicture = true,
    this.showFullscreenButton = true,
    this.useTvTransportBar = false,
    this.brightnessController,
    this.onBack,
    this.ownsPlatformBack = false,
    this.setAudioOnlyMode,
    this.requestPictureInPicture,
    this.onShowHelp,
    this.onOpenSettings,
    this.onShowMultiviewLayout,
    this.onShowWaysToWatch,
  });

  @override
  ConsumerState<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends ConsumerState<VideoPlayerWidget> {
  bool _showControlsOverlay = true;
  bool _isFullscreen = false;
  bool _isCinemaMode = false;
  bool _controlsHaveFocus = false;
  Timer? _hideControlsTimer;
  bool _suppressNextPlatformBack = false;
  bool _hintVisible = true;
  Timer? _watchHintTimer;
  static const _controlsHideDelay = Duration(seconds: 5);
  static const _watchHintDuration = Duration(seconds: 4);
  static const _controlsHint = '←→ Move    OK Select    Back Close';
  static const _pointerExitHideDelay = Duration(seconds: 3);

  /// Marks the video surface's own bounds (excluding surrounding chrome
  /// like the channel list/app bar) so the native PiP snapshot can be
  /// restricted to just the video via `setSourceRectHint` -- without this,
  /// Android snapshots the entire Activity window, capturing whatever else
  /// happens to be on screen the instant PiP is entered.
  final GlobalKey _videoSurfaceKey = GlobalKey();
  Rect? _lastReportedPipRect;

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
  final FocusNode _restartTransportFocusNode = FocusNode(
    debugLabel: 'player restart',
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
  final FocusNode _favoriteTransportFocusNode = FocusNode(
    debugLabel: 'player favorite',
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
  Timer? _tvPlaybackFocusTimer;
  String? _lastTvPlaybackFocusChannelId;
  bool _tvTransportRevealArmed = false;
  FocusNode? _contextMenuRestoreFocusNode;
  bool _playerModalOpen = false;
  String? _lastRecoveryFocusToken;
  Set<Key> _overflowedTvTransportKeys = {};

  // Channel change overlay state. Name is always shown; group is shown only
  // when it is non-empty and not the placeholder "Uncategorized".
  String? _channelChangeName;
  String? _channelChangeGroup;
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

  // Mini Guide is the only Watch browse overlay. Down from the video opens
  // it; Up hands focus to the transport. OK inside the guide switches.
  _TvQuickBrowse? _quickBrowse;

  // Netflix-style gesture controls (CV-PLAYER-GESTURES) + lock button.
  bool _isLocked = false;
  double _brightness = 0.5;
  late final PlayerBrightnessController _brightnessController;
  late final Future<void> Function(bool enabled) _setAudioOnlyMode;
  late final AikaHaptics _haptics;

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
    // TV chrome stays off until playback or a remote reveal. A bare video
    // Back must exit Watch; visible transport Back only closes the bar.
    if (widget.useTvTransportBar) {
      _showControlsOverlay = false;
    }
    _brightnessController =
        widget.brightnessController ?? SystemPlayerBrightnessController();
    _setAudioOnlyMode =
        widget.setAudioOnlyMode ?? AiroBackgroundAudioMode.setEnabled;
    _haptics = ref.read(aikaHapticsProvider);
    _loadInitialBrightness();
    _startHideControlsTimer();
    unawaited(_haptics.attachLocalPlayback());
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
    _watchHintTimer?.cancel();
    _channelChangeOverlayTimer?.cancel();
    _adjacentChannelWarmupDebounce?.cancel();
    _selectLongPressTimer?.cancel();
    _tvPlaybackFocusTimer?.cancel();
    _playerFocusNode.dispose();
    _centerControlFocusNode.dispose();
    _restartTransportFocusNode.dispose();
    _moreActionsFocusNode.dispose();
    _infoFocusNode.dispose();
    _audioTransportFocusNode.dispose();
    _subtitleTransportFocusNode.dispose();
    _favoriteTransportFocusNode.dispose();
    _playerActionsAudioFocusNode.dispose();
    _playerActionsQualityFocusNode.dispose();
    _playerActionsSubtitleFocusNode.dispose();
    _contextMenuFirstFocusNode.dispose();
    _diagnosticRetryFocusNode.dispose();
    _diagnosticSkipFocusNode.dispose();
    _diagnosticReportFocusNode.dispose();
    _genericRetryFocusNode.dispose();
    unawaited(_haptics.detachLocalPlayback());
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
    // A real remote can take longer than the visual timeout to traverse the
    // full transport row. Never remove the subtree that currently owns
    // primary focus; the timer resumes when focus returns to the player.
    if (_controlsHaveFocus) return;
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
    final becomingVisible = !_showControlsOverlay;
    setState(() => _showControlsOverlay = true);
    _startHideControlsTimer();
    if (becomingVisible) _armWatchHint();
  }

  void _showControlsForPointer() {
    if (_isLocked) return;
    if (!_showControlsOverlay) {
      setState(() => _showControlsOverlay = true);
    }
    // Desktop controls remain visible while the pointer is over the player.
    // onExit starts the standard delayed fade.
    _cancelHideControlsTimer();
  }

  void _hideControlsAfterPointerExit() {
    _cancelHideControlsTimer();
    if (_controlsHaveFocus) return;
    _hideControlsTimer = Timer(_pointerExitHideDelay, () {
      if (!mounted) return;
      setState(() => _showControlsOverlay = false);
      if (_playerFocusNode.canRequestFocus) {
        _playerFocusNode.requestFocus();
      }
    });
  }

  void _onControlsFocusChange(bool hasFocus) {
    if (_controlsHaveFocus == hasFocus) return;
    _controlsHaveFocus = hasFocus;
    if (hasFocus) {
      _cancelHideControlsTimer();
    } else if (_showControlsOverlay) {
      _startHideControlsTimer();
    }
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
    if (widget.handleNativeFullscreen) {
      unawaited(AiroNativeFullscreen.setMacosFullscreen(enteringFullscreen));
    }
    widget.onFullscreenToggle?.call();
    unawaited(ref.read(aikaHapticsProvider).play(AikaHapticIntent.fullscreen));
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

  /// Keeps the native side's PiP source-rect hint in sync with the video
  /// surface's actual on-screen bounds, in physical pixels. Auto-enter PiP
  /// can fire at any time (Home press), not only when the user explicitly
  /// requests it, so this runs on every frame the player builds rather than
  /// only right before an explicit PiP request -- otherwise the hint would
  /// be stale (or never set) for the more common auto-enter path.
  void _reportPipSourceRectIfChanged() {
    final renderObject = _videoSurfaceKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final topLeft = renderObject.localToGlobal(Offset.zero);
    final rect = Rect.fromLTWH(
      topLeft.dx * dpr,
      topLeft.dy * dpr,
      renderObject.size.width * dpr,
      renderObject.size.height * dpr,
    );
    if (rect == _lastReportedPipRect || rect.isEmpty) return;
    _lastReportedPipRect = rect;
    unawaited(AiroNativePictureInPicture.updateSourceRectHint(rect));
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

  void _togglePlayPause(
    VideoPlayerStreamingService service,
    StreamingState state,
  ) {
    if (state.isPlaying) {
      service.pause();
    } else {
      service.resume();
    }
    unawaited(ref.read(aikaHapticsProvider).play(AikaHapticIntent.playPause));
  }

  // Channel navigation button handlers
  void _goToNextChannel() {
    final streamingService = ref.read(iptvStreamingServiceProvider);
    final nextChannel = ref.read(nextSelectableChannelProvider);
    if (nextChannel != null) {
      streamingService.playChannel(nextChannel);
      _showChannelChangeOverlay(nextChannel);
      _scheduleAdjacentChannelWarmupFor(nextChannel);
      unawaited(
        ref.read(aikaHapticsProvider).play(AikaHapticIntent.channelStep),
      );
    }
  }

  void _goToPreviousChannel() {
    final streamingService = ref.read(iptvStreamingServiceProvider);
    final prevChannel = ref.read(previousSelectableChannelProvider);
    if (prevChannel != null) {
      streamingService.playChannel(prevChannel);
      _showChannelChangeOverlay(prevChannel);
      _scheduleAdjacentChannelWarmupFor(prevChannel);
      unawaited(
        ref.read(aikaHapticsProvider).play(AikaHapticIntent.channelStep),
      );
    }
  }

  void _playRandomFilteredChannel(VideoPlayerStreamingService service) {
    final channel = randomFilteredChannel(ref.read(filteredChannelsProvider));
    if (channel == null) return;
    service.playChannel(channel);
    _showChannelChangeOverlay(channel);
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
    final volumeChanged = next != state.volume;
    final unmute = state.isMuted && next > 0;
    if (!volumeChanged && !unmute) return;

    if (unmute) {
      service.toggleMute();
    }
    if (volumeChanged) {
      service.setVolume(next);
      unawaited(
        ref.read(aikaHapticsProvider).play(AikaHapticIntent.volumeTick),
      );
    } else {
      unawaited(ref.read(aikaHapticsProvider).play(AikaHapticIntent.muteOff));
    }
  }

  void _toggleMute(VideoPlayerStreamingService service, StreamingState state) {
    final nextMuted = !state.isMuted;
    service.toggleMute();
    unawaited(
      ref
          .read(aikaHapticsProvider)
          .play(nextMuted ? AikaHapticIntent.muteOn : AikaHapticIntent.muteOff),
    );
  }

  void _goLive(VideoPlayerStreamingService service, StreamingState state) {
    if (!state.isLiveStream || !state.isBehindLive) return;
    unawaited(service.goLive());
    unawaited(ref.read(aikaHapticsProvider).play(AikaHapticIntent.goLive));
  }

  WatchFocusZone get _watchZone {
    if (_quickBrowse == _TvQuickBrowse.miniGuide) {
      return WatchFocusZone.miniGuide;
    }
    if (_showControlsOverlay && widget.showControls) {
      return WatchFocusZone.controls;
    }
    return WatchFocusZone.video;
  }

  String get _transportHint {
    if (_watchZone == WatchFocusZone.controls && _hintVisible) {
      return _controlsHint;
    }
    return '';
  }

  void _armWatchHint() {
    _watchHintTimer?.cancel();
    final reveal = !_hintVisible;
    _hintVisible = true;
    _watchHintTimer = Timer(_watchHintDuration, () {
      if (!mounted) return;
      setState(() => _hintVisible = false);
    });
    if (reveal && mounted) setState(() {});
  }

  void _showWatchControls() {
    setState(() => _quickBrowse = null);
    _showControls();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _claimTvTransportFocus();
    });
  }

  /// Closes transport or the Mini Guide.
  ///
  /// Fire OS follows a raw BACK that closed the guide with a platform
  /// pop-route request. Some devices dispatch that paired route callback
  /// more than once, so [suppressPlatformBack] stays set until the next raw
  /// BACK begins a new, intentional operation. Down dismisses the guide
  /// without arming that latch.
  void _closeWatchChrome({required bool suppressPlatformBack}) {
    _suppressNextPlatformBack = suppressPlatformBack;
    setState(() {
      _showControlsOverlay = false;
      _quickBrowse = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_playerFocusNode.canRequestFocus) {
        _playerFocusNode.requestFocus();
      }
    });
  }

  // D-pad Watch contract. Locked playback and diagnostic recovery own the
  // keys before the zone map, matching the previous early returns.
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
    if (recoveryOwnsFocus) return TvInputResult.notHandled;

    final action = watchRemoteAction(zone: _watchZone, key: key);
    switch (action) {
      case WatchRemoteAction.openControls:
      case WatchRemoteAction.showControls:
        // Select stays with _detectSelectLongPress: handling the key-down
        // here would reveal controls under a long-press that opens the
        // context menu (issues/01-remote-focus-contract.md criterion 5).
        if (key == TvInputKey.select) return TvInputResult.notHandled;
        _showWatchControls();
        return TvInputResult.handled;
      case WatchRemoteAction.openMiniGuide:
        if (ref.read(streamingStateProvider).asData?.value.currentChannel ==
            null) {
          return TvInputResult.notHandled;
        }
        setState(() {
          _showControlsOverlay = false;
          _quickBrowse = _TvQuickBrowse.miniGuide;
        });
        return TvInputResult.handled;
      case WatchRemoteAction.previousChannel:
        _goToPreviousChannel();
        return TvInputResult.handled;
      case WatchRemoteAction.nextChannel:
        _goToNextChannel();
        return TvInputResult.handled;
      case WatchRemoteAction.closeControls:
      case WatchRemoteAction.closeGuide:
        _closeWatchChrome(
          suppressPlatformBack:
              action == WatchRemoteAction.closeGuide && key == TvInputKey.back,
        );
        return TvInputResult.handled;
      case WatchRemoteAction.exitPlayer:
        _suppressNextPlatformBack = false;
        final closeFullscreen = widget.onBack ?? widget.onFullscreenToggle;
        if (widget.initiallyFullscreen && closeFullscreen != null) {
          closeFullscreen();
          return TvInputResult.handled;
        }
        return TvInputResult.notHandled;
      case WatchRemoteAction.moreActions:
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
      case WatchRemoteAction.moveControl:
        // The full-screen player surface is skipTraversal, so a LEFT/RIGHT
        // that arrives before Pause has focus cannot walk the row. Claim
        // Pause; once it is focused the transport bar handles the walk.
        if (!_tvTransportHasPrimaryFocus()) {
          _armWatchHint();
          _claimTvTransportFocus();
          return TvInputResult.handled;
        }
        return TvInputResult.notHandled;
      case WatchRemoteAction.activateFocusedControl:
      case WatchRemoteAction.switchFocusedChannel:
      case WatchRemoteAction.moveChannel:
      case WatchRemoteAction.ignored:
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
    final recent = ref.read(recentlyWatchedChannelsProvider).asData?.value;
    if (recent != null && recent.isNotEmpty) return recent;
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
    _showChannelChangeOverlay(channel);
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
    unawaited(
      ref
          .read(aikaHapticsProvider)
          .play(
            isNowFavorite
                ? AikaHapticIntent.favoriteOn
                : AikaHapticIntent.favoriteOff,
          ),
    );
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

  void _showChannelChangeOverlay(IPTVChannel channel) {
    final group = channel.group.trim();
    final showGroup = group.isNotEmpty && group != 'Uncategorized';
    _channelChangeOverlayTimer?.cancel();
    setState(() {
      _channelChangeName = channel.name;
      _channelChangeGroup = showGroup ? group : null;
    });
    _channelChangeOverlayTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _channelChangeName = null;
          _channelChangeGroup = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(streamingStateProvider, (previous, next) {
      final wasError = previous?.asData?.value.hasError == true;
      final isError = next.asData?.value.hasError == true;
      if (isError && !wasError) {
        unawaited(ref.read(aikaHapticsProvider).play(AikaHapticIntent.error));
      }
    });
    ref.watch(recentlyWatchedRecorderProvider);
    ref.watch(recentlyWatchedChannelsProvider);
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
    _scheduleTvPlaybackFocus(state);
    // Update wakelock based on current playback state
    // This is called on every build when state changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleVodResume(service, state);
      _applyCaptionPreferenceIfNeeded(service, state);
      _scheduleAdjacentChannelWarmup(state);
      _reportPipSourceRectIfChanged();
    });

    // Listen-only mode never asks the engine for a view: the native
    // AVAudioSession/AudioFocusRequest handlers only manage OS audio focus,
    // they never touch the video pipeline, so this Dart-level gate is what
    // actually delivers the documented "video surface torn down, audio
    // keeps decoding" contract (AiroBackgroundAudioMode's doc comment) --
    // this was previously a no-op that only relabelled the menu entry.
    final videoView = _isAudioOnly ? null : service.buildVideoView();
    final compactInlinePlayer = _usesCompactInlinePlayer(context);
    final hasPlaybackError = state.hasError;
    final blocksPlaybackChrome =
        hasPlaybackError || state.isLoading || state.isBuffering;
    final adPlacements = ref.watch(iptvAdPlacementsProvider);
    final showPauseAd = iptvPauseAdVisible(
      placements: adPlacements,
      isPlaying: state.isPlaying,
      useTvTransportBar: widget.useTvTransportBar,
      isCasting: ref.watch(iptvCastProvider).isCasting,
      isFullscreen: _isFullscreen || widget.initiallyFullscreen,
      isPipActive: isPipActive,
      blocksPlaybackChrome: blocksPlaybackChrome,
    );

    // The state surface is deliberately exclusive. A retained engine view
    // must never win over a newer loading/error state and leave stale video
    // composited under recovery chrome.
    final playerSurface = Stack(
      alignment: Alignment.center,
      children: [
        // #1989 swapped the diagnostic error's inner Align(topCenter) for a
        // SingleChildScrollView (to stop bottom overflow on compact
        // players), but a scroll view shrink-wraps to its content instead
        // of filling available space -- so the surrounding
        // Stack(alignment: Alignment.center) started vertically centering
        // the whole (now content-sized) error box instead of it spanning
        // the full player height. Positioned.fill restores that full-height
        // frame so the box's own top-anchored padding still lands in the
        // upper band.
        if (hasPlaybackError)
          Positioned.fill(
            child: state.diagnostic != null
                ? _buildDiagnosticError(state)
                : _buildError(
                    state.errorMessage ?? 'Playback could not start.',
                  ),
          )
        else if (state.isLoading)
          _buildLoading()
        else if (_isAudioOnly)
          _buildAudioOnlyPlaceholder(state)
        else if (videoView != null)
          SizedBox.expand(
            key: _videoSurfaceKey,
            child: FittedBox(fit: _boxFitFor(aspectRatioFit), child: videoView),
          )
        else
          _buildPlaceholder(state),

        // Cinema mode vignette overlay
        if (_isCinemaMode && !blocksPlaybackChrome)
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
        if (state.isBuffering && !hasPlaybackError)
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
    final ownsFullscreenBack =
        widget.ownsPlatformBack &&
        widget.initiallyFullscreen &&
        (widget.onBack != null || widget.onFullscreenToggle != null);
    return PopScope(
      // A fullscreen player with an explicit close callback owns Android BACK
      // for its entire lifetime. Fire TV can keep a platform back operation
      // pending after the raw key-up; changing canPop from false to true on a
      // timer lets that old operation pop the route later.
      canPop:
          !ownsFullscreenBack &&
          !_showContextMenu &&
          _quickBrowse == null &&
          !_suppressNextPlatformBack,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Dismiss a visible overlay first, whatever the suppression latch says.
        // A latch left over from an earlier overlay must never strand the one
        // on screen now: BACK is the only way to close these.
        if (_showContextMenu) {
          _closeContextMenu();
          return;
        }
        if (_quickBrowse != null) {
          setState(() => _quickBrowse = null);
          return;
        }
        if (_suppressNextPlatformBack) {
          // Fire OS may deliver duplicate platform pop callbacks for the raw
          // BACK that already dismissed an overlay. Do not clear the latch
          // here: the next raw BACK clears it before performing the next
          // action.
          return;
        }
        // Nothing else to do when this player owns BACK. The raw key already
        // decided what this press meant -- dismiss an overlay, or leave
        // fullscreen via _handleTvInput. This callback is only the platform
        // half of that same press, which Fire OS also repeats, so acting on
        // it here would undo or double the action the raw key just took.
        // Blocking the pop is the whole job.
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
            onHover: (_) => _showControlsForPointer(),
            onEnter: (_) => _showControlsForPointer(),
            onExit: (_) => _hideControlsAfterPointerExit(),
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
                              final next = value.clamp(0.0, 1.0);
                              final audible = state.isMuted
                                  ? 0.0
                                  : state.volume;
                              if (state.isMuted && next > 0) {
                                service.toggleMute();
                              }
                              service.setVolume(next);
                              if (next != audible) {
                                unawaited(
                                  ref
                                      .read(aikaHapticsProvider)
                                      .play(AikaHapticIntent.volumeTick),
                                );
                              }
                            },
                            child: playerSurface,
                          )
                        : playerSurface,

                    // Failover toast only. Airo TV owns one visible control
                    // system below; keeping PlayerOverlay's old back/title layer
                    // mounted here caused a second set of controls to reappear
                    // after the floating controls faded.
                    //
                    // A failover switch reports itself as loading, so the
                    // exclusive-state rule would hide the one piece of chrome
                    // that explains the wait. Since this layer is the toast and
                    // nothing else, let it through while a switch is in flight.
                    if (!_isLocked &&
                        !isPipActive &&
                        !compactInlinePlayer &&
                        (!blocksPlaybackChrome || state.failover != null))
                      PlayerOverlay(
                        state: _toPlayerViewState(state),
                        onBack:
                            widget.onBack ?? widget.onFullscreenToggle ?? () {},
                        onPlayPause: () => _togglePlayPause(service, state),
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
                    // TV Watch keeps a single bottom child: transport, Mini
                    // Guide, or nothing.
                    if (widget.useTvTransportBar &&
                        !_isLocked &&
                        !isPipActive &&
                        !blocksPlaybackChrome)
                      Positioned.fill(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          layoutBuilder: (currentChild, previousChildren) {
                            // Loose fit keeps each bottom surface at its
                            // content height. Expand would pin the Mini Guide
                            // to the full player and cover the video.
                            return Stack(
                              alignment: Alignment.bottomCenter,
                              fit: StackFit.loose,
                              children: [...previousChildren, ?currentChild],
                            );
                          },
                          child: _watchBottomOverlay(context, service, state),
                        ),
                      )
                    else if (!_isLocked &&
                        !isPipActive &&
                        !blocksPlaybackChrome)
                      AnimatedOpacity(
                        key: const ValueKey('iptv-player-controls-opacity'),
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
                            child: Focus(
                              canRequestFocus: false,
                              onFocusChange: _onControlsFocusChange,
                              child: _buildControlsOverlay(
                                context,
                                service,
                                state,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Lock button: touch-only concept, hidden entirely when
                    // enableTouchGestures is false (e.g. TV/remote input).
                    if (widget.enableTouchGestures &&
                        !isPipActive &&
                        !blocksPlaybackChrome)
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
                    if (_channelChangeName != null)
                      Positioned(
                        child: AnimatedOpacity(
                          opacity: 1,
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
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _channelChangeName!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_channelChangeGroup != null)
                                  Text(
                                    _channelChangeGroup!,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
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

                    if (!widget.useTvTransportBar &&
                        _quickBrowse == _TvQuickBrowse.miniGuide &&
                        state.currentChannel != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _miniGuideOverlay(state),
                      ),
                    if (showPauseAd && adPlacements.pauseCard != null)
                      Positioned.fill(
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.54),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: 320,
                                maxHeight: 280,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Playback paused',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 220,
                                    child: adPlacements.pauseCard!,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
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

  FocusNode? _diagnosticRecoveryFocusNode(StreamingState state) {
    final diagnostic = state.diagnostic;
    if (!state.hasError || diagnostic == null) return null;
    return !diagnostic.retryEligible || state.retryCount == 0
        ? _diagnosticRetryFocusNode
        : _diagnosticSkipFocusNode;
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
    final target = _diagnosticRecoveryFocusNode(state)!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _lastRecoveryFocusToken != token) return;
      if (target.canRequestFocus) target.requestFocus();
    });
  }

  void _scheduleTvPlaybackFocus(StreamingState state) {
    if (!widget.useTvTransportBar) return;
    final channelId = state.currentChannel?.id;
    final readyForControls =
        channelId != null &&
        state.isPlaying &&
        !state.hasError &&
        !state.isLoading &&
        !state.isBuffering;
    if (!readyForControls) {
      _lastTvPlaybackFocusChannelId = null;
      _tvPlaybackFocusTimer?.cancel();
      return;
    }
    if (_lastTvPlaybackFocusChannelId == channelId) return;
    final firstPlayback = !_tvTransportRevealArmed;
    _lastTvPlaybackFocusChannelId = channelId;
    // A later channel step must leave the video zone alone. Revealing the
    // transport here would make the next Left/Right walk the rail.
    if (!firstPlayback) return;
    _tvTransportRevealArmed = true;

    void claimTransportFocus() {
      if (!mounted || _lastTvPlaybackFocusChannelId != channelId) return;
      // Never reset deliberate movement within the transport or steal from a
      // player-owned modal. The delayed claim exists only to beat focus that
      // escaped back to the retained channel grid on the first start.
      if (_controlsHaveFocus || _playerModalOpen || _showContextMenu) return;
      if (!_showControlsOverlay) {
        _showControls();
      }
      _claimTvTransportFocus();
    }

    // The channel grid remains mounted behind fullscreen playback. Fire OS
    // can restore its old card focus after Flutter's first frame, leaving the
    // visible transport unable to receive CENTER. Reclaim once after layout,
    // once after the following frame, and once after Fire's delayed restore.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      claimTransportFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        claimTransportFocus();
      });
    });
    _tvPlaybackFocusTimer?.cancel();
    _tvPlaybackFocusTimer = Timer(
      const Duration(milliseconds: 250),
      claimTransportFocus,
    );
  }

  List<FocusNode> _tvTransportFocusNodes() => [
    _centerControlFocusNode,
    _restartTransportFocusNode,
    _audioTransportFocusNode,
    _subtitleTransportFocusNode,
    _favoriteTransportFocusNode,
    _infoFocusNode,
    _moreActionsFocusNode,
  ];

  bool _tvTransportHasPrimaryFocus() =>
      _tvTransportFocusNodes().any((node) => node.hasPrimaryFocus);

  void _claimTvTransportFocus() {
    if (_centerControlFocusNode.canRequestFocus) {
      _centerControlFocusNode.requestFocus();
    }
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

  KeyEventResult _handleDiagnosticRecoveryKey(
    FocusNode node,
    KeyEvent event, {
    required bool showRetry,
  }) {
    final moveRight = event.logicalKey == LogicalKeyboardKey.arrowRight;
    final moveLeft = event.logicalKey == LogicalKeyboardKey.arrowLeft;
    if (!moveRight && !moveLeft) return KeyEventResult.ignored;

    // Consume the complete physical key sequence. Fire OS can expose a
    // directional press to both Flutter traversal and the raw TV listener;
    // allowing either key-up or repeat to bubble can therefore skip an action.
    if (event is! KeyDownEvent) return KeyEventResult.handled;

    final actions = <FocusNode>[
      if (showRetry) _diagnosticRetryFocusNode,
      _diagnosticSkipFocusNode,
      _diagnosticReportFocusNode,
    ];
    final currentIndex = actions.indexWhere((candidate) => candidate.hasFocus);
    if (currentIndex < 0) return KeyEventResult.handled;
    final offset = moveRight ? 1 : -1;
    final targetIndex = (currentIndex + offset).clamp(0, actions.length - 1);
    actions[targetIndex].requestFocus();
    return KeyEventResult.handled;
  }

  /// CV-001 structured failure state: user-safe copy plus bounded-retry
  /// progress from [StreamingState.diagnostic], with the legacy retry button.
  Widget _buildDiagnosticError(StreamingState state) {
    final diagnostic = state.diagnostic!;
    final showRetry = !diagnostic.retryEligible || state.retryCount == 0;
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
      //
      // Scrollable rather than a bare Align: on the compact embedded player
      // (phone-width, non-fullscreen -- a fraction of screen height), this
      // content (diagnostic overlay + up to 3 recovery buttons) can exceed
      // the available height and hard-overflow at the bottom (confirmed
      // on-device, "BOTTOM OVERFLOWED BY 47 PIXELS"). Scrolling degrades
      // gracefully instead; the ample-space (fullscreen) case is unaffected
      // since nothing needs to scroll there.
      child: SingleChildScrollView(
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
              Focus(
                canRequestFocus: false,
                skipTraversal: true,
                onKeyEvent: (node, event) => _handleDiagnosticRecoveryKey(
                  node,
                  event,
                  showRetry: showRetry,
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (showRetry)
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
                      autofocus:
                          diagnostic.retryEligible && state.retryCount > 0,
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

  /// Listen-only mode's cover: same channel-art treatment as
  /// [_buildPlaceholder], plus an explicit label so it reads as a
  /// deliberate mode rather than a stalled video.
  Widget _buildAudioOnlyPlaceholder(StreamingState state) {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (channel != null && channel.hasLogo)
              AiroNetworkImage(
                url: channel.logoUrl!,
                width: 96,
                height: 96,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.headphones,
                  size: 72,
                  color: Colors.white70,
                ),
              )
            else
              const Icon(Icons.headphones, size: 72, color: Colors.white70),
            const SizedBox(height: 16),
            Text(
              'Listening only',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
            if (channel != null) ...[
              const SizedBox(height: 4),
              Text(
                channel.name,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
            ],
          ],
        ),
      ),
    );
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
        // below as separate hit-testable siblings. The TV transport bar owns
        // its own bottom scrim, so skip this full-screen dim on that path.
        if (!widget.useTvTransportBar)
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
        // Top-left zone: fullscreen (unless a host screen already renders
        // its own persistent fullscreen affordance next to an embedded,
        // non-fullscreen preview of this widget -- see showFullscreenButton
        // doc), PiP, random channel. Kept as a single row, deliberately
        // separate from the center transport zone and the side VOL/CH zone
        // below so hover chrome never crowds into one cluster (#1025,
        // #1600).
        Positioned(
          top: 76,
          left: 16,
          child: SafeArea(
            bottom: false,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.showFullscreenButton) ...[
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
                  const SizedBox(width: 10),
                ],
                if (widget.showPictureInPicture) ...[
                  _PlayerRoundControlButton(
                    key: const ValueKey('iptv-player-pip-button'),
                    icon: Icons.picture_in_picture_alt_outlined,
                    tooltip: 'Picture-in-picture',
                    onPressed: _requestPictureInPicture,
                    diameter: 44,
                    iconSize: 22,
                    backgroundAlpha: 0.48,
                  ),
                  const SizedBox(width: 10),
                ],
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
        // Center zone: primary transport controls only (rewind, play/pause,
        // mute). The VOL/CH remote-hint pillars used to live in this same
        // row, where they crowded and visually overlapped the transport
        // buttons (#1025, #1600) -- they now live in their own zone, pinned
        // to the trailing edge, below.
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
                    onPressed: () => _toggleMute(service, state),
                    diameter: 64,
                    iconSize: 28,
                    backgroundColor: state.isMuted || state.volume == 0
                        ? Colors.green
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        // Trailing-edge zone: VOL/CH remote-hint pillars, vertically
        // centered and pinned to the trailing edge -- clear of both the
        // center transport row above and the top-left row's SafeArea
        // padding, so it never overlaps either (#1025, #1600).
        Positioned(
          top: 0,
          bottom: 0,
          right: 16,
          child: SafeArea(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                    const SizedBox(width: 16),
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

  Widget _watchBottomOverlay(
    BuildContext context,
    VideoPlayerStreamingService service,
    StreamingState state,
  ) {
    if (_quickBrowse == _TvQuickBrowse.miniGuide &&
        state.currentChannel != null) {
      return KeyedSubtree(
        key: const ValueKey('watch-bottom-guide'),
        child: _miniGuideOverlay(state),
      );
    }
    if (_showControlsOverlay && widget.showControls) {
      return AnimatedOpacity(
        key: const ValueKey('iptv-player-controls-opacity'),
        opacity: 1,
        duration: const Duration(milliseconds: 300),
        child: Focus(
          canRequestFocus: false,
          onFocusChange: _onControlsFocusChange,
          child: _buildTvTransportBar(context, service, state),
        ),
      );
    }
    return const SizedBox.shrink(key: ValueKey('watch-bottom-none'));
  }

  Widget _miniGuideOverlay(StreamingState state) {
    final channels = _miniGuideChannels(state.currentChannel!);
    if (channels.isEmpty) return const SizedBox.shrink();
    return TvMiniGuideOverlay(
      channels: channels,
      currentChannelId: state.currentChannel!.id,
      onSelected: _playChannelFromQuickBrowse,
      onMoveToControls: _showWatchControls,
      onDismiss: ({bool fromBack = false}) {
        _closeWatchChrome(suppressPlatformBack: fromBack);
      },
      previewFactory: ref.read(tvMiniGuidePreviewFactoryProvider),
    );
  }

  /// Bottom-centered Watch overlay: one width-capped action row. Overflow
  /// drops trailing actions (except More) rather than wrapping.
  Widget _buildTvTransportBar(
    BuildContext context,
    VideoPlayerStreamingService service,
    StreamingState state,
  ) {
    final channel = state.currentChannel;
    final detailLine = [
      if (channel?.group.trim().isNotEmpty ?? false) channel!.group,
      state.currentQuality.label,
    ].join(' · ');
    return TvTransportBar(
      channelName: channel?.name ?? '',
      detailLine: detailLine,
      isLive: state.isLiveStream,
      menuHint: _transportHint,
      onKeyEvent: _handleTvTransportKey,
      onDroppedKeys: _onTvTransportOverflow,
      actions: _buildTvTransportButtons(context, service, state),
    );
  }

  void _onTvTransportOverflow(Set<Key> dropped) {
    if (!mounted || setEquals(_overflowedTvTransportKeys, dropped)) return;
    setState(() => _overflowedTvTransportKeys = dropped);
  }

  KeyEventResult _handleTvTransportKey(FocusNode node, KeyEvent event) {
    final key = TvInputHandler.mapLogicalKeyToTvInput(event.logicalKey);
    if (key != TvInputKey.left && key != TvInputKey.right) {
      return KeyEventResult.ignored;
    }
    // Consume the complete physical press so Fire OS cannot combine this
    // explicit linear order with Flutter's geometric traversal.
    if (event is! KeyDownEvent) return KeyEventResult.handled;

    final focusNodes = _tvTransportFocusNodes()
        .where((candidate) => candidate.context != null)
        .toList(growable: false);
    final currentIndex = focusNodes.indexWhere(
      (candidate) => candidate.hasFocus,
    );
    if (currentIndex < 0) {
      // The bar received LEFT/RIGHT without a child holding focus (the
      // full-screen skipTraversal surface, or the outer Back handler).
      // Land on Pause so the next D-pad press can walk.
      _claimTvTransportFocus();
      return KeyEventResult.handled;
    }
    final offset = key == TvInputKey.right ? 1 : -1;
    final targetIndex = (currentIndex + offset).clamp(0, focusNodes.length - 1);
    focusNodes[targetIndex].requestFocus();
    return KeyEventResult.handled;
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
    final hasAudio = state.tracks.any(
      (track) => track.kind == AiroPlaybackTrackKind.audio,
    );
    final hasSubtitles = _subtitleTracksFor(state).isNotEmpty;

    return [
      TvFocusable(
        key: const ValueKey('iptv-tv-transport-play-pause'),
        focusNode: _centerControlFocusNode,
        autofocus: true,
        onFocus: _startHideControlsTimer,
        onSelect: () => _togglePlayPause(service, state),
        borderRadius: AiroSpacing.radiusSm,
        semanticLabel: state.isPlaying ? 'Pause' : 'Play',
        child: TvTransportActionButton(
          icon: state.isPlaying
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
        ),
      ),
      TvFocusable(
        key: const ValueKey('iptv-tv-transport-restart'),
        focusNode: _restartTransportFocusNode,
        onFocus: _startHideControlsTimer,
        onSelect: canRewind ? () => _seekBackward10(service, state) : null,
        borderRadius: AiroSpacing.radiusSm,
        semanticLabel: state.isLiveStream
            ? 'Rewind 10 seconds'
            : 'Back 10 seconds',
        child: const TvTransportActionButton(icon: Icons.skip_previous_rounded),
      ),
      TvFocusable(
        key: const ValueKey('iptv-tv-transport-audio'),
        focusNode: _audioTransportFocusNode,
        onFocus: _startHideControlsTimer,
        onSelect: hasAudio
            ? () => unawaited(
                _showTrackSelectorFor(
                  context,
                  service,
                  state,
                  kind: AiroPlaybackTrackKind.audio,
                  restoreFocusNode: _audioTransportFocusNode,
                ),
              )
            : null,
        borderRadius: AiroSpacing.radiusSm,
        semanticLabel: hasAudio ? 'Audio' : 'Audio, no tracks',
        child: TvTransportActionButton(
          icon: Icons.volume_up_outlined,
          enabled: hasAudio,
        ),
      ),
      TvFocusable(
        key: const ValueKey('iptv-tv-transport-subtitles'),
        focusNode: _subtitleTransportFocusNode,
        onFocus: _startHideControlsTimer,
        onSelect: hasSubtitles
            ? () => unawaited(
                _showTrackSelector(
                  context,
                  service,
                  state,
                  restoreFocusNode: _subtitleTransportFocusNode,
                ),
              )
            : null,
        borderRadius: AiroSpacing.radiusSm,
        semanticLabel: hasSubtitles ? 'Subtitles' : 'Subtitles, no tracks',
        child: TvTransportActionButton(
          icon: Icons.subtitles_outlined,
          enabled: hasSubtitles,
        ),
      ),
      TvFocusable(
        key: const ValueKey('iptv-tv-transport-favourite'),
        focusNode: _favoriteTransportFocusNode,
        onFocus: _startHideControlsTimer,
        onSelect: channel == null ? null : _toggleFavoriteForCurrentChannel,
        borderRadius: AiroSpacing.radiusSm,
        semanticLabel: isFavorite
            ? 'Remove from favourites'
            : 'Add to favourites',
        child: TvTransportActionButton(
          icon: isFavorite
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          selected: isFavorite,
        ),
      ),
      TvFocusable(
        key: const ValueKey('iptv-tv-transport-info'),
        focusNode: _infoFocusNode,
        onFocus: _startHideControlsTimer,
        onSelect: channel == null
            ? null
            : () => _openContextMenu(restoreFocusNode: _infoFocusNode),
        borderRadius: AiroSpacing.radiusSm,
        semanticLabel: 'Info',
        child: const TvTransportActionButton(icon: Icons.info_outline_rounded),
      ),
      TvFocusable(
        key: const ValueKey('iptv-player-more-button'),
        focusNode: _moreActionsFocusNode,
        onFocus: _startHideControlsTimer,
        onSelect: () => _showPlayerActionsSheet(
          context,
          service,
          state,
          restoreFocusNode: _moreActionsFocusNode,
        ),
        borderRadius: AiroSpacing.radiusSm,
        semanticLabel: 'More player actions',
        child: const TvTransportActionButton(icon: Icons.more_horiz_rounded),
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
        // Isolated top-right slot, matching the conventional placement used
        // by most video players (YouTube, Netflix, VLC): fullscreen must be
        // easy to find and never compete for space with the bottom-edge
        // transport/channel/settings cluster, which already gets crowded on
        // narrow phone widths (rewind/mute/vol on one side, prev/next/
        // random/settings on the other) -- packing a 5th-6th icon in there
        // caused it to wrap/overlap and effectively hide behind the others.
        if (widget.showFullscreenButton)
          Positioned(
            top: 12,
            right: 12,
            child: SafeArea(
              bottom: false,
              child: _PlayerFloatingControlButton(
                key: const ValueKey('iptv-player-fullscreen-button-compact'),
                icon: _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                tooltip: _isFullscreen ? 'Exit fullscreen' : 'Fullscreen',
                onPressed: _toggleFullscreen,
              ),
            ),
          ),
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
                  onPressed: () => _toggleMute(service, state),
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
    if (!_isFullscreen && size.shortestSide < 600) return true;
    // A hinge straddling the player's bounds must not split the expanded
    // layout's controls (positioned near the corners) across the fold.
    // The full window rect is an approximation of the player's real bounds,
    // which aren't known before layout — acceptable since a straddling
    // hinge always straddles the full window too when the player fills it.
    final fold = AiroFold.of(context);
    return AiroFold.straddles(Offset.zero & size, fold);
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
    final isFavorite =
        state.currentChannel != null &&
        (ref
                .read(favoriteChannelIdsProvider)
                .asData
                ?.value
                .contains(state.currentChannel!.id) ??
            false);
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
                  if (_overflowedTvTransportKeys.contains(
                    TvTransportOverflow.infoKey,
                  ))
                    _TvSheetListTile(
                      itemKey: const ValueKey('iptv-player-info-menu-action'),
                      leading: const Icon(Icons.info_outline_rounded),
                      title: const Text('Info'),
                      onSelect: () => unawaited(
                        afterSheet(
                          () => _openContextMenu(
                            restoreFocusNode: _moreActionsFocusNode,
                          ),
                        ),
                      ),
                    ),
                  if (_overflowedTvTransportKeys.contains(
                    TvTransportOverflow.favouriteKey,
                  ))
                    _TvSheetListTile(
                      itemKey: const ValueKey(
                        'iptv-player-favourite-menu-action',
                      ),
                      leading: Icon(
                        isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                      ),
                      title: Text(
                        isFavorite
                            ? 'Remove from favourites'
                            : 'Add to favourites',
                      ),
                      onSelect: () => unawaited(
                        afterSheet(_toggleFavoriteForCurrentChannel),
                      ),
                    ),
                  if (_overflowedTvTransportKeys.contains(
                    TvTransportOverflow.audioKey,
                  ))
                    _TvSheetListTile(
                      itemKey: const ValueKey('iptv-player-audio-menu-action'),
                      leading: const Icon(Icons.volume_up_outlined),
                      title: const Text('Audio'),
                      onSelect: () => unawaited(
                        _showTrackSelectorFor(
                          sheetContext,
                          service,
                          state,
                          kind: AiroPlaybackTrackKind.audio,
                          restoreFocusNode: _moreActionsFocusNode,
                        ),
                      ),
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
                  if (widget.onShowMultiviewLayout != null)
                    _TvSheetListTile(
                      itemKey: const ValueKey(
                        'iptv-player-multiview-layout-menu-action',
                      ),
                      leading: const Icon(Icons.grid_view),
                      title: const Text('MultiView layout'),
                      onSelect: () =>
                          unawaited(afterSheet(widget.onShowMultiviewLayout!)),
                    ),
                  if (widget.onShowWaysToWatch != null)
                    _TvSheetListTile(
                      itemKey: const ValueKey(
                        'iptv-player-ways-to-watch-menu-action',
                      ),
                      leading: const Icon(Icons.monitor_outlined),
                      title: const Text('Ways to Watch'),
                      onSelect: () =>
                          unawaited(afterSheet(widget.onShowWaysToWatch!)),
                    ),
                  if (widget.onShowHelp != null ||
                      widget.onOpenSettings != null)
                    const Divider(height: 1),
                  if (widget.onShowHelp != null)
                    _TvSheetListTile(
                      itemKey: const ValueKey('iptv-player-help-menu-action'),
                      leading: const Icon(Icons.help_outline),
                      title: const Text('Help'),
                      onSelect: () => unawaited(afterSheet(widget.onShowHelp!)),
                    ),
                  if (widget.onOpenSettings != null)
                    _TvSheetListTile(
                      itemKey: const ValueKey(
                        'iptv-player-settings-menu-action',
                      ),
                      leading: const Icon(Icons.settings_outlined),
                      title: const Text('App settings'),
                      onSelect: () =>
                          unawaited(afterSheet(widget.onOpenSettings!)),
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
          if (!mounted) return;
          final currentState = ref.read(streamingStateProvider).asData?.value;
          final target = currentState == null
              ? restoreFocusNode
              : _diagnosticRecoveryFocusNode(currentState) ?? restoreFocusNode;
          if (target.canRequestFocus) {
            target.requestFocus();
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
        onSelect: () => _goLive(service, state),
        semanticLabel: 'Go live',
        borderRadius: 40,
        child: GestureDetector(
          onTap: () => _goLive(service, state),
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
    void togglePlayPause() => _togglePlayPause(service, state);

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

enum _TvQuickBrowse { miniGuide }

/// Right-side overlay panel for actions on the currently-playing channel.
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
  });

  final FocusNode initialFocusNode;
  final Widget child;

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

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: FocusScope(node: _scopeNode, child: widget.child),
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
