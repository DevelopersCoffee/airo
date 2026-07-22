import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:platform_channels/platform_channels.dart';

import 'providers/iptv_providers.dart';
import 'providers/last_channel_provider.dart';

enum ResumeStatus { idle, noTarget, tuning, done, failed }

final resumeLookupTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 10),
);

final playChannelDelegateProvider =
    Provider<Future<void> Function(IPTVChannel)>((ref) {
      return (channel) =>
          ref.read(iptvStreamingServiceProvider).playChannel(channel);
    });

class ResumeLastChannelController extends StateNotifier<ResumeStatus> {
  ResumeLastChannelController(this._ref) : super(ResumeStatus.idle);

  final Ref _ref;
  bool _attempted = false;

  Future<void> attemptResume() async {
    if (_attempted) return;
    _attempted = true;

    try {
      final target = await _ref
          .read(resumeChannelProvider.future)
          .timeout(_ref.read(resumeLookupTimeoutProvider));
      if (target == null) {
        state = ResumeStatus.noTarget;
        return;
      }

      state = ResumeStatus.tuning;
      await _ref.read(playChannelDelegateProvider)(target);
      if (mounted) state = ResumeStatus.done;
    } catch (_) {
      if (mounted) state = ResumeStatus.failed;
    }
  }
}

final resumeLastChannelControllerProvider =
    StateNotifierProvider<ResumeLastChannelController, ResumeStatus>(
      (ref) => ResumeLastChannelController(ref),
    );
