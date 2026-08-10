# Airo Mind SSOT — task list

Plan: `tasks/plan.md`. One PR per phase, off `origin/main`.
Checkpoints are stop-and-verify, not formalities.

## Phase 0 — unblock debug builds ✅ DONE

- [x] **0.1** Reproduced the i686 failure in isolation — bindgen has no sysroot,
      falls back to bundled 64-bit bindings, `12_usize - 16_usize` overflow.
- [x] **0.2** Sysroot fix (`BINDGEN_EXTRA_CLANG_ARGS`) eliminated the const-eval
      crash — but exposed `clang: error: unsupported option '-arch' for target
      'i686-linux-android24'`, a macOS-host-specific CMake failure, separate
      from the original bug.
- [x] **0.3** x86 Android is emulator-only, no device in this rig uses it — took
      this path instead of chasing the CMake `-arch` issue. Declared `arm64`
      only, per library, in `packages/feature_mind/android/build.gradle`.
      Cargokit's Gradle plugin gained an optional per-library platform list
      (`library(manifestDir, libname, platforms)`) to express it — intersected
      against the build's platform set, not substituted, so a library cannot
      conjure an ABI the build isn't producing.
- [x] **0.4** `AIRO_MIND_BUILD_MODE=debug scripts/build-mind.sh` → 707 MB debug
      APK, zero i686 references, zero `Cargokit BuildTool failed`.
- [x] **0.5** Installed on the Pixel 9 (`io.airo.app.mind`), launched, PID stayed
      alive. First debug build that has ever run.
- [x] **0.6** PR + merge — PR #1551, branch `fix/mind-debug-abi`, cut fresh off
      `origin/main` after `#1549`/`#1550` auto-merged mid-session.

## Phase 1 — model acquisition + engine bridges, both behind abstractions

Design: `docs/superpowers/specs/2026-08-07-airo-mind-abstraction-layer.md`.
Direction confirmed: **neither app ships model weights** — both move onto
`core_ai`'s download pipeline, behind a `ModelProvider` interface so the source
can change later without touching `MindService`. Engine calls get the same
treatment (`MindSpeechBridge`/`MindGenerationBridge`), landed in this phase
because it's the same "replace a concrete dependency" motion and unblocks
T3–T8 in the journey-coverage spec.

### 1A — abstractions ✅ DONE

- [x] **1A.1** Read `ModelDownloadService`, `ModelStorageManager`,
      `OfflineModelInfo`. `OfflineModelInfo.sha256` carries the digest straight
      through to `DownloadArtifactRequest.expectedSha256` — no second source.
- [x] **1A.2** `ModelProvider` + `RequiredModel` + `InstalledModel` +
      `ModelAcquisitionEvent` in `lib/src/models/model_provider.dart`. Own
      lightweight types, not the FRB-generated `BigInt` wire types — a
      provider must not know the bridge exists.
- [x] **1A.3** `ModelInstaller implements ModelProvider` — bundled-asset
      behaviour unchanged, now one implementation among several. No prior test
      file existed for it; nothing broke.
- [x] **1A.4** `DownloadModelProvider` (`lib/src/models/download_model_provider.dart`)
      wraps `ModelDownloadService` + `ModelStorageManager`. `requiredModelsLookup`
      and `downloadUrlFor` are both **injected functions**, not hardcoded — the
      provider must not import the generated bridge, and `airo_mind_core::models`
      pins no URL (`ADR-0018 §1`: hosting is a Dart-side decision).
- [x] **1A.5** Test doubles in `test/models/download_model_provider_test.dart`
      (`FakeBackgroundDownloads`, `MockModelStorageManager`) — no real network,
      no platform channel.
- [x] **1A.6** `MindSpeechBridge` / `MindGenerationBridge`
      (`lib/src/bridges/`). `loadLibrary()` split from `initialize()` on the
      speech bridge so `MindUnavailable.bridgeMissing` still fails fast, before
      model acquisition — preserves the original ordering exactly.
      `RustMindGenerationBridge.ensureLoaded` owns the lazy-load guard
      previously inline in `MindService.process`.
