import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/audio_retention_policy.dart';

/// Persistence key for the Settings toggle (#1656 AC5). Same
/// `SharedPreferences` house pattern as `selectedAssistantModelIdProvider`
/// (`agent_chat/application/assistant_model_preferences.dart`).
const String audioRetentionPolicyKey = 'mind_audio_retention_policy';

final audioRetentionPolicyProvider =
    StateNotifierProvider<AudioRetentionPolicyNotifier, AudioRetentionPolicy>(
      (ref) => AudioRetentionPolicyNotifier(),
    );

class AudioRetentionPolicyNotifier extends StateNotifier<AudioRetentionPolicy> {
  AudioRetentionPolicyNotifier() : super(AudioRetentionPolicy.fallback) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AudioRetentionPolicy.fromStorageValue(
      prefs.getString(audioRetentionPolicyKey),
    );
  }

  Future<void> select(AudioRetentionPolicy policy) async {
    state = policy;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(audioRetentionPolicyKey, policy.storageValue);
  }
}
