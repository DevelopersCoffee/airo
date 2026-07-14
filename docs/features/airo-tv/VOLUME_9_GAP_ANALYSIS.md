# Airo TV Volume 9 Gap Analysis

**Volume:** Product Analytics, Playback Quality Telemetry, Privacy, and
Experimentation  
**Date:** 2026-07-13  
**Status:** Draft gap analysis  
**Input:** `/Users/udaychauhan/.codex/attachments/b5293f0d-a03c-49f9-960e-492d4747879c/pasted-text.txt`  
**Baseline inspected:** app logger, platform media logger, video player
analytics calls, pubspec dependencies, existing Airo TV plan, requirements
review, and feature packet.

## Executive Summary

Volume 9 defines Airo TV's analytics and telemetry architecture. The goal is
not broad behavioral tracking; it is privacy-safe measurement of onboarding,
playback quality, device reliability, handoff, legacy-device health, feature
adoption, subscription conversion, experimentation, and diagnostics.

The current repo has only placeholder-level analytics:

- `AppLogger.analytics()` writes debug log messages and has a TODO for a real
  analytics service.
- Crash reporting is a TODO in `AppLogger._reportToCrashlytics()`.
- `platform_media` has its own `AppLogger.analytics()` wrapper that prints
  event names and parameters.
- Some playback analytics calls include raw channel names, which conflicts with
  Volume 9's media privacy rules.
- No `firebase_analytics` or crash-reporting dependency is present.
- No shared `AnalyticsService`, typed event model, consent gate, schema
  registry, queue, sampling, provider adapter, local-only mode enforcement, or
  payload redaction test suite exists.

Volume 9 should therefore be added as a foundation contract and privacy gate
before product success metrics are treated as measurable.

## Requirement Intent

| Area | Intent |
| --- | --- |
| Vendor-neutral architecture | Feature modules submit typed events to a shared abstraction, never directly to Firebase or another SDK. |
| Privacy by default | Collect categories, buckets, and operational outcomes rather than raw titles, URLs, credentials, queries, local paths, or household identifiers. |
| Non-blocking playback | Analytics enqueue, upload, provider init, and failure must not delay playback, UI rendering, or app startup. |
| Consent and local-only mode | Product analytics, crash reporting, personalized analytics, cloud AI, diagnostics, and history sync need separate controls. |
| Playback quality telemetry | Measure startup, buffering, failure, failover, decoder, bitrate, resolution, and completion using buckets and categories. |
| Legacy telemetry | Measure constrained-device reliability with a reduced event set and bounded queues. |
| Schema governance | Every event has an owner, purpose, version, allowed fields, prohibited fields, retention, and tests. |
| Experimentation | Remote config and experiments need guardrails and must not override privacy, security, entitlement, or build composition. |

## Current Repo Fit

| Current asset | Fit | Gap |
| --- | --- | --- |
| `AppLogger.analytics()` | Provides a placeholder call site | Untyped arbitrary params, debug-only behavior, no consent, no redaction, no queue, no provider abstraction |
| `AppLogger._reportToCrashlytics()` | Notes intended crash-reporting integration | No crash adapter, no consent split, no redaction, no native-symbol or decoder grouping |
| `platform_media` logger | Captures player-related events during live/DVR actions | Logs raw channel names in analytics parameters; separate logger bypasses central policy |
| App dependencies | Firebase core/auth exist | No analytics/crash SDK and no vendor-neutral adapter layer |
| Existing feature packet | Already names analytics privacy filter and disabled mode use cases | No dedicated Volume 9 gap analysis or full backlog for schema registry, experimentation, retention, dashboards |
| Existing plan | Has a basic Analytics Foundation phase | Needs richer event governance, playback telemetry, reliability, experimentation, local diagnostics, and data-access scope |

## Major Gaps

### 1. Shared Analytics Service Is Missing

**Requirement:** Feature modules use a shared `AnalyticsService` with
initialize, consent, typed events, timed events, flush, reset, and collection
enablement.

**Current state:** Analytics calls are debug logs with arbitrary maps.

