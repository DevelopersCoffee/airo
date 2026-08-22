# Live transcript UX + Vocabulary Intelligence

Status: **Accepted** (implementation in progress)
Date: 2026-08-22
Companion: [`2026-08-22-streaming-stt-zero-copy-design.md`](./2026-08-22-streaming-stt-zero-copy-design.md), ADR-0025

## Problem

Meeting capture reads as a **recorder** (timer + empty space) rather than an
**intelligent live transcription** surface. Vocabulary correction was a
post-hoc normalize pass, not part of the live understanding pipeline.

## UX — P0 (this change)

| Requirement | Implementation |
|---|---|
| Live transcript primary (~65–75% height) | `LiveTranscriptView` in active capture layout |
| Compact privacy bar | `CompactTrustStatusBar` + detail bottom sheet |
| PARTIAL / STABLE / FINAL rendering | Partial tail with `▌`; stable committed text |
| LIVE + timer in app bar | `meeting_capture_live_badge` |
| Speaker labels | `Speaker 1` / `spN` → `Speaker N+1` (no invented names) |
| Follow live + jump to live | `LiveTranscriptView` + `Follow live` chip |
| Secondary waveform | `_AudioActivityBar` (decorative, not hero) |
| Focused capture mode | Pre-start vs active body split; nav de-emphasized via full-screen transcript |
| Pause / stop / timer | `LiveCaptureControls` |

## UX — P1 (stub / follow-up)

| Requirement | Status |
|---|---|
| Collapsible live insights rail | `LiveInsightsRail` stub |
| Live entity / decision / action detection | Not in this PR |
| Search during recording | Not in this PR |
| Speaker name resolution | Not in this PR |
| More menu (mic, language, …) | Not in this PR |

## Vocabulary Intelligence — P0

Pipeline position:

```text
STT → Transcript Stabilizer → Vocabulary Intelligence → Live UI / IR
```

- Module: `rust/airo_mind_transcript/src/vocabulary.rs`
- Types: `VocabularyContext`, `VocabularyEntry`, `VocabularyIntelligence`
- Matching order: exact/phrase (aliases) → technical `normalize` → fuzzy word (Levenshtein ≤2, confidence ≥0.85)
- Runs on **STABLE/FINAL** live segments only (`meetings.rs` `emit_live_delta`)
- Preserves `original_text` in `CorrectionResult`; provenance list in Rust (FRB/IR wire follow-up)
- **No LLM** on the hot path

### P1 vocabulary (documented, not this PR)

- User / project / domain / conversation layers populated from settings
- Phonetic index beyond alias tables
- Learning from user corrections
- Full Conversation IR provenance JSON on save

## Requirement traceability

User spec items:

1. Transcript primary — ✓ P0
2. Compact privacy banner — ✓ P0
3. Live transcript states — ✓ P0
4. Live indicator — ✓ P0
5. Speaker identification — ✓ P0 (generic labels)
6. Intelligence rail — stub P1
7. Bottom controls — ✓ P0
8. Transcript navigation / jump to live — ✓ P0
9. Simplified nav during recording — ✓ P0 (layout)
10. Follow speaker — ✓ P0 (`Follow live`)
11. Vocabulary two-path (not only post-stop) — ✓ P0 on stable live path
12. Not blind Levenshtein — layered matching + confidence threshold
13. Vocabulary context layers — types + global defaults; population P1
14. Confidence-based correction — ✓
15. Preserve raw transcript — ✓ in `CorrectionResult`
16. Stable-only correction for UI stability — ✓
17. No LLM in core vocabulary path — ✓

## Tests

- `airo_mind_transcript` vocabulary unit tests
- `live_speaker_label` / coordinator line mapping (Dart)
- Capture screen pre-start tests updated for compact trust bar
