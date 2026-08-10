# Phase 1 — Instrumentation: Task List

Plan: `tasks/tv-zero-copy-cast-phase1-plan.md` · Spec: `docs/specs/tv-zero-copy-cast.md`
Executor tier per task noted; escalation one-way per SPEC routing rules.

## Task 1: Streaming QoE metrics models in core_analytics — DONE (b33f1ec6)

**Tier:** implement (Sonnet)

**Description:** Pure Equatable models for per-session streaming quality,
mirroring existing `core_analytics` style (stableId enums, validate()
methods). Covers F7.1's metric set as an aggregate summary.

**Acceptance criteria:**
- [ ] `AiroStreamingSessionSummary`: sessionId, ttffMs, rebufferCount,
      rebufferDurationRatio, sourceSwitchCount, throughputKbpsP50,
      throughputKbpsP10, activeSourceId (redacted handle, never URL),
      networkKey, schemaVersion — all fields on stable string keys suitable
      for `AiroAnalyticsEvent.params`
- [ ] `toAnalyticsEvent()` produces an event with
      `purpose: playbackQuality` that passes existing `validateEvent()`
- [ ] Validation rejects: negative counts, ratio outside [0,1], raw URLs or
      `:` -delimited credential shapes in activeSourceId

**Verification:**
- [ ] `cd packages/core_analytics && flutter test` green
- [ ] `flutter analyze` clean

**Dependencies:** None

**Files likely touched:**
- `packages/core_analytics/lib/src/streaming_metrics_models.dart` (new)
- `packages/core_analytics/lib/core_analytics.dart` (export — mechanical)
- `packages/core_analytics/test/streaming_metrics_models_test.dart` (new)

**Estimated scope:** S

---

## Task 2: Network key derivation — DONE (8cb9e7a0)

**Tier:** implement (Sonnet)

**Description:** `NetworkKey` value type + derivation with mandatory BSSID
hashing (F7.6, F4.3.3). Interface + hashing logic in `core_analytics`
(pure, no platform deps); concrete provider at the repo's existing
connectivity seam — implementer greps for existing
connectivity/wifi usage first and extends rather than adds a plugin.

**Acceptance criteria:**
- [ ] Formats exactly `wifi:<bssid-hash>`, `cell:<carrier>:<radio-tech>`,
      `ethernet`, `wifi:unknown` (permission-degraded), `offline`
- [ ] Hash is salted-per-install SHA-256 truncated (raw BSSID unrecoverable,
      stable across sessions on same install); raw BSSID never appears in
      any persisted or emitted value — test asserts
- [ ] No location-permission prompt introduced; absent permission degrades
      to `wifi:unknown`

**Verification:**
- [ ] Unit tests: format table, hash stability, degradation paths
- [ ] `flutter analyze` clean in touched packages

**Dependencies:** None (parallel-safe with Task 1)

**Files likely touched:**
- `packages/core_analytics/lib/src/network_key.dart` (new)
- `packages/core_analytics/test/network_key_test.dart` (new)
- provider impl file at connectivity seam (located during task)

**Estimated scope:** S

---

## Task 3: StreamingSessionMetricsCollector — DONE (ed59cb44)

**Tier:** implement (Sonnet)

**Description:** Pure accumulator in `platform_player`: consumes engine
lifecycle signals (start, firstFrame, stallStart/stallEnd, throughputSample,
sourceSwitch, stop) and produces `AiroStreamingSessionSummary`. No I/O, no
timers of its own — caller feeds it timestamped events, so it is fully unit
testable and Phase 2's Kotlin engine can feed the same interface later.

**Acceptance criteria:**
- [ ] Correct TTFF, rebuffer count + duration ratio, switch count from a
      scripted event sequence
- [ ] Throughput p50/p10 from streamed samples without unbounded memory
      (fixed-size reservoir or windowed percentile)
- [ ] Double-stop, stop-before-first-frame, zero-sample sessions produce
      valid (not crashing, not NaN) summaries

**Verification:**
- [ ] `cd packages/platform_player && flutter test` green
- [ ] Coverage on collector file > 70% (NFR-13 floor)

