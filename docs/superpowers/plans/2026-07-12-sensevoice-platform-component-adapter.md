# SenseVoice Platform Component Adapter Research

**Date:** 2026-07-12
**Branch:** `research/sensevoice-platform-component-adapter`
**Worktree:** `/Users/udaychauhan/workspace/airo-sensevoice-platform-component`
**Base:** latest `origin/main` confirmed at `c9ca98a97a0c1e570226c8be07ffd65cf4ea274b`

## Critical Agent Gate

**Problem:** Make SenseVoice available to Airo consumers as a swappable platform
speech/transcription component without changing framework-level AI runtime
contracts.

**User / actor:** App features that need local speech-to-text or speech
understanding, starting with Meeting Intelligence and future Audio Scribe flows.

**Framework or application layer:** Platform/application component. This should
not modify `packages/core_ai` LLM routing, `LocalInferenceRuntimeAdapter`,
`AIProvider`, model registry semantics, or framework model residency contracts.

**Owning agent:** Meeting Intelligence Agent for first consumer integration.

**Reviewing agents:** Mobile UI Agent for settings/runtime switching, Security
and Privacy Agent for microphone/audio/model download handling, QA Automation
Agent for deterministic adapter tests.

**Impacted modules/files:**
- Existing platform component: `packages/platform_media`
- Proposed app provider wiring:
  `app/lib/features/meeting/application/providers/...`
- Existing app boundary:
  `app/lib/features/meeting/infrastructure/platform/native_meeting_contracts.dart`
- Existing domain output:
  `app/lib/features/meeting/domain/entities/transcript_chunk.dart`

**Base branch/worktree:** confirmed from latest `origin/main`: yes.

**Open questions:**
- Should the first runtime picker live under existing AI settings or under
  feature-specific Meeting/Audio settings?
- Should model downloads be app-managed assets, first-run downloads, or
  developer-provisioned paths for the initial spike?
- Do we need emotion/event tags in v1, or should v1 normalize only transcript
  text, timestamps, speaker labels, and confidence?

**Decision:** Ready for feature packet and implementation issue. Do not start
feature code until the GitHub issue contains the contract and automation flows
below.

## Upstream Findings

SenseVoice is a speech foundation model for ASR, language ID, speech emotion
recognition, and audio event detection. The upstream README says it supports
50+ languages and advertises faster-than-Whisper non-autoregressive inference.
The documented direct Python path uses FunASR `AutoModel`, VAD, optional
speaker model, and `trust_remote_code` for model code.

The 2026 upstream addition that matters for Airo is the llama.cpp/GGUF runtime:
the latest GitHub release is `runtime-llamacpp-v0.1.4` from 2026-06-29, with
self-contained binaries. The GGUF Hugging Face card lists an Apache-2.0 license,
`sensevoice-small-q8.gguf` at about 235 MB, and `sensevoice-small-f16.gguf` at
about 470 MB.

For Flutter, the practical integration path is `sherpa_onnx`. The current
pub.dev package is `sherpa_onnx` `1.13.4`, published 4 days before this plan,
with Android, iOS, Linux, macOS, and Windows support. Sherpa's SenseVoice docs
call out Dart/Flutter support and the relevant mobile/desktop platforms. The
currently documented SenseVoice model in Sherpa is Chinese, Cantonese, English,
Japanese, and Korean; treat upstream "50+ languages" as a broader model-family
claim until we verify the specific downloadable runtime artifact.

## Recommendation

Use the existing platform component instead of extending framework AI routing
or creating a new package. The first implementation should add speech
transcription contracts under `packages/platform_media`, because it is the
existing media platform boundary in this repo. A future split to
a separate speech package would need a separate ownership decision.

