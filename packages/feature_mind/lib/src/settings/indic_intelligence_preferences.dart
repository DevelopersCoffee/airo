import 'package:flutter_riverpod/legacy.dart';

import '../mind_indic_intelligence.dart';

final indicGenerationModeProvider =
    StateNotifierProvider<IndicGenerationModeNotifier, MindIndicGenerationMode>(
      (ref) => IndicGenerationModeNotifier(),
    );

final indicSpeechModeProvider =
    StateNotifierProvider<IndicSpeechModeNotifier, MindIndicSpeechMode>(
      (ref) => IndicSpeechModeNotifier(),
    );

class IndicGenerationModeNotifier extends StateNotifier<MindIndicGenerationMode> {
  IndicGenerationModeNotifier() : super(MindIndicGenerationMode.auto) {
    _load();
  }

  Future<void> _load() async {
    state = await MindIndicPreferences.readGenerationMode();
  }

  Future<void> select(MindIndicGenerationMode mode) async {
    state = mode;
    await MindIndicPreferences.writeGenerationMode(mode);
  }
}

class IndicSpeechModeNotifier extends StateNotifier<MindIndicSpeechMode> {
  IndicSpeechModeNotifier() : super(MindIndicSpeechMode.auto) {
    _load();
  }

  Future<void> _load() async {
    state = await MindIndicPreferences.readSpeechMode();
  }

  Future<void> select(MindIndicSpeechMode mode) async {
    state = mode;
    await MindIndicPreferences.writeSpeechMode(mode);
  }
}
