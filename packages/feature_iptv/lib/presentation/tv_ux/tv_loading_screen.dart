import 'package:flutter/material.dart';
import 'package:platform_channels/platform_channels.dart';

import '../widgets/channel_logo.dart';

/// Loading state shown while a channel list or a stream is being resolved.
///
/// When [channel] is known, its logo is shown above the spinner. When
/// [ready] flips from `false` to `true` (the stream has started), the logo
/// plays a short zoom-out/fade-out transition rather than disappearing
/// abruptly.
class TvLoadingScreen extends StatefulWidget {
  const TvLoadingScreen({
    super.key,
    this.message = 'Loading...',
    this.channel,
    this.ready = false,
  });

  final String message;

  /// The channel this loading screen is loading, if known. Null shows a
  /// spinner-only state (e.g. the channel list itself is still loading).
  final IPTVChannel? channel;

  /// Whether the stream has finished loading. Flipping this from `false` to
  /// `true` triggers the zoom-out/fade completion transition.
  final bool ready;

  static const Duration _transitionDuration = Duration(milliseconds: 350);

  @override
  State<TvLoadingScreen> createState() => _TvLoadingScreenState();
}

class _TvLoadingScreenState extends State<TvLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late CurvedAnimation _scaleCurve;
  late CurvedAnimation _opacityCurve;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: TvLoadingScreen._transitionDuration,
    );
    _scaleCurve = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _opacityCurve = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 1, end: 0.6).animate(_scaleCurve);
    _opacity = Tween<double>(begin: 1, end: 0).animate(_opacityCurve);
    if (widget.ready) {
      // Started already-ready (e.g. hot-restored mid-flow): jump to the end
      // state rather than animating from a fresh mount.
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant TvLoadingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.channel?.id != oldWidget.channel?.id) {
      // A new channel supersedes whatever transition was in flight for the
      // old one. `SingleTickerProviderStateMixin` allows only one ticker for
      // the life of this State, so the controller itself is never replaced
      // -- it is stopped and rewound here, then re-driven from the new
      // channel's `ready` state. The controller is only ever disposed in
      // [dispose].
      _controller
        ..stop()
        ..reset();
      if (widget.ready) {
        _controller.forward();
      }
      return;
    }

    if (!oldWidget.ready && widget.ready) {
      _controller.forward(from: 0);
    } else if (oldWidget.ready && !widget.ready) {
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _scaleCurve.dispose();
    _opacityCurve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final channel = widget.channel;
    return DecoratedBox(
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
            if (channel != null)
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return FadeTransition(
                    key: const ValueKey('tv-loading-screen-logo-fade'),
                    opacity: _opacity,
                    child: Transform.scale(
                      key: const ValueKey('tv-loading-screen-logo-transform'),
                      scale: _scale.value,
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ChannelLogo(
                    logoUrl: channel.effectiveLogoUrl,
                    channelName: channel.name,
                    size: 64,
                    isAudioOnly: channel.isAudioOnly,
                  ),
                ),
              ),
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 24),
            Text(
              widget.message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
