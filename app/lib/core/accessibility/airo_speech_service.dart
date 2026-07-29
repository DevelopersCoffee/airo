import 'package:flutter_tts/flutter_tts.dart';

/// Small, opt-in speech surface for screen-reader and read-aloud workflows.
class AiroSpeechService {
  AiroSpeechService._();

  static final AiroSpeechService instance = AiroSpeechService._();
  final FlutterTts _tts = FlutterTts();
  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _tts.awaitSpeakCompletion(true);
    await _tts.setSpeechRate(0.48);
    _configured = true;
  }

  /// Returns false when the platform has no usable TTS engine. Read-aloud is
  /// an enhancement and must never turn a chat action into an uncaught error.
  Future<bool> speak(String text) async {
    final value = text.trim();
    if (value.isEmpty) return false;
    try {
      await _ensureConfigured();
      await _tts.stop();
      final result = await _tts.speak(value);
      return result == null || result == 1 || result == true;
    } on Object {
      _configured = false;
      return false;
    }
  }

  Future<bool> stop() async {
    try {
      final result = await _tts.stop();
      return result == null || result == 1 || result == true;
    } on Object {
      return false;
    }
  }
}