```text
packages/platform_media
  lib/src/speech/speech_transcription_engine.dart
  lib/src/speech/speech_transcription_models.dart
  lib/src/speech/runtime/speech_runtime_registry.dart
  lib/src/speech/runtime/noop_transcription_engine.dart
  lib/src/speech/runtime/sherpa_sensevoice_transcription_engine.dart
  lib/src/speech/runtime/gguf_sensevoice_process_engine.dart
```

The component exposes a stable Airo-owned contract and hides vendor/runtime
details behind adapters. Consumers depend on `SpeechTranscriptionEngine`, not on
SenseVoice, Sherpa, GGUF, or platform channels.

```dart
abstract interface class SpeechTranscriptionEngine {
  SpeechRuntimeId get runtimeId;
  Future<SpeechRuntimeAvailability> availability();
  Future<SpeechTranscriptionResult> transcribeFile(
    SpeechTranscriptionRequest request,
  );
  Stream<SpeechTranscriptChunk> transcribeStream(
    SpeechStreamingTranscriptionRequest request,
  );
  Future<void> dispose();
}
```

Runtime IDs should be data, not compile-time conditionals:

```dart
enum SpeechRuntimeId {
  systemNative,
  sherpaSenseVoice,
  ggufSenseVoice,
  disabled,
}
```

Consumers switch at runtime through a small registry/resolver:

```dart
final engine = registry.resolve(
  preferred: userSettings.speechRuntimeId,
  policy: SpeechRuntimePolicy.localOnly,
);
```

Resolution order for the first implementation:

1. User-selected runtime if available.
2. `sherpaSenseVoice` for Android, iOS, Linux, macOS, Windows when model files
   are present.
3. Existing native meeting transcription contract, wrapped as `systemNative`,
   if the platform has it.
4. `disabled` engine with a typed unavailable reason.

## Adapter Choice

Start with `sherpa_onnx` for the SenseVoice adapter.

Reasons:
- It has a published Flutter package and native platform packages.
- It supports local/offline ASR and VAD-related speech functions.
- It avoids Python, Torch, and `trust_remote_code` in the app runtime.
- It keeps the implementation inside a platform component and does not require
  framework AI runtime changes.

Add the GGUF process adapter as a second adapter only for desktop/server
experiments:

```text
ggufSenseVoice -> Process.start("llama-funasr-sensevoice", [...])
```

This should not be the mobile MVP because upstream prebuilt GGUF binaries target
Linux, macOS, and Windows, while Android/iOS would need native build/package
work and ABI validation.

## Contract Shape

Normalize all engines into Airo-owned models:

```dart
class SpeechTranscriptionRequest {
  const SpeechTranscriptionRequest({
    required this.audioPath,
    required this.sessionId,
    this.languageCode = 'auto',
    this.enableTimestamps = true,
    this.enableSpeakerLabels = false,
    this.enableRichTags = false,
  });

  final String audioPath;
  final String sessionId;
  final String languageCode;
  final bool enableTimestamps;
  final bool enableSpeakerLabels;
  final bool enableRichTags;
}
```

```dart
class SpeechTranscriptChunk {
  const SpeechTranscriptChunk({
    required this.id,
    required this.sessionId,
    required this.text,
    required this.startMs,
    required this.endMs,
    required this.isFinal,
    this.languageCode,
    this.speakerLabel,
    this.confidence,
    this.emotionTag,
    this.audioEventTag,
    this.runtimeMetadata = const {},
  });
}
```

Meeting Intelligence can map `SpeechTranscriptChunk` to its existing
`TranscriptChunk` without changing the meeting domain entity in v1. Rich
SenseVoice tags stay optional metadata until UX and storage are explicitly
designed.

## Runtime Switching

Add a lightweight app/provider setting outside framework AI settings:

```text
speech_runtime.selected_id = sherpaSenseVoice | systemNative | ggufSenseVoice
speech_runtime.local_only = true
speech_runtime.model_root = <app-managed path>
```

The provider should expose:

