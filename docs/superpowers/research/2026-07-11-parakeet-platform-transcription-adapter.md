# Parakeet Platform Transcription Adapter Research

Date: 2026-07-11
Worktree: `/Users/udaychauhan/workspace/airo-parakeet-platform-component`
Branch: `research/parakeet-platform-component-adapter`
Base: `origin/main` at `e77688421dfa3fbc407f730d209b3ad0277543a3`

## Critical Agent Gate

**Problem:** Airo needs a way to make `achetronic/parakeet` available to app consumers through the existing speech/transcription platform component without changing framework-level AI/runtime contracts.

**User / actor:** Meeting Intelligence, Audio Scribe, and future voice workflows that need speech-to-text and should be able to switch transcription backends at runtime.

**Framework or application layer:** Platform component plus application integration. No `packages/core_ai` or framework model-routing changes are required.

**Owning agent:** Meeting Intelligence Agent.

**Reviewing agents:** Security and Privacy Agent, QA Automation Agent, Release and DevEx Agent.

**Impacted modules/files:** Existing platform component `packages/platform_media/**`; optional app provider wiring under `app/lib/features/meeting/**` or `app/lib/core/audio/**`; docs and tests.

**Base branch/worktree:** Confirmed from latest `origin/main`: yes, `e7768842`.

**Open questions:** Whether Parakeet should be treated as local-network only, self-hosted cloud, or developer-only in v1; whether Airo is willing to ship a server dependency for mobile workflows; final license review because the repository `LICENSE` is Apache-2.0 while the README currently says "Code: MIT License".

**Decision:** Ready for design packet and implementation issue. Reuse the existing `packages/platform_media` speech/transcription boundary established by the SenseVoice platform plan; do not create another transcription package or framework-level runtime path. Production rollout remains blocked until deployment/privacy policy and license interpretation are confirmed.

## External Research

Source: <https://github.com/achetronic/parakeet>

Parakeet is a Go ASR server using NVIDIA Parakeet TDT 0.6B through ONNX Runtime. It exposes an OpenAI Whisper-compatible API, including `POST /v1/audio/transcriptions`, optional bearer-token auth via `PARAKEET_API_KEY`, `GET /v1/models`, and unauthenticated `GET /health`.

The latest GitHub release visible during research was `v0.8.0 - Long audio`, dated 2026-07-03. The repository README documents long-audio support behind `-long-audio`, chunk sizing, overlap, and optional Silero VAD-based chunk boundary selection.

Operational details that matter for Airo:

- Runtime is a server process, not a Flutter/Dart library.
- Default HTTP port is `5092`.
- Docker image: `ghcr.io/achetronic/parakeet:latest`; CUDA image: `ghcr.io/achetronic/parakeet:latest-cuda`.
- CPU path requires ONNX Runtime and model files.
- int8 model bundle is approximately 670 MB on disk and uses about 2 GB RAM during inference.
- Full precision models are approximately 2.5 GB and are the recommended precision for CUDA.
- Non-WAV formats require `ffmpeg`; without it, non-WAV uploads return a client error.
- The transcription endpoint accepts multipart `file`, optional `language`, `response_format`, and `stream`.
- `response_format` supports `json`, `text`, `srt`, `vtt`, and `verbose_json`.
- Streaming uses Server-Sent Events with `transcript.text.delta` and `transcript.text.done`; the audio upload is still full-file upload, not microphone frame streaming.
- `/v1/models` returns `parakeet-tdt-0.6b` and `whisper-1` as a compatibility alias.
- CUDA support is Linux amd64 only and fails at startup if the provider cannot initialize.
- Repository license file is Apache-2.0; model license is documented as CC-BY-4.0.

## Local Repo Fit

Airo already has:

- Meeting transcript entities in `app/lib/features/meeting/domain/entities/transcript_chunk.dart`.
- A local meeting intelligence pipeline that consumes final `TranscriptChunk` values.
- Method-channel based native meeting transcription contracts in `app/lib/features/meeting/infrastructure/platform/native_meeting_contracts.dart`.
- Platform packages under `packages/platform_*` that export small, focused contracts and adapters.
- Existing adapter precedent in `packages/platform_player/lib/src/services/iptv_cast_media_adapter.dart`.

