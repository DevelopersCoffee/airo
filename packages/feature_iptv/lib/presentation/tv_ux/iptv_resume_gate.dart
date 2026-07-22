import 'dart:async';

import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/application/providers/last_channel_provider.dart';
import 'package:feature_iptv/application/resume_last_channel_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_player/platform_player.dart';

import 'iptv_resume_splash.dart';

class IptvResumeGate extends ConsumerStatefulWidget {
  const IptvResumeGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<IptvResumeGate> createState() => _IptvResumeGateState();
}

class _IptvResumeGateState extends ConsumerState<IptvResumeGate> {
  var _splashDone = false;

  @override
  void initState() {
    super.initState();
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

    final resumeStatus = ref.watch(resumeLastChannelControllerProvider);
    final playbackReady =
        ref.watch(playbackStateProvider) == PlaybackState.playing;
    final showSplash =
        !_splashDone &&
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
          onFinished: () {
            if (mounted) setState(() => _splashDone = true);
          },
        ),
      ],
    );
  }
}
