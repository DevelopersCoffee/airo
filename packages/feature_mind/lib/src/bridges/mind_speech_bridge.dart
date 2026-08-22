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

/// One transcript segment, with the evidence-grounding fields `#1657` needs:
/// a stable id (scoped to the recording that produced it) and the audio
/// timestamps whisper reported. Mirrors `rust.TranscriptSegmentRecord` for
/// the same reason [TranscriptEvent] mirrors `rust.TranscriptEvent`.
@immutable
class TranscriptSegment {
  const TranscriptSegment({
    required this.id,
    required this.startMs,
    required this.endMs,
    required this.text,
    this.speakerLabel,
  });

  final String id;
  final int startMs;
  final int endMs;
  final String text;

  /// Speaker label from diarization (`sp0`, `sp1`, …). Null before Wave 3
  /// wiring or when ASR-only segments have not been diarized yet.
  final String? speakerLabel;

  @override
  int get hashCode => Object.hash(id, startMs, endMs, text, speakerLabel);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranscriptSegment &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          startMs == other.startMs &&
          endMs == other.endMs &&
          text == other.text &&
          speakerLabel == other.speakerLabel;
}

/// Converts the generated wire type to [TranscriptSegment].
///
/// A standalone, public function rather than inlined into
/// [RustMindSpeechBridge.transcribe]: it is the one place `start_ms`/`end_ms`
/// cross from Rust's `u64` (bridged as [BigInt], since `flutter_rust_bridge`
/// has no unsigned 64-bit Dart integer) to Dart's `int`, and that narrowing is
/// exactly the step #1629 found silently dropping data before this change —
/// worth a name and a test of its own rather than being an anonymous closure.
TranscriptSegment toTranscriptSegment(rust.TranscriptSegmentRecord segment) =>
    TranscriptSegment(
      id: segment.id,
      startMs: segment.startMs.toInt(),
      endMs: segment.endMs.toInt(),
      text: segment.text,
      speakerLabel: segment.speakerLabel,
    );

/// The reverse of [toTranscriptSegment] — `#1629` Gap D: [MindSpeechBridge.
/// save] carries the segments back across the bridge so `save_meeting` can
/// persist them into `transcript.json`, which means the `int` → `u64` widening
/// has to happen exactly once here too, symmetrically with the narrowing
/// above.
rust.TranscriptSegmentRecord fromTranscriptSegment(TranscriptSegment segment) =>
    rust.TranscriptSegmentRecord(
      id: segment.id,
      startMs: BigInt.from(segment.startMs),
      endMs: BigInt.from(segment.endMs),
      text: segment.text,
      speakerLabel: segment.speakerLabel,
    );

final class TranscriptEventTranscribing extends TranscriptEvent {
  const TranscriptEventTranscribing(this.segment);
  final TranscriptSegment segment;

  /// Convenience for callers that only want the running text, same as before
  /// this event carried a full segment.
  String get text => segment.text;
}

final class TranscriptEventTranscriptReady extends TranscriptEvent {
  const TranscriptEventTranscriptReady(this.text, this.segments);
  final String text;

  /// Every segment that produced [text], in order, each carrying the audio
  /// timestamp it came from. This is the shape #1657's evidence links
  /// (action item → transcript segment → audio timestamp) resolve against.
  final List<TranscriptSegment> segments;
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
  ///
  /// [speechLanguage] is `#1629`: `rust.SpeechLanguage.englishOnly` (the
  /// default) resolves the bundled `.en` model; `multilingual` resolves the
  /// multilingual weights Hindi+English code-switching needs, which is only
  /// installed when a caller has explicitly acquired it — a build with only
  /// the default model on disk gets `MindUnavailable.loadFailed` naming the
  /// missing file, the same as any other unresolved model. Choosing this per
  /// user is #1664's job; this parameter is the mechanism it calls into.
  Future<void> initialize({
    required String modelsDir,
    required String storePath,
    required int memoryBudgetMb,
    rust.SpeechLanguage speechLanguage,
  });

