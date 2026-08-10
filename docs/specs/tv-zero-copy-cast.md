# Spec: Airo TV — Zero-Copy Cast & Adaptive Buffering Control

Status: draft for review · Requirements source: product v0.1 draft (6 phases)
Repos: `airo` (this worktree, public) + `airo-pro` (private overlay, see
`airo-pro-worktrees/tv-zero-copy-cast/SPEC.md`) · Branch (both repos):
`agent/claude/tv-zero-copy-cast-spec`

## Objective

Airo TV users buffer because community IPTV sources have no SLA and raw
MPEG-TS has no ABR ladder — the only remedy when a source degrades is
switching sources. Users who find content on their phone also have no way to
move it to the TV without routing media bytes through the phone (mirroring /
DLNA), which doubles LAN load and drains battery.

Build:
1. A **receiver streaming engine** (Android TV / Fire TV) with DNS caching,
   connection pre-warming, per-network source scoring, and mid-stream shadow
   failover — this is the actual buffering fix.
2. A **zero-copy cast protocol** (mDNS + WebSocket, no Google Cast) so a
   phone can hand a channel to the TV as a control-plane message; the TV
   fetches media directly from the provider, the phone never opens a media
   socket.
3. **Adaptive buffer profiles** keyed on network/device class, with a 0.97×
   speed-nudge instead of rebuffering on transient dips.

Success = the 9 acceptance criteria in §7 of the requirements doc, restated
as this spec's Success Criteria below.

**Users:** Airo TV viewers on Android TV, Google TV, Fire TV (receivers) and
Airo TV / Airo Coins-style companion use on Android/iOS phone (senders).

## Business model — this is a Pro feature, unpriced at launch

Per `airo-pro/PRO.md`: pro features ship **free during launch** via
`LaunchPromoEntitlements`; charging later is a single `createEntitlements()`
swap with zero call-site changes. This feature follows the same rule —
segregated into `packages_pro/` from day one, gated behind existing
`ProFeature.multiSourceFailover` (already defined, currently unused — see
`packages/core_entitlements/lib/src/entitlements.dart:26`) plus two new
`ProFeature` entries (below), but not charged for yet.

New `ProFeature` enum entries needed in `packages/core_entitlements` (public
repo — the enum and `Entitlements` interface are public; only *implementations*
of gated behavior are pro):
```dart
adaptiveBufferControl('adaptive_buffer_control'),   // F6: profiles + speed nudge
zeroCopyCast('zero_copy_cast'),                     // F1-F3, F9: cast + control
```
`multiSourceFailover` already covers F4.3/F4.4 (ranking + shadow failover).
Free tier keeps: single-source playback, fixed conservative buffer profile,
cast to 1 device (F8.6 "Limited" tier is a free-tier *count* cap, not a
separate ProFeature — see Open Questions).

### Open-core split (binding — see AD-1..AD-5 in requirements doc)

| Piece | Where | Why |
|---|---|---|
| `ProFeature` enum entries, `Entitlements` interface | `airo/packages/core_entitlements` (public) | Contract must be public so free build compiles and gates correctly |
| Fixed conservative buffer profile, single-source playback, cast to 1 device | `airo` public packages (`platform_player`, `platform_streams`, new `platform_cast_protocol`) | Free-tier baseline must be good, not deliberately broken (Risk table, requirements doc §9) |
| Adaptive buffer profiles, speed-nudge, per-network source ranking, shadow failover, favourite pre-warming, health panel, diagnostic export, unlimited cast devices | `airo-pro/packages_pro/pro_streaming_engine` (new) | F8 premium column |
| mDNS discovery, pairing, control-channel protocol (`LOAD`/`STATE`/`PLAY`/...) | `airo` public (`platform_cast_protocol`) | Core UX — casting itself isn't the moat, reliability is; also lets free tier hit AC-1/AC-2 |
| Receiver Kotlin engine (`DataSource`, ring buffer, `MediaCodec` pipeline) | `airo` public (`platform_player` native) | Zero-copy decode benefits all tiers; scoring/failover *logic* on top is pro |

This mirrors the existing `pro_source_diagnostics` pattern: connection
testing lives in `packages_pro/`, the `SourceConnectionTester` *interface*
and free stub live public, overlay wires the real implementation through
`airo_pro_bootstrap`.

