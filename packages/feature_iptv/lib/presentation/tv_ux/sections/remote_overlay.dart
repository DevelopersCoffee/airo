import 'dart:async';
import 'dart:math';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:platform_channels/platform_channels.dart';

/// Selects exclusively from the caller's already-filtered channel list.
IPTVChannel? randomFilteredChannel(
  List<IPTVChannel> channels, {
  int Function(int max)? nextInt,
}) {
  if (channels.isEmpty) return null;
  final index = (nextInt ?? Random().nextInt)(channels.length);
  return channels[index];
}

/// Touch controls over the video stage. TV surfaces retain hardware input and
/// expose only the random action as a focus stop in the surrounding shell.
class RemoteOverlay extends StatefulWidget {
  const RemoteOverlay({
    super.key,
    this.isTv = false,
    this.autoHideDuration = const Duration(seconds: 3),
    this.onVolumeDown,
    this.onVolumeUp,
    this.onChannelPrevious,
    this.onChannelNext,
    this.onMute,
    this.onRandom,
  });

  final bool isTv;
  final Duration autoHideDuration;
  final VoidCallback? onVolumeDown;
  final VoidCallback? onVolumeUp;
  final VoidCallback? onChannelPrevious;
  final VoidCallback? onChannelNext;
  final VoidCallback? onMute;
  final VoidCallback? onRandom;

  @override
  State<RemoteOverlay> createState() => _RemoteOverlayState();
}

class _RemoteOverlayState extends State<RemoteOverlay> {
  Timer? _hideTimer;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _restartTimer() {
    if (widget.isTv) return;
    _hideTimer?.cancel();
    _hideTimer = Timer(widget.autoHideDuration, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  void _show() {
    if (widget.isTv) return;
    if (!_visible) setState(() => _visible = true);
    _restartTimer();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isTv) {
      return Align(
        alignment: Alignment.bottomRight,
        child: TvFocusable(
          semanticLabel: 'Random channel',
          onSelect: widget.onRandom,
          child: IconButton(
            key: const ValueKey('remote-random'),
            tooltip: 'Random channel',
            onPressed: widget.onRandom,
            icon: const Icon(Icons.casino_outlined),
          ),
        ),
      );
    }

    if (!_visible) {
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _show(),
        child: const SizedBox.expand(),
      );
    }

    return Listener(
      onPointerDown: (_) => _show(),
      child: Center(
        child: Wrap(
          spacing: 8,
          children: [
            _button(
              'remote-volume-down',
              Icons.volume_down,
              widget.onVolumeDown,
            ),
            _button('remote-volume-up', Icons.volume_up, widget.onVolumeUp),
            _button(
              'remote-channel-previous',
              Icons.keyboard_arrow_up,
              widget.onChannelPrevious,
            ),
            _button(
              'remote-channel-next',
              Icons.keyboard_arrow_down,
              widget.onChannelNext,
            ),
            _button('remote-mute', Icons.volume_off, widget.onMute),
            _button('remote-random', Icons.casino_outlined, widget.onRandom),
          ],
        ),
      ),
    );
  }

  Widget _button(String id, IconData icon, VoidCallback? onPressed) {
    return IconButton.filledTonal(
      key: ValueKey(id),
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}
