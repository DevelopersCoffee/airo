import 'dart:async';
import 'dart:io';

import 'package:core_ai/core_ai.dart' show EmbeddingService;
import 'package:core_ai/core_ai.dart' as core_ai show DeviceCapabilityService;
import 'package:core_entitlements/core_entitlements.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'bridges/mind_generation_bridge.dart';
import 'bridges/mind_speech_bridge.dart';
import 'meeting_ir/meeting_ir_status_writer.dart';
import 'mind_diarization.dart';
import 'mind_indic_intelligence.dart';
import 'model_installer.dart';
import 'models/download_model_provider.dart';
import 'models/model_descriptor_adapter.dart';
import 'models/model_provider.dart';
import 'runtime/ports/operation_log_port.dart';
import 'search/meeting_embedding_store.dart';
import 'search/semantic_search_ranker.dart';
import 'speaker/global_speaker_enrollment_store.dart';
import 'trust/scribe_trust_state.dart';
import 'whisper/api/meetings.dart' as rust;
import 'whisper/meeting_ir_op_log.dart';

/// Why Airo Mind cannot start. Each case is one the user can act on, which is
/// the reason this is a type and not a string.
enum MindUnavailable {
  /// The platform has no Rust library — web, or a build without the native
  /// artefact linked in.
  bridgeMissing,

  /// The models are not on disk. Expected on first run.
  modelsMissing,

  /// The library loaded and the models are present, but loading them failed.
  loadFailed,
}

/// The result of trying to start.
@immutable
class MindStatus {
  const MindStatus.ready() : unavailable = null, detail = '';
  const MindStatus.unavailable(this.unavailable, this.detail);

  final MindUnavailable? unavailable;
  final String detail;

  bool get isReady => unavailable == null;
}

/// Progress through the pipeline, as the models produce it.
///
/// Mirrors `ProcessingEvent` on the Rust side into something a widget can hold:
/// the accumulated text so far, plus which stage produced it.
enum MindStage {
  idle,
  recording,
  transcribing,
  extracting,
  generating,
  saving,
  done,
  failed,
}

@immutable
class MindProgress {
  const MindProgress({
    required this.stage,
    this.transcript = '',
    this.minutes = '',
    this.segments = const [],
    this.meetingId,
    this.error,
  });

  final MindStage stage;
  final String transcript;
  final String minutes;

  /// The segments behind [transcript], each carrying the audio timestamp it
  /// came from. `#1629` Gap D: carried through `process()` so `saveMeeting`
  /// can persist them into `transcript.json`, not just accumulated into the
  /// flat string for the UI.
  final List<TranscriptSegment> segments;
  final String? meetingId;
  final String? error;

  MindProgress copyWith({
    MindStage? stage,
    String? transcript,
    String? minutes,
    List<TranscriptSegment>? segments,
    String? meetingId,
    String? error,
  }) {
    return MindProgress(
      stage: stage ?? this.stage,
      transcript: transcript ?? this.transcript,
      minutes: minutes ?? this.minutes,
      segments: segments ?? this.segments,
      meetingId: meetingId ?? this.meetingId,
      error: error ?? this.error,
    );
  }
}

/// Everything the UI is allowed to do.
///
/// The screens never touch the generated bindings. That keeps the widget tests
/// runnable without a Rust library present, and it means the day the bridge
/// changes shape, one file changes.
class MindService {
  /// Every collaborator is injectable, defaulting to the production path.
  ///
  /// [modelProvider] defaults to the bundled-asset [ModelInstaller] — the
  /// behaviour this class always had. Which app ships which provider
  /// (download vs. bundled) is a decision for the shell composing this
  /// service, not a default `feature_mind` bakes in
  /// (`docs/superpowers/specs/2026-08-07-airo-mind-abstraction-layer.md`).
  MindService({
    AudioRecorder? recorder,
    ModelProvider? modelProvider,
    MindSpeechBridge? speechBridge,
    MindGenerationBridge? generationBridge,
    OperationLogPort? operationLog,
    String meetingContextId = '',
    SemanticSearchRanker Function(Directory modelsDir)? rankerBuilder,
    rust.SpeechLanguage defaultSpeechLanguage = rust.SpeechLanguage.englishOnly,
    Entitlements entitlements = const LaunchPromoEntitlements(),
  }) : _recorder = recorder ?? AudioRecorder(),
       _models = modelProvider ?? const ModelInstaller(),
       _speech = speechBridge ?? const RustMindSpeechBridge(),
       _generation = generationBridge ?? RustMindGenerationBridge(),
       _operationLog = operationLog,
       _meetingContextId = meetingContextId,
       _defaultSpeechLanguage = defaultSpeechLanguage,
       _entitlements = entitlements,
       _rankerBuilder =
           rankerBuilder ??
           ((dir) => SemanticSearchRanker(
             embeddingService: EmbeddingService(),
             embeddingStore: MeetingEmbeddingStore(dir),
           ));

