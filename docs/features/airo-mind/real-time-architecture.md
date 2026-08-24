# Real-time conversation architecture

Status: **Implemented core (desktop fan-out + isolation). Not production-qualified.**
Date: 2026-08-23
Owner: Rust Architect + Platform Architect

Companion: [LIVE_CAPTURE_FAN_OUT.md](./LIVE_CAPTURE_FAN_OUT.md),
[production-qualification.md](./production-qualification.md),
[ADR-0025](../../adr/0025-streaming-speech-engine-boundary.md).

## Ownership

| Concern | Owner |
|---|---|
| Microphone consent, session start/pause/resume/stop | Dart (`MeetingCaptureController`) |
| Authoritative capture ingest | Native `CaptureFanout` (`airo_mind_audio`) |
| Encoded/WAV file (durability, crash recovery) | `IncrementalWavWriter` via fan-out |
| Live PCM ring, VAD, windowing, stabilizer | `LiveSpeechPipeline` |
| Speech inference | `SpeechEngine` behind `Supervisor::run_speech` |
| Transcript events | Native → Dart (`TranscriptEvent`) |
| UI | Flutter |

Live intelligence is an optional consumer of the recording stream. The file is
the recovery artifact. STT, vocabulary, IR, and LLM failure must not stop
capture.

## Desktop live path (this change)

```text
Consent → start_live_session (admission)
        → one record.startStream (PCM16 16 kHz)
        → push_live_pcm
              ├─ CaptureFanout → incremental WAV  (never waits on STT)
              └─ bounded channel → live worker
                    → ring → VAD → SpeechEngine → stabilizer → events
```

`FanoutBackedAudioRecorderPort` drives the capture controller timer without
opening a second microphone. After-recording mode still uses `package:record`
AAC as before.

`push_live_pcm` remains an interim FRB ingest (ZC-1). Removing it requires
in-process native capture (cpal / AudioRecord / AVAudioEngine) behind the
same session API.

## Failure isolation

```text
LIVE ENGINE ERROR / worker panic / channel overflow
        ↓
Mark live intelligence degraded
        ↓
Continue writing the WAV
        ↓
Stop → post-recording transcribe_recording
```

The UI already surfaces `TranscriptEvent::Degraded` and a start-time warning
when admission refuses live STT.

## Incremental Conversation IR

`airo_mind_meeting::IncrementalConversationIr` consumes **stable sentences**
and emits structured events (segment, entity, action, decision, question,
topic) without an LLM. Stable sentences fan out as
`TranscriptEvent::ConversationIr` (JSON) onto the live insights rail. Deep
Meeting IR remains the post-recording two-pass pipeline.

`ResourceGovernor` is applied at `start_live_session` from a host snapshot
(Linux `/proc` + sysfs). `CaptureAndSttOnly` keeps recording and STT and
skips live IR.
