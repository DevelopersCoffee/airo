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
incident) rather than keep re-touching a device in a bad state. **Redo the full
clean walk before this is treated as fully proven.**

**Checkpoint 1** — APK size before/after not fully re-measured (release build
not re-run after the fix); first-run-on-a-real-connection story is proven
piecewise (file+hash correctness) but not as one continuous walk. Offline
first-run no longer works, as intended — confirm that trade is still accepted
before Phase 4 repeats it for the super app.

## Phase 2 — merge feature_assistant into feature_mind

- [ ] **2.1** Council: agree the merged package's owner (AI/Brain Agent vs
      Product Manager). Blocks the rest of the phase.
- [ ] **2.2** `git mv` the four trees (`assistant`, `agent_chat`, `wellbeing`,
      `quotes`) into `packages/feature_mind/lib/src/`; same for `test/`
- [ ] **2.3** Merge `AssistantModule` + `MindScribeModule` into one `MindModule`
      exporting the combined route table
- [ ] **2.4** Widen `packages/feature_mind/module.yaml` `allowed_dependencies`
      to `core_ai`, `core_ui`, `core_product_shell`, `core_domain`, `core_data`;
      keep `forbidden_dependencies: [app]`
- [ ] **2.5** Update both shells to register `MindModule`
- [ ] **2.6** Delete `packages/feature_assistant/`
- [ ] **2.7** `cd packages/feature_mind && flutter test`;
      `assistant_route_parity_test.dart` passes unchanged
- [ ] **2.8** Module-manifest gate passes
- [ ] **2.9** PR + merge

**Checkpoint 2** — council sign-off on the owner, and explicit written
confirmation that the assistant leaving web/TV is understood as removing shipped
functionality from two surfaces.

## Phase 3 — claim /mind

- [ ] **3.1** Move `/assistant/*` paths to `/mind/*`, keeping every route
      **name** unchanged (names are what notifications and deep links resolve)
- [ ] **3.2** Redirect old `/assistant/*` paths
- [ ] **3.3** Invert the legacy mapping in
      `notification_navigation_service.dart:91` (`/mind` → `/assistant` becomes
      the reverse)
- [ ] **3.4** Retire `app/test/core/routing/mind_name_is_free_test.dart` — the
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
