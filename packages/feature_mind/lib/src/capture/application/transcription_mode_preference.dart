import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/transcription_mode.dart';

const String transcriptionModeKey = 'mind_transcription_mode';

final transcriptionModeProvider =
    StateNotifierProvider<TranscriptionModeNotifier, TranscriptionMode>(
      (ref) => TranscriptionModeNotifier(),
    );

class TranscriptionModeNotifier extends StateNotifier<TranscriptionMode> {
  TranscriptionModeNotifier() : super(TranscriptionMode.fallback) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = TranscriptionMode.fromStorageValue(
      prefs.getString(transcriptionModeKey),
    );
  }

  Future<void> select(TranscriptionMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(transcriptionModeKey, mode.storageValue);
  }
}

Future<TranscriptionMode> loadTranscriptionMode() async {
  final prefs = await SharedPreferences.getInstance();
  return TranscriptionMode.fromStorageValue(
    prefs.getString(transcriptionModeKey),
  );
}