**Dependencies:** Task 1

**Files likely touched:**
- `packages/platform_player/lib/src/services/streaming_session_metrics_collector.dart` (new)
- `packages/platform_player/test/streaming_session_metrics_collector_test.dart` (new)

**Estimated scope:** S

---

## Task 4: Engine wiring + emission — DONE (08f09014)

**Tier:** implement (Sonnet)

**Description:** Connect collector to the existing `AiroPlaybackEngine`
lifecycle (reusing `playback_session_tracker` session ids and its redaction
helper) and emit `streaming_session_started` / `streaming_session_summary`
through `AppLogger.analytics()` on session boundaries.

**Acceptance criteria:**
- [ ] One summary per session, emitted on stop/dispose/channel-switch
      (switch = old session closes, new opens)
- [ ] activeSourceId uses the CV-001 redaction path — no credentials, no
      full URLs (grep-able test)
- [ ] Engine hot path unaffected: no synchronous work on frame/stall
      callbacks beyond field updates

**Verification:**
- [ ] `cd packages/platform_player && flutter test` green
- [ ] Manual dev-build check (Checkpoint B): play/stop → summary visible in
      local diagnostics output

**Dependencies:** Tasks 1, 2, 3

**Files likely touched:**
- `packages/platform_player/lib/src/services/airo_playback_engine.dart`
- `packages/platform_player/lib/src/services/streaming_session_metrics_collector.dart`
- test file(s)

**Estimated scope:** M

---

## Task 5: Batched upload wiring — DONE (f6f1cd22, contract tests, no app-bootstrap wiring — see note below)

**Tier:** implement (Sonnet)

**Description:** Route summaries through the existing
`core_analytics` gateway/service configuration: batching, consent gate
(collection off until consent — F7.5), local-diagnostics sink always on,
upload on separate connection from media (F7.3). Answer P1-2 (existing
consent UI?) and report back before adding any UI.

**Acceptance criteria:**
- [ ] With consent disabled: zero network emission, local sink still
      records (existing `localOnly` semantics)
- [ ] With consent enabled + gateway configured: batch upload path invoked;
      never shares a connection/client with playback fetches
- [ ] Existing rate-limit policy applies to the new events

**Verification:**
- [ ] Unit/integration tests at service-config level
- [ ] `cd app && flutter build web --release` passes (web-path gotcha)

**Dependencies:** Task 4

**Files likely touched:** located during task (service wiring in app/ or
platform_media); ≤5 files or split the task

**Estimated scope:** M

---

## Task 6: Credential/PII leak scan test (AC-9 seed) — DONE (678ca6a7)

**Tier:** implement (Sonnet)

**Description:** Automated test that feeds hostile inputs (Xtream-style
`user/pass` URLs, BSSIDs, tokens in query strings) through the full
collect→summarise→event path and asserts none survive into emitted params.
This becomes the seed of the AC-9 automated scan required at feature
acceptance.

**Acceptance criteria:**
- [ ] Test corpus covers: credentials in path, in query, in userinfo;
      raw BSSID; provider hostnames allowed (host is not a secret)
- [ ] Fails the build if any corpus item appears verbatim in event params

**Verification:**
- [ ] Test green; deliberately breaking redaction makes it red

**Dependencies:** Task 4

**Files likely touched:**
- `packages/platform_player/test/telemetry_leak_scan_test.dart` (new)

**Estimated scope:** S

---

## Task 7: Settings UI + bootstrap wiring — DONE (5b809cf5)

**Tier:** implement (Sonnet)

**Description:** Resolves P1-2 (below) — a product decision, now made:
opt-in consent default, `AiroLocalDiagnosticsAnalyticsService` ships
first (no backend). Wires `AppLogger.setAnalyticsService()` at TV
bootstrap and adds a Privacy settings toggle for `playbackQuality`
consent.

**Acceptance criteria:**
- [x] `AiroLocalDiagnosticsAnalyticsService` constructed with the
      persisted consent at `main_tv.dart` startup, wired via
      `AppLogger.setAnalyticsService()`