  final AudioRecorder _recorder;
  final ModelProvider _models;
  final MindSpeechBridge _speech;
  final MindGenerationBridge _generation;
  final OperationLogPort? _operationLog;
  final String _meetingContextId;
  final rust.SpeechLanguage _defaultSpeechLanguage;
  final Entitlements _entitlements;

  /// Last language mode handed to [MindSpeechBridge.initialize], or the
  /// constructor default before the first successful init. Read-only seam
  /// for #1774 trust badges — not the #1664 pin UI.
  rust.SpeechLanguage? _activeSpeechLanguage;

  /// Speech-model language mode the pipeline is configured for (#1629).
  ///
  /// Thin read-only seam for multilingual / language badges (#1774). Does
  /// not expose or set a per-recording whisper.cpp pin — that remains #1664.
  rust.SpeechLanguage get speechLanguage =>
      _activeSpeechLanguage ?? _defaultSpeechLanguage;

  /// Trust UX snapshot for scribe/meeting surfaces (#1774).
  ScribeTrustState scribeTrustState({
    bool modelMissing = false,
    String? pinnedLanguageCode,
  }) => ScribeTrustState.forSpeechModel(
    multilingual: speechLanguage == rust.SpeechLanguage.multilingual,
    modelMissing: modelMissing,
    pinnedLanguageCode: pinnedLanguageCode,
  );

  /// Built lazily against [modelsDirectory] rather than in the constructor:
  /// resolving that directory is async, and every other collaborator here is
  /// a ready-made instance. [rankerBuilder] is the seam a test substitutes
  /// to avoid touching `core_ai`'s real `EmbeddingService`/model download
  /// pipeline (`docs/superpowers/specs/2026-08-09-mind-scribe-semantic-search.md`).
  final SemanticSearchRanker Function(Directory modelsDir) _rankerBuilder;
  SemanticSearchRanker? _ranker;
  String? _recordingPath;

  /// Loads the native library and the models.
  ///
  /// Returns a status rather than throwing: on a real device "the models are
  /// not downloaded yet" is the ordinary first-run state, and an exception
  /// would make the app's normal opening move look like a crash.
  ///
  /// [speechLanguage] is `#1629` / `#1664`: defaults to
  /// [_defaultSpeechLanguage] (English-only unless the shell overrides).
  /// Passing `multilingual` requires the multilingual weights to already be
  /// installed — this method does not acquire them; it only asks the Model
  /// Manager to resolve against them.
  ///
  /// [ensureReady] is safe to call before every pipeline run — a no-op when
  /// [initialize] already succeeded for the same [speechLanguage]. A Settings
  /// change (#1664) that picks a different mode re-runs initialize so the
  /// speech bridge sees the new weights / pin.
  Future<MindStatus> ensureReady({rust.SpeechLanguage? speechLanguage}) async {
    final desired = speechLanguage ?? _defaultSpeechLanguage;
    if (_speech.isReady() && _activeSpeechLanguage == desired) {
      return const MindStatus.ready();
    }
    return initialize(speechLanguage: desired);
  }

