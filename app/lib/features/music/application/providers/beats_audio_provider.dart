import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/services/beats_audio_handler.dart';

/// Singleton instance of BeatsAudioHandler
BeatsAudioHandler? _audioHandler;
Future<BeatsAudioHandler>? _audioHandlerInitialization;

/// Initialize the audio service - call this once from startup orchestration.
Future<BeatsAudioHandler> initAudioService() async {
  if (_audioHandler != null) return _audioHandler!;
  if (_audioHandlerInitialization != null) return _audioHandlerInitialization!;

  _audioHandlerInitialization = _initializeAudioServiceWithRetry();
  try {
    _audioHandler = await _audioHandlerInitialization!;
    return _audioHandler!;
  } finally {
    if (_audioHandler == null) {
      _audioHandlerInitialization = null;
    }
  }
}

Future<BeatsAudioHandler> _initializeAudioServiceWithRetry() async {
  const maxAttempts = 5;

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await AudioService.init(
        builder: () => BeatsAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.airo.app.audio',
          androidNotificationChannelName: 'Airo Music',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          androidNotificationIcon: 'mipmap/ic_launcher',
          fastForwardInterval: Duration(seconds: 10),
          rewindInterval: Duration(seconds: 10),
        ),
      );
    } on PlatformException catch (error) {
      if (!_isSharedEngineStartupRace(error) || attempt == maxAttempts) {
        rethrow;
      }

      await Future<void>.delayed(Duration(milliseconds: attempt * 200));
    }
  }

  throw StateError('Audio service initialization exited without a result.');
}

bool _isSharedEngineStartupRace(PlatformException error) {
  final message = error.message;
  return message != null && message.contains('correct FlutterEngine');
}

/// Provider for BeatsAudioHandler
/// This requires initAudioService() to complete before use.
final beatsAudioHandlerProvider = Provider<BeatsAudioHandler>((ref) {
  if (_audioHandler == null) {
    throw StateError(
      'Audio service not initialized. It is scheduled during startup and may still be warming up.',
    );
  }
  return _audioHandler!;
});

