import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:platform_channels/platform_channels.dart';

import '../../widgets/channel_logo.dart';

/// Transient "what am I watching" badge drawn over the video stage.
///
/// Replaces the always-visible `ChannelInfoBar` chrome row that used to sit
/// below the stage: identity belongs on the video for a few seconds after it
/// changes, not in a permanent strip that costs a row of grid height forever
/// (Netflix/YouTube-TV convention).
///
/// Must be a child of a [Stack] — it returns a [Positioned] so it can own the
/// whole stage as an activity surface while painting only a small badge in
/// the top-left corner.
///
/// Reveal/auto-hide follows the state machine `VideoPlayerWidget` already
/// uses for its own controls overlay (`_showControls` /
/// `_startHideControlsTimer`): a reveal is always paired with a fresh idle
/// timer, so input keeps it alive and silence retires it.
class ChannelNameOverlay extends StatefulWidget {
  const ChannelNameOverlay({
    super.key,
    required this.channel,
    required this.dismissRequested,
  });

  /// The channel currently on the stage. A change of [IPTVChannel.id] is what
  /// reveals the badge; null renders nothing at all.
  final IPTVChannel? channel;

  /// True while a player-actions sheet (Settings / Help / MultiView layout)
  /// owns the screen. Hides the badge immediately, exactly like an idle
  /// timeout, and — unlike a timeout — also *blocks* further reveals until it
  /// goes false again, so a channel change or a stray tap behind the barrier
  /// can't put a second floating layer under the open sheet.
  final bool dismissRequested;

  @override
  State<ChannelNameOverlay> createState() => _ChannelNameOverlayState();
}

class _ChannelNameOverlayState extends State<ChannelNameOverlay> {
  static const _idleTimeout = Duration(seconds: 5);
  static const _fadeDuration = Duration(milliseconds: 250);

  bool _visible = false;
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    // Mounting with a channel already playing is itself a channel change from
    // the viewer's point of view (it is how a cold launch into a resumed
    // stream looks), so the badge starts revealed and times out normally.
    if (widget.channel != null && !widget.dismissRequested) {
      _visible = true;
      _scheduleHide();
    }
  }

  @override
  void didUpdateWidget(covariant ChannelNameOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dismissRequested) {
      _cancelHide();
      if (_visible) setState(() => _visible = false);
      return;
    }
    if (widget.channel != null && oldWidget.channel?.id != widget.channel?.id) {
      _reveal();
    }
  }

  @override
  void dispose() {
    _cancelHide();
    super.dispose();
  }

  void _scheduleHide() {
    _cancelHide();
    _idleTimer = Timer(_idleTimeout, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  void _cancelHide() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  /// Reveals the badge and restarts its idle window. Called on a channel
  /// change and on any pointer activity reaching the stage.
  void _reveal() {
    if (widget.dismissRequested || widget.channel == null) return;
    if (!_visible) setState(() => _visible = true);
    _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    final channel = widget.channel;
    if (channel == null) return const SizedBox.shrink();
    return Positioned.fill(
      // `Listener`, not `GestureDetector`: this layer spans the whole stage,
      // and a gesture recognizer here would enter the arena against the
      // player's own tap/swipe handling underneath it. A translucent
      // `Listener` observes the pointer and still reports "not hit", so the
      // video, its controls, and the stage action row all keep their input.
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _reveal(),
        child: IgnorePointer(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: AnimatedOpacity(
                key: const ValueKey('airo-tv-channel-name-overlay'),
                opacity: _visible ? 1 : 0,
                duration: _fadeDuration,
                curve: Curves.easeOut,
                child: _ChannelBadge(channel: channel),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelBadge extends StatelessWidget {
  const _ChannelBadge({required this.channel});

  final IPTVChannel channel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        // Same scrim + radius tokens the stage action row and hero frame
        // already use — no new palette for this overlay.
        color: Colors.black.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(AiroSpacing.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChannelLogo(
              logoUrl: channel.effectiveLogoUrl,
              channelName: channel.name,
              size: 28,
              isAudioOnly: channel.isAudioOnly,
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                channel.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const AiroBadge(
              label: 'LIVE',
              variant: AiroBadgeVariant.live,
              size: AiroBadgeSize.sm,
              pulse: false,
              borderRadius: AiroSpacing.radiusSm,
            ),
          ],
        ),
      ),
    );
  }
}
