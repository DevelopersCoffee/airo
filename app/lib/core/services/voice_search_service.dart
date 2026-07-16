import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

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

/// Mock implementation of VoiceSearchService for testing and fallback
/// On real Fire TV devices, this would be replaced with speech_to_text integration
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
    // Mock: always return false in debug, would check speech recognition
    return !kDebugMode;
  }

  @override
  Future<VoiceSearchResult> startListening() async {
    _setState(VoiceSearchState.listening);

    // Simulate listening for 3 seconds
    await Future<void>.delayed(const Duration(seconds: 3));

    _setState(VoiceSearchState.processing);

    // Simulate processing
    await Future<void>.delayed(const Duration(milliseconds: 500));

    _setState(VoiceSearchState.completed);

    // In mock mode, return empty result
    // Real implementation would return recognized text
    return VoiceSearchResult.empty();
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