## Tech Stack

- Dart/Flutter (Melos workspace), Riverpod for state/DI
- Android receiver: Kotlin, AndroidX Media3 (ExoPlayer), custom
  `androidx.media3.datasource.DataSource`, `MediaCodec` → `SurfaceView`
- iOS sender: Dart control logic only (no receiver role this release)
- Control channel: WebSocket over TLS (self-signed, pinned post-pairing),
  JSON messages; mDNS via `NsdManager` (Android) / `NetService` (iOS)
- Flutter↔Kotlin bridge: `MethodChannel` (commands) + `EventChannel` (STATE
  stream) + `PlatformView` (video surface) — per AD-5, no `video_player`
- Entitlements: `core_entitlements` (`ProModule`/`ProFeature`, existing)

## Commands

```
Analyze (public):   cd app && flutter analyze
Analyze (pro):       cd airo-pro/app && flutter analyze
Test (package):      cd packages/<pkg> && flutter test
Test (workspace):    melos run test
Web build gate:       cd app && flutter build web --release
Android build:        cd app && flutter build apk --flavor tv
R05 isolation check:  <existing R05 CI job — must stay green, see PR #1561>
Format:                dart format --set-exit-if-changed .
Pro allowlist gate:    airo-pro/.github/workflows/pro-hygiene.yml (CI-only)
```

## Project Structure

```
airo/packages/
  core_entitlements/            existing — add 2 ProFeature entries
  platform_cast_protocol/       NEW public — mDNS, pairing, control channel,
                                  LOAD/STATE message types, sender now-playing
                                  provider, receiver session controller
  platform_player/              existing — extend: custom DataSource seam,
                                  resolver cache, connection pool, ring
                                  buffer, MediaCodec→Surface pipeline,
                                  fixed conservative buffer profile
  platform_streams/             existing — extend: buffer profile selection
                                  interface (free returns fixed profile)
  core_media_routing/           existing — likely handoff/session ownership
  feature_iptv/                 existing — "Play on TV" entry point (US-1)

airo-pro/packages_pro/
  pro_streaming_engine/         NEW — source scorer, shadow failover,
                                  adaptive buffer profiles, speed-nudge,
                                  favourite pre-warming, health panel data,
                                  diagnostic bundle export
  pro_billing/                  existing — future entitlement swap point,
                                  no change needed yet (LaunchPromoEntitlements)

Android native (Kotlin), inside platform_player's android/ dir:
  .../datasource/AiroDataSource.kt
  .../resolver/ResolverCache.kt
  .../pool/ConnectionPool.kt
  .../buffer/RingBuffer.kt
  .../decode/PlaybackEngine.kt        MediaCodec + SurfaceView wiring
  .../cast/CastReceiverService.kt     mDNS advertise, session controller
```

Each new package gets a `module.yaml` (public repo only — `packages_pro/`
has none, confirmed against existing pro packages):
```yaml
name: platform_cast_protocol
owner: Playback Architect
reviewers:
  - Chief Architect
  - Chief Performance Officer
  - Chief Security Officer
  - Tv Experience Architect
allowed_dependencies:
  - core_entitlements
  - platform_player
  - core_media_routing
forbidden_dependencies:
  - app
quality_gates: {}
```

## Code Style

Match existing package conventions — abstract interface class + Riverpod
provider seam, one concrete free implementation public, pro implementation
registered via `ProModuleRegistry` in `airo_pro_bootstrap`. Example shape
(mirrors `pro_source_diagnostics` / `SourceConnectionTester`):

```dart
// public: airo/packages/platform_player/lib/src/buffer_profile.dart
abstract interface class BufferProfileSelector {
  BufferProfile selectFor(NetworkSnapshot network, DeviceClass device);
}

class FixedConservativeProfileSelector implements BufferProfileSelector {
  const FixedConservativeProfileSelector();
  @override
  BufferProfile selectFor(NetworkSnapshot network, DeviceClass device) =>
      BufferProfile.constrained;
}
```
```dart
// pro: airo-pro/packages_pro/pro_streaming_engine/lib/src/adaptive_selector.dart
class AdaptiveBufferProfileSelector implements BufferProfileSelector {
  @override
  BufferProfile selectFor(NetworkSnapshot network, DeviceClass device) {
    // re-evaluated every 60s per F6.1; profile table in requirements §F6
  }
}
```
Kotlin side: no comments beyond WHY-only per repo convention; direct
`ByteBuffer` slices, no copies in the hot path (F5.2/F5.3) — this is a hard
constraint, not a style preference, so annotate any exception with why.

