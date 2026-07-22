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
  const IptvResumeGate({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  ConsumerState<IptvResumeGate> createState() => _IptvResumeGateState();
}

class _IptvResumeGateState extends ConsumerState<IptvResumeGate> {
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

    if (!showSplash) return widget.child;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IptvResumeSplash(
          playbackReady: playbackReady,
          onFinished: _markSplashCompleted,
        ),
      ],
    );
  }

  void _markSplashCompleted() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final completed = ref.read(resumeSplashCompletedProvider);
      if (completed) return;
      ref.read(resumeSplashCompletedProvider.notifier).state = true;
    });
  }
}

final resumeSplashCompletedProvider = StateProvider<bool>((ref) => false);