The current native meeting contract is app-facing and method-channel specific. Replacing it with Parakeet would pull HTTP, server lifecycle, auth, and privacy choices into the meeting feature. That is the wrong boundary for this request.

## Recommendation

Reuse the existing platform component package:

```text
packages/platform_media/
  lib/src/speech/speech_transcription_engine.dart
  lib/src/speech/speech_transcription_models.dart
  lib/src/speech/runtime/speech_runtime_registry.dart
  lib/src/speech/runtime/noop_transcription_engine.dart
  lib/src/speech/runtime/parakeet_http_transcription_engine.dart
  test/speech/parakeet_http_transcription_engine_test.dart
  test/speech/speech_runtime_registry_test.dart
```

`packages/platform_media` should own the consumer-facing STT contract. Parakeet becomes one engine behind that existing contract. Native method-channel STT, SenseVoice, Whisper.cpp, Google Speech, Meetily, or test fakes can be registered as peers later without touching framework code.

Do not modify `packages/core_ai` for this. Speech-to-text is a media/platform capability here, not LLM text generation or model routing.

## Proposed Contract

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

Minimum request model:

```dart
class SpeechTranscriptionRequest {
  const SpeechTranscriptionRequest({
    required this.audioPath,
    required this.sessionId,
    this.languageCode = 'auto',
    this.enableTimestamps = true,
    this.enableSpeakerLabels = false,
    this.runtimeMetadata = const {},
  });

  final String audioPath;
  final String sessionId;
  final String languageCode;
  final bool enableTimestamps;
  final bool enableSpeakerLabels;
  final Map<String, String> runtimeMetadata;
}
```

Minimum result model:

```dart
class SpeechTranscriptionResult {
  const SpeechTranscriptionResult({
    required this.text,
    required this.runtimeId,
    required this.chunks,
    this.languageCode,
    this.duration,
  });

  final String text;
  final SpeechRuntimeId runtimeId;
  final List<SpeechTranscriptChunk> chunks;
  final String? languageCode;
  final Duration? duration;
}
```

Runtime registry:

```dart
final engine = registry.resolve(
  preferred: userSettings.speechRuntimeId,
  policy: SpeechRuntimePolicy.localOnly,
);
```

Add Parakeet as a runtime ID in that existing registry:

```dart
enum SpeechRuntimeId {
  systemNative,
  sherpaSenseVoice,
  ggufSenseVoice,
  parakeetHttp,
  disabled,
}
```

For Riverpod consumers, expose app-level providers rather than framework routing:

```dart
final selectedSpeechRuntimeProvider = StateProvider<SpeechRuntimeId>(
  (ref) => SpeechRuntimeId.parakeetHttp,
);

final speechRuntimeRegistryProvider = Provider<SpeechRuntimeRegistry>(
  (ref) => SpeechRuntimeRegistry(
    engines: [
      ParakeetHttpTranscriptionEngine(
        endpoint: Uri.parse(ref.watch(parakeetEndpointProvider)),
        apiKey: ref.watch(parakeetApiKeyProvider),
      ),
      SystemNativeTranscriptionEngine(...),
    ],
  ),
);
```

Consumers switch at runtime by updating `selectedSpeechRuntimeProvider`; meeting/audio code depends only on `SpeechTranscriptionEngine` or the registry.

## Parakeet Adapter Behavior

`ParakeetHttpTranscriptionEngine` should:

- Probe `GET /health` for availability.
- Optionally call `GET /v1/models` for capability diagnostics.
- Send `multipart/form-data` to `/v1/audio/transcriptions`.
- Add `Authorization: Bearer <apiKey>` only when configured.
- Map `json` and `verbose_json` responses into `SpeechTranscriptionResult`.
- Map SSE `transcript.text.delta` into partial `SpeechTranscriptChunk` events.
- Map SSE `transcript.text.done` into a final `SpeechTranscriptChunk`.
- Convert HTTP 401/403 into auth errors, 400 into unsupported-audio/request errors, timeout into availability/runtime errors.
- Avoid logging audio file paths, auth tokens, transcript text, or raw server payloads by default.