- [x] New `streamingTelemetryConsentProvider` (Riverpod) persists the
      toggle via `SharedPreferences` and calls `.updateConsent()` on
      the live service instance
- [x] Granted consent state built explicitly, NOT from
      `AiroAnalyticsConsentState.localOnly()` (that preset silently
      blackholes `playbackQuality` regardless of the field itself —
      proven wrong end to end by a new test, not just asserted)
- [x] New TV Privacy settings section (`TvPrivacySection`), TV-only
      scope this pass — flagged, not silently deferred

**Verification:**
- [x] `flutter analyze` clean across `app/`
- [x] New provider test suite 7/7 green, including end-to-end
      `validateEvent()` proof
- [x] `packages/feature_iptv` full suite 865/865 green
- [x] `flutter build web --release` passes
- [x] `scripts/check-variant-pubspecs.sh` passes

**Dependencies:** Task 5

**Files touched:**
- `app/lib/core/providers/streaming_telemetry_consent_provider.dart` (new)
- `app/lib/features/settings/presentation/tv/tv_privacy_section.dart` (new)
- `app/lib/features/settings/presentation/tv/tv_settings_screen.dart`
- `app/lib/main_tv.dart`
- `app/pubspec.yaml`, `app/pubspec_tv.yaml`
- `packages/feature_iptv_core/lib/src/iptv_settings_manifest.dart`
- `packages/feature_iptv/test/iptv/domain/iptv_settings_manifest_test.dart`
- `app/test/core/providers/streaming_telemetry_consent_provider_test.dart` (new)

**Estimated scope:** M

---

## Checkpoints

### Checkpoint A (after Tasks 1–2) — DONE
- [x] `core_analytics` tests + analyzer green (97/97, 0 issues)

### Checkpoint B (after Tasks 3–4) — DONE
- [x] Dev-build manual check: session summary appears, redacted, hashed key
      (verified via test-harness output, not a manual UI run — see Task 4 commit)
- [x] `platform_player` tests green (235/235), `platform_media` 165/165

### Checkpoint C — phase gate (after Tasks 5–6) — DONE (client-side scope)
- [x] Narrow test runs green: core_analytics 105/105, platform_player 235/235,
      platform_media 170/170; analyzer clean on every touched file
- [x] Web release build passes (`flutter build web --release`, verified
      after Task 4's engine wiring; Tasks 5-6 were test-only, no lib/ change)
- [x] Leak-scan test verified non-vacuous by mutation: temporarily fed a raw
      URL into activeSourceId, confirmed the test goes RED, reverted cleanly
- [x] P1-2 resolved (Task 7, commit `5b809cf5`) — opt-in consent
      default, local-diagnostics tier first, bootstrap + settings UI
      shipped
- [ ] Human review + PRs (cluster: core_analytics PR, platform_player PR,
      platform_media PR, app PR for Task 7) — not yet opened, pending
      user direction
- [ ] CSO + QA council review recorded — not yet requested
- [x] Phase 2 planning unblocked (baseline instrumentation ships; app-wide
      consent/backend wiring explicitly deferred, see note below)

**Note on scope actually delivered vs. planned:** Task 5's acceptance
criteria as written assumed a live app-bootstrap wiring decision
(which `AiroAnalyticsService` to install, what default consent posture).
Investigation found `core_analytics` already ships three complete,
tested implementations (`AiroNoOpAnalyticsService` — today's actual
wired default everywhere, since `AppLogger.setAnalyticsService()` is
never called in `app/lib` — `AiroLocalDiagnosticsAnalyticsService`,
`AiroProviderBackedAnalyticsService` with a playback-aware upload gate)
plus a bounded queue and consent-transition policy. No new
batching/gateway code was needed or written (matches AD-P1.3). What
*was* missing, and is out of scope for a code task: neither built-in
consent preset grants `playbackQuality`, so streaming telemetry records
nothing today even locally, and there's no settings surface to grant it.
Task 5 shipped as contract tests proving the existing pipeline correctly
carries our event once a grant exists; wiring a real default into
`app/lib/main.dart` is deferred to Open Question P1-2 (product decision:
default consent posture + settings UI), not silently defaulted here.
