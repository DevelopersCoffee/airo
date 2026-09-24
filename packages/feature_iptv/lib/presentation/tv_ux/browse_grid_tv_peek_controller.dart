import 'dart:async';

import 'package:flutter/material.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_media/platform_media.dart';
import 'package:platform_player/platform_player.dart';

import '../widgets/tv_mini_guide_overlay.dart';

/// One muted preview decoder for the TV library grid — same session class as
/// [TvMiniGuideOverlay], owned by [ChannelLibraryGrid] instead of Watch.
class BrowseGridTvPeekController {
  BrowseGridTvPeekController({
    required TvMiniGuidePreviewFactory previewFactory,
  }) : _previewFactory = previewFactory;

  static const settleDuration = Duration(milliseconds: 500);
  static const firstFrameTimeout = Duration(seconds: 4);

  final TvMiniGuidePreviewFactory _previewFactory;

  Timer? _settleTimer;
  Timer? _firstFrameTimer;
  int _epoch = 0;
  VideoPlayerStreamingService? _preview;
  StreamSubscription<StreamingState>? _previewSub;
  LayerLink? _anchorLink;
  IPTVChannel? _focusedChannel;
  String? _previewChannelId;
  bool _previewHasFrame = false;
  bool _previewFailed = false;

  LayerLink? get anchorLink => _anchorLink;
  IPTVChannel? get focusedChannel => _focusedChannel;
  bool get isStartingPreview =>
      _previewChannelId != null && !_previewHasFrame && !_previewFailed;
  Widget? get previewView =>
      _previewHasFrame && !_previewFailed ? _preview?.buildVideoView() : null;

  void onTileFocused(IPTVChannel channel, LayerLink anchorLink) {
    if (_focusedChannel?.id == channel.id && _anchorLink == anchorLink) {
      return;
    }
    _focusedChannel = channel;
    _anchorLink = anchorLink;
    _schedulePreview(channel);
  }

  void onTileUnfocused() {
    _cancelScheduledPreview();
  }

  void onLibrarySignatureChanged() {
    _epoch++;
    _cancelScheduledPreview();
    unawaited(_stopPreviewSession());
  }

  void dispose() {
    _epoch++;
    _settleTimer?.cancel();
    _firstFrameTimer?.cancel();
    unawaited(_stopPreviewSession());
  }

  Future<void> releaseBeforePlay() async {
    _epoch++;
    _settleTimer?.cancel();
    _firstFrameTimer?.cancel();
    await _stopPreviewSession();
  }

  void _schedulePreview(IPTVChannel channel) {
    _settleTimer?.cancel();
    _firstFrameTimer?.cancel();
    _epoch++;
    final epoch = _epoch;
    _previewChannelId = null;
    _previewHasFrame = false;
    _previewFailed = false;
    unawaited(_stopPreviewSession());
    _settleTimer = Timer(settleDuration, () {
      unawaited(_startPreview(channel, epoch));
    });
  }

  void _cancelScheduledPreview() {
    _settleTimer?.cancel();
    _firstFrameTimer?.cancel();
    _epoch++;
    _previewChannelId = null;
    _previewHasFrame = false;
    _previewFailed = false;
    unawaited(_stopPreviewSession());
  }

  Future<void> _stopPreviewSession() async {
    _firstFrameTimer?.cancel();
    final preview = _preview;
    final sub = _previewSub;
    _preview = null;
    _previewSub = null;
    _previewChannelId = null;
    _previewHasFrame = false;
    await sub?.cancel();
    if (preview == null) return;
    try {
      await preview.stop();
    } catch (_) {}
    try {
      await preview.dispose();
    } catch (_) {}
  }

  Future<void> _startPreview(IPTVChannel channel, int epoch) async {
    if (epoch != _epoch) return;
    await _stopPreviewSession();
    if (epoch != _epoch) return;

    final preview = _previewFactory();
    _preview = preview;
    _previewChannelId = channel.id;

    _previewSub = preview.stateStream.listen((state) {
      if (epoch != _epoch || _preview != preview) return;
      if (state.hasError) {
        _previewFailed = true;
      }
      if (state.playbackState == PlaybackState.playing) {
        _previewHasFrame = true;
        _firstFrameTimer?.cancel();
      }
    });

    _firstFrameTimer = Timer(firstFrameTimeout, () {
      if (epoch != _epoch || _preview != preview) return;
      if (!_previewHasFrame) {
        _previewFailed = true;
        unawaited(_stopPreviewSession());
      }
    });

    try {
      await preview.setVolume(0);
      if (!preview.currentState.isMuted) {
        await preview.toggleMute();
      }
      if (epoch != _epoch || _preview != preview) return;
      await preview.playChannel(channel);
      if (epoch != _epoch || _preview != preview) return;
      if (preview.currentState.hasError ||
          preview.currentState.playbackState != PlaybackState.playing) {
        _previewFailed = true;
        await _stopPreviewSession();
      }
    } catch (_) {
      if (epoch != _epoch) return;
      _previewFailed = true;
      await _stopPreviewSession();
    }
  }
}
