import 'package:flutter/foundation.dart';

import '../library_loader.dart';
import '../whisper/api/meetings.dart' as rust;

/// Transcription progress, mirroring `rust.TranscriptEvent` one for one.
///
/// A distinct type rather than re-exporting the generated one: this is the
/// abstraction's own contract, and it must not change shape just because
/// `flutter_rust_bridge_codegen` regenerated its output.
@immutable
sealed class TranscriptEvent {
  const TranscriptEvent();
}

final class TranscriptEventTranscribing extends TranscriptEvent {
  const TranscriptEventTranscribing(this.text);
  final String text;
}

final class TranscriptEventTranscriptReady extends TranscriptEvent {
  const TranscriptEventTranscriptReady(this.text);
  final String text;
}

final class TranscriptEventCancelled extends TranscriptEvent {
  const TranscriptEventCancelled();
}

/// The speech half of the pipeline, and the meeting library. Behind this
/// abstraction rather than called directly is what makes `MindService`'s
/// sequencing testable at all — see
/// `docs/superpowers/specs/2026-08-06-airo-mind-journey-coverage.md` §3, T3–T8.
///
/// Not a claim that a second speech engine is coming. Whisper stays pinned;
/// this interface exists so a test can stand somewhere, not as a plugin
/// system.
abstract interface class MindSpeechBridge {
  /// Loads the native library. Separate from [initialize] so
  /// `MindService.initialize` can fail fast on a platform with no bridge
  /// (`MindUnavailable.bridgeMissing`) before spending time acquiring model
  /// weights that a working bridge would still need — the same order the
  /// original inline implementation used.
  Future<void> loadLibrary();

  /// True once the speech model has loaded and the store is open.
  bool isReady();

  /// Loads the speech model and opens the store. Requires [loadLibrary] to
  /// have already succeeded.
  Future<void> initialize({
    required String modelsDir,
    required String storePath,
    required int memoryBudgetMb,
  });

  Stream<TranscriptEvent> transcribe({required String wavPath});

  /// Makes a meeting durable and searchable. Returns its id.
  ///
  /// `model` is the logical identity of whatever produced `minutes`
  /// (`ADR-0018 §5`) — it comes from [MindGenerationBridge.modelId], not from
  /// this bridge, because only the generation library knows it.
  Future<String> save({
    required String title,
    required int recordedAtMs,
    required String transcript,
    required String minutes,
    required String model,
  });

  void cancel();

  // The meeting library. Reads, not part of the transcribe/generate/save
  // pipeline, but owned by the same library that owns the store — kept on
  // this bridge rather than left as a fourth, ungoverned direct call.
  Future<List<rust.MeetingRecord>> meetings();
  Future<List<rust.SearchHit>> search(String query);
  Future<rust.MeetingRecord?> meeting(String id);
}

/// Delegates to the generated whisper bridge. The production default —
/// nothing about `MindService`'s runtime behaviour changes by this type
/// existing.
class RustMindSpeechBridge implements MindSpeechBridge {
  const RustMindSpeechBridge();

  @override
  Future<void> loadLibrary() => initializeWhisperBridge();

  @override
  bool isReady() => rust.isReady();

  @override
  Future<void> initialize({
    required String modelsDir,
    required String storePath,
    required int memoryBudgetMb,
  }) => rust.initialize(
    config: rust.MindConfig(
      modelsDir: modelsDir,
      storePath: storePath,
      memoryBudgetMb: memoryBudgetMb,
    ),
  );

  @override
  Stream<TranscriptEvent> transcribe({required String wavPath}) =>
      rust.transcribeRecording(wavPath: wavPath).map((event) {
        return switch (event) {
          rust.TranscriptEvent_Transcribing(:final text) =>
            TranscriptEventTranscribing(text),
          rust.TranscriptEvent_TranscriptReady(:final text) =>
            TranscriptEventTranscriptReady(text),
          rust.TranscriptEvent_Cancelled() => const TranscriptEventCancelled(),
        };
      });

  @override
  Future<String> save({
    required String title,
    required int recordedAtMs,
    required String transcript,
    required String minutes,
    required String model,
  }) => rust.saveMeeting(
    title: title,
    recordedAtMs: BigInt.from(recordedAtMs),
    transcript: transcript,
    minutes: minutes,
    model: model,
  );

  @override
  void cancel() => rust.cancelProcessing();

  @override
  Future<List<rust.MeetingRecord>> meetings() => rust.listMeetings();

  @override
  Future<List<rust.SearchHit>> search(String query) =>
      rust.searchMeetings(query: query);

  @override
  Future<rust.MeetingRecord?> meeting(String id) => rust.getMeeting(id: id);
}
