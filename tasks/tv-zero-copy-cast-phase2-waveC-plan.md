# Implementation Plan: Phase 2 Wave C — Source Ranking + Shadow Failover

Spec: `SPEC.md`. Requirements: F4.3 (source scoring), F4.4 (mid-stream
failover). Follows Wave B (code-complete, device verification tracked in
[#1574](https://github.com/DevelopersCoffee/airo/issues/1574)).

**This is the first pro-gated wave.** Per SPEC.md's package table and F8:
"Multi-source shadow failover" (F8.4) and "per-network learned CDN
ranking" (F8.5) are premium-only. `ProFeature.multiSourceFailover`
already exists in `core_entitlements`, defined but unused — this wave is
its first real consumer.

## Investigation findings — this reshapes the plan significantly

- **No pro package has ever shipped native (Kotlin/Android) code.**
  Checked all 5 existing `packages_pro/*` packages in the `airo-pro`
  overlay — every one is pure Dart (`pro_source_diagnostics` uses `dio`
  for HTTP, nothing native). There is no precedent for the overlay
  mechanism injecting native Android source into the shared `app/android`
  build the way Wave A/B did for the public engine.
- **The `airo-pro` worktree hasn't seen any of this branch's work.**
  `airo-pro-worktrees/tv-zero-copy-cast` syncs from the public GitHub
  repo via `scripts/sync_upstream.sh`, not from this local uncommitted
  branch — it currently has no `src/tv/` directory at all. Nothing here
  can be implemented *in* that worktree until this branch is pushed and
  synced, or until we accept that Wave C's Dart-only pro code doesn't
  actually need the native TV work to be *present* in that worktree, only
  to *exist upstream* by the time pro code depends on `platform_streaming_engine`.
- **A genuine precedent for standalone native Flutter plugins does
  exist** in the public repo — `packages/feature_mind/android/` and
  `packages/platform_downloads/android/` are self-contained Gradle
  modules Flutter auto-includes via its plugin registration, with zero
  changes to `app/android/app`'s own source tree. This is the technically
  correct pattern *if* Wave C needed new native code in pro — but
  investigation below concludes it doesn't need to, for a cleaner reason.

## Proposed architecture — mechanism stays public, decision logic is pro

**AD-P2C.1 (proposed, not yet confirmed — see below):** Rather than
duplicating native networking/splice logic into a new pro-side native
module (which would need its own `OkHttpClient`, unable to share Wave B's
connection pool state across independent Gradle plugin projects), the
receiver's *mechanism* — shadow-fetch a candidate source, measure its
throughput without disturbing playback, splice to it on a keyframe — is
exposed as new method-channel commands on the **existing public**
`AiroStreamingEnginePlugin`/`AiroStreamingEngine` (already own the
`OkHttpClient`, the `ExoPlayer`, the `DataSource`). The **decision** of
*when* to shadow-fetch, *which* source to try, and the scoring/ranking
math (F4.3) is pure Dart in `packages_pro/pro_streaming_engine`, gated by
`Entitlements.isEnabled(ProFeature.multiSourceFailover)` at the call
site — the same pattern `pro_source_diagnostics` already uses via
`ProModuleRegistry`. Free tier's engine simply never has anything call
these commands.

This mirrors AD-2 from SPEC.md (sender is a controller, not a media
socket owner) at a smaller scale: the pro package *controls*, the public
engine *executes*. It avoids inventing new native-in-pro infrastructure
this wave, keeps the connection pool as one shared instance (no split
state), and matches how every existing pro feature already gates purely
in Dart.

**This is a meaningful open-core boundary decision — flagging for
explicit confirmation before Task 1, same weight as a new-dependency
proposal, per SPEC.md's own routing rule ("open-core boundary" review
listed under chief-architect for Phase 5, applies here a wave early
since it's being decided now).**

## Task List (draft — task-broken pending AD-P2C.1 confirmation)

### Task 0: Confirm AD-P2C.1 with the user
No code. If rejected, this plan needs a different Task 1 (native-in-pro
module using the `feature_mind`/`platform_downloads` precedent instead).

### Task 1 (public repo): Shadow-fetch + splice mechanism on AiroStreamingEnginePlugin — DONE (9c37d0f0)
`AiroShadowFetch.probe` + `AiroShadowFetchLimiter` fully implemented and
JVM-tested (real local-server tests). `switchSource` shipped as a v1
"basic swap" — explicitly NOT the frame-accurate splice-on-keyframe this
task originally specified; see the new todo file's "Task 1-follow-up"
entry for the real splice work, scoped separately given its size.
**Description:** New method-channel commands: `shadowFetch(sourceUrl) ->
{throughputKbps}` (opens a second connection via the shared
`OkHttpClient`, measures sustained throughput over the first 512KB per
F4.3.2, closes without touching playback) and `switchSource(sourceUrl)`
(splices the active `ExoPlayer` to the new source — PAT/PMT + IDR
boundary for TS per F4.4.5, next-segment boundary for HLS). Max 2
concurrent connections total (F4.4.8) enforced here, not trusted to the
caller.
**Acceptance criteria:**
- [ ] `shadowFetch` never blocks or interrupts current playback
- [ ] `switchSource` only completes at a valid splice point, never mid-frame
- [ ] Concurrent-connection cap enforced server-side (Kotlin), not just documented
**Verification:** JVM tests for the connection-cap/measurement logic
(fakeable); device verification for actual splice-without-artifact
behavior (extends the existing device issue).
**Dependencies:** Wave B (confirmed on this branch).
**Estimated scope:** L — likely needs breaking into 2-3 sub-tasks once
started (probe/measure, splice-detection, cap enforcement are each
non-trivial).

### Task 2 (pro repo): Source scorer (F4.3)
**Description:** `packages_pro/pro_streaming_engine` — pure Dart,
`AiroSourceScore` (connect time, TTFB, sustained throughput, historical
stall rate → cost function per the requirements doc's own formula),
persisted per `AiroNetworkKey` (reuses Phase 1's `core_analytics`
`AiroNetworkKey` — already built, already hashes BSSID) with a 7-day
half-life decay (F4.3.4) and a 120s just-penalized exclusion (F4.3.5).
**Acceptance criteria:** matches F4.3.1–F4.3.5 exactly; fully unit-testable
in plain `flutter test`, no native dependency at all.
**Dependencies:** None (parallel-safe with Task 1).

### Task 3 (pro repo): Failover decision state machine (F4.4) + `ProModule` wiring
**Description:** Ring-buffer-fill-rate-driven degraded-state detection
(F4.4.2: <85% of required bitrate for 2s), 1.3× hysteresis before
switching (F4.4.4), 20s cooldown (F4.4.7) — calls Task 1's `shadowFetch`/
`switchSource` public commands, never touches native code directly.
Registers as a `ProModule` (id, `ProFeature.multiSourceFailover`) in
`packages/airo_pro_bootstrap`'s `registerProModules`, same pattern as
`ImportIntelligenceModule`/`SourceDiagnosticsModule`.
**Dependencies:** Task 1, Task 2.

### Checkpoint: Wave C complete
- [ ] Public Task 1 device-verified (extends existing issue)
- [ ] Pro Tasks 2-3 fully unit-tested (no native dependency, should be
      100% CI-provable unlike every prior wave)
- [ ] Free tier confirmed to never invoke shadow-fetch/switch (instrumentation
      check per AC-8's spirit)
- [ ] chief-architect + chief-security-officer review (open-core boundary
      + F8.12 "receiver validates entitlement independently" — worth
      revisiting whether Dart-only gating is sufficient or the receiver
      needs its own check too, flagged as Open Question below)

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Dart-only entitlement gating means a modified/pirated pro Dart binary could call the public mechanism commands without a real entitlement | Med | F8.12 says "receiver validates entitlement independently — sender assertions are not trusted." Current proposal doesn't yet satisfy this for local (non-cast) playback since there's no cross-process sender/receiver boundary on a single device the way cast has. Flagged as Open Question P2C-1, not resolved by this plan — needs chief-security-officer input on whether it matters for this specific (single-process) case vs. the cast protocol's actual sender/receiver split. |
| Task 1's splice-without-artifact requirement is genuinely hard (spec's own risk table calls this the top risk for the whole feature) | High | Fall back to spec's own mitigation: 200ms mute-and-cut if a clean splice point isn't found within 3s, rather than risking a garbled frame |
| Shadow fetch competing with playback bandwidth on constrained connections | Med | F4.4.8's 2-connection cap + spec's existing guidance to abandon the shadow if aggregate throughput drops — Task 1 must implement the abort path, not just the happy path |

## Open Questions

- **P2C-1:** Does single-device (non-cast) shadow-fetch/switch need
  receiver-side entitlement re-validation, or is Dart-level gating
  (matching every other pro feature) sufficient here specifically because
  there's no separate sender process to distrust? Needs a security
  decision before Task 1 ships, not before this plan is written.
- **P2C-2:** This branch (`agent/claude/tv-zero-copy-cast-spec`) hasn't
  been pushed/PR'd. Wave C's pro-side tasks depend on
  `platform_streaming_engine` existing in the airo-pro overlay's view of
  upstream — does that mean Wave C pro work waits for this branch to
  merge to `main` and sync into `airo-pro`, or can it proceed against a
  local path override in the interim? Process question, not a code one.
