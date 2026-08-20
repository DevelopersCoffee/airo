import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../whisper/api/meetings.dart' as rust;
import '../domain/speech_language_mode.dart';

/// Persistence key for the Mind capture language Settings tile (#1664 / #1774).
/// Same `SharedPreferences` house pattern as [audioRetentionPolicyKey].
const String speechLanguageModeKey = 'mind_speech_language_mode';

final speechLanguageModeProvider =
    StateNotifierProvider<SpeechLanguageModeNotifier, SpeechLanguageMode>(
      (ref) => SpeechLanguageModeNotifier(),
    );

class SpeechLanguageModeNotifier extends StateNotifier<SpeechLanguageMode> {
  SpeechLanguageModeNotifier() : super(SpeechLanguageMode.fallback) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = SpeechLanguageMode.fromStorageValue(
      prefs.getString(speechLanguageModeKey),
    );
  }

  Future<void> select(SpeechLanguageMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(speechLanguageModeKey, mode.storageValue);
  }
}

/// Bridge mapping kept next to the preference so domain stays free of FRB types.
extension SpeechLanguageModeBridge on SpeechLanguageMode {
  rust.SpeechLanguage get speechLanguage => englishOnly
      ? rust.SpeechLanguage.englishOnly
      : rust.SpeechLanguage.multilingual;
}

/// Reads the persisted mode without Riverpod — used by shell composition
/// (`requiredModelsLookup`, `MindModule.initialize`) before a widget tree
/// exists.
Future<SpeechLanguageMode> loadSpeechLanguageMode() async {
  final prefs = await SharedPreferences.getInstance();
  return SpeechLanguageMode.fromStorageValue(
    prefs.getString(speechLanguageModeKey),
  );
}