  Future<MindStatus> initialize({rust.SpeechLanguage? speechLanguage}) async {
    final language = speechLanguage ?? _defaultSpeechLanguage;
    try {
      // Only the speech library. Generation is loaded on first use — see
      // `process`.
      await _speech.loadLibrary();
    } on Object catch (e) {
      return MindStatus.unavailable(MindUnavailable.bridgeMissing, '$e');
    }

    final dir = await modelsDirectory();

    // `ModelProvider` — bundled asset by default, download in production
    // (`docs/superpowers/specs/2026-08-07-airo-mind-abstraction-layer.md`).
    // Not from the checkout: that made a developer machine work and a device
    // fail.
    if (!await _models.isInstalled(dir)) {
      // A download is not started here. `acquiresWithoutNetwork` false means
      // the models cost the user roughly 570 MB of their connection, and
      // spending that unasked on first launch is not a decision this method
      // gets to make. The screen offers it instead — [acquireModels] — and
      // this returns the state that makes the offer visible (#1554).
      if (!_models.acquiresWithoutNetwork) {
        final missing = await missingModels();
        return MindStatus.unavailable(
          MindUnavailable.modelsMissing,
          'Missing: ${missing.map((m) => m.fileName).join(', ')}.',
        );
      }

      final failed = <String>[];
      await for (final event in _models.acquire(dir)) {
        switch (event) {
          case ModelAcquisitionProgress(
            :final fileName,
            :final fetched,
            :final total,
          ):
            onInstallProgress?.call(fileName, fetched, total);
          case ModelAcquisitionDone(:final failedFileNames):
            failed.addAll(failedFileNames);
        }
      }
      if (failed.isNotEmpty) {
        // "This build does not carry" was accurate for the bundled-asset
        // default; a download provider can also fail here from no network,
        // an interrupted transfer, or a digest mismatch, none of which "not
        // carried by this build" describes.
        return MindStatus.unavailable(
          MindUnavailable.modelsMissing,
          'Could not get ${failed.join(', ')}.',
        );
      }
    }

    try {
      // `ADR-0018 §1`: hand over a DIRECTORY and a budget. Which model serves
      // which task is the Model Manager's decision, not this layer's.
      await _speech.initialize(
        modelsDir: dir.path,
        storePath: p.join(dir.path, 'meetings.log'),
        // Admission ceiling, not an allocation. The Supervisor refuses a
        // model it cannot afford before anything is loaded.
        memoryBudgetMb: 4096,
        speechLanguage: language,
      );
      _activeSpeechLanguage = language;
      try {
        await GlobalSpeakerEnrollmentStore().syncToRuntime();
      } on Object {
        // Enrollment sync is best-effort; speech is already configured.
      }
      return const MindStatus.ready();
    } on Object catch (e) {
      return MindStatus.unavailable(MindUnavailable.loadFailed, '$e');
    }
  }

  /// Where models and the meeting log live. Application support rather than
  /// documents: these are not the user's files, and on iOS the documents
  /// directory is user-visible.
  Future<Directory> modelsDirectory() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'airo_mind'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Reports asset-copy progress on first launch. Half a gigabyte takes long
  /// enough that a silent first launch reads as a hang.
  void Function(String fileName, int copied, int total)? onInstallProgress;

  /// True when acquiring the models spends the user's network, so the UI has
  /// to offer the download rather than assume it.
  bool get modelsNeedDownload => !_models.acquiresWithoutNetwork;

  /// The models the runtime needs and does not have, at their pinned sizes —
  /// what the UI needs to say how large the download is before starting it.
  ///
  /// Answered by the provider, which owns what "installed" means for its own
  /// layout, rather than by this class stat-ing the directory itself.
  Future<List<RequiredModel>> missingModels() async =>
      _models.missingModels(await modelsDirectory());

  /// Puts the missing models on disk, streaming progress.
  ///
  /// Separate from [initialize] because it is the user's decision, not a
  /// startup step: on the download provider this is ~570 MB. Call
  /// [initialize] again once the stream ends without failures.
  Stream<ModelAcquisitionEvent> acquireModels() async* {
    yield* _models.acquire(await modelsDirectory());
  }

