# Implementation Plan: Phase 2 — Receiver Streaming Engine

Spec: `docs/specs/tv-zero-copy-cast.md` (this branch). Requirements: F4.1 (DNS), F4.2 (connections),
F5 (zero-copy decode), F6 (adaptive buffer). Delivery Phase 2 of 6 — ships
as a **receiver-only improvement, no cast protocol yet** (that's Phase 4).
F4.3/F4.4 (source ranking, shadow failover) are Phase 3, out of scope here.

## Overview

Phase 1 shipped instrumentation on the *existing* Dart/`video_player`
engine. Phase 2 replaces that engine on Android TV/Fire TV with a
Media3-native Kotlin pipeline (AD-1, AD-5 in docs/specs/tv-zero-copy-cast.md): custom `DataSource`,
DNS resolver cache, pre-warmed connection pool, and `MediaCodec`→`Surface`
decode with zero heap copies, all exposed to Flutter through a
`MethodChannel`/`EventChannel`/`PlatformView` bridge.

## Investigation findings that reshape this plan

Checked before writing tasks, not assumed:

- **No native module exists yet.** `packages/platform_player/` has no
  `android/` directory — it's pure Dart wrapping `video_player`. There is
  no Media3/ExoPlayer dependency anywhere in `app/android`. There is no
  `PlatformView` anywhere in this repo (searched — zero hits). This is a
  **from-scratch native module**, not an extension of existing Kotlin.
- **CORRECTED (was wrong when first written): there is no Gradle flavor
  dimension at all.** `isTvVariant` is a plain Kotlin DSL `val` in
  `build.gradle.kts`, derived from a `--dart-define=APP_VARIANT=tv`
  Gradle property — not a `productFlavors`/`flavorDimensions` block (none
  exists). The `main` source set's `kotlin.srcDirs` is *always*
  `src/product/kotlin` (TV included) unless `isCoinsVariant`; `src/tv/`
  only contributes `AndroidManifest.xml` and `res/`, never Kotlin.
  **MainActivity and every plugin registered in it are shared source
  across phone and TV builds.** TV-only differences are expressed via
  `isTvVariant`-gated `excludes` in the packaging block (native libs) and
  the tv manifest/res override, not via a separate Kotlin source
  directory. Tasks below were corrected to match this before any Kotlin
  was written — the new plugin lives in `src/product/kotlin` alongside
  everything else and registers unconditionally; nothing tv-exclusive
  happens until Media3 actually gets added in Task 4, at which point
  APK-size gating (if needed) follows the existing `excludes` pattern,
  not a separate source set.
- **The MethodChannel plugin pattern is established and should be reused
  exactly**, not reinvented: a static Dart wrapper class holding a `const
  MethodChannel('com.airo.player/<name>')`, `MissingPluginException`
  caught and degraded gracefully, paired with a Kotlin `*Plugin` class
  instantiated and wired in `MainActivity.configureFlutterEngine` (see
  `AiroNativePictureInPicture` / `AiroPictureInPicturePlugin` — the PiP
  feature is the closest existing precedent and this plan mirrors its
  shape for both the method channel and the eventual event stream).
- **`platform_channels` is not Flutter platform channels.** Despite the
  name, that package holds IPTV channel *data models* (`IPTVChannel`,
  `ChannelStreamSource`...). Do not confude it with the
  `MethodChannel`/`EventChannel` bridge work here — no collision, just a
  naming trap worth flagging once.
- **Verification ceiling for this phase is lower than Phase 1's.**
  Phase 1 was pure Dart — every acceptance criterion had a `flutter test`
  proof. Kotlin/Media3/`PlatformView` behavior cannot be verified by
  `flutter test`; it needs a real Android TV device or the Fire TV Stick
  in the physical test rig (`physical-device-test-rig` memory — no
  simulators/emulators for TV per repo convention). Tasks below are
  scoped so each has *some* automated proof (JVM unit tests for pure
  Kotlin logic, `flutter analyze`/`gradle build` for compilation), but the
  actual "does a frame render on a TV" check is manual, interactive, and
  requires the user present with the physical rig — flagged per-task, not
  glossed over.

## Architecture Decisions

- **AD-P2.1 — New package `platform_streaming_engine`, TV-flavor Kotlin
  only.** Per docs/specs/tv-zero-copy-cast.md's package table. Dart side holds the
  `MethodChannel`/`EventChannel` wrappers and the `PlatformView` widget;
  Kotlin side (`app/android/app/src/tv/kotlin/...`) holds Media3. This
  needs a new `module.yaml` — owner Playback Architect, reviewers per
  SPEC's routing table (playback-architect, chief-performance-officer,
  platform-architect) — a genuine new-package creation, not a small edit.
