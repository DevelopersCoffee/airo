# Airo Mind Rust Build Wiring

## Scope

Audits how the Airo Mind Rust crates cross-compile and link into the Flutter
app today, confirms the story is reproducible, and records what a future
milestone crate should (and should not) copy. Written for #1655
(`MIND-LLM-14`, epic #1627, Milestone 26) — the milestone's own framing is
that Rust surface under `rust/` has grown past `feature_mind`'s original two
engines, and the build story needs to be deliberate rather than improvised
per crate.

This document does not add a new CI matrix or workflow (see
[Cost-Control](#cost-control) below) and does not introduce new build
infrastructure — every claim below was verified by running the actual build
command in this repo, not inferred from config.

## Crate inventory

| Crate | `crate-type` | FFI surface | Vendored C/C++ |
|---|---|---|---|
| `airo_mind_whisper` | `cdylib`, `staticlib`, `rlib` | Yes — `whisper` FRB bridge | whisper.cpp (via `whisper-rs`) |
| `airo_mind_llama` | `cdylib`, `staticlib`, `rlib` | Yes — `llama` FRB bridge | llama.cpp (via `llama-cpp-2`) |
| `airo_mind_meeting` | `rlib` only | None | None |
| `airo_mind_reasoning` | `rlib` only | None | None |
| `airo_mind_intent` | `rlib` only | None | None |
| `airo_mind_transcript` | `rlib` only | None | None |
| `airo_mind_core` | `rlib` (workspace dep) | None (linked into both engine cdylibs) | None |
| `airo_core` | `cdylib`/`staticlib` (via `core_native`) | Yes — `core_native` FRB bridge | None |

`airo_mind_meeting` (Meeting IR schema + two-pass extraction, #1633) and
`airo_mind_transcript` (chunking, #1632) are **pure Rust, `rlib`-only, and
deliberately carry no FFI surface of their own** — both crates' own doc
comments say so. They are library dependencies of whichever cdylib drives
the pipeline (today: nothing yet: `airo_mind_llama` does not depend on
`airo_mind_meeting` as of this writing — extraction is invoked from Dart by
constructing prompts against `GenerationEngine`, not by linking the crate
into a bridge). This is intentional, not a gap: declaring a bridge for a
crate with no engine of its own would link an empty extra artifact on every
build, the same reasoning `airo_mind`'s own Cargo.toml already documents.
There is no separate eval crate yet (#1636 has not landed) — nothing here
should be read as covering it.

## Per-platform build mechanism

Both engine crates are wired through **cargokit**, Flutter's own
Rust-FFI-plugin build tool, vendored (not hand-rolled) at
`packages/feature_mind/cargokit/` and, identically, at
`packages/core_native/cargokit/` (verified byte-identical with
`diff -rq` between the two directories — copying the vendored directory
verbatim is the supported reuse path for a new package).

- **Android** — `packages/feature_mind/android/build.gradle` applies
  cargokit's `gradle/plugin.gradle` and calls its `library()` task twice, once
  per engine, restricted to `engineAbis = ["android-arm64"]`. 32-bit and x86
  Android are excluded on purpose: `whisper-rs-sys` cannot generate bindings
  without a sysroot on i686, and `llama-cpp-sys-2`'s build script panics on
  `armv7-linux-androideabi`. A device without arm64 degrades to
  `MindUnavailable` in the UI rather than failing the build.
  `packages/core_native/android/build.gradle` uses the same plugin but the
  simpler single-crate `manifestDir`/`libname` form (no engine collision to
  work around), and is not ABI-restricted.
- **macOS** — `packages/feature_mind/macos/feature_mind.podspec` declares two
  custom CocoaPods `script_phases` per engine (build, then embed), wrapping
  `tool/build_runtime_pod.sh` / `tool/embed_runtime.sh`, which in turn wrap
  cargokit's own `build_pod.sh`. macOS consumes the **cdylib**
  (`.dylib`), not the static archive — see [Why two libraries](#why-two-libraries-per-engine-everywhere).
- **iOS** — the podspec exists (`packages/feature_mind/ios/feature_mind.podspec`)
  but is **not wired**: `feature_mind`'s `pubspec.yaml` omits `ios` from
  `flutter.plugin.platforms` (dropped deliberately in #1704/#1717), so no iOS
  build is ever attempted. The podspec's own header documents why: iOS links
  static archives *into* the app binary rather than loading dylibs, so the
  whisper.cpp/llama.cpp ggml symbol collision (below) reproduces there in a
  form macOS's dylib-per-engine trick cannot fix. Tracked by #1546 phase 4.
  `core_native`'s iOS podspec has no such restriction (no colliding engine),
  and is wired.
- **Linux/Windows** — declared (`linux/CMakeLists.txt`,
  `windows/CMakeLists.txt`) and buildable via the same cargokit path, but no
  bundled model or local workflow in this repo currently exercises them.

### Why two libraries per engine, everywhere

whisper.cpp and llama.cpp each statically vendor their own copy of ggml under
identical symbol names. One library containing both is a one-definition-rule
conflict, not a missing flag: Android's `lld` refuses to link it outright,
and Apple's linker accepts a merged static archive but silently picks one
implementation per symbol (591–592 duplicate symbols, measured, not
estimated — see the comments in `airo_mind_whisper/Cargo.toml`,
`airo_mind_llama/Cargo.toml`, and both podspecs). Keeping the two engines as
separate `cdylib`s keeps their ggml copies in separate linked images, which
is why there are two Gradle `library()` calls, two sets of podspec script
phases, two `library_loader.dart` init paths, and — per crate — three
`crate-type` entries (`cdylib` for Android/macOS, `staticlib` because
cargokit's pod flow expects one, `rlib` so the crate can also be linked as an
ordinary workspace dependency by tests or future in-process callers).

## flutter_rust_bridge wiring

One `flutter_rust_bridge*.yaml` at the repo root per engine, each gated on
the crate's real backend feature so an accidental default-feature build does
not silently generate empty bindings:

- `flutter_rust_bridge.yaml` → `rust/airo_core` → `packages/core_native/lib/src`
- `flutter_rust_bridge_mind_whisper.yaml` → `rust/airo_mind_whisper` (feature
  `whisper`) → `packages/feature_mind/lib/src/whisper`
- `flutter_rust_bridge_mind_llama.yaml` → `rust/airo_mind_llama` (feature
  `llama`) → `packages/feature_mind/lib/src/llama`

`flutter_rust_bridge` is pinned to the identical `=2.11.1` in every
`Cargo.toml` and `pubspec.yaml` that uses it — two FRB versions in one app is
a link-time conflict, not a warning, per the in-file comments. There is no
shared/base FRB config; a new engine crate needs its own YAML, hand-written
from an existing one. `packages/feature_mind/lib/src/library_loader.dart`
hand-writes a `_once()` idempotency guard per bridge (`RustLib.init()`
throws on a second call); this is bespoke per-package logic, not generated,
and not shared with `core_native`.

Each engine crate carries its own `cargokit.yaml` (e.g.
`rust/airo_mind_llama/cargokit.yaml`) that force-passes
`--features llama`/`--features whisper` to every cargokit build profile —
without it the crate builds with its Cargo `default = []` feature set, the
FRB-gated `api` module never compiles in, and the app fails at
`RustLib.init()` with no diagnostic (cargo itself reports success).

## Metal acceleration (macOS)

Confirmed *enabled* for both engines as of #1724 (commit `9125cf7b`), landed
in this same milestone's Wave 0 pass:

- `llama-cpp-sys-2`'s build script never reads a Rust-level `metal` feature —
  llama.cpp's own `CMakeLists.txt` defaults `GGML_METAL` to `ON` for every
  Apple target, so `airo_mind_llama` was already linking Metal on macOS
  before #1724. The change makes that an explicit, checked contract
  (`cargo build --features llama,metal`) rather than an implicit upstream
  default.
- `whisper-rs-sys`'s build script explicitly hard-disables `GGML_METAL`
  unless the `metal` feature is present, so `airo_mind_whisper` was genuinely
  CPU-only until #1724 added the feature.

Both crates gate the acceleration through a
`[target.'cfg(target_os = "macos")'.dependencies]` table that adds the
feature to the existing optional dependency, rather than routing
`--features metal` through `cargokit.yaml` (which has no per-platform axis
and would force-feed Metal into the Android cross-compile, where it does not
link). The result: Metal is unified in automatically the moment
`llama`/`whisper` is enabled on macOS — nothing to remember to pass at the
cargokit layer, and Android is unaffected.

CoreML (`whisper-rs`'s `coreml` feature) is deliberately **not** enabled —
its model path needs a second artifact (`.mlmodelc`, a directory) that this
repo's one-file-per-model registry has no slot for. Tracked as its own
follow-up: #1723. iOS Metal is out of scope because iOS does not build at
all yet (above).

## Verification run in this repo

All commands below were executed directly, in this worktree, on 2026-08-14.
Toolchain: `rustc 1.96.1` (Homebrew) / `cargo-ndk` installed at
`~/.cargo/bin/cargo-ndk`, Xcode 26.6 CLT, Android SDK 37.0 with NDK
27.0.12077973, `cmake 4.4.2`.

```
$ cd rust && cargo build --workspace
   Finished `dev` profile [unoptimized + debuginfo] target(s) in 14.26s
```
Default-feature workspace build (no `whisper`/`llama`) compiles clean —
this is the config CI's boundary check exercises, and it does not pull in
either vendored C++ engine.

```
$ cargo build -p airo_mind_whisper --features whisper,metal
   Finished `dev` profile [unoptimized + debuginfo] target(s) in 29.51s

$ cargo build -p airo_mind_llama --features llama,metal
   Finished `dev` profile [unoptimized + debuginfo] target(s) in 1m 02s
```
Both real-engine, Metal-enabled builds compile clean on Apple Silicon.

```
$ cd app && flutter build web --release
✓ Built build/web
```
Web stays clean: `feature_mind`'s `library_loader.dart` conditionally
imports `library_loader_stub.dart` (dart2js/wasm) vs. `library_loader_io.dart`
(`dart.library.io`); the stub returns `null` and lets the generated
`RustLib.init()` fall through to `frb_generated.web.dart`, surfacing as
`MindUnavailable.bridgeMissing` in the UI instead of a `dart:ffi` compile
error. No web plugin platform is declared for `feature_mind` at all. The
`dart:ffi`-related lines the Wasm dry-run check prints during this build
belong to `media_kit` (an unrelated, pre-existing dependency of the player
stack), not `feature_mind` — confirmed by reading the printed file paths.

```
$ cd app && flutter build apk --debug
INFO: Building airo_core for aarch64-linux-android / armeabi-v7a / x86 / x86_64-linux-android
INFO: Building airo_mind_llama for aarch64-linux-android
INFO: Building airo_mind_whisper for aarch64-linux-android
✓ Built build/app/outputs/flutter-apk/app-debug.apk
```
Full Android cross-compile, run through the app's own Gradle build (not a
synthetic `cargo` invocation), producing:
`app/build/feature_mind/jniLibs/debug/arm64-v8a/libairo_mind_llama.so`,
`.../libairo_mind_whisper.so`, and `app/build/core_native/jniLibs/debug/{arm64-v8a,armeabi-v7a,x86,x86_64}/libairo_core.so`.
This is real evidence the arm64-only restriction in
`feature_mind/android/build.gradle` and the unrestricted 4-ABI build in
`core_native/android/build.gradle` both work as documented.

**A local environment gotcha, not a repo bug**, had to be worked around to
get the Android build above to succeed: this machine has Homebrew's `rustc`/
`cargo` (`/opt/homebrew/bin`) ahead of `rustup`'s shim on `PATH`. `cargokit`
invokes `rustup run stable cargo ...` internally, but on this machine
`rustup run stable which rustc` itself resolved to the Homebrew binary, not
the toolchain that actually has the Android std library components
installed (`error[E0463]: can't find crate for 'core'`, reproduced for both
`armv7-linux-androideabi` and `aarch64-linux-android` outside of Gradle too).
Prepending the real toolchain directory
(`~/.rustup/toolchains/stable-aarch64-apple-darwin/bin`) to `PATH` before
invoking `flutter build apk` was sufficient; no repo file needed to change.
This is already a known issue on this machine (see prior session notes on
"Homebrew rustc shadows rustup PATH"); flagged here as a per-developer-machine
setup note, not something this doc's audit should encode into build files.

**iOS cross-compile** was not run: `feature_mind`'s `pubspec.yaml`
deliberately omits `ios` from `flutter.plugin.platforms` (see above), so
there is no `flutter build ipa`/Xcode target that would exercise it — running
one would test nothing, since the plugin declares itself absent on that
platform. This is the documented, intentional state (#1546 phase 4), not an
unverified claim.

## Reusing this wiring for new crates

**Confirmed reusable, zero copy-paste:**
- The vendored `cargokit/` directory itself — verified byte-identical
  between `packages/feature_mind/cargokit/` and
  `packages/core_native/cargokit/`. A new package copies it as-is.
- FRB version pinning (`=2.11.1` everywhere).
- The existing CI toolchain steps (`dtolnay/rust-toolchain` plus Android/Apple
  target installs already present in `airo-mobile-tablet-release.yml`,
  `build-and-release.yml`, `ci.yml`, `airo-macos-release.yml`) run for any
  package the app depends on that triggers cargokit — a new crate wired
  through an existing FFI-plugin package rides these for free.

**Still hand-written per crate today (no generator/scaffold exists for
these — a real, named gap, not invented for this doc):**
- A new `flutter_rust_bridge_mind_<name>.yaml` at the repo root.
- A new `cargokit { }` block in whichever package's `android/build.gradle`
  hosts the crate.
- A podspec (macOS/iOS) and a `library_loader.dart`-style init guard for
  whichever package hosts it.

**Which shape to copy** — there are two known-good cargokit shapes in this
repo, and picking the wrong one is the mistake to avoid:
- `core_native`'s **single-crate template** (`manifestDir =`/`libname =`,
  standard unmodified `build_pod.sh`, iOS wired) is correct for a crate that
  does not vendor a competing native engine.
- `feature_mind`'s **two-engine, symbol-collision template** (two
  `library()` calls, dual script phases, arm64-only Android, no iOS) exists
  *solely* to solve the whisper.cpp/llama.cpp ggml collision. Copying it onto
  a crate without that problem is over-engineering that then has to be
  maintained.

`airo_mind_meeting` and `airo_mind_transcript` need neither shape today —
they have no FFI surface (see [Crate inventory](#crate-inventory)). If a
future crate in this milestone (the eval harness from #1636, for instance)
turns out to need its own bridge, it should default to `core_native`'s
single-crate template unless it specifically vendors a second native engine
with colliding symbols.

## Cost-control

This audit adds no new CI workflow or matrix, per this repo's CLAUDE.md
("GitHub Actions minutes are a costed shared resource... full matrices and
release workflows are opt-in") and per this issue's own acceptance criteria.
The existing per-push CI already builds the default-feature (no
`whisper`/`llama`) workspace as a boundary check; it does not exercise the
real engines or Android/macOS artifact production. If that coverage gap
becomes a priority, a narrow smoke job (build one engine crate with its
real feature, on one platform, on a schedule rather than every push) is the
right shape to propose next — not added here, per the "no new CI matrix"
constraint on this issue.

## Known gaps (tracked elsewhere, not fixed by this doc)

- iOS does not build for either engine (#1546 phase 4).
- CoreML acceleration for `airo_mind_whisper` is deferred pending a
  second-artifact slot in the model registry (#1723).
- No scaffold/generator exists for the per-crate FRB yaml, gradle block, or
  podspec a new engine crate needs — each is still hand-copied from an
  existing one. Worth a generator if this milestone adds more than one or
  two more FFI-surfaced crates.
- Windows CUDA for `airo_mind_llama` is a named seam, not a linked backend.
  `AccelBackend::Cuda` / `GpuBackend.cuda` / the `cuda` Cargo feature exist
  so a Windows rig with nvcc can opt in without a protocol change. The
  feature currently only enables `llama`; turning it into
  `llama-cpp-2/cuda` is the Windows-testing change, documented in
  [GENERATION_BENCH_PROTOCOL.md](./GENERATION_BENCH_PROTOCOL.md).
- `library_loader.dart`'s per-bridge `_once()` init guard is duplicated by
  hand per package (`feature_mind`, `core_native`); no shared helper package
  exists to extract it into. Not urgent at 2 packages; revisit if a third
  FFI-plugin package joins.
