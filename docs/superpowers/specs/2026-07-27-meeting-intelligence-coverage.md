# Meeting Intelligence — Coverage Against Airo, and Gaps to Adopt

Status: **Research.** Input to milestones 13, 19, 20.
Date: 2026-07-27
Reference feature set: Meetily (local-first meeting transcription and summarisation).
Owner: Product Manager (Airo Engineering Council)

Answers the question "are we supporting this?" against what is actually in the
repository, not against intent. Every row is checked.

---

## 1. Summary

- **Most of the list is already scoped**, across milestone 13 (Audio Scribe,
  #266–#269, #306), the meeting-intelligence issues (#241, #242, #248), and the
  reliability phases (#504, #511, #512).
- **`app/lib/features/meeting/` is real and substantial** — a full domain model
  with `MeetingRecord`, `TranscriptChunk`, `MeetingSummary`, `MeetingSegment`,
  `MeetingAudioMetadata`, `MeetingIntelligence`, a redaction service, and an
  intelligence pipeline.
- **Transcription itself is not built.** No Whisper, whisper.cpp, or Parakeet
  code exists anywhere in `packages/`, `app/`, or `rust/`. The only hit for
  "whisper" in the tree is a comment in `intent_parser.dart`.
- **Three capabilities are not covered at all:** simultaneous microphone and
  system-audio capture with ducking, desktop GPU acceleration
  (Metal/CoreML, CUDA, Vulkan), and document export (PDF/DOCX/Markdown).
- **One is refused, deliberately:** self-hosted team deployment. It contradicts
  the v1 trust boundary.
- **One item Airo is structurally better at:** GDPR audit trails. The operation
  log *is* an append-only audit trail, so this is a property of the
  architecture rather than a feature to build.
- **One existing violation found.** `DriftMeetingRepository` persists meetings
  to a feature-owned SQLite database, outside the operation log. Under runtime
  invariant **I2** that is a defect, and it is the first concrete instance.

---

## 2. Coverage table

| Capability | Status | Where |
|---|---|---|
| Works offline | **Yes** | Core positioning; runtime is local-first by construction |
| Local-first, no data leaves the machine | **Yes** | Design spec §7; stronger than the reference — no cloud OAuth broker, no telemetry |
| Real-time transcription | **Planned, not built** | #248 Live Notes, #241 Android recorder + whisper.cpp, #242 iOS |
| AI-powered summaries | **Planned** | `meeting_summary.dart` entity exists; `core_ai` has LiteRT / Gemini Nano / GGUF routers |
| macOS, Windows, Linux | **Partial** | Flutter desktop targets exist (`app/macos`, `app/windows`, `app/linux`); no evidence of a shipped desktop build |
| Open source | **Yes** | MIT, public repo |
| Flexible AI providers | **Partial** | #287 remote model servers with LAN discovery, #308 local OpenAI-compatible API, #139 on-prem, #132 Bedrock, #136 Vertex. Ollama-style local is #277/#284. |
| Local transcription (Whisper) | **Planned** | #241, #242, #248, #511 robustness |
| Local transcription (Parakeet) | **Not covered** | No mention anywhere in the tree |
| Import audio files / re-transcribe | **Planned** | #269 import, #306 formats and multi-clip |
| Mic + system audio simultaneously, with ducking | **NOT COVERED** | Gap — see §3 |
| Hardware acceleration, mobile | **Planned** | #279 Pixel TPU, NPU, GPU, CPU |
| Hardware acceleration, desktop (Metal/CoreML, CUDA, Vulkan) | **NOT COVERED** | Gap — see §3 |
| Custom summary templates | **Conceptually covered** | Capability templates, milestone 20 (#1246). Not specified for meetings. |
| Export PDF / DOCX / Markdown | **NOT COVERED** | Gap — see §3 |
| Auto-detect and join meetings | **Not covered** | See §4 — needs a decision, not just an issue |
| Speaker identification | **Planned** | #267 enrolment, #504 speaker learning, #512 diarisation validation |
| Chat with meetings | **Planned** | #300 Memory Chat grounded in user history |
| Calendar integration | **Partial** | `CalendarEvent` is a core ontology entity (#1223); no calendar connector exists |
| Self-hosted deployment for teams | **REFUSED** | Contradicts the v1 trust boundary — see §4 |
| GDPR compliance, audit trails | **Structurally superior** | The operation log is an append-only signed audit trail. Plus real erasure via crypto-shredding, which most "GDPR-compliant" products cannot offer. |

---

## 3. Gaps worth adopting

### G1 — Simultaneous microphone and system-audio capture

The single most valuable missing piece. Without system audio, only the local
speaker is transcribed, which makes remote-meeting transcription close to
useless — and remote meetings are the use case.

Needs: dual-stream capture, intelligent ducking, clipping prevention, and a
per-platform capture path (macOS requires a system-audio driver or
ScreenCaptureKit; Windows uses WASAPI loopback; Linux uses PulseAudio/PipeWire
monitor sources).

**Consent obligation, binding:** capturing system audio records every remote
participant. Eleven US states require all-party consent, and interstate calls
default to the most restrictive jurisdiction (`2026-07-27-airo-mind-roadmap.md`
§4). A visible indicator is **not** legally sufficient consent. No system-audio
capture ships without a consent design reviewed by counsel.

### G2 — Desktop GPU acceleration

Mobile acceleration is scoped (#279). Desktop is not, and desktop is where
long meeting transcription actually runs. Metal + CoreML on Apple Silicon,
CUDA on NVIDIA, Vulkan on AMD/Intel.

The reference implementation enables these at build time with no runtime
configuration, which is the right default — a user should not choose a
backend.

### G3 — Document export

PDF, DOCX, and Markdown with formatting. Currently nothing in the tree exports
a meeting artifact to a document.

This is a good early test of invariant **I1**: an exported document is derived
from content and must not become a second source of truth. Export writes a
file the user owns and the runtime stops tracking — the same one-way boundary
as capsule export (§7).

### G4 — Parakeet as an alternative STT model

NVIDIA Parakeet, via the ONNX conversion, alongside Whisper. Worth having as
a second option for accuracy and speed trade-offs, but strictly after Whisper
works. Not urgent.

### G5 — Calendar connector

`CalendarEvent` exists as a core ontology entity, so meetings can already
attach to calendar entries structurally. What is missing is a connector that
populates them.

---

## 4. Two items that need a decision, not an issue

### Auto-detect and join meetings

Joining a meeting means driving a third-party client, or joining as a bot with
credentials. Both put Airo inside the meeting as a participant, which changes
the consent story from "I am recording my own audio" to "an automated
participant is recording everyone".

Recommendation: **detect and prompt, never auto-join.** Detection (a calendar
event is starting, a meeting app is in the foreground) is a local signal and
is fine. Joining is an action with legal weight and belongs behind an explicit
per-meeting approval — the same class as `#1235`'s destructive confirmations.

### Self-hosted deployment for teams

**Refused for v1**, consistent with the roadmap's existing refusals. It
requires a multi-user trust domain, shared storage, and administrative
control — none of which exist in a design whose trust boundary is one person's
device mesh, and all of which reopen the human-to-human sharing question
already refused (`roadmap.md` §2).

If team meeting intelligence is wanted, it is a different product with a
different threat model, not a deployment mode of this one.

---

## 5. The violation this analysis found

`app/lib/features/meeting/infrastructure/storage/drift_meeting_repository.dart`
persists meeting records, transcripts, summaries, and audio metadata into a
feature-owned Drift/SQLite database via `core/database/app_database_native.dart`.

Under design spec **I2** — *no capability may create durable storage outside
the runtime* — this is a defect. Concretely, meeting data stored this way is
invisible to:

- `DestroyContent` — a destroyed meeting survives in the SQLite file
- Backup and Recovery Package — meetings are not in the Vault or the log
- Sync — meetings never reach another device
- Projection rebuild — nothing can regenerate them
- Crypto-shredding — the audio and transcript are not behind a content key

The same pattern appears in `features/coins/data/datasources/`,
`features/money/application/services/`, and the settings AI-storage dashboard.
Meetings are simply the clearest case because the content is high-sensitivity
and the erasure claim is loudest.

This is not a reason to stop meeting work. It is the reason meeting storage
should migrate to the runtime rather than grow further on its own schema —
and it is worth knowing before #241, #242, and #248 add transcription data to
that same database.

Migration is not free and is not Phase 1 work. It belongs after the operation
log and content store exist (#1194), tracked as its own issue.
