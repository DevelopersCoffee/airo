# Airo Mind — Real-Time Conversation Architecture

Status: **Preview (desktop) / Not production**. This document records the
architecture that exists today (Phase 1 baseline audit) and the target
architecture the production-qualification program is closing toward. It is
descriptive of code in-tree; where a box is target-only it is marked
**(target)**.

## 1. Current architecture (as implemented)

### Live path (desktop only)

```text
Microphone
 ├── AudioRecorder #1 (package:record, AAC)  ──► meeting-*.m4a file
 └── AudioRecorder #2 (package:record, PCM16) ──► MeetingLivePcmShim
                                                    │  pushLivePcm(samples)
                                                    ▼
                                             Rust airo_mind_whisper
                                             push_live_pcm → PcmRingBuffer
                                                    ▼
                                             EnergyVad (RMS + silence run)
                                                    ▼
                                             WhisperSpeechEngine (window re-transcribe)
                                                    ▼
                                             TranscriptStabilizer (PARTIAL→STABLE→FINAL)
                                                    ▼
                                             vocabulary_correct_stable (Rust)
                                                    ▼
                                             SpeakerActivityTracker (provisional sp0/sp1)
                                                    ▼
                                             TranscriptEvent.delta (FRB stream)
                                                    ▼
                                             MeetingLiveSessionCoordinator (Dart)
                                                    ▼
                                             LiveTranscriptView  +  LiveInsightsRail (stub)
```

### Post-recording path (all native platforms)

```text
meeting-*.m4a ──► MindService.process
                    ▼
                  transcribeRecording (whisper FRB)
                    ▼
                  diarization (airo_mind_diarize: solo / ECAPA)
                    ▼
                  Meeting IR (airo_mind_meeting: 2-pass extract)
                    ▼
                  Minutes / MoM (airo_mind_llama)
                    ▼
                  saveMeeting (Rust store + transcript.json)
```

### Key finding

There are **two independent microphone captures** on desktop when live mode is
on (the file recorder and the live-PCM shim). The shim is a documented interim
violation (`docs/features/airo-mind/LIVE_CAPTURE_FAN_OUT.md`, ZC-1). This is the
first thing Phase 2 must remove.

### Component / crate map

| Concern | Location |
| --- | --- |
| File capture | `feature_mind/lib/src/capture/data/audio_recorder_port.dart` |
| Live PCM shim (interim) | `feature_mind/lib/src/capture/application/meeting_live_pcm_shim.dart` |
| Live coordinator (Dart) | `feature_mind/lib/src/capture/application/meeting_live_session_coordinator.dart` |
| Ring buffer | `rust/airo_mind_audio/src/ring.rs` |
| VAD | `rust/airo_mind_audio/src/vad.rs` |
| Stabilizer | `rust/airo_mind_audio/src/stabilizer.rs` |
| Speaker activity | `rust/airo_mind_audio/src/speaker_activity.rs` |
| Whisper engine | `rust/airo_mind_whisper/src/whisper.rs` |
| Live session / FRB | `rust/airo_mind_whisper/src/api/meetings.rs` |
| Vocabulary | `rust/airo_mind_transcript/src/vocabulary.rs` |
| Diarization | `rust/airo_mind_diarize/` |
| Meeting IR | `rust/airo_mind_meeting/src/ir.rs` |
| Generation / minutes | `rust/airo_mind_llama/` |
| Supervisor / admission | `rust/airo_mind_core/src/supervisor.rs`, `budget.rs`, `models.rs` |
| Transcript event types (Dart) | `feature_mind/lib/src/bridges/mind_speech_bridge.dart` |
| Qualification model (Dart) | `feature_mind/lib/src/qualification/mind_qualification.dart` |

## 2. Target architecture

```text
Audio
 ↓
Unified Native Fan-out (single capture, bounded backpressure)   (target)
 ├──────────────→ File Recorder (authoritative recovery artifact)
 └──────────────→ Live PCM → VAD → Streaming STT → Stabilizer
                       ↓
                 Vocabulary Intelligence (provenance preserved)  (partial)
                       ↓
                 Canonical Transcript
                       ↓
                 Incremental Conversation IR                     (target)
                       ↓
                 Intelligence Events
       ┌─────────────┼──────────────┐
       ↓             ↓              ↓
    Live UI       Memory          Search
```

## 3. Ownership boundaries (preserved)

- **Rust** owns: session lifecycle, audio pipeline, event protocol, resource
  governor, model lifecycle, conversation state, the FFI boundary.
- **Flutter** owns: UI, presentation state, navigation, settings, visualization.
- **Native C/C++ engines** (whisper.cpp, llama.cpp) are replaceable backends
  behind Rust traits; Flutter never learns which engine is in use.

## 4. Delta from current → target

| Area | Current | Target work |
| --- | --- | --- |
| Capture | 2 mic captures (desktop) | 1 native source fanned out to file + live |
| Failure isolation | ring-overflow degrade only | full degraded-mode across all failure classes |
| Streaming STT | window re-transcribe | measured PARTIAL/STABLE/FINAL contract + latency |
| Event protocol | no `sequence_number`/`confidence`/provenance | add fields; typed engine/model/thermal events |
| Vocabulary | Rust-only, provenance dropped at boundary | surface provenance to Dart/persistence |
| Speaker | provisional turn-taking + post-hoc diarization | typed timeline + reconciliation API |
| Conversation IR | post-recording batch only | incremental, event-driven |
| Intelligence | one tier, post-stop | fast/deep tiers on semantic boundaries |
| Governor | scattered thermal/residency policies | one resource + thermal + battery governor |
| Qualification | boolean host gate | capability × platform matrix + derived states (this PR) |

See `docs/mind/production-qualification.md` for the gate status and verdict.
