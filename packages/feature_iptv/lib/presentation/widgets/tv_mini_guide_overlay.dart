import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_media/platform_media.dart';
import 'package:platform_player/platform_player.dart';

import 'channel_logo.dart';

/// Creates the single Mini Guide preview decoder. Tests override this so they
/// can count start/stop without opening a real engine.
typedef TvMiniGuidePreviewFactory = VideoPlayerStreamingService Function();

final tvMiniGuidePreviewFactoryProvider = Provider<TvMiniGuidePreviewFactory>((
  ref,
) {
  return () => VideoPlayerStreamingService(mixWithOthers: true);
});

/// Watch Mini Guide: logos on every card, one muted preview on the focused
/// card after a short settle. Closing the overlay always releases the preview.
class TvMiniGuideOverlay extends StatefulWidget {
  const TvMiniGuideOverlay({
    super.key,
    required this.channels,
    required this.currentChannelId,
    required this.onSelected,
    required this.previewFactory,
    this.settleDuration = defaultSettleDuration,
  });

  static const defaultSettleDuration = Duration(milliseconds: 500);

  final List<IPTVChannel> channels;
  final String? currentChannelId;
  final ValueChanged<IPTVChannel> onSelected;
  final TvMiniGuidePreviewFactory previewFactory;
  final Duration settleDuration;

  @override
  State<TvMiniGuideOverlay> createState() => _TvMiniGuideOverlayState();
}

class _TvMiniGuideOverlayState extends State<TvMiniGuideOverlay> {
  late List<FocusNode> _focusNodes;
  late int _focusedIndex;
  Timer? _settleTimer;
  int _epoch = 0;
  VideoPlayerStreamingService? _preview;
  StreamSubscription<StreamingState>? _previewSub;
  String? _previewChannelId;
  String? _errorChannelId;
  String? _scheduledChannelId;
  bool _previewHasFrame = false;

  String get _channelSignature =>
      widget.channels.map((channel) => channel.id).join('|');

  @override
  void initState() {
    super.initState();
    _createFocusNodes();
    _requestInitialFocus();
  }

