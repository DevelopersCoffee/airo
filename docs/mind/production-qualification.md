# Airo Mind — Production Qualification

Final state: **NOT PRODUCTION QUALIFIED.**

This document defines the qualification policy, records the gap matrix from the
Phase 1 baseline audit, and tracks each Definition-of-Done gate. It is updated
from test evidence, not assumptions.

## 1. Qualification states

Airo Mind derives an explicit state per capability per platform:

| State | Meaning |
| --- | --- |
| `UNSUPPORTED` | Not available on the platform (no FFI on web, iOS not wired). |
| `EXPERIMENTAL` | Implemented, no measured gates; may change or break. |
| `PREVIEW` | Opt-in with disclaimer; not default, not fully gated. |
| `PRODUCTION` | Backed by passing release gates, benchmarks, platform validation. |

**Derivation rule (enforced in code):** the resolved state is
`min(declared_ceiling, runtime_capability_ceiling)`. The declared ceiling lives
in `MindQualificationMatrix.current()`; the runtime ceiling is computed from
actual signals (`MindRuntimeCapabilitySignals`: native bridge loaded, recorder
present, live host supported). Because the runtime ceiling can only cap *down*,
a feature flag can never produce a `PRODUCTION` label — satisfying spec §24.
See `packages/feature_mind/lib/src/qualification/mind_qualification.dart` and
its tests.

The current declared matrix contains **no `PRODUCTION` cells** (verified by the
test `declares no capability as production on any platform`). This is
intentional and consistent with the verdict below: promoting a cell to
`PRODUCTION` requires raising its declared ceiling, which must be justified by
the evidence in `latency-benchmarks.md` and `evaluation-results.md`.

## 2. Gap matrix (Phase 1 audit)

Verdicts: EXISTS / PARTIAL / MISSING, relative to the production spec.

| # | Requirement | Verdict | Notes |
| --- | --- | --- | --- |
| 2 | Unified native audio fan-out | **MISSING** | Duplicate mic capture on desktop; interim PCM shim (ZC-1). |
| 3 | Crash recovery / failure isolation | **PARTIAL** | Ring-overflow degrade + queue restart; no unified degraded mode across all failure classes. |
| 4 | Real streaming STT (PARTIAL/STABLE/FINAL) | **PARTIAL** | Contract + stabilizer exist; engine re-transcribes a window; no latency measurement. |
| 5 | Transcript event protocol | **PARTIAL** | Structured `TranscriptEvent`/`TranscriptDelta`; missing `sequence_number`, `confidence`, provenance, typed engine/model/thermal events. |
| 6 | Vocabulary intelligence | **PARTIAL** | Rust corrector (alias/phrase/normalize/phonetic/fuzzy/threshold); layers mostly empty; provenance dropped at Dart boundary; no context scoring. |
| 7 | Speaker timeline + reconciliation | **PARTIAL** | Provisional live turn-taking + post-hoc ECAPA/solo diarization + enrollment; no typed `SpeakerActivity`/`SpeakerSegment`/`SpeakerCluster` wire types. |
| 8 | Conversation IR (incremental) | **PARTIAL** | Full Rust `MeetingIr`; post-recording batch only; not incremental/event-driven. |
| 9 | Incremental intelligence (fast/deep tiers) | **MISSING** | One generation slot; runs after stop; no semantic-boundary triggering. |
| 10 | Model admission / resource governor | **PARTIAL** | Memory-budget admission + registry; Mind init hard-codes 4096 MB; no full runtime-headroom matrix; no unified governor. |
| 11 | Thermal + battery governor | **PARTIAL** | 4-level thermal signals + batch pause; no `<20%`/`<10%` battery thresholds; no single governor object. |
| 12 | Desktop production qualification | **MISSING** | Preview only; gates below unmet. |
| 13 | Android device qualification | **MISSING** | Live gated off; standalone APK not in CI; no actual-device evidence. |
| 14 | iOS device qualification | **MISSING** | Native Mind not wired (feature_mind omits iOS). |
| 15 | Web explicit gating | **EXISTS** | Live/native explicitly unsupported; now encoded in the matrix. |
| 16 | Golden evaluation framework | **PARTIAL** | `rust/airo_mind_eval` (WER/MoM gates) exists; no multi-language golden corpus. |
| 17 | Release gates in CI | **PARTIAL** | Rust conformance tests exist; no latency/WER/failure gates wired as blocking CI. |
| 18 | Live search | **MISSING** | Post-recording semantic search only. |
| 19 | Live insights UI | **MISSING** | `LiveInsightsRail` is a stub with placeholder copy. |
| 23 | Qualification matrix | **PARTIAL (this PR)** | Matrix + derivation implemented and tested; cells still Preview/Experimental/Unsupported. |
| 24 | Qualification states | **PARTIAL (this PR)** | States implemented and derived from runtime signals. |

## 3. Definition of Done — gate status

| # | Gate | Status |
| --- | --- | --- |
| 1 | Unified native audio fan-out | ❌ Not implemented |
| 2 | Recording survives live inference failure | ❌ Not proven end-to-end |
| 3 | Live STT measurable partial/stable/final latency | ❌ Not measured |
| 4 | Transcript stabilization passes golden tests | ❌ No golden corpus |
| 5 | Vocabulary correction context-aware + provenance-preserving | ❌ Provenance not surfaced |
| 6 | Speaker activity typed timeline | ❌ Not a typed wire abstraction |
| 7 | Post-stop diarization reconciles live assignments | ⚠️ Partial (overwrite, not typed reconcile) |
| 8 | Conversation IR incremental events | ❌ Post-recording only |
| 9 | Incremental extraction without continuous deep LLM | ❌ Not implemented |
| 10 | Model/resource admission | ⚠️ Partial (memory only) |
| 11 | Thermal/battery degradation | ⚠️ Partial (thermal only) |
| 12 | Desktop passes all production gates | ❌ |
| 13 | Android actual-device qualification | ❌ |
| 14 | iOS actual-device qualification | ❌ |
| 15 | Web explicitly gated | ✅ (encoded in matrix this PR) |
| 16 | Golden conversation benchmarks exist | ❌ |
| 17 | Latency/WER/speaker/memory/failure measured | ❌ |
| 18 | CI/release gates prevent regressions | ⚠️ Partial |
| 19 | Live UI shows only supported capabilities | ⚠️ Machinery landed (matrix); UI wiring pending |
| 20 | Qualification doc updated from evidence | ✅ (this document) |

## 4. Verdict

Multiple mandatory gates are unmet, and several (measured live latency, golden
WER/CER, actual-device Android/iOS qualification) require audio-capture
hardware, built native engines with downloaded model weights, and physical
devices that are **not available in the CI/cloud environment** used to produce
this document. Per spec §27, the gate is not lowered to obtain a pass.

> **NOT PRODUCTION QUALIFIED**

## 5. Path to promotion

Execute in the dependency order of spec §26. A capability may only have its
declared ceiling raised toward `PRODUCTION` in `MindQualificationMatrix.current()`
once the corresponding gates in this table are green with linked evidence in
`latency-benchmarks.md` and `evaluation-results.md`.
