# Airo Mind — split the runtime into two cdylibs

**Date:** 2026-08-06
**Status:** Draft, pre-implementation
**Issue:** #1546
**Follows:** #1545 (the three build-wiring causes around this one)
**Touches a frozen surface:** ADR-0021 `MindRuntime` port — see §6

## 1. Objective

Make the Airo Mind runtime linkable on every platform it ships to, so an
installable APK exists and the Mind journey can be exercised on hardware. No
device has ever run it.

`whisper-rs-sys` and `llama-cpp-sys-2` each statically vendor **their own**
copy of ggml. Both are linked into the single `airo_mind_runtime` cdylib, and
the link fails:

```
ld.lld: error: duplicate symbol: ggml_backend_buffer_free
ld.lld: error: duplicate symbol: ggml_backend_buft_alloc_buffer
... 20+ total
```

The two trees differ by **348 files**; `ggml.h` differs by 121 lines. So
`-Wl,--allow-multiple-definition` is excluded: it resolves duplicates by taking
the first definition, which binds one library's callers to the other's struct
layouts — memory corruption at run time in place of an error at build time.

Each engine links cleanly on its own (verified, `aarch64-linux-android`):
whisper alone → 16.7 MB `.so`, llama alone → 48.7 MB. Only co-residency in one
linked object fails.

**Target users:** Airo Mind users on private devices (R05 — phone, tablet,
desktop; never web or TV). Nothing about the product surface changes. This is
invisible to them except that the app exists.

## 2. Scope

Split `airo_mind_runtime` into three crates:

| Crate | Type | Contents |
|---|---|---|
| `airo_mind_core` | rlib | supervisor, engine traits, budget, cancel, store, search, models, wav, digest |
| `airo_mind_whisper` | cdylib | `whisper.rs` + its own FRB bridge |
| `airo_mind_llama` | cdylib | `llama.rs` + its own FRB bridge |

`engine.rs` already defines `SpeechEngine` and `GenerationEngine` with the
backends behind them, so the core boundary exists today and is not being
invented here.

**All five platforms in one change** — Android, macOS, iOS, Windows, Linux.
macOS is included because it is silently affected (§7), not merely for
symmetry.

**Out of scope:** the Mind runtime's architecture, the scribe journey, the M19
vault work, any change to what the UI shows.

## 3. Commands

Existing, unchanged in name:

```bash
# APK (the acceptance gate for this work)
AIRO_MIND_BUILD_MODE=debug scripts/build-mind.sh

# Mind flavour analyzer + tests (the define is not optional)
cp app/pubspec_mind.yaml app/pubspec.yaml
cp app/analysis_options_mind.yaml app/analysis_options.yaml
cd app && flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings lib/main_mind.dart lib/core/mind
flutter test test_mind/ --dart-define=APP_VARIANT=mind

# Rust
cd rust && cargo test --workspace
cd rust/airo_mind_whisper && cargo build --target aarch64-linux-android
cd rust/airo_mind_llama   && cargo build --target aarch64-linux-android

# codegen — two configs after this change
dart run flutter_rust_bridge_codegen generate --config-file flutter_rust_bridge_mind_whisper.yaml
dart run flutter_rust_bridge_codegen generate --config-file flutter_rust_bridge_mind_llama.yaml
```

New:

```bash
# Proves the thing this spec exists for: no engine's ggml leaks into the other
scripts/check-mind-no-ggml-collision.sh
```

## 4. Project structure

```
rust/
  airo_mind_core/          # rlib — no backend deps
    src/{supervisor,engine,budget,cancel,store,search,models,wav,digest}.rs
  airo_mind_whisper/       # cdylib
    src/{lib,whisper,frb_generated}.rs
    src/api/{mod,transcribe,setup}.rs
  airo_mind_llama/         # cdylib
    src/{lib,llama,frb_generated}.rs
    src/api/{mod,generate}.rs

packages/feature_mind/
  lib/src/
    whisper/frb_generated.dart     # generated
    llama/frb_generated.dart       # generated
    library_loader.dart            # resolves BOTH, per platform
    mind_service.dart              # composes the two; the seam stops here
  android/build.gradle             # two cargokit invocations
  ios/feature_mind.podspec         # two dynamic frameworks — see §7
  macos/feature_mind.podspec       # two dylibs in the framework
  linux/CMakeLists.txt             # two apply_cargokit calls
  windows/CMakeLists.txt           # two apply_cargokit calls
```

### The API cut

The current bridge is ten functions. The cut is not even:

| Function | Lands in | Note |
|---|---|---|
| `initialize`, `is_ready`, `cancel_processing` | both | each library owns its own lifecycle |
| `list_meetings`, `search_meetings`, `get_meeting` | whisper | store and index live with transcripts |
| `required_models`, `verify_installed_models` | both | each reports only its own models |
| `process_recording` | **neither, as-is** | see below |

`process_recording` (`api/mind.rs:246`) runs transcribe → generate as one
Rust-side pipeline and streams `ProcessingEvent`. That pipeline is exactly what
now spans two libraries. It splits into `transcribe_recording` (whisper) and
`generate_minutes` (llama), with `MindService` composing them and re-emitting
the same `ProcessingEvent` sequence so the UI is untouched.

## 5. Testing strategy

Follows the repo's existing rule-as-test discipline: each rule gets a test
whose only failing cause is removing that rule's enforcement.

