import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_media/platform_media.dart';
import 'package:platform_player/platform_player.dart';

import '../../application/caption_appearance.dart';
import '../../application/caption_webvtt_parser.dart';
import '../../application/providers/caption_preference_provider.dart';
import '../../application/providers/iptv_providers.dart';

/// Renders sidecar WebVTT captions with persisted appearance settings.
class PlayerCaptionOverlay extends ConsumerStatefulWidget {
  const PlayerCaptionOverlay({super.key, required this.state});

  final StreamingState state;

  @override
  ConsumerState<PlayerCaptionOverlay> createState() =>
      _PlayerCaptionOverlayState();
}

class _PlayerCaptionOverlayState extends ConsumerState<PlayerCaptionOverlay> {
  List<CaptionCue> _cues = const [];
  Object? _loadToken;
  String? _loadedSubtitleId;

  @override
  void didUpdateWidget(covariant PlayerCaptionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    unawaited(_syncSubtitleSource());
  }

  @override
  void initState() {
    super.initState();
    unawaited(_syncSubtitleSource());
  }

  Future<void> _syncSubtitleSource() async {
    final selectedId =
        widget.state.selectedTrackIds[AiroPlaybackTrackKind.subtitle];
    if (selectedId == null ||
        !selectedId.startsWith(kAiroExternalSubtitleTrackIdPrefix)) {
      if (_cues.isNotEmpty || _loadedSubtitleId != null) {
        setState(() {
          _cues = const [];
          _loadedSubtitleId = null;
        });
      }
      return;
    }
    if (_loadedSubtitleId == selectedId && _cues.isNotEmpty) return;

    final subtitle = ref
        .read(iptvStreamingServiceProvider)
        .activeExternalSubtitle;
    if (subtitle == null) return;

    final token = Object();
    _loadToken = token;
    try {
      final response = await ref
          .read(dioProvider)
          .get<String>(
            subtitle.handle.value,
            options: Options(responseType: ResponseType.plain),
          );
      if (!mounted || _loadToken != token) return;
      setState(() {
        _cues = parseWebVtt(response.data ?? '');
        _loadedSubtitleId = selectedId;
      });
    } on Object {
      if (!mounted || _loadToken != token) return;
      setState(() {
        _cues = const [];
        _loadedSubtitleId = selectedId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedId =
        widget.state.selectedTrackIds[AiroPlaybackTrackKind.subtitle];
    if (selectedId == null) return const SizedBox.shrink();

    final cue = captionCueAt(_cues, widget.state.position);
    if (cue == null) return const SizedBox.shrink();

    final preference = ref.watch(captionPreferenceProvider);
    final style = captionTextStyle(
      size: preference.textSize,
      color: preference.textColor,
    );

    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(cue.text, textAlign: TextAlign.center, style: style),
            ),
          ),
        ),
      ),
    );
  }
}
