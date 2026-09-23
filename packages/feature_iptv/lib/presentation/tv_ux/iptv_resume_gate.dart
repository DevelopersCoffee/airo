import 'dart:async';

import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/application/providers/last_channel_provider.dart';
import 'package:feature_iptv/application/resume_last_channel_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:platform_player/platform_player.dart';

import 'iptv_resume_splash.dart';

class IptvResumeGate extends ConsumerStatefulWidget {
  const IptvResumeGate({
    super.key,
    required this.child,
    this.enabled = true,
    this.holdUntilTerminal = false,
    this.onEnterWatch,
  });

  final Widget child;
  final bool enabled;
  final bool holdUntilTerminal;
  final VoidCallback? onEnterWatch;

  @override
  ConsumerState<IptvResumeGate> createState() => _IptvResumeGateState();
}

class _IptvResumeGateState extends ConsumerState<IptvResumeGate> {
  var _skippedBeforeDone = false;
  var _enterWatchOffered = false;

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(resumeLastChannelControllerProvider.notifier).attemptResume(),
      );
    });
  }

  bool _isTerminal(ResumeStatus status) {
    return status == ResumeStatus.noTarget ||
        status == ResumeStatus.failed ||
        status == ResumeStatus.done;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(lastChannelRecorderProvider);
    if (!widget.enabled) return widget.child;

    final resumeStatus = ref.watch(resumeLastChannelControllerProvider);
    final splashCompleted = ref.watch(resumeSplashCompletedProvider);
    final playbackReady =
        ref.watch(playbackStateProvider) == PlaybackState.playing;
    final showSplash =
        !splashCompleted &&
        (resumeStatus == ResumeStatus.idle ||
            resumeStatus == ResumeStatus.tuning ||
            resumeStatus == ResumeStatus.done);

    if (widget.holdUntilTerminal &&
        !splashCompleted &&
        _isTerminal(resumeStatus)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _markSplashCompleted();
      });
    }

    if (!showSplash) return widget.child;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IptvResumeSplash(
          playbackReady: playbackReady,
          onFinished: _markSplashCompleted,
          onSkipped: widget.holdUntilTerminal ? _onSkipped : null,
        ),
      ],
    );
  }

  void _onSkipped() {
    _skippedBeforeDone = true;
    if (!mounted) return;
    if (ref.read(resumeSplashCompletedProvider)) return;
    ref.read(resumeSplashCompletedProvider.notifier).state = true;
  }

  void _markSplashCompleted() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final status = ref.read(resumeLastChannelControllerProvider);
      if (widget.holdUntilTerminal &&
          (status == ResumeStatus.idle || status == ResumeStatus.tuning)) {
        return;
      }
      if (ref.read(resumeSplashCompletedProvider)) {
        _offerEnterWatchIfDone(status);
        return;
      }
      ref.read(resumeSplashCompletedProvider.notifier).state = true;
      _offerEnterWatchIfDone(status);
    });
  }

  void _offerEnterWatchIfDone(ResumeStatus status) {
    if (_skippedBeforeDone || _enterWatchOffered) return;
    if (status != ResumeStatus.done) return;
    _enterWatchOffered = true;
    widget.onEnterWatch?.call();
  }
}

final resumeSplashCompletedProvider = StateProvider<bool>((ref) => false);