| # | Property | Test |
|---|---|---|
| T1 | Neither cdylib exports ggml symbols | `check-mind-no-ggml-collision.sh` over both built libraries |
| T2 | Each engine links alone on every target | per-crate `cargo build` in CI |
| T3 | `ProcessingEvent` sequence is unchanged after the split | Dart test against a fake pair of bridges |
| T4 | Cancellation mid-pipeline stops **both** libraries | Dart test, cancel between transcribe and generate |
| T5 | llama is not loaded until first generation | Dart test asserting the loader is untouched after a transcribe-only run |
| T6 | `MindUnavailable` still surfaces when either library is absent | existing `RustMindRuntime` tests, extended per library |
| T7 | The APK installs and launches | `scripts/build-mind.sh` + device |

T1 is the mutation test for this whole change: it fails if anyone recombines
the engines.

**Load timing:** llama loads lazily, on first generation. It is 48.7 MB and
only minutes need it, so record → transcribe pays nothing for it. First
summarize therefore has a load latency that needs a real UI state, not a silent
pause — that state is part of this work, not a follow-up.

## 6. Boundaries

**Always**

- Keep `packages/feature_mind`'s public Dart API unchanged. The two-library
  split is an implementation detail; `MindService` is where it stops.
- Keep the `MindRuntime` port (ADR-0021) as the contract. If the split cannot
  satisfy it, file an ADR — do not edit the port.
- Both engines stay reachable in one session. The Mind journey is record →
  transcribe → **minutes** → search.
- Every parse or transform over ~50 KB stays off the main isolate.

**Ask first**

- Any change to the `MindRuntime` port, the seven primitives, or invariants
  I1–I8. The architecture is frozen at v1.
- Moving Supervisor responsibility into Dart beyond composing the two calls.
  Budget (C6) and cancellation (I7) are runtime properties; routing from Dart
  must not quietly become orchestrating from Dart. **This is the main design
  risk in the chosen approach** and needs chief-architect sign-off.
- Adding a dependency — including any shared-ggml crate such as
  `blazen-ggml-sys`. Requires chief-open-source-officer review.

**Never**

- `-Wl,--allow-multiple-definition`, or any other flag that resolves the ggml
  duplicates by picking a winner. It converts a build error into silent ABI
  mixing across 348 differing files.
- Ship a fix that makes Android link by removing an engine from the product.
- Put real Firebase keys, model URLs, or secrets in a tracked file.
- Enable Mind on web or TV. R05 is a security property, enforced at link time.

## 7. Per-platform notes

**Android.** Cargokit's Gradle extension takes a single `manifestDir`/`libname`
(`cargokit/gradle/plugin.gradle:16-17`, task name derived from `libname` at
:156). Two libraries need either two applications of the extension or a loop
over a list — a change to the vendored cargokit, which is already patched here
for Gradle 9.

**iOS — the hardest, and the reason this is not a small change.** The podspec
links a **static** `libairo_mind_runtime.a` into the app binary and keeps the
bridge alive with `-Wl,-u,` entry points (`ios/feature_mind.podspec:46,50-60`).
Two static archives, each carrying its own ggml, collide at app-link time in
exactly the way Android does now. Static linking cannot express this split.
iOS must move to two dynamic frameworks, which also means revisiting the
`ExternalLibrary.process(...)` path in `library_loader.dart:30-32`.

iOS also has no CI — every Mind job in `ci.yml` and `pr-checks.yml` is
`ubuntu-latest` — and iOS was explicitly out of scope in the original Mind
modular-app design. So its current state is unknown, and "support iOS" here may
mean *bringing the platform up* rather than preserving something that works.

That is why the **iOS feasibility spike comes first** (§9) while the iOS
*implementation* comes last: the answer to "can iOS do this at all" reshapes the
scope, and it is far cheaper to learn before the other platforms are built than
after.

**macOS.** `library_loader.dart:26-29` already records that macOS ships a dylib
*because* the two ggml copies collide. That is a route around, not a fix: the
link succeeds only because static-archive members load lazily, which means one
engine is most likely already calling the **other's** ggml today. Nothing has
verified which copy wins. **First task on macOS is to confirm this at symbol
level**, so the split is measured against a known state rather than a guess.

**Linux / Windows.** `apply_cargokit(...)` is called once per CMakeLists
(`linux/CMakeLists.txt:10`, `windows/CMakeLists.txt:10`); it takes the library
name as an argument, so a second call is the whole change. Lowest risk — do
these first to prove the crate split before touching iOS.

## 8. Acceptance criteria

1. `scripts/build-mind.sh` produces an installable APK.
2. Both engines usable in one session on a Pixel 9: record → transcribe →
   minutes → search.
3. T1–T6 green in CI; T7 walked on device.
4. macOS ggml ambiguity resolved and stated, not inherited.
5. `feature_mind`'s public Dart API unchanged — diffable, and proven by the
   existing tests passing untouched.
6. No new dependency without the governance review named in §6.

## 9. Order

0. **iOS feasibility spike — read-only, first.** Two questions, no code moved:
   does `feature_mind` build for iOS today at all, and can two dynamic
   frameworks replace the static archive? A negative answer changes the platform
   scope, and that is worth knowing before anything is built on the assumption.
1. **Linux + Windows** — cheapest proof the crate split is sound.
2. **Android** — unblocks device dogfood.
3. **macOS** — resolve the latent ggml ambiguity, diagnosis before change.
4. **iOS** — highest risk, shaped by step 0's answer.

Each phase lands as its own PR off `origin/main`.