**Gap:** Define a vendor-neutral analytics package with typed events,
provider adapters, no-op provider, local diagnostics provider, and no direct
SDK usage in feature modules.

### 2. Typed Events and Schema Registry Are Missing

**Requirement:** Every event should have a stable snake_case name, schema
version, owner, purpose, allowed fields, prohibited fields, retention, dashboard
requirement, and tests.

**Current state:** No event schema registry or compile-time event model exists.

**Gap:** Add `AiroAnalyticsEvent`, event envelope, schema registry, development
rejection for unknown fields, production stripping for unknown fields, and
schema compatibility tests.

### 3. Current Playback Analytics Can Leak Media Data

**Requirement:** Do not collect exact channel names, movie titles, program
titles, raw search terms, playlist names, URLs, credentials, local paths, local
IP addresses, voice transcripts, or private playlist contents by default.

**Current state:** `video_player_streaming_service.dart` logs channel names in
live stream events.

**Gap:** Replace raw media labels with `contentType`, `sourceType`,
`category`, `decoderType`, `resolutionBucket`, `startupTimeBucket`,
`errorCategory`, and other approved bucketed values.

### 4. Consent Model Is Missing

**Requirement:** Separate required operational data, optional product analytics,
optional crash reporting, and optional personalized analytics.

**Current state:** No Airo TV analytics consent state or opt-out behavior exists.

**Gap:** Add consent settings, collection gates, immediate disable behavior,
queue deletion after opt-out, analytics ID reset, account-deletion integration,
and local-only mode behavior.

### 5. Event Buffer, Queue, Priority, and Scheduling Are Missing

**Requirement:** Analytics must buffer, batch, cap queues, retry with backoff,
drop low-priority events first, respect metered/battery/memory/playback states,
and never block shutdown or playback.

**Current state:** No queue exists.

**Gap:** Define bounded queues, priority classes, sampling rules, upload
scheduling, provider outage behavior, and Lite/Receiver reduced queue budgets.

### 6. Playback Quality Telemetry Is Not Modeled

**Requirement:** Measure time to first frame, join failure rate, rebuffer
ratio, failover recovery, decoder failure, restart count, bitrate bucket,
resolution bucket, subtitle/audio failure, completion, and end reason.

**Current state:** Player state and debug logs exist, but no typed playback
quality event model or derived KPI definitions exist in code.

**Gap:** Add playback request/start/fail/end events and derived KPI definitions
before claiming measurable playback reliability.

### 7. Pairing, Handoff, Device Ecosystem, and Delegation Metrics Are Missing

**Requirement:** Measure pairing, discovery, command route, handoff, local vs
cloud commands, delegated task success, companion availability, and session
recovery without media titles or URLs.

**Current state:** These systems are mostly planned; no telemetry contracts
exist.

**Gap:** Add event schemas now so future connected-device implementation emits
privacy-safe measurements.

### 8. Legacy and Embedded Telemetry Need Reduced Profiles

**Requirement:** Lite Receiver and Embedded Receiver should collect a reduced
set focused on startup, pairing, playback, decoder behavior, memory pressure,
command latency, critical crashes, activation, and updates.

**Current state:** No profile-specific telemetry policy exists.

**Gap:** Add per-product-profile analytics profiles and queue/memory budgets.

### 9. Crash Reporting and Diagnostics Redaction Are Missing

**Requirement:** Crash telemetry may include app version, platform, profile,
API bucket, device tier, active module, memory pressure, decoder family, stack
trace, and native symbols, but must redact URLs, headers, provider domains,
file paths, usernames, device names, search text, titles, local IPs, and
playlist names.

**Current state:** Crashlytics integration is a TODO; no crash redaction exists.

**Gap:** Add crash adapter, redaction pipeline, native playback diagnostic
schema, local diagnostics store, redacted support bundle export, and opt-out
behavior.

### 10. Experimentation and Remote Config Guardrails Are Missing

**Requirement:** Experiments need stable anonymous assignment, eligibility,
control group, dates, primary metric, guardrails, minimum sample, remote stop,
and restrictions. Remote config must not enable absent code, override consent,
weaken security, bypass entitlement, or activate untested legacy modules.

