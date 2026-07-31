import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

/// Small, opt-in speech surface for screen-reader and read-aloud workflows.
class AiroSpeechService {
  AiroSpeechService._();

  static final AiroSpeechService instance = AiroSpeechService._();
  static const _operationTimeout = Duration(seconds: 30);
  final FlutterTts _tts = FlutterTts();
  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _tts.awaitSpeakCompletion(true).timeout(_operationTimeout);
    await _tts.setSpeechRate(0.48).timeout(_operationTimeout);
    _configured = true;
  }

  /// Returns false when the platform has no usable TTS engine. Read-aloud is
  /// an enhancement and must never turn a chat action into an uncaught error.
  Future<bool> speak(String text) async {
    final value = text.trim();
    if (value.isEmpty) return false;
    try {
      await _ensureConfigured();
      await _tts.stop().timeout(_operationTimeout);
      final result = await _tts.speak(value).timeout(_operationTimeout);
      return result == null || result == 1 || result == true;
    } on Object {
      _configured = false;
      return false;
    }
  }

  Future<bool> stop() async {
    try {
      final result = await _tts.stop().timeout(_operationTimeout);
      return result == null || result == 1 || result == true;
    } on Object {
      return false;
    }
  }
}