- **AD-P2.2 — Risk-first vertical slice, not horizontal layering.**
  Rather than building DNS cache → connection pool → ring buffer → decode
  pipeline in isolation and integrating at the end, Wave A proves the
  entire chain end-to-end on a trivial pass-through `DataSource` first:
  Flutter → `PlatformView` → Kotlin `MediaCodec`→`Surface` → visible frame.
  If the native bridge itself has a problem (Gradle flavor wiring,
  `PlatformView` texture registration, Fire OS quirks), that surfaces in
  days, not after weeks of building the sophisticated networking layer on
  top of an unproven foundation. This mirrors the incremental-
  implementation skill's risk-first slicing strategy.
- **AD-P2.3 — This plan only task-breaks Wave A.** Waves B–D (DNS/pool,
  buffer profiles, zero-copy hardening) are outlined at the phase level
  below but not yet broken into acceptance-criteria-level tasks — writing
  15+ tasks against Kotlin patterns not yet proven to work in this repo
  would mean re-planning most of them anyway once Wave A lands. Plan
  Wave B once Wave A's checkpoint passes.
- **AD-P2.4 — Gradle/dependency changes are flagged, not silently
  added.** Adding Media3 as a Gradle dependency is a build-config and
  new-dependency change — per user's standing boundaries (global
  CLAUDE.md: "ask first" on adding dependencies / changing CI config) and
  `chief-open-source-officer`'s dependency-governance remit
  (`platform_dependency_governance`). Task 2 below stops at "propose the
  dependency + versions" and waits for explicit confirmation before
  touching `build.gradle`.

## Wave A: Native bridge proof-of-concept

### Task 1: `platform_streaming_engine` package scaffold + method-channel round trip

**Tier:** architect for the module.yaml/package-boundary shape, implement
for the mechanical scaffold.

**Description:** Create the new package (Dart side only this task) with
a `module.yaml`, a static `AiroStreamingEngineChannel` wrapper mirroring
`AiroNativePictureInPicture`'s shape (const `MethodChannel`, graceful
`MissingPluginException` fallback), and a `ping()` method for round-trip
proof. No Kotlin yet — this task proves the Dart-side contract compiles
and is unit-testable before any native code exists.

**Acceptance criteria:**
- [ ] `packages/platform_streaming_engine/module.yaml` exists, owner
      Playback Architect, reviewers per docs/specs/tv-zero-copy-cast.md's Phase 2 routing table