  /// [wavPath] is the on-disk recording path. Despite the name, Rust preprocesses
  /// `.m4a` (meeting capture) and `.wav` to 16 kHz mono PCM before whisper runs
  /// (`#1786`).
  ///
  /// [language] is `#1664`'s per-recording pin: a whisper.cpp language code
  /// (`"en"`, `"hi"`, ...), or `null` to leave the engine on auto-detect.
  /// Settings choosing a primary language maps to this caller supplying the
  /// same code on every call — there is no separate "global" pin to
  /// synchronize, and no way to pin two languages for one pass: whisper.cpp
  /// accepts exactly one language per run (see
  /// `rust.transcribeRecording`/`TranscriptionOptions` on the Rust side).
  Stream<TranscriptEvent> transcribe({
    required String wavPath,
    String? language,
  });

  /// Makes a meeting durable and searchable, and persists its structured
  /// transcript document. Returns the meeting's id.
  ///
  /// `model` is the logical identity of whatever produced `minutes`
  /// (`ADR-0018 §5`) — it comes from [MindGenerationBridge.modelId], not from
  /// this bridge, because only the generation library knows it.
  ///
  /// `segments` and `wavPath` are `#1629` Gap D: written to a per-meeting
  /// `transcript.json` alongside the flat `Meeting` record, so the ASR step —
  /// which segments, which model, which recording — is reproducible
  /// independent of the flat transcript string.
  ///
  /// `decisions`/`actionItems`/`metrics` are `ADR-0022 §1`: the Meeting IR's
  /// facts, flattened onto the same `Meeting` record. Default to empty --
  /// nothing in this codebase extracts a `MeetingIr` yet (that pipeline is
  /// `rust/airo_mind_meeting`, not wired to this bridge), so every caller
  /// today saves a meeting with no IR, exactly as before this parameter
  /// existed.
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
  });

  /// Reopens a meeting's structured transcript document. `#1629` Gap D's
  /// reload half — `null` for a meeting saved before this feature shipped, or
  /// one with no matching id.
  Future<rust.TranscriptDocumentRecord?> getTranscript(String meetingId);

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
    rust.SpeechLanguage speechLanguage = rust.SpeechLanguage.englishOnly,
  }) => rust.initialize(
    config: rust.MindConfig(
      modelsDir: modelsDir,
      storePath: storePath,
      memoryBudgetMb: memoryBudgetMb,
      speechLanguage: speechLanguage,
    ),
  );

  @override
  Stream<TranscriptEvent> transcribe({
    required String wavPath,
    String? language,
  }) => rust.transcribeRecording(wavPath: wavPath, language: language).map((
    event,
  ) {
    return switch (event) {
      rust.TranscriptEvent_Transcribing(:final segment) =>
        TranscriptEventTranscribing(toTranscriptSegment(segment)),
      rust.TranscriptEvent_TranscriptReady(:final text, :final segments) =>
        TranscriptEventTranscriptReady(
          text,
          segments.map(toTranscriptSegment).toList(growable: false),
        ),
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
    required List<TranscriptSegment> segments,
    required String wavPath,
    List<rust.MeetingDecisionRecord> decisions = const [],
    List<rust.MeetingActionItemRecord> actionItems = const [],
    List<rust.MeetingMetricRecord> metrics = const [],
  }) => rust.saveMeeting(
    title: title,
    recordedAtMs: BigInt.from(recordedAtMs),
    transcript: transcript,
    minutes: minutes,
    model: model,
    segments: segments.map(fromTranscriptSegment).toList(growable: false),
    audioPath: wavPath,
    decisions: decisions,
    actionItems: actionItems,
    metrics: metrics,
  );

  @override
  Future<rust.TranscriptDocumentRecord?> getTranscript(String meetingId) =>
      rust.getTranscript(meetingId: meetingId);

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
