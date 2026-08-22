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
  List<rust.MeetingDecisionRecord>? savedDecisions;
  List<rust.MeetingActionItemRecord>? savedActionItems;
  List<rust.MeetingMetricRecord>? savedMetrics;
  rust.SpeechLanguage? initializedSpeechLanguage;
  rust.TranscriptDocumentRecord? transcriptDocumentToReturn;

  /// `#1664`: what the last `transcribe` call was asked to pin, so a test can
  /// assert a Settings-chosen language reaches the bridge unchanged.
  String? transcribeLanguage;

  /// Set to make [loadLibrary] throw, simulating a platform with no native
  /// library (`MindUnavailable.bridgeMissing`).
  Object? loadLibraryError;

  var _ready = false;

  @override
  Future<void> loadLibrary() async {
    if (loadLibraryError != null) throw loadLibraryError!;
  }

  @override
  bool isReady() => _ready;

  @override
  Future<void> initialize({
    required String modelsDir,
    required String storePath,
    required int memoryBudgetMb,
    rust.SpeechLanguage speechLanguage = rust.SpeechLanguage.englishOnly,
  }) async {
    initializedSpeechLanguage = speechLanguage;
    _ready = true;
  }

  @override
  Stream<TranscriptEvent> transcribe({
    required String wavPath,
    String? language,
  }) {
    transcribeLanguage = language;
    return Stream.fromIterable(transcriptEvents);
  }

  @override
  Future<String> save({
    required String title,
    required int recordedAtMs,
    required String transcript,
    required String minutes,
    required String model,
    required List<TranscriptSegment> segments,
    required String wavPath,
    List<rust.MeetingDecisionRecord> decisions = const [],
    List<rust.MeetingActionItemRecord> actionItems = const [],
    List<rust.MeetingMetricRecord> metrics = const [],
  }) async {
    if (saveError != null) throw saveError!;
    savedModel = model;
    savedSegments = segments;
    savedWavPath = wavPath;
    savedDecisions = decisions;
    savedActionItems = actionItems;
    savedMetrics = metrics;
    return 'meeting-1';
  }

  @override
  Future<rust.TranscriptDocumentRecord?> getTranscript(
    String meetingId,
  ) async => transcriptDocumentToReturn;

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
  List<MeetingIntelligenceEvent> meetingIntelligenceEvents = const [];
  List<GenerationEvent> generationEvents = const [];
  List<GenerationEvent>? completeEvents;
  String modelIdValue = 'test-model@1';
  GenerationStats statsValue = const GenerationStats(
    prefillMs: 0,
    prefillTokens: 0,
    generationMs: 0,
    generatedTokens: 0,
    tokensPerSecond: 0,
    peakRssBytes: 0,
  );
  var ensureLoadedCalls = 0;
  var cancelCalls = 0;
  var unloadCalls = 0;
  String? lastGrammar;
  String? lastCompletePrompt;
  String? lastCompleteGrammar;
  int? lastCompleteMaxOutputTokens;
  var _loaded = false;

  @override
  bool get isLoaded => _loaded;

  @override
  bool get isEngineReady => _loaded;

  @override
  Future<void> ensureLoaded({
    required String modelsDir,
    required int memoryBudgetMb,
    bool preferIndicGeneration = false,
    bool allowCompactFallback = true,
  }) async {
    ensureLoadedCalls++;
    _loaded = true;
  }

  @override
  Stream<MeetingIntelligenceEvent> processMeetingIntelligence({
    required String meetingId,
    required String title,
    required List<TranscriptSegment> segments,
  }) => Stream.fromIterable(meetingIntelligenceEvents);

  @override
  Stream<GenerationEvent> generate({
    required String transcript,
    String? grammar,
  }) {
    lastGrammar = grammar;
    return Stream.fromIterable(generationEvents);
  }

  @override
  Stream<GenerationEvent> complete({
    required String prompt,
    required int maxOutputTokens,
    String? grammar,
  }) {
    lastCompletePrompt = prompt;
    lastCompleteMaxOutputTokens = maxOutputTokens;
    lastCompleteGrammar = grammar;
    return Stream.fromIterable(completeEvents ?? generationEvents);
  }

  @override
  String modelId() => modelIdValue;

  @override
  GenerationStats stats() => statsValue;

  @override
  void unload() {
    unloadCalls++;
    _loaded = false;
  }

  @override
  void cancel() => cancelCalls++;
}
