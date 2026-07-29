import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Voice search state
enum VoiceSearchState {
  /// Not listening, idle state
  idle,

  /// Listening for voice input
  listening,

  /// Processing voice input
  processing,

  /// Voice search completed with result
  completed,

  /// Error occurred during voice search
  error,
}

/// Voice search result
class VoiceSearchResult {
  /// The recognized text from voice input
  final String? text;

  /// Error message if search failed
  final String? errorMessage;

  /// Whether the search was successful
  final bool isSuccess;

  /// Confidence score (0.0 to 1.0)
  final double confidence;

  const VoiceSearchResult({
    this.text,
    this.errorMessage,
    this.isSuccess = false,
    this.confidence = 0.0,
  });

  /// Factory for successful result
  factory VoiceSearchResult.success(String text, {double confidence = 1.0}) {
    return VoiceSearchResult(
      text: text,
      isSuccess: true,
      confidence: confidence,
    );
  }

  /// Factory for error result
  factory VoiceSearchResult.error(String message) {
    return VoiceSearchResult(errorMessage: message, isSuccess: false);
  }

  /// Factory for empty result (no speech detected)
  factory VoiceSearchResult.empty() {
    return const VoiceSearchResult(isSuccess: false);
  }
}

/// Abstract interface for voice search functionality
/// Platform-specific implementations can be provided for Android TV, Fire TV, etc.
abstract class VoiceSearchService {
  /// Current state of voice search
  VoiceSearchState get state;

  /// Stream of state changes
  Stream<VoiceSearchState> get stateStream;

  /// Check if voice search is available on this device
  Future<bool> isAvailable();

  /// Start listening for voice input
  /// Returns the recognized text or null if cancelled/error
  Future<VoiceSearchResult> startListening();

  /// Stop listening and cancel voice search
  Future<void> stopListening();

  /// Dispose resources
  void dispose();
}

/// Honest unavailable implementation used until a platform speech adapter is
/// registered. It deliberately does not pretend to listen or return an empty
/// result after an artificial delay.
class MockVoiceSearchService implements VoiceSearchService {
  VoiceSearchState _state = VoiceSearchState.idle;
  final _stateController = StreamController<VoiceSearchState>.broadcast();

  @override
  VoiceSearchState get state => _state;

  @override
  Stream<VoiceSearchState> get stateStream => _stateController.stream;

  void _setState(VoiceSearchState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  @override
  Future<bool> isAvailable() async {
    return false;
  }

  @override
  Future<VoiceSearchResult> startListening() async {
    const message = 'Voice search is unavailable on this device.';
    _setState(VoiceSearchState.error);
    return VoiceSearchResult.error(message);
  }

  @override
  Future<void> stopListening() async {
    _setState(VoiceSearchState.idle);
  }

  @override
  void dispose() {
    _stateController.close();
  }
}

/// Android speech-recognition adapter. The platform recognizer is used only
/// for capture/transcription; generated answers still follow Airo's normal
/// local/cloud runtime policy.
class AndroidVoiceSearchService implements VoiceSearchService {
  AndroidVoiceSearchService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.airo.voice_search');

  final MethodChannel _channel;
  VoiceSearchState _state = VoiceSearchState.idle;
  final _stateController = StreamController<VoiceSearchState>.broadcast();
  bool _disposed = false;

  @override
  VoiceSearchState get state => _state;

  @override
  Stream<VoiceSearchState> get stateStream => _stateController.stream;

  void _setState(VoiceSearchState value) {
    if (_disposed) return;
    _state = value;
    _stateController.add(value);
  }

  @override
  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on PlatformException catch (_) {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<VoiceSearchResult> startListening() async {
    if (!await isAvailable()) {
      const message = 'Speech recognition is unavailable on this device.';
      _setState(VoiceSearchState.error);
      return VoiceSearchResult.error(message);
    }

    _setState(VoiceSearchState.listening);
    try {
      final response = await _channel.invokeMethod<Map<Object?, Object?>>(
        'startListening',
      );
      _setState(VoiceSearchState.processing);
      final result = response == null
          ? const <Object?, Object?>{}
          : Map<Object?, Object?>.from(response);
      final text = (result['text'] as String?)?.trim();
      final error = (result['error'] as String?)?.trim();
      if (text != null && text.isNotEmpty) {
        _setState(VoiceSearchState.completed);
        return VoiceSearchResult.success(
          text,
          confidence: (result['confidence'] as num?)?.toDouble() ?? 1.0,
        );
      }
      final message = error?.isNotEmpty == true
          ? error!
          : 'No speech was recognized.';
      _setState(VoiceSearchState.error);
      return VoiceSearchResult.error(message);
    } on PlatformException catch (error) {
      _setState(VoiceSearchState.error);
      return VoiceSearchResult.error(
        error.message ?? 'Speech recognition failed.',
      );
    } on MissingPluginException {
      _setState(VoiceSearchState.error);
      return VoiceSearchResult.error(
        'Speech recognition is not installed in this build.',
      );
    }
  }

  @override
  Future<void> stopListening() async {
    try {
      await _channel.invokeMethod<void>('stopListening');
    } on PlatformException catch (_) {
      // Stopping is best effort; always restore the public state.
    } on MissingPluginException {
      // Unsupported platform/build: keep the state contract consistent.
    }
    _setState(VoiceSearchState.idle);
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stopListening());
    _stateController.close();
  }
}

/// Provider for VoiceSearchService
final voiceSearchServiceProvider = Provider<VoiceSearchService>((ref) {
  final service = defaultTargetPlatform == TargetPlatform.android
      ? AndroidVoiceSearchService()
      : MockVoiceSearchService();
  ref.onDispose(service.dispose);
  return service;
});

/// Provider for voice search state
final voiceSearchStateProvider = StreamProvider<VoiceSearchState>((ref) {
  final service = ref.watch(voiceSearchServiceProvider);
  return service.stateStream;
});

/// Provider for checking if voice search is available
final voiceSearchAvailableProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(voiceSearchServiceProvider);
  return service.isAvailable();
});
