# Platform capability matrix

Status: **QA evidence, not marketing.** Date: 2026-08-23
States: `UNSUPPORTED` · `EXPERIMENTAL` · `PREVIEW` · `PRODUCTION`

A cell is PRODUCTION only when implementation **and** tests exist for that
host. Compilation alone is not enough.

| Capability | Desktop | Android | iOS | Web |
|---|---|---|---|---|
| Recording | PRODUCTION (`package:record` AAC after-recording; live WAV fan-out) | PRODUCTION (foreground service + MediaRecorder) | PREVIEW (engine build gated #1546) | PRODUCTION (after-recording where the recorder plugin works) |
| Offline STT (file) | PRODUCTION | PREVIEW (weights + FFI) | UNSUPPORTED (#1546) | UNSUPPORTED (no FFI) |
| Live STT | PREVIEW (fan-out + worker; PCM still via FRB shim) | UNSUPPORTED | UNSUPPORTED | UNSUPPORTED |
| Stabilization | PREVIEW (host unit tests) | UNSUPPORTED | UNSUPPORTED | UNSUPPORTED |
| Vocabulary (stable/final) | PREVIEW | UNSUPPORTED | UNSUPPORTED | UNSUPPORTED |
| Live speaker activity | PREVIEW (provisional lanes) | UNSUPPORTED | UNSUPPORTED | UNSUPPORTED |
| Final diarization | PREVIEW (post-stop on file) | PREVIEW | UNSUPPORTED | UNSUPPORTED |
| Live Conversation IR | EXPERIMENTAL (Rust extractor; not on FRB/UI) | UNSUPPORTED | UNSUPPORTED | UNSUPPORTED |
| Live insights | EXPERIMENTAL (UI stub) | UNSUPPORTED | UNSUPPORTED | UNSUPPORTED |
| Post-recording IR | PREVIEW (`airo_mind_meeting` two-pass) | PREVIEW | UNSUPPORTED | UNSUPPORTED |
| Search | PRODUCTION (meeting library) | PREVIEW | UNSUPPORTED | UNSUPPORTED |
| Memory | PREVIEW (vault / notes) | PREVIEW | UNSUPPORTED | UNSUPPORTED |