## Testing Strategy

- Package-level `flutter test` per new/extended package, target NFR-13
  (>70% coverage on engine code: resolver cache, connection pool, ring
  buffer, scorer, buffer-profile selection, message (de)serialization)
- Kotlin unit tests for `DataSource`, `RingBuffer`, splice-point detection
  (PAT/PMT + IDR parsing) — pure logic, no device needed
- Integration: control-channel round trip (LOAD→STATE) against a fake
  receiver, using existing patterns in `platform_channels` tests
- Device-required, not CI: AC-1 through AC-9 all require the physical rig
  documented in memory (`physical-device-test-rig.md` — Pixel 9, no
  simulators/emulators for TV; add Fire TV Stick Lite/4K, Chromecast w/
  Google TV, one mid-range Android TV per Acceptance Criteria device set)
- R05 web-gate: any new package touched by the web build must not
  regress the isolation check just fixed in PR #1561 — run
  `flutter build web --release` before landing anything that touches
  `platform_player`/`platform_streams` (per repo web-fallback gotcha)

## Boundaries

- **Always do:** keep control-plane and data-plane fully separate (AD-2 is
  the entire point of this feature vs. DLNA); gate every pro behavior
  through `Entitlements.isEnabled`, never a call-site `if (isPro)`; run
  `flutter build web --release` before landing player-path changes; hash
  BSSID before persisting as a network key (F7.6); keep provider
  credentials in Keystore/Keychain only, never logged (NFR-11)