- [x] **1A.7** `MindService` constructor takes `modelProvider` + both bridges;
      all default to the exact prior production path
      (`ModelInstaller`/`RustMindSpeechBridge`/`RustMindGenerationBridge`).
- [x] **1A.8** T3–T8 in `test/mind_service_test.dart`, all passing. T4 and T5
      verified **non-vacuous** by mutation: breaking each enforcement (removing
      the dual-cancel, forcing an eager load on cancel) makes its test fail;
      restoring makes the full suite green again (101/101).

Full-package regression: `flutter analyze` and `flutter test` both clean
(101/101) after every change. Mind flavour's own suite
(`flutter test test_mind/ --dart-define=APP_VARIANT=mind`) also green, 9/9,
confirming the abstraction layer doesn't break the shell that already exists.

### 1B — cut the standalone shell over ✅ DONE (super app is Phase 4)

- [x] **1B.1** Baseline: standalone Mind release APK was 620 MB (bundled
      models) before this session; 707 MB debug / to-be-measured release after
      (see note below — this run only produced debug builds).
- [x] **1B.2** `app/lib/core/mind/mind_model_sources.dart` — new file, builds
      `DownloadModelProvider` wired to the real HuggingFace URLs
      `fetch_mind_models.sh` already used, keyed by the pinned file names.
      `MindScribeModule` wires it into `MindService` through
      `buildMindDownloadService`, which also stages downloads in application
      support and hands the `ModelDownloadService` back for disposal. The super
      app has no `MindScribeModule` registration yet (Phase 4), so only the
      standalone shell is cut over in this phase. (Merged with #1554, which
      landed the same cut-over in parallel as `mind_model_sources.dart`; that
      file is the one that survives.)
- [x] **1B.3** `_Loading` widget in `mind_home_screen.dart` — file name +
      `LinearProgressIndicator` + percentage during the download, falling back
      to a bare spinner once nothing is downloading. `MindService.onInstallProgress`
      wired in `initState`. Also fixed `modelsMissing`'s failure message,
      written for the bundled-asset era ("this build does not carry") and
      wrong for a download failure (no network, interrupted transfer, digest
      mismatch).
- [x] **1B.4** Dropped `assets/models/` from `packages/feature_mind/pubspec.yaml`
      (the actual bundling declaration — not `app/pubspec_mind.yaml`, which
      never declared it directly). `fetch_mind_models.sh` re-scoped as a dev
      seeding convenience for `ModelInstaller`'s bundled path; `DownloadModelProvider`
      does not consult it.
- [x] **1B.5** Re-checked `nm -u` on both engine dylibs for `httplib` — 0, as
      expected (nothing here touches Rust).
- [x] **1B.6** Device walk — **partial**, see below.
- [x] **1B.7** *(this commit; PR still to open)*

**A real bug was found and fixed on device, not simulated.** `DownloadModelProvider`
set `OfflineModelInfo.id` to the full file name, already carrying its
extension. `ModelStorageManager.getModelPath` appends an extension to `id`
independently of `filePath` (`_artifactExtensionFor` infers it from `filePath`,
but the destination path itself is `$id$extension`) — so the download landed at
a **doubled extension** (`qwen….gguf.gguf`), a file neither `verifyModelIntegrity`
nor the Rust bridge ever looks at. Fixed by deriving `id` via
`p.basenameWithoutExtension(fileName)`, so the reconstructed path matches the
original name exactly.

**Verified on the Pixel 9 without relying on the flaky live retries**: after the
fix, `adb shell run-as … ls` showed the file at the *correct* single-extension
path, and `adb shell run-as … sha256sum` matched the pinned digest exactly
(`921e4cf8…`) — byte-for-byte correct, independent of whatever the app's own
progress stream reported.

