# Airo Mind — one package, one route tree, one model pipeline

Full plan: see the Context, Dependency graph, Phases, Files, Verification and
Risks sections below. Task checklist lives in `tasks/todo.md`.

## Context

"Airo Mind" means two different products depending on which app you open:

| | Super app Mind tab | Airo Mind standalone |
|---|---|---|
| Assistant hub (chat, models, prompt lab, wellbeing) | ✅ `AssistantModule` | ✅ same module |
| Scribe (record → transcribe → minutes → search) | ❌ absent | ✅ `MindScribeModule` |

`feature_mind` is not in `app/pubspec.yaml` at all. The split shows in the names
too: the product is Mind, the package is `feature_assistant`, the routes are
`/assistant/*`, and `/mind` sits reserved and empty
(`app/test/core/routing/mind_name_is_free_test.dart` — *"Airo Mind claims /mind
in P4"*).

**Outcome:** one package, one route namespace, one model pipeline, and a Mind
tab in the super app that is the same product as the standalone app.

### Decisions taken

1. **One package** — `feature_assistant` (69 files, 15.6k lines) folds into
   `feature_mind` (44 files, 6.9k lines).
2. **Super app carries the engines** — real whisper + llama in the phone build.
3. **Claim `/mind` now** — `/assistant/*` becomes `/mind/*`. This is P4.
4. **Mind is private-devices only** — accepted consequence of R05: the assistant
   hub leaves web and TV with the scribe. This removes shipped functionality
   from two surfaces and is intended.
5. **No bundled models in either app** — both the super app and the standalone
   app move onto `core_ai`'s `ModelDownloadService`. Neither ships model
   weights in the APK.
6. **Both seams are abstracted, not hardcoded** — `ModelProvider` behind model
   acquisition, `MindSpeechBridge`/`MindGenerationBridge` behind the engines.
   Design: `docs/superpowers/specs/2026-08-07-airo-mind-abstraction-layer.md`.
   This is what makes T3–T8 in the journey-coverage spec writable, and what
   lets the download source change later without touching `MindService`.

Decision 5 is what makes decision 2 affordable: the engines are ~5 MB of `.so`;
the ~570 MB is model weights.

## Dependency graph

```
core_ai (ModelDownloadService, ModelStorageManager, ModelDownloadProgress)
   ↑
feature_mind  ← merged: scribe + MindRuntime port + assistant hub
   ↑                    module.yaml allowed_dependencies: [] must widen
   ├── app (super app)      main.dart registers MindModule
   ├── app (main_mind.dart) registers the same MindModule
   └── packages/stubs/feature_mind_stub   ← web + TV swap it in (R05)

rust/airo_mind_{core,whisper,llama}   unchanged by this work
```

Hard constraints, all pre-existing:

- **R05 is gated** (`scripts/check-mind-private-devices.sh`). Web and TV must
  not link the real `feature_mind`.
- **`ADR-0018 §1`: the runtime never acquires models.** Downloading is Dart-side
  in `core_ai`; Rust stays free of an HTTP client, which
  `build_runtime_pod.sh` already checks on the shipped binary.
- **`ADR-0021` freezes the `MindRuntime` port.** The merge must not edit it.
- **Two council owners** — `feature_assistant` is AI/Brain Agent, `feature_mind`
  is Product Manager. The merged package needs one, agreed before Phase 2.

## Phases

Each lands as its own PR off `origin/main`.

### Phase 0 — unblock debug builds (blocks everything)

`feature_mind` in a debug build fails today: cargokit adds x86 ABIs for debug
only, and `whisper-rs-sys` falls back to bundled 64-bit bindings that fail
const-eval on i686 (`12_usize - 16_usize` overflow). The moment `feature_mind`
enters `app/pubspec.yaml`, every super-app debug build breaks.

**Done.** Sysroot fix (`BINDGEN_EXTRA_CLANG_ARGS`) eliminated the const-eval
crash, but exposed a second, host-specific CMake failure on i686
(`unsupported option '-arch'` — an Apple flag reaching an Android cross-compile
from macOS). x86 Android is emulator-only and no device in this project's rig
uses it, so the engines are now declared `arm64` only, per library, in
`packages/feature_mind/android/build.gradle` (cargokit's Gradle plugin gained
an optional per-library platform list to express this).

- **Acceptance:** `flutter build apk --debug` succeeds with `feature_mind` on
  the dependency path. ✅ verified: 707 MB debug APK built, installed on the
  Pixel 9, launched, PID stayed alive.
- **Verify:** `AIRO_MIND_BUILD_MODE=debug scripts/build-mind.sh`. ✅

### Phase 1 — model acquisition moves to `core_ai`, behind `ModelProvider`

Design: `docs/superpowers/specs/2026-08-07-airo-mind-abstraction-layer.md`.

Introduce `ModelProvider` (abstract). `ModelInstaller`'s bundled-asset behaviour
becomes one implementation, demoted from the only path. `DownloadModelProvider`
wraps `ModelDownloadService` + `ModelStorageManager`
(`packages/core_ai/lib/src/download/` — already has pause/resume/retry/cancel/queue
restore) and becomes the default for **both** apps — neither ships model weights
in the APK. Keep the pinned SHA-256 digests in `rust/airo_mind_core/src/models.rs`
as the verification; only the source of bytes changes. Drop `assets/models/`
from `pubspec_mind.yaml`; keep `fetch_mind_models.sh` as a dev seeding
convenience.

At the same time, introduce `MindSpeechBridge` / `MindGenerationBridge` behind
`MindService.process()` — same spec, §3. Both seams land in one PR: both
concrete dependencies are being replaced in this window, and building the
interface once is cheaper than building `DownloadModelProvider` against a
concrete `ModelInstaller` and re-deriving the interface after.

- **Acceptance:** fresh install downloads both models via `DownloadModelProvider`,
  verifies them against the pinned digests, APK no longer carries ~570 MB;
  `MindService` accepts a `ModelProvider` and both bridges via constructor
  injection, defaults unchanged in production behaviour.
- **Verify:** install on the Pixel, first-run download, then the full journey;
  `verify_installed_models` reports both verified; `flutter test` in
  `feature_mind` covers `DownloadModelProvider` and T3–T8 with fakes, no
  network, no native library.

**Checkpoint 1:** APK size before/after, and first-run on a real connection.

### Phase 2 — merge `feature_assistant` into `feature_mind`

`git mv` the four trees (`assistant`, `agent_chat`, `wellbeing`, `quotes`) into
`packages/feature_mind/lib/src/`, same for `test/`. Merge the two `AppModule`s
into one `MindModule` exporting the combined route table. `module.yaml` gains
`core_ai`, `core_ui`, `core_product_shell`, `core_domain`, `core_data`.

- **Acceptance:** one package, one module, both shells register `MindModule`,
  `feature_assistant` gone, module-manifest gate passes.
- **Verify:** `cd packages/feature_mind && flutter test`;
  `assistant_route_parity_test.dart` passes unchanged.

**Checkpoint 2:** council sign-off on the merged owner, and explicit
confirmation that the assistant leaving web/TV is understood.

### Phase 3 — claim `/mind`

Move `/assistant/*` paths to `/mind/*`. **Keep every route *name* stable** —
names are what notifications and deep links resolve, and changing paths and
names together makes a failure impossible to attribute. Invert the legacy
mapping in `notification_navigation_service.dart:91` (today `/mind` →
`/assistant`). Retire `mind_name_is_free_test.dart`: the reservation has been
claimed by its intended owner.

- **Acceptance:** `/mind/*` resolves everywhere, old paths redirect, no route
  name changed.
- **Verify:** route-parity test, plus a notification payload with an old path
  resolving to the new one.

### Phase 4 — the super app carries Mind

Add `feature_mind` to `app/pubspec.yaml`; register `MindModule` in `main.dart`
beside `CoinVaultModule` and `IptvFeatureModule`. Web and TV keep the stub.

- **Acceptance:** the super app's Mind tab is the same product as the standalone
  app, scribe included; `check-mind-private-devices.sh` passes; web still builds.
- **Verify:** `cd app && flutter build web --release`;
  `scripts/check-mind-private-devices.sh`; device walk on both shells.

**Checkpoint 3:** phone APK size and cold-build time before/after.

## Files

**Moved:** `packages/feature_assistant/lib/src/{assistant,agent_chat,wellbeing,quotes}`
→ `packages/feature_mind/lib/src/`; same for `test/`.

**Modified:** `packages/feature_mind/{module.yaml,pubspec.yaml}`,
`app/lib/main.dart`, `app/lib/main_mind.dart`,
`app/lib/core/routing/app_router.dart`, `app/pubspec.yaml`,
`app/pubspec_mind.yaml`, `packages/feature_mind/lib/src/model_installer.dart`,
`notification_navigation_service.dart`.

**Deleted:** `packages/feature_assistant/`,
`app/test/core/routing/mind_name_is_free_test.dart`, the `assets/models/`
staging.

**Reuse, do not reinvent:** `ModelDownloadService`, `ModelStorageManager`,
`ModelDownloadProgress` (`packages/core_ai/lib/src/`); `MindScribeModule` and
`AssistantModule` as the two halves of `MindModule`;
`packages/stubs/feature_mind_stub` for web/TV; the `scripts/check-mind-*.sh`
POSIX-grep idiom with a positive control (CI has no ripgrep).

## Verification

```bash
cd packages/feature_mind && flutter test
cd app && flutter test test/assistant_route_parity_test.dart
cp app/pubspec_mind.yaml app/pubspec.yaml && cd app && flutter pub get
flutter test test_mind/ --dart-define=APP_VARIANT=mind
cd app && flutter build web --release
scripts/check-mind-private-devices.sh
AIRO_MIND_BUILD_MODE=release scripts/build-mind.sh
```

**End to end on the Pixel 9, both shells.** First-run model download, record →
transcribe → minutes → search, and `/mind` → chat → model library → prompt lab →
wellbeing. The super app is the case that has never existed; the standalone is
the regression check.

## Risks

- **Removing the assistant from web and TV is a product regression**, accepted
  under R05. Announce it, do not merely merge it.
- **Debug builds are the blocker** (Phase 0). Merging first leaves the super app
  unbuildable in debug.
- **`feature_mind` becomes large** — ~113 files, ~22.5k lines, holding a frozen
  runtime port and a large AI hub. Deliberate acceptance, not a later discovery.
- **First run changes character**: models move from the APK to a download, so
  offline first-run stops working until they land.
