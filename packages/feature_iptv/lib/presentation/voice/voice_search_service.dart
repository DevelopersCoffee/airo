import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    this.confidence = 0,
  });

  factory VoiceSearchResult.empty() {
    return const VoiceSearchResult(isSuccess: false);
  }
}

abstract class VoiceSearchService {
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
  Future<bool> isAvailable() async => false;

  @override
  Future<VoiceSearchResult> startListening() async {
    _setState(VoiceSearchState.listening);
    await Future<void>.delayed(const Duration(milliseconds: 300));
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

  void _setState(VoiceSearchState state) {
    _state = state;
    _stateController.add(state);
  }
}

final voiceSearchServiceProvider = Provider<VoiceSearchService>((ref) {
  final service = MockVoiceSearchService();
  ref.onDispose(service.dispose);
  return service;
});