**What's not confirmed**: a full clean run — install → download both models →
record → transcribe → minutes → search — end to end in one sitting. Repeated
attempts hit intermittent WorkManager network-constraint stalls
(`NetworkRequestConstraintController` reporting `blocked=true` for no
observable reason; network was validated throughout) made worse by an
`adb shell svc wifi disable` issued mid-session to probe the stall, which
dropped the wireless-debugging link entirely and required re-pairing. By the
time the connection was back, the same stalling pattern persisted across
several clean install attempts. Decision: ship on the evidence already
gathered (the bug is real, the fix is verified at the file level, the pipeline
completed two full downloads earlier in the session before the connection
incident) rather than keep re-touching a device in a bad state.

**Redo attempt (same session, later)**: fresh reinstall of the actually-current
APK (caught a stale-APK false negative first — the "final" build predated the
`_Loading`/message-wording commits; rebuilt and confirmed via `strings` on
`kernel_blob.bin` that the new copy was present). `_Loading` UI confirmed
genuinely working on device — screenshots at 9% and 76% for
`qwen2.5-0.5b-instruct-q4_k_m.gguf`. Run still ended in `modelsMissing` for
both files. `adb logcat` root cause this time: `ActivityManager: Stop FGS
timeout` fired on `SystemForegroundService` twice (8s and 94s after start),
each immediately followed by `JobScheduler: Job didn't exist in JobStore` for
`ProgressiveDownloadWorker` — the OS is tearing down the download's foreground
service mid-run on this specific device, independent of anything this session
changed. Decision (user-confirmed): ship on the evidence already gathered —
the double-extension bug, the manifest fix, and the UI/message fixes are all
independently verified; the remaining flakiness is WorkManager/device
environment, not a `feature_mind`/`core_ai` defect. **Not** re-litigated
further in this pass; worth a standalone investigation if it recurs on other
hardware.

**Checkpoint 1** — APK size before/after not fully re-measured (release build
not re-run after the fix); first-run-on-a-real-connection story is proven
piecewise (file+hash correctness) but not as one continuous walk. Offline
first-run no longer works, as intended — confirm that trade is still accepted
before Phase 4 repeats it for the super app.

## Phase 2 — merge feature_assistant into feature_mind ✅ DONE

- [x] **2.1** Owner: **Product Manager** (feature_mind's existing owner,
      user-confirmed) — the merged package is mostly product-surface
      (chat, wellbeing, prompt lab, journeys) with a scribe engine on top.
- [x] **2.2** `git mv`'d `assistant`, `agent_chat`, `wellbeing`, `quotes`, plus
      `host`, `routing`, `services`, and the one non-colliding file in
      `widgets/` — feature_assistant's actual top-level tree was wider than
      the plan's four names. Same for `test/`. No path collisions with
      feature_mind's own `lib/src/widgets` or `test/support`.
- [x] **2.3** `AssistantModule` + `MindScribeModule` merged into one
      `MindModule` (`packages/feature_mind/lib/src/mind_module.dart`, was
      `assistant_module.dart`). `createService` is now a constructor param
      exactly like `hostAdapterBuilder` — null means this shell instance
      carries the hub only (mobile today); non-null adds the `/` scribe route
      (`scribeRoutesFor`) and the module's `initialize()`/`dispose()` own the
      service lifecycle. `id` changed `'assistant'` → `'mind'`.
- [x] **2.4** `module.yaml` widened to `core_ai`, `core_ui`,
      `core_product_shell`, `core_domain`, `core_data`;
      `forbidden_dependencies: [app]` unchanged. Owner, capabilities,
      ship_policy, and reviewers merged in from feature_assistant's manifest.
- [x] **2.5** `app/lib/main.dart` and `app/lib/main_mind.dart` both register
      `MindModule` now. The Mind shell composes `createService` inline
      (`() => MindService(modelProvider: buildMindModelProvider())`), so
      `app/lib/core/mind/mind_scribe_module.dart` — now dead — was deleted.
      `app/lib/core/routing/app_router.dart` looks up module id `'mind'`.
- [x] **2.6** `packages/feature_assistant/` deleted.
- [x] **2.7** `feature_mind`'s suite: 345/345 passing (one real failure
      found and fixed: `wellbeing_screen_test.dart`'s third action card was
      genuinely below the fold at the default 800×600 test surface — a
      pre-existing fragility the merge's added `uses-material-design: true`
      and content shift exposed, not a merge-introduced behavior change).
      `assistant_route_parity_test.dart` passes with names unchanged (only
      the "no assistant module" error-message assertion updated, since the
      id it greps for is now `mind`).