  /// Downloads optional pinned files (for example the Sarvam-1 pro pack) into
  /// [modelsDirectory]. Only the download-backed provider can fetch over the
  /// network; bundled installers report every file as failed.
  Stream<ModelAcquisitionEvent> acquireModelFiles(
    List<RequiredModel> models,
  ) async* {
    final dir = await modelsDirectory();
    if (_models case DownloadModelProvider provider) {
      yield* provider.acquireFiles(dir, models);
      return;
    }
    yield ModelAcquisitionDone(models.map((model) => model.fileName).toList());
  }

  /// Optional ECAPA diarization weights for multi-speaker labels.
  Stream<ModelAcquisitionEvent> acquireOptionalDiarizeModels() =>
      acquireModelFiles(mindDiarizeOptionalModels());

  /// Hashes every installed model against the digest pinned in Rust source.
  Future<List<InstalledModel>> verifyModels() async =>
      _models.verify(await modelsDirectory());

  Future<bool> hasMicrophonePermission() => _recorder.hasPermission();

  /// Starts capture at exactly what whisper wants: 16 kHz mono 16-bit PCM.
  ///
  /// Converting later would mean resampling in Dart on the main isolate. Asking
  /// the platform for the right format costs nothing and removes that entirely.
  Future<void> startRecording() async {
    final dir = await modelsDirectory();
    final path = p.join(
      dir.path,
      'recording-${DateTime.now().millisecondsSinceEpoch}.wav',
    );
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    _recordingPath = path;
  }

  Future<bool> get isRecording => _recorder.isRecording();

  /// Stops capture and returns the file. Null if nothing was recording.
  Future<String?> stopRecording() async {
    final path = await _recorder.stop();
    return path ?? _recordingPath;
  }

