import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'voice_search_desktop_stub.dart'
    if (dart.library.io) 'voice_search_desktop.dart'
    as desktop;

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
  AndroidVoiceSearchService({
    MethodChannel? channel,
    this.operationTimeout = const Duration(seconds: 45),
    this.stopTimeout = const Duration(seconds: 2),
  }) : _channel = channel ?? const MethodChannel('com.airo.voice_search');

  final MethodChannel _channel;
  final Duration operationTimeout;
  final Duration stopTimeout;
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
      final response = await _channel
          .invokeMethod<Map<Object?, Object?>>('startListening')
          .timeout(operationTimeout);
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
    } on TimeoutException {
      // A recognizer can lose its terminal callback when the activity pauses
      // or the system speech service is reclaimed. Always cancel the native
      // request and restore a terminal state instead of leaving the UI stuck.
      unawaited(_stopNativeListening());
      _setState(VoiceSearchState.error);
      return VoiceSearchResult.error(
        'Speech recognition timed out. Please try again.',
      );
    }
  }

  @override
  Future<void> stopListening() async {
    await _stopNativeListening();
    _setState(VoiceSearchState.idle);
  }

  Future<void> _stopNativeListening() async {
    try {
      await _channel.invokeMethod<void>('stopListening').timeout(stopTimeout);
    } on PlatformException catch (_) {
      // Stopping is best effort; always restore the public state.
    } on MissingPluginException {
      // Unsupported platform/build: keep the state contract consistent.
    } on TimeoutException {
      // The native stop call must not block disposal or a retry.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stopListening());
    _stateController.close();
  }
}

/// Desktop mic path: record WAV, then transcribe with on-device whisper.
///
/// Does not call Apple's Speech framework. `speech_to_text` on macOS can
/// abort the process (TCC) when the sandbox/prompt is not ready; chat voice
/// must survive a tap even when permission is denied.
class DesktopWhisperVoiceSearchService implements VoiceSearchService {
  DesktopWhisperVoiceSearchService({
    required this.hasPermission,
    required this.startCapture,
    required this.stopCapture,
    required this.transcribe,
    required this.tempPath,
  });

  final Future<bool> Function() hasPermission;
  final Future<void> Function(String path) startCapture;
  final Future<String?> Function() stopCapture;
  final Future<String> Function(String path) transcribe;
  final Future<String> Function() tempPath;

  VoiceSearchState _state = VoiceSearchState.idle;
  final _stateController = StreamController<VoiceSearchState>.broadcast();
  Completer<void>? _untilStop;
  var _recording = false;
  var _disposed = false;

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
      return await hasPermission();
    } on Object {
      return false;
    }
  }

  @override
  Future<VoiceSearchResult> startListening() async {
    try {
      if (!await isAvailable()) {
        _setState(VoiceSearchState.error);
        return VoiceSearchResult.error(
          'Microphone access is required. Allow it in System Settings → Privacy & Security → Microphone.',
        );
      }
      final path = await tempPath();
      await startCapture(path);
      _recording = true;
      _setState(VoiceSearchState.listening);
      _untilStop = Completer<void>();
      await _untilStop!.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {},
      );
      final recorded = await _finishCapture() ?? path;
      _setState(VoiceSearchState.processing);
      final text = (await transcribe(recorded)).trim();
      if (text.isEmpty) {
        _setState(VoiceSearchState.error);
        return VoiceSearchResult.error('No speech was recognized.');
      }
      _setState(VoiceSearchState.completed);
      return VoiceSearchResult.success(text);
    } on Object catch (error) {
      await _finishCapture();
      _setState(VoiceSearchState.error);
      return VoiceSearchResult.error(
        'Voice input failed. ${error.toString()}',
      );
    }
  }

  Future<String?> _finishCapture() async {
    if (!_recording) return null;
    _recording = false;
    try {
      return await stopCapture();
    } on Object {
      return null;
    }
  }

  @override
  Future<void> stopListening() async {
    final gate = _untilStop;
    if (gate != null && !gate.isCompleted) {
      gate.complete();
    }
    _untilStop = null;
    await _finishCapture();
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
  final VoiceSearchService service;
  if (defaultTargetPlatform == TargetPlatform.android) {
    service = AndroidVoiceSearchService();
  } else if (defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux) {
    service = desktop.createDesktopWhisperVoiceSearchService();
  } else {
    service = MockVoiceSearchService();
  }
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
