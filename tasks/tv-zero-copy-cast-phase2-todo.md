# Phase 2 — Receiver Streaming Engine: Wave A Task List

Plan: `tasks/tv-zero-copy-cast-phase2-plan.md` · Spec: `docs/specs/tv-zero-copy-cast.md`
Only Wave A is task-broken (see plan's AD-P2.3 for why). Waves B–D get
their own todo list once Wave A's checkpoint passes.

**Read before starting:** every "Verification" below that says "manual,
device-required" cannot be closed out by an agent alone — it needs the
user present with the physical rig. Don't report a task done on Gradle-
green alone when its acceptance criteria include a device check.

## Task 1: `platform_streaming_engine` package scaffold + method-channel round trip
- [x] DONE (3ff18d46) — 4/4 tests green, analyzer clean
- **Tier:** architect (package shape) → implement (scaffold)
- **Verification:** `flutter test && flutter analyze` in the new package
- **Dependencies:** None

## Task 2: Kotlin plugin skeleton + `ping` (shared source, registers unconditionally — corrected, see plan)
- [x] DONE (0135ae68) — `./gradlew :app:compileDebugKotlin` BUILD SUCCESSFUL,
  confirmed after fixing the media_kit_libs_android_video sandbox blocker
  (root cause: Java's URL.openStream() failing where curl succeeds fine;
  fix: pre-seeded the 4 verified-MD5 jars to the exact cache path Gradle
  checks — see debugging session, build/ dir only, nothing committed).
  Zero warnings on the new file/lines. Manual device round-trip check
  (ping actually resolving Dart→Kotlin→Dart) still outstanding — needs
  the user with the physical rig.
- **Tier:** implement + platform-architect review before merge
- **Verification:** Gradle compile (flavor-scoped) + **manual device
  round-trip check**
- **Dependencies:** Task 1

## Task 3: Propose Media3 dependency — approval checkpoint, no code
- [x] DONE — proposal at tasks/tv-zero-copy-cast-phase2-task3-media3-proposal.md,
  user confirmed via AskUserQuestion ("Yes, proceed")
- **Tier:** architect (proposal only)
- **Verification:** N/A — gate is explicit user confirmation
- **Dependencies:** None (parallel-safe with 1–2)

## Task 4: Media3 dependency + minimal SurfaceView PlatformView
- [x] DONE (1304fb95) — `./gradlew :app:compileDebugKotlin` BUILD SUCCESSFUL
  on all three variants (default/stub, tv/real Media3, coins/unaffected —
  all three actually re-run and confirmed, not assumed from one). Real
  tv-only Kotlin source dir created (`src/tv/kotlin`) plus a stub
  (`src/streaming_engine_stub/kotlin`) mirroring the existing LiteRT-LM
  available/unavailable split, since Media3 is variant-gated but Kotlin
  source was previously fully shared. Dart: 6/6 tests green, analyzer
  clean. **Manual on-device frame check still outstanding** — needs the
  user with the physical rig; this is the actual bar for the task, the
  Gradle build is necessary but not sufficient.
- **Tier:** implement + chief-performance-officer + platform-architect review
- **Verification:** Gradle build both flavors + **manual on-device frame check**
- **Dependencies:** Task 3 (confirmed), Task 2

## Task 5: STATE event stream (phase mapping) back to Dart
- [x] DONE (f3ea808d) — EventChannel + Player.Listener wired, phase
  stableIds reuse `AiroPlaybackEnginePhase` from platform_player (not
  forked). Caught and fixed a real Kotlin circular-type-inference compiler
  error during verification (explicit `ExoPlayer` type annotation).
  Re-verified all three variants compile clean after the fix. Dart: 9/9
  tests green (3 new), analyzer clean. **Manual device check for real
  phase transitions still outstanding** — needs the user with the rig.
- **Tier:** implement + playback-architect review
- **Verification:** `flutter test` (mockable Dart half) + **manual device
  check for real transitions**
- **Dependencies:** Task 4

## Checkpoint: Wave A — code-complete, device verification outstanding
- [x] Tasks 1–5 done, Dart tests green (19 total across the new
  package), all three Gradle variants (default, tv, coins) build clean
- [ ] **Interactive session with user + physical rig**: frame renders
  end-to-end on a real device — the actual go/no-go gate, not yet done
- [ ] Human review of the new package/module boundary
- [ ] Only then: plan Wave B (DNS + connection pool) as its own todo list