## Consumer Integration

Meeting Intelligence should keep its current domain entities. The adapter layer maps each platform speech chunk to a meeting chunk:

```dart
TranscriptChunk.finalChunk(
  id: '$meetingId-transcript-1',
  meetingId: meetingId,
  text: chunk.text,
  startMs: chunk.startMs,
  endMs: chunk.endMs,
)
```

If `verbose_json` segments are available, each segment can become one final chunk. Parakeet does not provide diarization, so `speakerLabel` remains null unless a separate diarization component is added.

Audio Scribe can use `packages/platform_media` directly for file transcription without depending on Meeting Intelligence internals.

## Runtime Switching Model

Provider selection should be data, not code branching:

- `parakeetHttp`: HTTP engine to self-hosted/local Parakeet server.
- `systemNative`: current method-channel adapter for platform-native STT.
- `disabled`: deterministic unavailable/noop engine.
- Future peers in the same registry: `sherpaSenseVoice`, `ggufSenseVoice`, `whisperCpp`, `meetily`, etc.

Selection can come from user settings, feature flags, or environment config. The registry should allow unavailable adapters to remain registered so UI can explain why a provider cannot run.

## Security And Privacy

Parakeet is local-first only when the endpoint is a trusted local machine or bundled sidecar. If pointed at a remote host, audio leaves the device. The UI and settings must disclose this clearly.

Required v1 safeguards:

- Endpoint allowlist defaults to `http://127.0.0.1:5092` or user-confirmed LAN/HTTPS endpoint.
- API key stored in secure storage, not plain shared preferences.
- No transcript/audio payload logs.
- Clear network opt-in before remote endpoint usage.
- Timeout and max file size controls at the adapter layer.
- License review before bundling binaries, images, or model artifacts.

## Automation Plan

Deterministic tests should not require a real Parakeet server.

Package tests:

- Registry selects configured provider.
- Registry falls back to first available adapter when selected provider is unavailable.
- Parakeet engine sends the correct multipart fields.
- Parakeet engine includes bearer auth only when an API key exists.
- JSON response maps into `SpeechTranscriptionResult`.
- Verbose JSON maps segments with start/end times.
- SSE delta/done events map into transcript events.
- 400, 401, 500, timeout, and malformed payloads map into stable error types.

App tests:

- Meeting session receives platform transcription result and saves final chunks.
- Runtime provider switch changes the adapter without rebuilding feature code.
- Remote endpoint setting requires explicit user opt-in.

## Rollout Plan

1. Extend `packages/platform_media` with only missing reusable speech interfaces, models, registry pieces, and tests. If the SenseVoice implementation has already added them, reuse those exact names and add only the Parakeet engine.
2. Add `ParakeetHttpTranscriptionEngine` using `package:http` or the repo-standard HTTP client wrapper.
3. Add app-level Riverpod providers for provider selection and Parakeet endpoint config.
4. Add a small Meeting Intelligence adapter that maps `SpeechTranscriptionResult` to `TranscriptChunk`.
5. Wire the Meeting/Audio Scribe consumer behind provider overrides.
6. Add settings UI only after the provider contract is tested.

## Non-Goals

- No changes to `packages/core_ai`.
- No changes to LLM routing or local model registry.
- No new `packages/platform_transcription` package; use the existing `packages/platform_media` speech boundary.
- No bundled Parakeet binary/model artifacts in the first adapter pass.
- No diarization, speaker identification, or live microphone frame streaming.
- No automatic remote endpoint use without explicit user configuration.

## Decision

Parakeet is viable as an Airo platform transcription engine because it speaks an OpenAI Whisper-compatible HTTP API. It should not become a framework-level runtime and should not create a second transcription platform package. The clean integration is to reuse the existing `packages/platform_media` speech boundary and add Parakeet as a runtime-selectable engine consumed by Meeting Intelligence and Audio Scribe through app-level providers.
