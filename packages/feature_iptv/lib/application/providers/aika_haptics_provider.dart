import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:platform_haptics/platform_haptics.dart';

import '../aika_haptics.dart';
import 'iptv_providers.dart' show sharedPreferencesProvider;

/// Persisted user preference for haptic feedback strength (or off).
class AikaHapticStrengthNotifier extends StateNotifier<AiroHapticStrength> {
  AikaHapticStrengthNotifier(this._ref) : super(AiroHapticStrength.medium) {
    _loadFromStorage();
  }

  static const storageKey = 'aika_haptic_strength';

  final Ref _ref;

  Future<void> setStrength(AiroHapticStrength strength) async {
    state = strength;
    try {
      await _ref
          .read(sharedPreferencesProvider)
          .setString(storageKey, strength.name);
    } catch (_) {
      // Persistence failure must not break the settings screen.
    }
  }

  void _loadFromStorage() {
    try {
      final stored = _ref.read(sharedPreferencesProvider).getString(storageKey);
      if (stored != null) state = AiroHapticStrength.fromName(stored);
    } catch (_) {
      // Keep the default when preferences are unavailable.
    }
  }
}

final aikaHapticStrengthProvider =
    StateNotifierProvider<AikaHapticStrengthNotifier, AiroHapticStrength>(
      (ref) => AikaHapticStrengthNotifier(ref),
    );

final aikaHapticsProvider = Provider<AikaHaptics>((ref) {
  final haptics = EngineAikaHaptics();
  unawaited(haptics.setStrength(ref.read(aikaHapticStrengthProvider)));
  ref.listen<AiroHapticStrength>(
    aikaHapticStrengthProvider,
    (_, next) => unawaited(haptics.setStrength(next)),
  );
  ref.onDispose(() {
    unawaited(haptics.detachCastSession());
    unawaited(haptics.detachLocalPlayback());
  });
  return haptics;
});
