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

  Future<void> speak(String text) async {
    final value = text.trim();
    if (value.isEmpty) return;
    await _ensureConfigured();
    await _tts.stop();
    await _tts.speak(value);
  }

  Future<void> stop() => _tts.stop();
}
