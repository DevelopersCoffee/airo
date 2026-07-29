import 'dart:async';

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

/// Provider for VoiceSearchService
final voiceSearchServiceProvider = Provider<VoiceSearchService>((ref) {
  final service = MockVoiceSearchService();
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
