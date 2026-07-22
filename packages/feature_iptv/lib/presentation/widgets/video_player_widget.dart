import 'dart:async';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_channels/platform_channels.dart';
import '../../application/player_backgrounding_coordinator.dart';
import '../../application/providers/caption_preference_provider.dart';
import '../../application/providers/channel_auto_scan_providers.dart';
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

/// Video player widget with YouTube-like controls
class VideoPlayerWidget extends ConsumerStatefulWidget {
  final bool showControls;
  final VoidCallback? onFullscreenToggle;
  final bool enableSwipeChannelChange;
  final bool initiallyFullscreen;
  final bool enableTouchGestures;
  final PlayerBrightnessController? brightnessController;

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

  // Channel change overlay state
  String? _channelChangeOverlayText;
  Timer? _channelChangeOverlayTimer;

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
    }
  }

  void _goToPreviousChannel() {
    final streamingService = ref.read(iptvStreamingServiceProvider);
    final prevChannel = ref.read(previousSelectableChannelProvider);
    if (prevChannel != null) {
      streamingService.playChannel(prevChannel);
      _showChannelChangeOverlay(prevChannel.name);
    }
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
    switch (key) {
      case TvInputKey.up:
        _goToPreviousChannel();
        return TvInputResult.handled;
      case TvInputKey.down:
        _goToNextChannel();
        return TvInputResult.handled;
      default:
        return TvInputResult.notHandled;
    }
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
    // Update wakelock based on current playback state
    // This is called on every build when state changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleVodResume(service, state);
      _applyCaptionPreferenceIfNeeded(service, state);
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

    return TvInputHandler(
      onInput: _handleSurfInput,
      // Focus.onKeyEvent always ignores so the event bubbles up to
      // TvInputHandler's own listener above -- this node exists purely to
      // hold primary focus by default, since nothing else in the player
      // (controls auto-hide) reliably claims it otherwise.
      child: Focus(
        autofocus: true,
        skipTraversal: true,
        onKeyEvent: (node, event) => KeyEventResult.ignored,
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
                  // when it's null we fall through to loading/diagnostic/
                  // placeholder inside the same gesture-enabled stack.
                  widget.enableTouchGestures
                      ? PlayerGestureOverlay(
                          locked: _isLocked,
                          brightness: _brightness,
                          volume: state.isMuted ? 0.0 : state.volume,
                          onBrightnessChanged: _onBrightnessGestureChanged,
                          onVolumeChanged: (value) {
                            if (state.isMuted) service.toggleMute();
                            service.setVolume(value);
                          },
                          child: playerSurface,
                        )
                      : playerSurface,

                  // Renderer-agnostic top chrome (back button, title/
                  // subtitle, quality + LIVE pills) and failover toast, built
                  // from PlayerViewState (Task 8/9). Supersedes the old
                  // network/quality/live badge row and the old channel-name
                  // row inside `_buildControlsOverlay` below. Center
                  // transport and the bottom bar are left to that richer
                  // control bar — which still owns mute, aspect ratio,
                  // cinema mode, subtitle selection, VOD seek, and Go Live —
                  // since PlayerOverlay's current fixed contract has no
                  // equivalent hooks for those yet (see task-9-report.md for
                  // the follow-up).
                  //
                  // Painted (and therefore hit-tested) BEFORE
                  // `_buildControlsOverlay` below on purpose: PlayerOverlay's
                  // own tap-to-reveal surface is full-bleed (StackFit.expand)
                  // so it can catch a tap anywhere on the video, but that
                  // must not win the gesture arena over the buttons in the
                  // richer overlay (mute/subtitle/fullscreen/etc) that sit at
                  // the same screen coordinates — putting it first in paint
                  // order means those buttons hit-test in front of it and
                  // claim the tap first.
                  //
                  // This only works because `_buildControlsOverlay`'s own
                  // decorative gradient background is wrapped in
                  // `IgnorePointer` (see below): `Decoration.hitTest()`
                  // reports a hit across a `Container`'s ENTIRE bounding box
                  // regardless of the gradient's alpha, and that container is
                  // full-bleed over the whole stack. Left un-ignored, it
                  // would swallow every tap in its bounds — including
                  // PlayerOverlay's back button up top, which has no legacy
                  // content behind it since the old channel-name row moved
                  // into PlayerOverlay — before PlayerOverlay's own
                  // GestureDetector ever saw the tap.
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
                      showCenterControls: false,
                      showBottomBar: false,
                    ),

                  // Controls overlay with fade animation — hidden entirely while
                  // locked so only the lock button remains interactive.
                  if (!_isLocked && !isPipActive)
                    AnimatedOpacity(
                      opacity: (widget.showControls && _showControlsOverlay)
                          ? 1.0
                          : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: IgnorePointer(
                        ignoring: !widget.showControls || !_showControlsOverlay,
                        child: _buildControlsOverlay(context, service, state),
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
                        opacity: _channelChangeOverlayText != null ? 1.0 : 0.0,
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
                ],
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PlaybackDiagnosticOverlay(
            diagnostic: diagnostic,
            retryAttempt: state.retryCount > 0 ? state.retryCount : null,
            maxRetryAttempts: 3,
          ),
          if (!diagnostic.retryEligible || state.retryCount == 0)
            ElevatedButton.icon(
              onPressed: () => ref.read(iptvStreamingServiceProvider).retry(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
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
              // Retry button with better styling
              ElevatedButton.icon(
                onPressed: () => ref.read(iptvStreamingServiceProvider).retry(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
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
        // never hit-tests. Without this, `Decoration.hitTest()` claims every
        // tap across this Container's full bounding box (opaque hit area,
        // not per-pixel alpha), and since this whole overlay paints in front
        // of PlayerOverlay above, that would swallow taps meant for
        // PlayerOverlay's back button before its GestureDetector ever saw
        // them — even though the gradient's top band has nothing visually
        // interactive under it anymore (the old channel-name row moved to
        // PlayerOverlay). The real buttons live in `_buildControlButtons`
        // below as separate hit-testable siblings, so they're unaffected by
        // this IgnorePointer and keep working exactly as before.
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
                if (!_isFullscreen) ...[
                  _PlayerRoundControlButton(
                    key: const ValueKey('iptv-player-fullscreen-button'),
                    icon: Icons.fullscreen,
                    tooltip: 'Fullscreen',
                    onPressed: _toggleFullscreen,
                    diameter: 44,
                    iconSize: 24,
                    backgroundAlpha: 0.48,
                  ),
                  const SizedBox(width: 10),
                ],
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
                  key: const ValueKey('iptv-player-more-button'),
                  icon: Icons.settings_outlined,
                  tooltip: 'Player settings',
                  onPressed: () =>
                      _showPlayerActionsSheet(context, service, state),
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
                      value: displayPosition.inSeconds.toDouble().clamp(
                        0.0,
                        state.duration.inSeconds.toDouble(),
                      ),
                      min: 0,
                      max: state.duration.inSeconds.toDouble(),
                      activeColor: Colors.white,
                      inactiveColor: Colors.white38,
                      onChanged: (value) {
                        setState(() {
                          _vodSeekDragPosition = Duration(
                            seconds: value.round(),
                          );
                        });
                      },
                      onChangeEnd: (value) {
                        final target = Duration(seconds: value.round());
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
          onPressed: () => _showPlayerActionsSheet(context, service, state),
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
    StreamingState state,
  ) {
    final hasQualityChoices = _qualityOptionsFor(state).length > 1;
    final hasSubtitles = _subtitleTracksFor(state).isNotEmpty;

    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        Future<void> afterSheet(VoidCallback action) async {
          Navigator.of(sheetContext).pop();
          await Future<void>.delayed(const Duration(milliseconds: 250));
          if (!mounted) return;
          action();
        }

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text('Player actions'),
                subtitle: Text('Secondary controls for this stream'),
              ),
              ListTile(
                key: const ValueKey('iptv-player-pip-menu-action'),
                leading: const Icon(Icons.picture_in_picture_alt_outlined),
                title: const Text('Picture-in-picture'),
                onTap: () => unawaited(afterSheet(_requestPictureInPicture)),
              ),
              if (hasQualityChoices)
                ListTile(
                  key: const ValueKey('iptv-player-quality-menu-action'),
                  leading: const Icon(Icons.hd_outlined),
                  title: const Text('Quality'),
                  subtitle: Text(state.currentQuality.label),
                  onTap: () => unawaited(
                    afterSheet(
                      () => _showQualitySelector(context, service, state),
                    ),
                  ),
                ),
              if (hasSubtitles)
                ListTile(
                  key: const ValueKey('iptv-player-subtitle-menu-action'),
                  leading: Icon(
                    state.selectedTrackIds.containsKey(
                          AiroPlaybackTrackKind.subtitle,
                        )
                        ? Icons.subtitles
                        : Icons.subtitles_off_outlined,
                  ),
                  title: const Text('Subtitles'),
                  onTap: () => unawaited(
                    afterSheet(
                      () => _showTrackSelector(context, service, state),
                    ),
                  ),
                ),
              ListTile(
                key: const ValueKey('iptv-player-audio-only-menu-action'),
                leading: Icon(
                  _isAudioOnly ? Icons.hearing : Icons.hearing_disabled,
                ),
                title: Text(_isAudioOnly ? 'Exit audio-only' : 'Listen only'),
                onTap: () => unawaited(afterSheet(_toggleAudioOnly)),
              ),
              ListTile(
                key: const ValueKey('iptv-player-aspect-ratio-menu-action'),
                leading: const Icon(Icons.aspect_ratio),
                title: const Text('Aspect ratio'),
                onTap: () => unawaited(
                  afterSheet(
                    () => ref
                        .read(videoAspectRatioProvider.notifier)
                        .cycleToNext(),
                  ),
                ),
              ),
              ListTile(
                key: const ValueKey('iptv-player-cinema-menu-action'),
                leading: Icon(_isCinemaMode ? Icons.wb_sunny : Icons.theaters),
                title: Text(_isCinemaMode ? 'Standard mode' : 'Cinema mode'),
                onTap: () => unawaited(
                  afterSheet(
                    () => setState(() => _isCinemaMode = !_isCinemaMode),
                  ),
                ),
              ),
              ListTile(
                key: const ValueKey('iptv-player-fullscreen-menu-action'),
                leading: Icon(
                  _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                ),
                title: Text(_isFullscreen ? 'Exit fullscreen' : 'Fullscreen'),
                onTap: () => unawaited(afterSheet(_toggleFullscreen)),
              ),
            ],
          ),
        );
      },
    );
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

  void _showTrackSelector(
    BuildContext context,
    VideoPlayerStreamingService service,
    StreamingState state,
  ) {
    final subtitleTracks = _subtitleTracksFor(state);
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.subtitles_off_outlined),
                title: const Text('Off'),
                trailing:
                    state.selectedTrackIds[AiroPlaybackTrackKind.subtitle] ==
                        null
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  service.clearTrackSelection(AiroPlaybackTrackKind.subtitle);
                  Navigator.of(context).pop();
                },
              ),
              for (final track in subtitleTracks)
                ListTile(
                  title: Text(track.label),
                  subtitle: track.isExternal ? const Text('External') : null,
                  trailing: state.selectedTrackIds[track.kind] == track.id
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () {
                    service.selectTrack(kind: track.kind, trackId: track.id);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showQualitySelector(
    BuildContext context,
    VideoPlayerStreamingService service,
    StreamingState state,
  ) {
    final options = _qualityOptionsFor(state);
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final quality in options)
                ListTile(
                  title: Text(quality.label),
                  trailing: state.selectedQuality == quality
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () {
                    service.setQuality(quality);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        );
      },
    );
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
      return GestureDetector(
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
      );
    }

    // Standard play/pause button — translucent white circle behind a dark
    // glyph, matching the design handoff's player chrome.
    return GestureDetector(
      onTap: () {
        if (state.isPlaying) {
          service.pause();
        } else {
          service.resume();
        }
      },
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
    );
  }

  /// VOD-only seek bar (CV-016). Live streams use the live-edge/DVR
  /// controls instead — this never renders when [StreamingState.isLiveStream]
  /// is true or the stream has no known duration.
  Widget _buildVodSeekBar(
    VideoPlayerStreamingService service,
    StreamingState state,
  ) {
    final durationSeconds = state.duration.inSeconds.toDouble();
    final displayPosition = (_vodSeekDragPosition ?? state.position).inSeconds
        .toDouble()
        .clamp(0.0, durationSeconds);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            _formatDuration(_vodSeekDragPosition ?? state.position),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Expanded(
            child: Material(
              type: MaterialType.transparency,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                ),
                child: Slider(
                  key: const ValueKey('iptv-player-vod-seek-bar'),
                  value: displayPosition,
                  min: 0,
                  max: durationSeconds,
                  activeColor: Colors.white,
                  inactiveColor: Colors.white24,
                  onChanged: (value) {
                    setState(() {
                      _vodSeekDragPosition = Duration(seconds: value.round());
                    });
                  },
                  onChangeEnd: (value) {
                    final target = Duration(seconds: value.round());
                    service.seek(target);
                    setState(() => _vodSeekDragPosition = null);
                  },
                ),
              ),
            ),
          ),
          Text(
            _formatDuration(state.duration),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final hours = d.inHours;
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  Widget _buildBufferIndicator(StreamingState state) {
    final bufferHealth = state.bufferStatus.bufferHealth;
    final color = bufferHealth >= 80
        ? Colors.green
        : bufferHealth >= 50
        ? Colors.yellow
        : Colors.red;
    return Column(
      children: [
        LinearProgressIndicator(
          value: bufferHealth / 100,
          backgroundColor: Colors.white24,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
        const SizedBox(height: 4),
        Text(
          'Buffer: ${state.bufferStatus.bufferedAhead.inSeconds}s',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
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
    this.iconColor = Colors.white,
    this.backgroundColor,
    this.backgroundAlpha = 0.64,
    this.diameter = 64,
    this.iconSize = 28,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color iconColor;
  final Color? backgroundColor;
  final double backgroundAlpha;
  final double diameter;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = onPressed == null
        ? Colors.white.withValues(alpha: 0.38)
        : iconColor;
    return Material(
      color: backgroundColor ?? Colors.black.withValues(alpha: backgroundAlpha),
      shape: const CircleBorder(),
      elevation: 8,
      shadowColor: Colors.black54,
      child: SizedBox.square(
        dimension: diameter,
        child: IconButton(
          icon: Icon(icon, color: effectiveColor, size: iconSize),
          tooltip: tooltip,
          onPressed: onPressed,
          visualDensity: VisualDensity.compact,
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