  /// Transcribe → extract IR → MoM → save, streaming.
  ///
  /// Each event folds into the previous [MindProgress], so a widget can render
  /// the latest value and nothing accumulates in two places.
  ///
  /// # Why this is composed here
  ///
  /// The two engines are in two libraries, because whisper.cpp and llama.cpp
  /// vendor incompatible copies of ggml and cannot share a linked image. So the
  /// pipeline that used to be one Rust call is sequenced here across both
  /// cdylibs.
  ///
  /// After `#1785`, the generation half runs the meeting-intelligence pipeline
  /// (`transcript::process` → extract → validate → `generate_mom`) rather than
  /// prose-only minutes. The emitted [MindStage] sequence is now
  /// transcribing → extracting → generating → saving → done.
  /// [language] is `#1664`'s per-recording pin, forwarded to
  /// [MindSpeechBridge.transcribe] unchanged: a whisper.cpp language code, or
  /// `null` to leave the engine on auto-detect. A Settings screen choosing a
  /// primary language calls `process` with that code on every recording —
  /// there is no separate global toggle this service tracks, and pinning two
  /// languages for one pass is not offered because whisper.cpp itself has no
  /// such mode.
  Stream<MindProgress> process({
    required String wavPath,
    required String title,
    String? language,
  }) async* {
    var progress = const MindProgress(stage: MindStage.transcribing);
    yield progress;

    // Dart owns the clock. `C2` forbids reading a wall clock on a path replay
    // must reproduce, so the timestamp is taken once, here, and carried through
    // to `saveMeeting` as the meeting's identity.
    final recordedAtMs = DateTime.now().millisecondsSinceEpoch;
    final meetingId = 'm$recordedAtMs';

    var decisions = const <rust.MeetingDecisionRecord>[];
    var actionItems = const <rust.MeetingActionItemRecord>[];
    var metrics = const <rust.MeetingMetricRecord>[];

    try {
      final speechMode = await MindIndicPreferences.readSpeechMode();
      if (speechMode == MindIndicSpeechMode.sarvamEdge) {
        yield progress.copyWith(
          stage: MindStage.failed,
          error:
              'Sarvam Edge on-device ASR is not available in this build yet.',
        );
        return;
      }

      // ── 1. Audio → transcript, in the speech library ───────────────────────
      await for (final event in _speech.transcribe(
        wavPath: wavPath,
        language: language,
      )) {
        switch (event) {
          case TranscriptEventTranscribing(:final text):
            progress = progress.copyWith(
              stage: MindStage.transcribing,
              transcript: _append(progress.transcript, text),
            );
          // The joined transcript AND segment list from Rust replace what was
          // accumulated, so a dropped segment cannot leave transcript,
          // segments and the eventual transcript.json out of step (`#1629`
          // Gap D needs `segments` to reach `saveMeeting` intact).
          case TranscriptEventTranscriptReady(:final text, :final segments):
            progress = progress.copyWith(
              stage: MindStage.extracting,
              transcript: text,
              segments: ensureSpeakerLabels(segments),
            );
          case TranscriptEventCancelled():
            yield progress.copyWith(stage: MindStage.idle);
            return;
        }
        yield progress;
      }

      // ── 2. Segments → IR → MoM, in the generation library ─────────────────
      //
      // Loaded now rather than at startup: it is roughly 48 MB and only this
      // step needs it.
      final dir = await modelsDirectory();
      final memoryInfo =
          await core_ai.DeviceCapabilityService().getMemoryInfo();
      final generationMode = await MindIndicPreferences.readGenerationMode();
      final indicCapability = MindIndicCapability(
        entitlements: _entitlements,
        memoryInfo: memoryInfo,
      );
      final wantsIndicGeneration = indicCapability.shouldPreferIndicGeneration(
        generationMode,
      );
      final sarvamOnDisk =
          wantsIndicGeneration &&
          PinnedModelFiles.isPresent(dir, pinnedIndicGenerationModel);
      await _generation.ensureLoaded(
        modelsDir: dir.path,
        memoryBudgetMb: 4096,
        preferIndicGeneration: sarvamOnDisk,
        allowCompactFallback:
            generationMode != MindIndicGenerationMode.enhancedIndic,
      );

      await for (final event in _generation.processMeetingIntelligence(
        meetingId: meetingId,
        title: title,
        segments: progress.segments,
      )) {
        switch (event) {
          case MeetingIntelligenceEventExtracting():
            progress = progress.copyWith(stage: MindStage.extracting);
          case MeetingIntelligenceEventGenerating(:final text):
            progress = progress.copyWith(
              stage: MindStage.generating,
              minutes: progress.minutes + text,
            );
          case MeetingIntelligenceEventIrReady(
            decisions: final irDecisions,
            actionItems: final irActionItems,
            metrics: final irMetrics,
          ):
            decisions = irDecisions;
            actionItems = irActionItems;
            metrics = irMetrics;
            continue;
          case MeetingIntelligenceEventMinutesReady(:final text):
            progress = progress.copyWith(
              stage: MindStage.saving,
              minutes: text,
            );
          case MeetingIntelligenceEventCancelled():
            yield progress.copyWith(stage: MindStage.idle);
            return;
        }
        yield progress;
      }

      // ── 3. Durable, in the speech library, which owns the store ───────────
      //
      // `model` comes from the generation library: only it knows which model
      // produced these minutes, and `ADR-0018 §5` records that with the content
      // rather than inferring it later.
      final savedMeetingId = await _speech.save(
        title: title,
        recordedAtMs: recordedAtMs,
        transcript: progress.transcript,
        minutes: progress.minutes,
        model: _generation.modelId(),
        segments: progress.segments,
        wavPath: wavPath,
        decisions: decisions,
        actionItems: actionItems,
        metrics: metrics,
      );

      final savedMeeting = await _speech.meeting(savedMeetingId);
      if (savedMeeting != null) {
        // Agent G (#1770): warm semantic search index after each save.
        await indexMeetingForSearch(savedMeeting);
      }

      final log = _operationLog;
      if (log != null) {
        await appendMeetingIrExtractedOp(
          log: log,
          meetingId: savedMeetingId,
          meetingTitle: title,
          contextId: _meetingContextId,
          decisionCount: decisions.length,
          actionItemCount: actionItems.length,
          metricCount: metrics.length,
        );
      }

      yield progress.copyWith(stage: MindStage.done, meetingId: savedMeetingId);
    } on Object catch (e) {
      yield progress.copyWith(
        stage: MindStage.failed,
        error: _formatProcessingError(e),
      );
    }
  }