```dart
final speechRuntimeRegistryProvider = Provider<SpeechRuntimeRegistry>(...);
final selectedSpeechRuntimeProvider = StateNotifierProvider<...>(...);
final speechTranscriptionEngineProvider = Provider<SpeechTranscriptionEngine>(
  (ref) => ref.watch(speechRuntimeRegistryProvider).resolve(...),
);
```

This lets Meeting Intelligence, Audio Scribe, and future voice search consume
the existing platform media component and switch engines at runtime without
branching inside the feature workflow.

## Security And Privacy

- Default to local-only execution.
- Do not send raw meeting audio to cloud fallback from this component.
- Store model files in app-managed storage with checksum verification.
- Treat model downloads as explicit user/developer actions, not silent startup
  downloads.
- Keep raw audio retention under the existing meeting privacy policy.
- Redact only after transcription, using the current Meeting Intelligence
  pipeline.
- Record runtime ID and model version in metadata for audit/debug, but do not
  store raw vendor payloads unless explicitly needed.

## Deterministic Use Cases

1. User selects `sherpaSenseVoice`; model files are present; Meeting
   Intelligence transcribes a local fixture and stores final transcript chunks.
2. User selects `sherpaSenseVoice`; model files are missing; registry returns
   typed `modelMissing` availability and UI can show download/setup state.
3. User selects `systemNative`; SenseVoice is unavailable; meeting flow still
   works through existing native contract.
4. User selects `ggufSenseVoice` on unsupported mobile platform; registry
   rejects it before process launch.
5. Adapter emits rich tags; Meeting v1 ignores unsupported tags while preserving
   text/timestamp correctness.
6. Adapter throws runtime failure; session controller stops transcription and
   preserves recorded audio metadata for retry.
7. Local-only policy is enabled; no cloud fallback is attempted.

## Automation Flow Draft

- Unit test `SpeechRuntimeRegistry` selection order with fake adapters.
- Unit test unavailable states: unsupported platform, missing model, binary
  missing, permission denied.
- Unit test `SherpaSenseVoiceTranscriptionEngine` mapping with a fake Sherpa
  client so CI does not require native binaries.
- Unit test `GgufSenseVoiceProcessEngine` command construction with a fake
  process runner.
- Unit test Meeting mapper from `SpeechTranscriptChunk` to `TranscriptChunk`.
- Integration test with a small checked-in or generated WAV fixture once legal
  test audio is approved.

## Implementation Sequence

1. Add the GitHub issue feature packet using this document.
2. Extend `packages/platform_media` with only Airo-owned speech interfaces,
   models, fake/noop runtime, and registry tests.
3. Add `sherpa_onnx` as an implementation dependency in `platform_media` and
   build the SenseVoice adapter behind an injectable client boundary.
4. Add optional GGUF process adapter for desktop only.
5. Wire app-level providers for runtime selection and availability.
6. Wire Meeting Intelligence to consume the provider through a mapper, leaving
   `core_ai` unchanged.
7. Add UI/runtime settings after the engine contract is test-covered.

## Non-Goals

- No changes to `packages/core_ai` framework model routing.
- No new `AIProvider` enum value for SenseVoice.
- No new platform package for v1; use the existing `packages/platform_media`
  boundary unless a future ownership decision explicitly splits speech out.
- No direct Python/FunASR runtime in the mobile app.
- No cloud fallback for raw meeting audio.
- No speaker diarization storage change in v1 unless the issue explicitly adds
  the contract and migrations.

## Sources

- https://github.com/FunAudioLLM/SenseVoice
- https://github.com/FunAudioLLM/SenseVoice/releases
- https://huggingface.co/FunAudioLLM/SenseVoiceSmall
- https://huggingface.co/FunAudioLLM/SenseVoiceSmall-GGUF
- https://k2-fsa.github.io/sherpa/onnx/sense-voice/index.html
- https://github.com/k2-fsa/sherpa/blob/master/docs/source/onnx/sense-voice/dart-api.rst
- https://pub.dev/packages/sherpa_onnx