  @override
  void didUpdateWidget(covariant TvMiniGuideOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldSignature = oldWidget.channels
        .map((channel) => channel.id)
        .join('|');
    if (oldSignature == _channelSignature &&
        oldWidget.currentChannelId == widget.currentChannelId) {
      return;
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    _createFocusNodes();
    _requestInitialFocus();
  }

  @override
  void dispose() {
    _epoch++;
    _settleTimer?.cancel();
    _stopPreviewSession();
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _createFocusNodes() {
    _focusedIndex = widget.channels.indexWhere(
      (channel) => channel.id == widget.currentChannelId,
    );
    if (_focusedIndex < 0) _focusedIndex = 0;
    _focusNodes = [
      for (final channel in widget.channels)
        FocusNode(debugLabel: 'quick browse ${channel.name}'),
    ];
  }

  void _requestInitialFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _focusNodes.isEmpty) return;
      _focusNodes[_focusedIndex].requestFocus();
    });
  }

  KeyEventResult _handleBrowseKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || widget.channels.isEmpty) {
      return KeyEventResult.ignored;
    }
    final key = TvInputHandler.mapLogicalKeyToTvInput(event.logicalKey);
    final nextIndex = switch (key) {
      TvInputKey.left => (_focusedIndex - 1).clamp(
        0,
        widget.channels.length - 1,
      ),
      TvInputKey.right => (_focusedIndex + 1).clamp(
        0,
        widget.channels.length - 1,
      ),
      _ => null,
    };
    if (nextIndex != null) {
      _focusedIndex = nextIndex;
      _focusNodes[_focusedIndex].requestFocus();
      return KeyEventResult.handled;
    }
    if (key == TvInputKey.up || key == TvInputKey.down) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onCardFocused(int index) {
    if (index < 0 || index >= widget.channels.length) return;
    final channel = widget.channels[index];
    _focusedIndex = index;
    if (_scheduledChannelId == channel.id) return;
    _schedulePreview(channel);
  }

  void _schedulePreview(IPTVChannel channel) {
    _settleTimer?.cancel();
    _epoch++;
    final epoch = _epoch;
    _scheduledChannelId = channel.id;
    _errorChannelId = null;
    _previewHasFrame = false;
    _stopPreviewSession();
    _settleTimer = Timer(widget.settleDuration, () {
      if (!mounted || epoch != _epoch) return;
      unawaited(_startPreview(channel, epoch));
    });
    if (mounted) setState(() {});
  }

  void _stopPreviewSession() {
    final preview = _preview;
    final sub = _previewSub;
    _preview = null;
    _previewSub = null;
    _previewChannelId = null;
    _previewHasFrame = false;
    unawaited(sub?.cancel());
    if (preview == null) return;
    unawaited(preview.stop().catchError((_) {}));
    unawaited(preview.dispose().catchError((_) {}));
  }

  Future<void> _startPreview(IPTVChannel channel, int epoch) async {
    if (!mounted || epoch != _epoch) return;
    _stopPreviewSession();
    if (!mounted || epoch != _epoch) return;

    final preview = widget.previewFactory();
    _preview = preview;
    _previewChannelId = channel.id;
    if (mounted) setState(() {});

    _previewSub = preview.stateStream.listen((state) {
      if (!mounted || epoch != _epoch || _preview != preview) return;
      setState(() {
        if (state.hasError) {
          _errorChannelId = channel.id;
        }
        if (state.playbackState == PlaybackState.playing) {
          _previewHasFrame = true;
        }
      });
    });

    try {
      await preview.playChannel(channel);
      if (!mounted || epoch != _epoch || _preview != preview) return;
      if (preview.currentState.hasError ||
          preview.currentState.playbackState != PlaybackState.playing) {
        setState(() => _errorChannelId = channel.id);
        _stopPreviewSession();
        return;
      }
      await preview.setVolume(0);
      if (!preview.currentState.isMuted) {
        await preview.toggleMute();
      }
      if (!mounted || epoch != _epoch || _preview != preview) return;
      setState(() {
        if (preview.currentState.hasError) {
          _errorChannelId = channel.id;
        }
        if (preview.currentState.playbackState == PlaybackState.playing) {
          _previewHasFrame = true;
        }
      });
    } catch (_) {
      if (epoch != _epoch) return;
      if (mounted) setState(() => _errorChannelId = channel.id);
      _stopPreviewSession();
    }
  }

  void _selectChannel(IPTVChannel channel) {
    _epoch++;
    _settleTimer?.cancel();
    _stopPreviewSession();
    widget.onSelected(channel);
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Colors.white;
    final muted = Colors.white54;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _handleBrowseKey,
        child: FocusScope(
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              AiroSpacing.lg,
              AiroSpacing.md,
              AiroSpacing.lg,
              AiroSpacing.md,
            ),
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
                      'Mini guide',
                      style: AiroTypography.titleSmall.copyWith(
                        color: onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '◀ ▶ browse   OK switch',
                      style: AiroTypography.labelSmall.copyWith(color: muted),
                    ),
                  ],
                ),
                const SizedBox(height: AiroSpacing.sm),
                SizedBox(
                  height: 132,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.channels.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: AiroSpacing.sm),
                    itemBuilder: (context, index) {
                      final channel = widget.channels[index];
                      return _MiniGuideCard(
                        channel: channel,
                        isCurrent: channel.id == widget.currentChannelId,
                        showError: _errorChannelId == channel.id,
                        showSpinner:
                            index == _focusedIndex &&
                            _previewChannelId == channel.id &&
                            !_previewHasFrame &&
                            _errorChannelId != channel.id,
                        showPreview:
                            index == _focusedIndex &&
                            _previewChannelId == channel.id &&
                            _previewHasFrame &&
                            _errorChannelId != channel.id,
                        previewView: _preview?.buildVideoView(),
                        focusNode: _focusNodes[index],
                        onFocus: () => _onCardFocused(index),
                        onSelect: () => _selectChannel(channel),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniGuideCard extends StatelessWidget {
  const _MiniGuideCard({
    required this.channel,
    required this.isCurrent,
    required this.showError,
    required this.showSpinner,
    required this.showPreview,
    required this.previewView,
    required this.focusNode,
    required this.onFocus,
    required this.onSelect,
  });

  final IPTVChannel channel;
  final bool isCurrent;
  final bool showError;
  final bool showSpinner;
  final bool showPreview;
  final Widget? previewView;
  final FocusNode focusNode;
  final VoidCallback onFocus;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      key: ValueKey('quick-browse-${channel.id}'),
      focusNode: focusNode,
      semanticLabel: channel.name,
      onFocus: onFocus,
      onSelect: onSelect,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(AiroSpacing.sm),
        decoration: BoxDecoration(
          color: isCurrent
              ? Colors.white.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AiroSpacing.radiusSm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AiroSpacing.radiusXs),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ChannelLogo(
                      logoUrl: channel.logoUrl,
                      channelName: channel.name,
                      size: 72,
                      width: 144,
                      fit: BoxFit.contain,
                      isAudioOnly: channel.isAudioOnly,
                    ),
                    if (showPreview && previewView != null)
                      ColoredBox(
                        key: ValueKey('mini-guide-preview-${channel.id}'),
                        color: Colors.black,
                        child: IgnorePointer(child: previewView),
                      ),
                    if (showSpinner)
                      const ColoredBox(
                        color: Colors.black54,
                        child: Center(
                          child: SizedBox(
                            width: AiroSpacing.lg,
                            height: AiroSpacing.lg,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    if (showError)
                      ColoredBox(
                        key: ValueKey('mini-guide-error-${channel.id}'),
                        color: Colors.black54,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AiroSpacing.xs),
                            child: Text(
                              'Preview unavailable',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AiroTypography.labelSmall.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (showPreview)
                      Positioned(
                        top: AiroSpacing.xs,
                        left: AiroSpacing.xs,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            borderRadius: BorderRadius.circular(
                              AiroSpacing.radiusXs,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AiroSpacing.xs,
                              vertical: AiroSpacing.xxs,
                            ),
                            child: Text(
                              'LIVE',
                              style: AiroTypography.labelSmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AiroSpacing.xs),
            if (isCurrent)
              Text(
                'ON NOW',
                style: AiroTypography.labelSmall.copyWith(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            Text(
              channel.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AiroTypography.labelLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