  static String _formatProcessingError(Object error) {
    final message = '$error';
    if (message.contains('airo.generation.indic.standard') &&
        message.contains('sarvam-1-Q4_K_M.gguf')) {
      return 'Sarvam-1 is not installed on this device. '
          'Open Models → Meeting scribe picks and choose Standard (Qwen), '
          'or download the Sarvam stack from On-device models.';
    }
    return message;
  }

  static String _append(String existing, String segment) {
    final piece = segment.trim();
    if (piece.isEmpty) return existing;
    return existing.isEmpty ? piece : '$existing $piece';
  }

  /// Stops the in-flight job at the next segment or token.
  ///
  /// Both libraries, unconditionally. The user pressed Stop once; which engine
  /// happens to be running is not something they should have to know, and
  /// cancelling an idle library is a documented no-op on both sides. Cancelling
  /// only the "current" one would leave the other running whenever the guess
  /// was wrong — which is exactly at the handover, the moment most likely to be
  /// slow enough for someone to press Stop.
  void cancelProcessing() {
    _speech.cancel();
    if (_generation.isLoaded) _generation.cancel();
  }

  Future<List<rust.MeetingRecord>> meetings() => _speech.meetings();

  /// Step 7 of the journey, now ranked by keyword **and** meaning
  /// (`docs/superpowers/specs/2026-08-09-mind-scribe-semantic-search.md`).
  /// Signature is unchanged from the keyword-only version this replaced —
  /// [MindHomeScreen]'s search box needed no changes for this.
  Future<List<rust.SearchHit>> search(String query) async {
    final keywordHits = await _speech.search(query);
    _ranker ??= _rankerBuilder(await modelsDirectory());
    final allMeetings = await _speech.meetings();
    final segmentTextsByMeetingId = <String, List<String>>{};
    for (final meeting in allMeetings) {
      final doc = await _speech.getTranscript(meeting.id);
      if (doc == null || doc.segments.isEmpty) continue;
      segmentTextsByMeetingId[meeting.id] = [
        for (final segment in doc.segments) segment.text,
      ];
    }
    return _ranker!.rank(
      query: query,
      keywordHits: keywordHits,
      meetings: allMeetings,
      segmentTextsByMeetingId: segmentTextsByMeetingId,
    );
  }

  /// Indexes [meeting] for EmbeddingGemma semantic search.
  ///
  /// **Agent G seam** (`#1770` Wave 2 chat-over-meetings): call after a
  /// meeting is saved/processed, or from a chat tool that needs the archive
  /// already embedded. [search] still indexes lazily when a meeting was
  /// never passed here. Returns `false` when no embedding model is
  /// installed — keyword search continues to work.
  Future<bool> indexMeetingForSearch(rust.MeetingRecord meeting) async {
    _ranker ??= _rankerBuilder(await modelsDirectory());
    final doc = await _speech.getTranscript(meeting.id);
    final segmentTexts = doc == null
        ? const <String>[]
        : [for (final segment in doc.segments) segment.text];
    return _ranker!.indexMeeting(meeting, segmentTexts: segmentTexts);
  }

  Future<rust.MeetingRecord?> meeting(String id) => _speech.meeting(id);

  /// `#1629` Gap D's reload half — the structured transcript document a prior
  /// `process()` call persisted for [meetingId], or `null` if none exists
  /// (a meeting saved before this feature shipped, or an unknown id).
  Future<rust.TranscriptDocumentRecord?> transcriptDocument(String meetingId) =>
      _speech.getTranscript(meetingId);

  /// #1658 / MIND-LLM-16: checkable action status writes back through the
  /// existing `saveMeeting` path (append-only, latest wins) — no new store.
  Future<rust.MeetingRecord> updateActionItemStatus({
    required rust.MeetingRecord meeting,
    required String actionItemId,
    required rust.MeetingActionStatus status,
  }) => MeetingIrStatusWriter(_speech).updateActionStatus(
    meeting: meeting,
    actionItemId: actionItemId,
    status: status,
  );

  /// Releases the microphone and the model provider. The provider matters
  /// because the download-backed one holds a subscription to the platform
  /// download stream, and the shell that composed it cannot reach it once it
  /// is in here.
  Future<void> dispose() async {
    await _recorder.dispose();
    await _models.dispose();
  }
}