- **Ask first:** adding a new `ProFeature` enum value (stableId is
  permanent once shipped); any change to `airo_pro_bootstrap` (overlay-owned
  seam, conflicts silently favor overlay on sync); cloud relay for off-LAN
  control (F1.9, backend cost — Open Question #3, unresolved); Fire TV
  Amazon Appstore submission vs. sideload-only (Open Question #2)
- **Never do:** put pro business logic in the public `platform_*` packages
  (only widen the seam, per repo CLAUDE.md gotcha on `airo_pro_bootstrap`);
  let free tier be deliberately crippled beyond F8's table (Risk: "premium
  perceived as artificial throttling"); re-resolve DNS mid-stream under any
  condition (F4.1.4, hard invariant); let a shadow fetch exceed 2 concurrent
  connections (F4.4.8); ship without instrumentation first (Phase 1 must land
  before Phase 2 — "nothing optimised before it is measured")

## Success Criteria

Adopting AC-1 through AC-9 from the requirements doc verbatim as this spec's
done-condition, against the reference device set {Fire TV Stick Lite, Fire
TV Stick 4K, Chromecast with Google TV, one mid-range Android TV}. Full NFR
table (NFR-1..13) applies unchanged. Additionally:
- Free-tier build instrumented check (AC-8) becomes a CI assertion once
  `pro-hygiene.yml`-equivalent gating exists on the public side, not just a
  manual verification
- `ProFeature.multiSourceFailover`, `.adaptiveBufferControl`,
  `.zeroCopyCast` all appear in `LaunchPromoEntitlements.changes` and
  `NoEntitlements` denies all three — covered by existing entitlement tests

## Delivery Phases

Unchanged from requirements doc §8 (Instrumentation → Receiver engine →
Ranking/failover → Cast protocol → Premium packaging → Hardening). Each
phase gets its own `tasks/plan.md` + `tasks/todo.md` via `/agent-skills:plan`
when that phase starts — this SPEC.md is the fixed contract across all six;
individual phase plans are not written yet.

## Model & Agent Routing

Delegation contract per established workflow: expensive model architects and
reviews; cheaper models implement against delegation-ready tasks. Every task
in a phase's `tasks/todo.md` names its executor tier so any orchestrator
(Claude Code, workflow scripts, FleetView) can route without re-deciding.

### Tier definitions

| Tier | Model | Use for |
|---|---|---|
| **architect** | Opus / Fable | Spec + phase plans, contract design (message schemas, `DataSource` seam, `ProFeature` additions), splice-algorithm design, risk calls |
| **implement** | Sonnet | Package scaffolding, Dart/Kotlin implementation against written acceptance criteria, test writing, wiring platform channels |
| **mechanical** | Haiku | Renames, `module.yaml`/pubspec edits, export lists, doc mirrors, format fixes |
| **cross-check** | Codex (gpt-5.4-mini via codex-delegate hook) | Adversarial review of every edit (auto, already active); `/codex:rescue` (gpt-5.4 high) after 3 failed attempts — self-escalate, no ask needed |

### Routing rules

1. **Contract-touching = architect.** Anything changing a public interface
   (`Entitlements`, `BufferProfileSelector`, control-channel message types,
   Kotlin↔Dart channel shape) is authored or explicitly approved at
   architect tier before implement tier builds against it.
2. **Hot-path Kotlin = implement tier + mandatory perf review.** Ring
   buffer, `DataSource`, splice logic route to `chief-performance-officer`
   + `playback-architect` agents for review regardless of who wrote it —
   F5.2/F5.3 zero-alloc constraint is easy to silently break.
3. **Security-relevant = implement tier + `chief-security-officer`.**
   Pairing/TLS pinning, credential brokering (F2.1 auth material), Keystore
   paths, telemetry redaction (F7.6, NFR-11, AC-9).
4. **Escalation is one-way per task.** mechanical→implement→architect on
   failure or discovered ambiguity; never silently downgrade. 3+ failed
   attempts at any tier → `/codex:rescue` with precise problem statement.
5. **Device-rig work is not delegable to background agents** — AC
   verification on physical rig (Fire TV sticks, Pixel 9) runs in an
   interactive session with the user present.

### Per-phase defaults

| Phase | Plan author | Bulk executor | Mandatory reviewers (council agents) |
|---|---|---|---|
| 1 Instrumentation | architect | implement | chief-qa-officer, chief-cloud-officer (backend ingestion), chief-security-officer (F7.5/F7.6 consent + redaction) |
| 2 Receiver engine | architect | implement (Kotlin-heavy) | playback-architect, chief-performance-officer, platform-architect (channel contracts) |
| 3 Ranking/failover | architect | implement | playback-architect, chief-performance-officer, media-intelligence-architect (source semantics) |
| 4 Cast protocol | architect | implement | platform-architect (protocol), chief-security-officer (pairing/TLS), tv-experience-architect (receiver UX), flutter-architect (sender UI) |
| 5 Premium packaging | architect (entitlement seam) | implement + mechanical | chief-security-officer (F8.12), product-manager (free/pro split), chief-architect (open-core boundary) |
| 6 Hardening | architect (triage) | implement | chief-qa-officer, chief-performance-officer, chief-release-devops-officer (release workflows) |

Council reviewer set comes from each touched package's `module.yaml`
(`owner` + `reviewers`); table above is the floor, not the ceiling.

## Open Questions (carried from requirements doc, unresolved)

1. ~~Provider mirror URLs vs. user-supplied backup lines~~ — **Resolved:**
   user-supplied backup lines only. F4.3/F4.4 rank across per-channel
   backup sources the user enters; no provider mirror-discovery API assumed.
2. First-party Fire TV Appstore submission vs. sideload-only — affects
   content-policy review exposure, not yet decided.
3. Cloud relay for off-LAN control (F1.9) worth the backend cost in v1? —
   currently scoped "Could", default to LAN-only for v1 unless decided
   otherwise.
4. iOS as receiver (iPad) — out of scope this release per §1.3, revisit
   post-v1.
5. Legal distance from community IPTV source content — outside this spec's
   scope, flag to product/legal before Phase 4 (cast ships the "Play on TV"
   surface, raises visibility).
6. Pricing: standalone tier vs. bundled — deferred; `LaunchPromoEntitlements`
   means this doesn't block any engineering phase.
7. **New:** exact free-tier cap mechanics for F8.6 ("cast to 1 device" free
   vs. "unlimited" pro) — is this enforced receiver-side (F8.12 says
   receiver validates entitlement independently) as a connected-sender
   count, or something else? Needs a decision before Phase 4 implementation,
   not before this spec.
