# Implementation Plan: Phase 1 — Instrumentation

Spec: `SPEC.md` (this branch). Requirements: F7 (Telemetry & Connection
Health), delivery Phase 1 of 6. Principle from spec: **nothing is optimised
before it is measured** — Phases 2–6 are blocked on this landing.

## Overview

Add streaming QoE instrumentation to the existing playback path: a
per-session metrics model, a collector hooked into the playback engine, a
network-key deriver (hashed BSSID / carrier), and batched upload through the
existing `core_analytics` gateway under existing consent gating. Output is a
baseline: rebuffer ratio, TTFF, throughput percentiles per session, keyed by
network — the numbers every later phase is judged against.

## What already exists (build on, don't duplicate)

| Asset | Where | Use |
|---|---|---|
| Analytics schema, consent, gateway policy, rate limits, `playbackQuality` purpose, no-op + validation | `packages/core_analytics` | The pipeline. No new analytics framework. |
| `AppLogger.analytics()` bridge (validates, consent-gates, forwards to `AiroAnalyticsService`) | `packages/platform_media/lib/src/platform_media_logger.dart` | Emission path for collector events |
| Playback engine + session lifecycle w/ credential redaction (CV-001) | `packages/platform_player` (`airo_playback_engine.dart`, `playback_session_tracker.dart`) | Hook points for TTFF/stall/switch events |
| Basic failover models (stall/error trigger, switch decision codes) | `packages/platform_player/lib/src/models/multi_source_failover_models.dart` | Source-switch events already have stable ids — reuse `AiroFailoverDecisionCode` etc. in metrics |

## Architecture Decisions

- **AD-P1.1 — Metrics models live in `core_analytics`, collection lives in
  `platform_player`.** `core_analytics` has `allowed_dependencies: []` and
  CSO ownership — pure models + BSSID-hash helper fit; anything touching the
  engine does not. Collector in `platform_player` consumes the models.
- **AD-P1.2 — Network key derivation is an interface in `core_analytics`,
  implementation at the existing connectivity seam (implementer locates it,
  see Task 2).** Format per F4.3.3: `wifi:<bssid-hash>` /
  `cell:<carrier>:<radio-tech>`. Raw BSSID never stored or transmitted
  (F7.6) — hash at derivation, single code path.
- **AD-P1.3 — No new backend this phase.** `core_analytics` already models
  self-hosted gateways. Phase 1 ships: (a) local diagnostics sink always,
  (b) gateway upload when configured + consented. Standing up the actual
  ingestion endpoint + dashboard is a backend/infra work item outside this
  repo — tracked as Open Question P1-1, not a blocker for the client side.
- **AD-P1.4 — Session metrics are aggregates, not event streams.** One
  `streaming_session_summary` event per session end (plus one
  `streaming_session_started` for funnel counting) keeps volume inside
  existing rate-limit policy. Per-stall sub-events deferred until a phase
  needs them.
- **AD-P1.5 — Free tier included.** Instrumentation is not pro-gated; it
  measures the baseline both tiers are compared against. Only the
  user-facing health *panel* (F7.2, Phase 5) is premium.

## Task List

### Stage A: Models (foundation)
- [ ] Task 1: Streaming QoE metrics models in `core_analytics`
- [ ] Task 2: Network key derivation (interface + hashing in
      `core_analytics`, platform impl at the connectivity seam)

### Checkpoint A
- [ ] `cd packages/core_analytics && flutter test` green; analyzer clean

### Stage B: Collection (vertical slice — a session produces a summary)
- [ ] Task 3: `StreamingSessionMetricsCollector` in `platform_player`
- [ ] Task 4: Wire collector into playback engine lifecycle + emit via
      `AppLogger.analytics()`

### Checkpoint B
- [ ] Play/stop a stream in dev build → one valid
      `streaming_session_summary` in local diagnostics output, credentials
      absent, network key hashed
- [ ] `cd packages/platform_player && flutter test` green

### Stage C: Transport & verification
- [ ] Task 5: Batched upload wiring through existing gateway policy
      (consent-gated, separate connection per F7.3)
- [ ] Task 6: Credential/PII leak scan test (AC-9 seed)

### Checkpoint C (phase gate)
- [ ] Narrow per-package tests green (CI-spend rule); `cd app &&
      flutter build web --release` passes
- [ ] Human review; PR per package-cluster; then Phase 2 planning may start

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| `core_analytics` is a 4.8k-line single file; adding models bloats it | Med | New file `streaming_metrics_models.dart` in same package, exported from barrel — no edits inside the giant file beyond export |
| Engine hook points for TTFF/stall don't exist yet (real engine is Phase 2 Kotlin) | Med | Phase 1 instruments the *current* playback path (existing `AiroPlaybackEngine` events). Collector consumes an interface, so Phase 2's Kotlin engine feeds the same collector via EventChannel. |
| BSSID access needs location permission on Android | Med | If permission absent, network key degrades to `wifi:unknown` — never prompt for location just for telemetry |
| Consent default wrong way | High | Follow existing `core_analytics` consent model exactly — collection off until consent (F7.5). CSO reviews (module owner). |

## Model & Agent Routing (per SPEC.md)

Plan author: architect (this doc). Tasks 1–6: implement tier (Sonnet);
export/barrel edits mechanical tier (Haiku). Reviewer floor:
chief-qa-officer, chief-security-officer (consent + redaction; CSO owns
`core_analytics`), chief-cloud-officer if gateway config touches backend
assumptions. Codex adversarial review auto-runs on every edit.

## Open Questions

- **P1-1:** Where does the ingestion backend + baseline dashboard live?
  (Self-hosted per `AiroAnalyticsGatewayRegion` model? Owner:
  chief-cloud-officer.) Client ships gateway-ready regardless.
- **P1-2:** Does an existing settings surface expose analytics consent
  today, or does Phase 1 need a toggle UI? Implementer answers in Task 5;
  if UI is needed it becomes Task 7 (flutter-architect review).
