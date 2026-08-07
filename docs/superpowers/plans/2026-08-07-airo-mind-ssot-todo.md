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
- [x] **1B.2** `app/lib/core/mind/mind_model_source.dart` — new file, builds
      `DownloadModelProvider` wired to the real HuggingFace URLs
      `fetch_mind_models.sh` already used, keyed by the pinned file names.
      `MindScribeModule._defaultService` wires it into `MindService`. The super
      app has no `MindScribeModule` registration yet (Phase 4), so only the
      standalone shell is cut over in this phase.
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

## Phase 3 — claim /mind  (3.1-3.4 done; 3.5 tests deferred)

- [x] **3.1** Move `/assistant/*` paths to `/mind/*`, keeping every route
      **name** unchanged (names are what notifications and deep links resolve)
- [x] **3.2** Redirect old `/assistant/*` paths
- [x] **3.3** Invert the legacy mapping in
      `notification_navigation_service.dart:91` (`/mind` → `/assistant` becomes
      the reverse)
- [x] **3.4** Retire `app/test/core/routing/mind_name_is_free_test.dart` — the
      reservation has been claimed by its intended owner
- [ ] **3.5** Tests: route parity, redirect coverage, and a notification payload
      carrying an old path
- [ ] **3.6** PR + merge

## Phase 4 — the super app carries Mind

- [ ] **4.1** Record the baseline: phone APK size and cold-build time
- [ ] **4.2** Add `feature_mind` to `app/pubspec.yaml`
- [ ] **4.3** Register `MindModule` in `main.dart` beside `CoinVaultModule` and
      `IptvFeatureModule`
- [ ] **4.4** Confirm web and TV still swap in `feature_mind_stub`
- [ ] **4.5** `cd app && flutter build web --release` succeeds
- [ ] **4.6** `scripts/check-mind-private-devices.sh` passes (R05)
- [ ] **4.7** Device walk on **both** shells: first-run download, record →
      transcribe → minutes → search, `/mind` → chat → models → prompt lab →
      wellbeing
- [ ] **4.8** PR + merge

**Checkpoint 3** — phone APK size and cold-build time before/after. Two native
engines now cross-compile on every super-app build.

## Carried over, not part of this plan

- [ ] Journey coverage spec
      (`docs/superpowers/specs/2026-08-06-airo-mind-journey-coverage.md`) — T3/T4/T5
      restore the tests deleted in #1549. Still an open regression.
- [ ] iOS (#1546 phase 4) — has never built; needs dynamic frameworks.
