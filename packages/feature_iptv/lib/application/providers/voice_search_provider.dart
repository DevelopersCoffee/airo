import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

enum VoiceSearchState { idle, listening, processing, completed, error }

class VoiceSearchResult {
  final String? text;
  final String? errorMessage;
  final bool isSuccess;
  final double confidence;

  const VoiceSearchResult({
    this.text,
    this.errorMessage,
    this.isSuccess = false,
    this.confidence = 0.0,
  });

  factory VoiceSearchResult.success(String text, {double confidence = 1.0}) {
    return VoiceSearchResult(
      text: text,
      isSuccess: true,
      confidence: confidence,
    );
  }

  factory VoiceSearchResult.error(String message) {
    return VoiceSearchResult(errorMessage: message);
  }

  factory VoiceSearchResult.empty() {
    return const VoiceSearchResult();
  }
}

abstract interface class VoiceSearchService {
  VoiceSearchState get state;
  Stream<VoiceSearchState> get stateStream;
  Future<bool> isAvailable();
  Future<VoiceSearchResult> startListening();
  Future<void> stopListening();
  void dispose();
}

class MockVoiceSearchService implements VoiceSearchService {
  VoiceSearchState _state = VoiceSearchState.idle;
  final _stateController = StreamController<VoiceSearchState>.broadcast();

  @override
  VoiceSearchState get state => _state;

  @override
  Stream<VoiceSearchState> get stateStream => _stateController.stream;

  @override
  Future<bool> isAvailable() async => !kDebugMode;

  @override
  Future<VoiceSearchResult> startListening() async {
    _setState(VoiceSearchState.listening);
    await Future<void>.delayed(const Duration(seconds: 3));
    _setState(VoiceSearchState.processing);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _setState(VoiceSearchState.completed);
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

  void _setState(VoiceSearchState value) {
    _state = value;
    _stateController.add(value);
  }
}

final voiceSearchServiceProvider = Provider<VoiceSearchService>((ref) {
  final service = MockVoiceSearchService();
  ref.onDispose(service.dispose);
  return service;
});

final voiceSearchStateProvider = StreamProvider<VoiceSearchState>((ref) {
  return ref.watch(voiceSearchServiceProvider).stateStream;
});

final voiceSearchAvailableProvider = FutureProvider<bool>((ref) async {
  return ref.watch(voiceSearchServiceProvider).isAvailable();
});