- [ ] `AiroStreamingEngineChannel.ping()` returns `false`/degrades
      gracefully on a host with no platform implementation (provable in
      `flutter test` today, before Kotlin exists — mirrors how
      `AiroNativePictureInPicture`'s `isSupported()` is tested)
- [ ] Package builds: `flutter analyze` clean, `flutter test` green

**Verification:**
- [ ] `cd packages/platform_streaming_engine && flutter test && flutter analyze`

**Dependencies:** None

**Files likely touched:**
- `packages/platform_streaming_engine/module.yaml` (new)
- `packages/platform_streaming_engine/pubspec.yaml` (new)
- `packages/platform_streaming_engine/lib/src/airo_streaming_engine_channel.dart` (new)
- `packages/platform_streaming_engine/test/airo_streaming_engine_channel_test.dart` (new)

**Estimated scope:** S

---

### Task 2: Kotlin plugin skeleton + `ping` implementation

**Tier:** implement, with platform-architect review before merge (channel
contract shape) per docs/specs/tv-zero-copy-cast.md routing rule 1 ("contract-touching = architect").

**Description:** `AiroStreamingEnginePlugin.kt` under the *shared*
`app/android/app/src/product/kotlin/io/airo/app/` (corrected — see
Investigation findings above; there is no separate tv Kotlin source
set), registered unconditionally in `MainActivity.configureFlutterEngine`
alongside the other plugins there. Implements `ping` only — proves the
channel resolves end-to-end on a real device. No Media3 dependency yet,
so there is nothing to gate by variant at this stage; phone/Coins builds
simply carry an inert extra `MethodChannel` handler, same as every other
plugin already registered there.

**Acceptance criteria:**
- [ ] Plugin compiles into every variant (phone, TV, Coins, Mind) since
      the Kotlin source is shared — confirm this is acceptable (it
      matches existing precedent for every other plugin in this file)
      rather than assuming TV-only registration was ever required
- [ ] `ping()` round-trips Dart→Kotlin→Dart on a real Android device
      (**manual verification with the user present — no automated proof
      for this half**)
- [ ] `./gradlew :app:compileDebugKotlin` succeeds (confirm the exact
      task name against this project's actual Gradle task list — no
      flavor-scoped variant exists to target specifically)

**Verification:**
- [ ] Gradle compile succeeds
- [ ] Manual round-trip check on device (flag this explicitly when
      reporting the task done — it is not a `flutter test` proof)

**Dependencies:** Task 1

**Files likely touched:**
- `app/android/app/src/product/kotlin/io/airo/app/AiroStreamingEnginePlugin.kt` (new)
- `app/android/app/src/product/kotlin/io/airo/app/MainActivity.kt` (registration)

**Estimated scope:** S

---

### Task 3: Propose Media3 dependency — approval checkpoint, no code

**Tier:** architect (proposal only).

**Description:** Not an implementation task. Produces a short written
proposal: exact Media3/ExoPlayer artifact versions, APK size delta
estimate, license (Apache 2.0, already compatible), and confirmation it's
`tv`-flavor-scoped so phone/Coins builds are unaffected. Per AD-P2.4, this
stops here and waits for explicit user confirmation before Task 4 touches
`build.gradle`.

**Acceptance criteria:**
- [ ] Proposal names exact `androidx.media3:media3-exoplayer` /
      `media3-common` / `media3-datasource` versions and their combined
      size impact
- [ ] User has explicitly confirmed before Task 4 starts

**Verification:** N/A (no code)

**Dependencies:** None (can run parallel to Tasks 1–2)

**Files likely touched:** None (proposal delivered in chat, or as a
short doc if the user wants it recorded)

**Estimated scope:** XS

---

### Task 4: Media3 dependency + minimal `SurfaceView` `PlatformView`

**Tier:** implement, chief-performance-officer + platform-architect
review (docs/specs/tv-zero-copy-cast.md Phase 2 reviewer floor).

**Description:** Add the confirmed Media3 dependency (tv flavor only),
create a `PlatformViewFactory` hosting a bare `SurfaceView`, and a Dart
`AndroidView`-based widget in `platform_streaming_engine`. `ExoPlayer`
plays one hardcoded test HLS URL through Media3's *stock* `DataSource`
(no custom networking yet) to prove Media3 can render into the
`PlatformView` texture at all on this repo's Gradle/Flutter version
combination.

**Acceptance criteria:**
- [ ] Media3 dependency added `isTvVariant`-gated in
      `build.gradle.kts`'s `dependencies {}` block, following the same
      pattern as the existing `isTvVariant`/`isCoinsVariant`-conditional
      `excludes` in the packaging block (corrected from an earlier,
      wrong assumption of a separate tv flavor's own `build.gradle`)
- [ ] `./gradlew :app:assembleDebug` with `APP_VARIANT=tv` succeeds with
      Media3 present (confirm exact invocation — this project builds
      variants via Flutter's `--dart-define`, not Gradle flavor tasks;
      see `run-airo-tv` skill for the real launch command)
- [ ] A frame from the hardcoded test stream is visible on a real TV
      device/rig (**manual, interactive verification — the actual bar
      for this task, not the Gradle build**)
- [ ] A phone-variant build (`APP_VARIANT` unset/`full`) is unaffected
      at runtime — if the dependency can't be Gradle-conditionally
      excluded per variant (single source set, single `dependencies`
      block, only `packaging.excludes` is variant-aware today), confirm
      whether Media3 ends up on the phone classpath too and whether
      that's acceptable or needs its own follow-up

**Verification:**
- [ ] Gradle build succeeds
- [ ] Manual on-device frame check (flag explicitly, requires the
      physical rig and the user's presence)

**Dependencies:** Task 3 (confirmed), Task 2

**Files likely touched:**
- `app/android/app/build.gradle.kts` (Media3 dependency)
- `app/android/app/src/product/kotlin/io/airo/app/AiroStreamingSurfaceViewFactory.kt` (new)
- `packages/platform_streaming_engine/lib/src/airo_streaming_surface_view.dart` (new)

**Estimated scope:** M

---

### Task 5: STATE event stream (phase mapping) back to Dart

**Tier:** implement, playback-architect review (contract shape reuses
Phase 1's `AiroPlaybackEnginePhase`-equivalent semantics deliberately, so
downstream code — e.g. Phase 1's `StreamingSessionMetricsCollector` —
can eventually consume either engine uniformly).

**Description:** Wire an `EventChannel` from the Kotlin `Player.Listener`
(playback state, position, buffering) to a Dart `Stream`, using the same
phase vocabulary as `AiroPlaybackEnginePhase` (idle/opening/playing/
buffering/stopped/...) from `platform_player` rather than inventing a
parallel one — a future task unifies them behind a shared interface, but
naming them the same now avoids a rename later.

**Acceptance criteria:**
- [ ] Kotlin phase transitions map 1:1 onto `AiroPlaybackEnginePhase`
      values (reuse the enum from `platform_player`, don't fork it)
- [ ] Dart `Stream<AiroPlaybackState>`-shaped output is unit-testable
      with a fake `EventChannel` (`setMockStreamHandler` in tests) even
      without a device
- [ ] Manual check: state stream reflects real playing/buffering
      transitions on device for the Task 4 test stream

**Verification:**
- [ ] `flutter test` on the Dart-side stream mapping (mockable, no
      device needed for this half)
- [ ] Manual device check for the Kotlin→Dart transitions themselves

**Dependencies:** Task 4

**Files likely touched:**
- `app/android/app/src/product/kotlin/io/airo/app/AiroStreamingEnginePlugin.kt`
- `packages/platform_streaming_engine/lib/src/airo_streaming_engine_state.dart` (new)
- `packages/platform_streaming_engine/test/airo_streaming_engine_state_test.dart` (new)

**Estimated scope:** M

---

## Checkpoint: Wave A complete (native bridge proven)

- [ ] Tasks 1–5 done; Dart-side tests green; both flavors build
- [ ] **Interactive session with the user and the physical rig**: confirm
      a frame renders end-to-end on at least one real Android TV device
      and, if available, the Fire TV Stick — this is the actual go/no-go
      gate for the rest of Phase 2, not a CI-green checkmark
- [ ] Human review of the new package/module boundary before Wave B is
      planned

## Waves B–D (outlined, not yet task-broken — plan after Wave A checkpoint)

- **Wave B — DNS + connection pool (F4.1, F4.2):** replace Task 4's stock
  `DataSource` with the custom one; resolver cache with DoH race, IP
  pinning for session lifetime, pre-warmed connection pool,
  `TCP_NODELAY`/`SO_RCVBUF` tuning. Pure-Kotlin logic (cache, pool state
  machine) is the JVM-unit-testable part; the DNS/socket behavior itself
  needs device verification.
- **Wave C — Adaptive buffer profiles + speed nudge (F6):** profile
  table from docs/specs/tv-zero-copy-cast.md, `NetworkCapabilities`-based signal reads (not the
  deprecated `WifiManager.getConnectionInfo()` path), `LoadControl`
  tuning, 0.97× speed-nudge instead of rebuffering.
- **Wave D — Zero-copy decode hardening (F5):** confirm no `ImageReader`/
  pixel readback anywhere in the Task 4 pipeline, direct `ByteBuffer`
  slices end to end, buffer pool reuse, tunneled playback where
  supported. Largely a *verification and tightening* pass over Wave A's
  code rather than new surface area, since Task 4 already targets
  `SurfaceView` + `MediaCodec` directly.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| No prior `PlatformView` in this repo — texture registration/lifecycle could surprise on Fire OS specifically | High | Wave A deliberately isolates this risk into Task 4, before any networking sophistication is built on top |
| Media3 dependency adds APK size / cold-start cost (NFR-12: <4s cold start on Fire TV Stick Lite) | Med | Task 3's proposal step measures size delta before it's committed to; tv-flavor-scoped so phone/Coins are unaffected regardless |
| Kotlin/native work is not CI-provable the way Phase 1 was | Med | Every task pairs a compile/unit-test proof with an explicit, separately-flagged manual device step — never silently claim "tests pass" for behavior only a device can confirm |
| Gradle flavor wiring for a genuinely new native module is unfamiliar territory in this codebase (only plugin-per-file precedent exists, not a full player subsystem) | Med | Task 2 stays minimal (ping only) specifically to surface flavor-wiring problems before Media3 is even in the mix |

## Open Questions

- **P2-1 — RESOLVED (investigation):** There is no flavor-scoped Gradle
  task naming to confirm — there are no `productFlavors`, so builds are
  plain `assembleDebug`/`assembleRelease` etc. with variant selection via
  `--dart-define=APP_VARIANT=tv` at the Flutter level, per the
  `run-airo-tv` skill.
- **P2-2:** Does the physical test rig currently include an Android TV
  device with `tv` flavor installable, or only the Fire TV Stick /
  Pixel 9 phone (per `physical-device-test-rig` memory)? Affects which
  device Wave A's checkpoint actually verifies against first.
- **P2-3 (carried from docs/specs/tv-zero-copy-cast.md):** Fire TV Appstore submission vs.
  sideload-only — doesn't block Wave A, but affects whether Wave A should
  also stand up a Fire OS-specific manual QA pass now or defer it.
