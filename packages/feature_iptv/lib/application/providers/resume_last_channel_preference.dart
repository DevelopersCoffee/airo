import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'iptv_providers.dart' show sharedPreferencesProvider;

const iptvResumeLastChannelEnabledKey = 'iptv_resume_last_channel_enabled';

class ResumeLastChannelEnabledNotifier extends StateNotifier<bool> {
  ResumeLastChannelEnabledNotifier(this._ref) : super(true) {
    _loadFromStorage();
  }

  final Ref _ref;

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    try {
      await _ref
          .read(sharedPreferencesProvider)
          .setBool(iptvResumeLastChannelEnabledKey, enabled);
    } catch (_) {
      // Settings persistence failures must not affect playback.
    }
  }

  void _loadFromStorage() {
    try {
      final stored = _ref
          .read(sharedPreferencesProvider)
          .getBool(iptvResumeLastChannelEnabledKey);
      if (stored != null) {
        state = stored;
      }
    } catch (_) {
      // Keep default ON when preferences are unavailable.
    }
  }
}

final resumeLastChannelEnabledProvider =
    StateNotifierProvider<ResumeLastChannelEnabledNotifier, bool>(
      (ref) => ResumeLastChannelEnabledNotifier(ref),
    );
