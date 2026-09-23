import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'iptv_providers.dart';

const sleepTimerPresetMinutes = {15, 30, 45, 60};

final sleepTimerTickProvider = Provider<Duration>(
  (ref) => const Duration(minutes: 1),
);

final sleepTimerExpireDelegateProvider = Provider<Future<void> Function()>((
  ref,
) {
  return () async {
    try {
      await ref.read(iptvStreamingServiceProvider).stop();
    } catch (_) {}
    ref.read(isFullscreenModeProvider.notifier).state = false;
  };
});

class SleepTimerNotifier extends StateNotifier<int> {
  SleepTimerNotifier(this._ref) : super(0);

  final Ref _ref;
  Timer? _timer;
  var _expireArmed = false;

  void setMinutes(int minutes) {
    _timer?.cancel();
    if (!sleepTimerPresetMinutes.contains(minutes)) {
      state = 0;
      _expireArmed = false;
      return;
    }
    state = minutes;
    _expireArmed = true;
    _timer = Timer.periodic(_ref.read(sleepTimerTickProvider), (_) {
      handleTick();
    });
  }

  void cancel() {
    _timer?.cancel();
    _expireArmed = false;
    state = 0;
  }

  void handleTick() {
    if (state <= 0) return;
    final next = state - 1;
    state = next;
    if (next > 0) return;
    _timer?.cancel();
    if (!_expireArmed) return;
    _expireArmed = false;
    unawaited(_ref.read(sleepTimerExpireDelegateProvider)());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final sleepTimerRemainingProvider =
    StateNotifierProvider<SleepTimerNotifier, int>(
      (ref) => SleepTimerNotifier(ref),
    );