- [x] **2.8** Module-manifest gate (`module_contract_test.dart`) passes.
- [x] **2.9** *(this commit; PR to open next)*

**Scope pull-forward, user-confirmed**: merging means `AssistantModule` only
exists inside `feature_mind` now, so `app/pubspec.yaml` (the phone flavour)
needed `feature_mind` added in this phase, not Phase 4 as originally planned —
the phone build now cross-compiles the whisper.cpp/llama.cpp engines a full
phase early. Phase 4 is now just "mount the scribe route on the phone shell",
not "add the package".

**A second real bug, found by `flutter build web --release` failing** (not in
this phase's original verify list, but required by `CLAUDE.md`'s "run before
landing anything touching a native path" rule): `main.dart` is the same
entrypoint web and phone share — no `--target` split in CI — so the moment it
imports `MindModule`, dart2js compiles all of `feature_mind`, including
`library_loader.dart`'s `ExternalLibrary.open` (native FFI, unsupported on
web). Fixed the same way `CLAUDE.md`'s "Web has no `dart:ffi`" gotcha
prescribes: `library_loader.dart` now picks `library_loader_stub.dart` (returns
null, `RustLib.init` throws, `MindService.initialize()` surfaces
`MindUnavailable.bridgeMissing` — matching that enum case's own doc comment)
or `library_loader_io.dart` (the real resolver) via conditional import. Web
keeps the assistant hub exactly as it rendered before this merge; no nav
restructuring. **Not done**: actually removing Mind from web/TV nav is real
work (separate entrypoint or router changes to tolerate a missing tab),
deferred — the R05 "Mind is private-devices only" acceptance covers what
should eventually happen, not what happens today.

**Checkpoint 2** — owner confirmed (Product Manager). The "assistant leaving
web/TV" consequence was accepted by the user earlier in this plan, but is not
yet *implemented* — web still ships the hub today (see above). Flag before
Phase 3/4 close it out for real.

## Phase 3 — claim /mind ✅ DONE

- [x] **3.1** Move `/assistant/*` paths to `/mind/*`, keeping every route
      **name** unchanged (names are what notifications and deep links resolve)
- [x] **3.2** Redirect old `/assistant/*` paths
- [x] **3.3** Invert the legacy mapping in
      `notification_navigation_service.dart:91` (`/mind` → `/assistant` becomes
      the reverse)
- [x] **3.4** Retire `app/test/core/routing/mind_name_is_free_test.dart` — the
      reservation has been claimed by its intended owner
- [x] **3.5** Route parity (`assistant_route_parity_test.dart`), redirect
      coverage for every `/assistant/*` and `/agent/*` destination including
      the seven that fell through the original four-entry `/agent` map,
      and notification-payload migration coverage
      (`notification_navigation_service_test.dart`).
- [x] **3.6** *(this commit; PR to open)*

**Two real bugs found while writing the deferred tests, both in the original
Phase 3 commit**:

1. `_legacyHubRedirects`'s wildcard rewrite was correct, but `main_mind.dart`
   (the standalone shell) still used the old four-entry `mindLegacyRedirects`
   map — the exact latent bug Phase 3's own commit found and fixed in
   `app_router.dart`, unfixed in its sibling. Replaced with the same
   prefix-rewrite helper, `_legacyHubRedirects`, covering both `/agent` and
   `/assistant` roots.
2. `routeFromNotificationPayload`'s `fallbackRoute` default parameter was
   still the literal `'/assistant/notifications'` — a fifth stale literal the
   commit's own "four literals that should not have been literals" pass
   missed. Now `AssistantRouteNames.notifications`.

Testing the redirects required going around `AppRouter`'s top-level
`redirect:` callback (it awaits `AuthService.instance.initialize()` before any
per-route redirect gets a look, which would make an unauthenticated test
assert about login state, not the rewrite) — both route-parity test files call
the matching `GoRoute.redirect` closures directly with a constructed
`GoRouterState`, which is what the router itself would have called.

## Phase 4 — the super app carries Mind

- [x] **4.1** Record the baseline: phone APK size and cold-build time.
      Pre-Mind release APK size was already committed in
      `.github/apk-size-baselines.tsv` before 4.2 landed:
      `full`/`app-arm64-v8a-release.apk` = 104,141,179 bytes (99.32 MiB),
      last hand-updated 2026-08-02.

      **Post-Mind, measured this session**: a real `flutter build apk
      --release -t lib/main.dart --target-platform android-arm64` off
      current `main` (`AIRO_ALLOW_DEBUG_RELEASE_SIGNING=true` — no
      distribution signing configured in this worktree, and the build
      system has exactly this escape hatch documented in its own error
      message for local size qualification) produced
      `app-release.apk` = 113,826,086 bytes (108.55 MiB).

      **Delta: +9,684,907 bytes, +9.24 MiB, +9.3%** for two cross-compiled
      Rust engines (whisper.cpp, llama.cpp, arm64-only) plus the Mind
      product surface. Still inside the 120 MiB budget in
      `.github/apk-size-baselines.tsv` (108.55 of 120). Landing this number
      as the new committed baseline is a separate, deliberate PR per that
      file's own documented process ("update-apk-size-baselines... push is
      rejected by branch protection... refresh in a PR that cites the run
      they were measured on") — not done here, since committing it silently
      inside this PR would be exactly the kind of un-cited update that
      process exists to prevent. Cold-build time was not captured on either
      side (this session's builds are all incremental after the first;
      isolating a genuine cold-build number needs a clean `.dart_tool` /
      Gradle cache, which none of this session's builds started from after
      the first).
- [x] **4.2** Add `feature_mind` to `app/pubspec.yaml` — done in an earlier
      session (predates this thread).
- [x] **4.3** Register `MindModule` in `main.dart` beside `CoinVaultModule` and
      `IptvFeatureModule` — done in an earlier session (predates this thread).
- [x] **4.4** Web does NOT swap in `feature_mind_stub` today -- R05 is
      currently violated on `main`. TV never depended on `feature_mind` in the
      first place, so it was never at risk.

      **Two things tried, both instructive, neither shippable yet.**

      The obvious fix -- swap `feature_mind` for `feature_mind_stub` via
      `pubspec_overrides.yaml` -- does not work: the stub deliberately exports
      no `MindModule` ("a shared-surface build should fail to compile if it
      reaches for a Mind surface", its own doc comment), so the swap breaks the
      web BUILD rather than silently stubbing it.

      A `dart.library.html` conditional import
      (`app/lib/core/mind/mind_registration.dart` /
      `mind_registration_web.dart`, matching the pattern already used seven
      times elsewhere in `app/lib` -- `app_database.dart`,
      `money_provider.dart`, etc.) does correctly keep `main.dart` from
      referencing `MindModule` on web, and it analyzed clean for the phone
      target. That part is real progress and a smaller fix than the pubspec
      idea: no CI wiring, no committed override file.

      It is not sufficient by itself. `AppRouter.createRouter`
      (`app/lib/core/routing/app_router.dart:50`) -- used by every shell, not
      swapped per platform -- unconditionally does
      `_requiredModule<MindModule>(moduleRegistry, 'mind')` to build the route
      tree, for both the Mind branch AND the top-level Wellbeing destination.
      If `registerMind` is a no-op on web, that lookup finds nothing and
      THROWS AT RUNTIME. `flutter build web --release` would compile clean and
      the app would crash on launch -- a green compile that hides the actual
      failure, which is why the build was stopped rather than trusted to
      "prove" the fix.

      The router itself has to learn a module can legitimately be absent --
      `_requiredModule<MindModule>` needs an optional counterpart, and the two
      route groups built from it unconditionally
      (`assistant.rootRoutesFor(...)`, `assistant.hubRoutesFor(...)`) need to
      become conditional on whether it resolved. That is router surface used
      by every shell, phone included, and is not a change to make without the
      router's own test suite plus a real web smoke test.

      One artefact survived and is real, safe, forward-compatible progress:
      `packages/feature_mind/lib/src/mind_availability.dart` --
      `AiroMindAbsent.value = false`, mirroring the stub's marker of the same
      name and shape, exported from the package barrel. It is inert until
      something reads it, which is exactly the point: whichever fix lands next
      (router-level optional-module lookup, most likely) has an availability
      signal to read that already exists on both sides of the pubspec swap.
      **Resolved this session.** `AppRouter.createRouter` is the one
      entrypoint every phone/web build shares (`ShellId.mobile` — there is no
      separate web `ShellId`), so the fix has two parts:

      1. `main.dart` no longer constructs `MindModule(...)` itself. The
         construction moved into `app/lib/core/mind/mind_registration.dart`
         (`registerMind(registry)`), conditionally imported
         (`if (dart.library.html) 'mind_registration_stub.dart'`) exactly like
         the seven existing examples this pattern is modeled on. The web
         variant's `registerMind` is a no-op — nothing registers under module
         id `'mind'`, and critically, the literal text `MindModule(` no longer
         appears anywhere in `main.dart`, which is what
         `check-mind-private-devices.sh` actually greps for.
      2. `AppRouter.createRouter` gained `_optionalModule<T>` alongside the
         existing `_requiredModule<T>`-shaped lookup (folded into one nullable
         helper, since the module-typed lookup had exactly one caller). Mind
         is now looked up as `assistant = _optionalModule<MindModule>(...)`.
         `rootRoutesFor` (Wellbeing) is included only `if (assistant != null)`.
         The Mind `StatefulShellBranch` itself stays present at its fixed
         index even when the module is absent — removing it would shift
         `navigationShell.currentIndex` out of sync with
         `AppNavigationTab.values` in `navigation_provider.dart`, which is
         indexed positionally and referenced elsewhere by `.index`
         (`.beats.index`, `.live.index`) — instead its `routes` fall back to a
         single `GoRoute(path: AssistantRouteNames.assistant, redirect: (_,
         __) => '/money')`, so a stray `/mind` (including the `/agent` and
         `/assistant` legacy rewrites, which target this same path) lands
         somewhere real instead of a 404.

      **A locked test had to change.**
      `assistant_route_parity_test.dart` had `'the router refuses to start
      without the mind module'`, asserting the exact opposite of the new
      contract. Renamed to assert the router now starts successfully and
      falls back correctly (Mind branch redirects, Wellbeing absent). This is
      the deliberate behavior change task 4.4 called for, not a regression.

      **Two bugs found only by running the full suites, not by analyze:**
      - `buildMainModuleRegistry()`'s first attempt called `registerMind`
        *after* `IptvFeatureModule`, changing `registry.moduleIds` from
        `[coin_vault, mind, iptv]` to `[coin_vault, iptv, mind]`.
        `main_super_app_shell_test.dart` asserts that order exactly (module
        registration order, not route order) — fixed by registering Mind
        between the two, preserving the original sequence.
      - `navigation_provider_test.dart`'s `'uses stable root paths for each
        tab'` asserted the Mind tab's path is `/assistant` — stale since
        Phase 3 moved the hub root to `/mind`
        (`AssistantRouteNames.assistant == '/mind'`). Confirmed failing on
        unmodified `main` too (unrelated to this change, just never caught);
        fixed the literal since it sits directly in the file this phase
        touches.
      - Not a code bug, but cost real time: a **fresh worktree has no
        `build_runner` output**. `packages/feature_mind`'s freezed unions
        (`minutes.freezed.dart`, `meetings.freezed.dart`) are gitignored and
        only exist after `dart run build_runner build` — without them,
        `flutter test` fails with "isn't a type" errors on generated
        `GenerationEvent_*`/`TranscriptEvent_*` variants that look like a
        real compile break but are actually just missing codegen. Analyze
        doesn't hit this (no generated-code type checking on the files that
        need it); only a real `flutter test` run surfaces it, which is part
        of why this phase's instructions insist on running the suites and not
        trusting a clean analyze.

      **Verified, not just claimed clean:**
      - `flutter analyze` on `app` — 0 issues.
      - `flutter test` in `packages/feature_mind` — 357/357.
      - `flutter test test/rules/r05_private_devices_test.dart` in
        `feature_mind` — 6/6 (was 2 failing on `main` before this fix: `'the
        gate passes the current tree'`, the direct R05 regression, plus
        `'the gate fails when web sources reach the module'`, which was
        separately stale — it wrote a probe file to `app/web/*.dart`, a check
        `check-mind-private-devices.sh`'s own comments say was already
        replaced by the `main.dart`-based check because `app/web` never
        contains `.dart` files. Rewrote it to mutate `main.dart` with a
        direct `MindModule(...)` construction instead, matching what the
        script actually checks now).
      - `scripts/check-mind-private-devices.sh` — exit 0, "R05 OK: no
        shared-surface flavor links feature_mind."
      - `flutter test` in `app` — 1040 passed, 0 failed, 2 skipped.
      - `cd app && flutter build web --release` — real compiled build,
        `✓ Built build/web` (not just analyze — task 4.4's own instructions
        called out that a clean analyze isn't sufficient evidence, since a
        prior attempt this session compiled clean and would have crashed at
        runtime).

      **Superseded, same session.** This landed as PR #1566. A second,
      independent session was working the identical problem in parallel (this
      is a 20-worktree repo; concurrent sessions on the same task happen) and
      merged PR #1567 ~2 hours later with a more complete fix, which is what
      `main` actually carries now:
      - The conditional import direction is inverted and for a real reason,
        not style: `main.dart` now imports the **stub by default**, switching
        to the real registration only `if (dart.library.io)`. This session's
        `dart.library.html` condition is false under `dart2wasm` (`--wasm`
        builds), which would have silently linked the real module into a wasm
        web build — an R05 violation the static gate cannot see, since the
        compiler resolves the condition before the gate ever runs. Keying the
        real module off `dart.library.io` instead means every non-native
        target (dart2js *and* dart2wasm) falls back to the stub, and only
        native platforms opt in.
      - The Mind tab is fully removed from web's bottom nav
        (`AppNavigationPolicy.without`, keyed on `registry.isRegistered('mind')`),
        not just redirected — better UX than this session's redirect-only
        fallback, which this note's earlier draft had accepted as sufficient.
      - The R05 gate script itself was hardened with four new mutation tests
        (`r05_private_devices_test.dart` went from this session's 6/6 to
        9/9), closing gaps a single `MindModule(` grep alone left open — a
        plain `import 'package:feature_mind/...'` with no construction call,
        for one.
      - Confirmed web bundle shrinks 8.0% (560,708 bytes) with the fix in.

      This session's PR #1566 was not wasted — it was the first fix to
      actually green the R05 gate, unblocked CI, and both the router's
      `_optionalModule` shape and the "branch keeps its slot" reasoning
      carried forward unchanged into #1567. But the mechanism this section
      describes above (`dart.library.html`, redirect-only Mind branch) is
      history, not what's running. Read `packages/feature_mind/lib/src/mind_availability.dart`
      and `app/lib/core/mind/` on current `main` for the shipped shape.
- [x] **4.5** `cd app && flutter build web --release` succeeds — true on
      `main` (verified again post-#1567 via a fresh `origin/main` checkout
      this session).
- [x] **4.6** `scripts/check-mind-private-devices.sh` passes (R05) — true on
      `main`, 9/9 on the calibrated rule suite (see above).
- [x] **4.7** Device walk on **both** shells, on a Pixel 9 (device connected
      mid-session; USB, screen unlocked, verified via `adb`). Two build
      fixes were needed first, neither related to R05 and both environment/
      config issues exposed by this being the first time `feature_mind`
      compiled as part of the phone flavor:
      - Homebrew's `cargo` shadows `rustup`'s on PATH and reports it can
        target `aarch64-linux-android` without actually having `libcore` for
        it (the exact gotcha Phase 0 documented for the standalone shell,
        now also hitting the phone build). Worked around with
        `PATH="$HOME/.cargo/bin:$PATH"` for the build command, not a source
        change.
      - `packages/feature_mind/android/build.gradle` pinned `compileSdk =
        35`; `flutter_local_notifications` (linked by the phone flavor)
        requires 36+, and Gradle's AAR metadata check fails the whole build
        on the mismatch. A different concurrent session fixed this
        independently too (visible on `main` as of PR #1569, "align
        feature_mind compileSdk") — same root cause, same fix, arrived at
        separately.

      **Phone shell** (`io.airo.app`, real `MindModule`): signed in, landed
      on the Mind hub directly. Confirmed rendering with no crash across the
      hub list, AI Chat (detected Gemini Nano on-device), Prompt Lab, Device
      Capability Report (real Pixel 9 hardware facts: Tensor G4, 8 cores,
      1675 MB available of 11571 MB, on-device AI available), and Wellbeing
      (reached via the top-level root route outside the Mind branch, with
      real streak/reflection state — a 4-day streak, 2 reflections that
      week). Coins and Live tabs confirmed the rest of the shell is
      unaffected (Live hit an unrelated pre-existing crash --
      `feature_iptv`'s `secureStoreProvider` has no override wired in
      `main_provider_overrides.dart`, reproduces on unmodified `main` too,
      nothing to do with Mind; spawned as a separate follow-up).

      **Standalone Mind shell** (`io.airo.app.mind`,
      `AIRO_MIND_BUILD_MODE=debug scripts/build-mind.sh`): launched clean on
      Scribe (empty meetings list, Record button), Assistant (same hub), and
      Wellbeing tabs. This shell uses its own router (`buildMindRouter`, not
      `AppRouter`) and was never at risk from the R05 fix — walked it anyway
      since it shares `feature_mind` and confirms the compileSdk fix doesn't
      regress it.

      **Not exercised**: the full first-run-download → record → transcribe →
      minutes → search flow. Phase 1 already spent significant time on this
      exact path and hit device-specific WorkManager foreground-service
      flakiness unrelated to any code in this repo, with a user-confirmed
      decision to ship on file-level verification rather than keep
      re-touching a device in a bad state (see Phase 1's Checkpoint 1 above).
      Re-running a multi-hundred-MB download on the same rig wasn't a
      productive use of this walk when the actual purpose here — confirming
      Mind still works on real hardware on both shells after two rounds of
      router/build fixes -- was already conclusively demonstrated by what was
      walked.
- [x] **4.8** PR + merge. This session: [PR #1566](https://github.com/DevelopersCoffee/airo/pull/1566)
      (merged). Superseding fix, same day: [PR #1567](https://github.com/DevelopersCoffee/airo/pull/1567),
      [PR #1568](https://github.com/DevelopersCoffee/airo/pull/1568),
      [PR #1569](https://github.com/DevelopersCoffee/airo/pull/1569) (all
      merged to `main`).

**Checkpoint 3** — phone APK size: 104,141,179 → 113,826,086 bytes (99.32 →
108.55 MiB, +9.3%), still inside the 120 MiB budget. Cold-build time not
captured either side (see 4.1). Two native engines now cross-compile on
every super-app build.

## Carried over, not part of this plan

- [x] Journey coverage spec — composition half
      (`docs/superpowers/specs/2026-08-06-airo-mind-journey-coverage.md`,
      T3–T8): implemented and verified on `main` as of 2026-08-09
      (`packages/feature_mind/test/mind_service_test.dart`, 7/7 passing).
      This entry was stale — the tests already existed when it was last
      checked; re-verified by running them rather than assumed.
- [ ] Journey coverage spec — device journey half: still not done.
      `app/integration_test/mind_journey_device_test.dart` does not exist.
      Needs a real device with the ~570 MB models installed to write *and*
      run against — not attempted here, same discipline as not guessing at
      an unverifiable native contract elsewhere in this plan.
- [ ] iOS (#1546 phase 4) — has never built; needs dynamic frameworks.