**Current state:** Only basic feature flags exist.

**Gap:** Add experiment assignment, remote config contract, guardrail metrics,
kill switch, sampling controls, and composition-aware feature eligibility.

### 11. Dashboards, Alerts, Retention, and Access Controls Are Missing

**Requirement:** Executive, playback reliability, legacy device, device
ecosystem, and subscription dashboards; alerts for regressions; technical
retention enforcement; least-privilege audited access.

**Current state:** No analytics backend or dashboard definitions exist.

**Gap:** Add dashboard metric specs, alert thresholds, retention categories,
data deletion workflow, role-based access model, and future self-hosted event
gateway requirements.

## Plan Additions Required

| Addition | Priority | Why |
| --- | --- | --- |
| Analytics service contract | P0 | Required before any feature module logs product analytics |
| Typed event and envelope model | P0 | Prevents arbitrary raw maps and supports schema governance |
| Privacy filter and prohibited-field tests | P0 | Blocks URLs, credentials, search text, titles, paths, headers, and local IPs |
| Consent and local-only enforcement | P0 | Required for privacy-first positioning |
| No-op/local diagnostics providers | P0 | Allows builds to run without external analytics |
| Bounded event queue and priorities | P0 | Ensures analytics never blocks playback or overloads legacy devices |
| Playback quality event model | P1 | Required for reliability KPIs and player decisions |
| Crash reporting adapter and redaction | P1 | Required before native playback crash telemetry |
| Schema registry and retention policy | P1 | Required for governance and deletion requests |
| Experimentation and remote config guardrails | P1 | Required before A/B tests or remote rollout controls |
| Dashboards and alerts | P2 | Needed once events are implemented and validated |
| Self-hosted event gateway | P2 | Future vendor-independence option |

## Acceptance Coverage Gaps

The first test layer should prove:

- No feature module calls Firebase or another vendor SDK directly.
- Analytics disabled mode preserves normal playback.
- Local-only mode disables external analytics and crash upload unless the user
  explicitly exports diagnostics.
- Optional queued events are deleted immediately when consent is withdrawn.
- Payload validation rejects URLs, credentials, auth headers, local IPs, local
  paths, raw queries, media titles, channel names, and playlist names.
- Playback startup never waits for analytics initialization.
- Event enqueue is bounded and non-blocking.
- Provider failure falls back to no-op behavior.
- Lite and Embedded profiles use reduced event sets.
- Remote config cannot enable absent build-time modules.
- Experiment assignment cannot override consent, security, or entitlement.

## Product Packaging Impact

Volume 9 should be implemented as a shared platform capability, with different
collection profiles by product edition:

- **Full TV / mobile / desktop:** product analytics, playback quality, feature
  adoption, subscription, reliability telemetry, subject to consent.
- **Lite Receiver:** startup, pairing, playback quality, decoder behavior,
  memory pressure, command reliability, and critical crashes only.
- **Embedded Receiver:** activation, playback success, error categories,
  command latency, device health, software version, and update success only.
- **Local-only mode:** no external analytics; local diagnostics only, exportable
  by user action.

## Open Questions

- Which provider is first: no-op only, Firebase adapter, self-hosted gateway, or
  local diagnostics?
- Where should the schema registry live: repo YAML, Dart declarations, backend,
  or generated artifacts?
- What consent defaults apply by platform, region, profile, and child profile?
- Which events are required for v2.0.0.1 readiness versus later dashboards?
- What retention periods are approved for product events, crash data,
  performance aggregates, and security events?
- Who owns data access approval and deletion workflows?
- What exact redaction patterns must be enforced for media URLs, provider
  domains, local IPs, file paths, titles, and voice/query text?
- Which experiments are explicitly disallowed for subscription and security?

## Recommendation

Add Volume 9 as the analytics governance layer for v2.0.0.1. The first
implementation should be a typed, no-op-capable analytics contract with consent
gates and privacy tests, not a Firebase integration. Provider adapters,
dashboards, experimentation, and self-hosted ingestion should come after the
event model proves it cannot leak private media data or affect playback.
