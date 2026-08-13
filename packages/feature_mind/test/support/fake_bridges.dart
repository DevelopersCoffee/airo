import 'dart:async';

import 'package:feature_mind/src/bridges/mind_generation_bridge.dart';
import 'package:feature_mind/src/bridges/mind_speech_bridge.dart';
import 'package:feature_mind/src/whisper/api/meetings.dart' as rust;

/// Scripts a [TranscriptEvent] sequence for [MindSpeechBridge.transcribe] and
/// records every call, so tests can assert on sequencing and cancellation
/// without a native library.
class FakeMindSpeechBridge implements MindSpeechBridge {
  List<TranscriptEvent> transcriptEvents = const [];
  Object? saveError;
  var cancelCalls = 0;
  String? savedModel;

  /// What the last `save` call carried — `#1629` Gap D: lets a test assert
  /// the segments and audio path that reached `process()` are exactly what
  /// gets threaded to the bridge, without a real Rust store.
  List<TranscriptSegment>? savedSegments;
  String? savedWavPath;
  rust.SpeechLanguage? initializedSpeechLanguage;
  rust.TranscriptDocumentRecord? transcriptDocumentToReturn;

  /// Set to make [loadLibrary] throw, simulating a platform with no native
  /// library (`MindUnavailable.bridgeMissing`).
  Object? loadLibraryError;

  @override
  Future<void> loadLibrary() async {
    if (loadLibraryError != null) throw loadLibraryError!;
  }

  @override
  bool isReady() => true;

  @override
  Future<void> initialize({
    required String modelsDir,
    required String storePath,
    required int memoryBudgetMb,
    rust.SpeechLanguage speechLanguage = rust.SpeechLanguage.englishOnly,
  }) async {
    initializedSpeechLanguage = speechLanguage;
  }

  @override
  Stream<TranscriptEvent> transcribe({required String wavPath}) =>
      Stream.fromIterable(transcriptEvents);

  @override
  Future<String> save({
    required String title,
    required int recordedAtMs,
    required String transcript,
    required String minutes,
    required String model,
    required List<TranscriptSegment> segments,
    required String wavPath,
  }) async {
    if (saveError != null) throw saveError!;
    savedModel = model;
    savedSegments = segments;
    savedWavPath = wavPath;
    return 'meeting-1';
  }

  @override
  Future<rust.TranscriptDocumentRecord?> getTranscript(String meetingId) async =>
      transcriptDocumentToReturn;

  @override
  void cancel() => cancelCalls++;

  @override
  Future<List<rust.MeetingRecord>> meetings() async => [];

  @override
  Future<List<rust.SearchHit>> search(String query) async => [];

  @override
  Future<rust.MeetingRecord?> meeting(String id) async => null;
}

/// Same idea, for the generation half. [ensureLoaded] is tracked separately
/// from construction so a test can assert it was never called (T5).
class FakeMindGenerationBridge implements MindGenerationBridge {
  List<GenerationEvent> generationEvents = const [];
  String modelIdValue = 'test-model@1';
  var ensureLoadedCalls = 0;
  var cancelCalls = 0;
  var _loaded = false;

  @override
  bool get isLoaded => _loaded;

  @override
  Future<void> ensureLoaded({
    required String modelsDir,
    required int memoryBudgetMb,
  }) async {
    ensureLoadedCalls++;
    _loaded = true;
  }

  @override
  Stream<GenerationEvent> generate({required String transcript}) =>
      Stream.fromIterable(generationEvents);

  @override
  String modelId() => modelIdValue;

  @override
  void cancel() => cancelCalls++;
}
