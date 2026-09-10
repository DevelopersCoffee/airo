# ADR-0026: Extract the M3U parser into a standalone, publishable package

## Status

Proposed

## Date

2026-09-10

## Context

Epic [#1482](https://github.com/DevelopersCoffee/airo/issues/1482) commits
Airo to publishing reusable internals as pub.dev packages, with the M3U
parser (`m3u_parser`, issue
[#1496](https://github.com/DevelopersCoffee/airo/issues/1496)) as one of the
named extraction targets. Extraction is gated behind this ADR plus a Chief
Architect sign-off
([#1495](https://github.com/DevelopersCoffee/airo/issues/1495)); nothing
extracts before it. Issues
[#1501](https://github.com/DevelopersCoffee/airo/issues/1501) (publishing
pipeline) and [#1502](https://github.com/DevelopersCoffee/airo/issues/1502)
(Airo consumes the package, originals deleted) are the remaining steps in
that sequence and are out of scope here.

Two things changed since the epic was written on 2026-08-03 that this ADR
needs to account for:

1. **The native Rust path is real now, not phantom.** A prior audit
   (refactor-cycle milestone,
   [#1677](https://github.com/DevelopersCoffee/airo/issues/1677)) found
   `airo_core` never compiled into any build — `initializeCoreNativeBridge()`
   always failed and Airo ran pure-Dart everywhere. #1677 is closed:
   `packages/core_native/android`, `/ios`, `/macos` now wire cargokit to
   cross-compile `rust/airo_core`, and it ships in real builds. Issue #1496
   was scoped as "pure-Dart" under the phantom-Rust assumption; that
   assumption no longer holds.
2. **Web crashed on the download step regardless.** A separate bug (fixed
   same session, `platform_playlist_import`) had web's playlist fetch use
   `dio.download()` to a `dart:io` `File`, which throws `UnsupportedError`
   at runtime on web. That fix made native/web share one fetch abstraction;
   this ADR is the natural next step — share the *parser* itself, not just
   the code that decides which parser to call.

Given those two facts, the owner chose (this session, in conversation) to
scope this extraction as **Rust-backed with a Dart fallback**, not
pure-Dart-only, reversing #1496's original framing. That choice trades a
larger build-tooling footprint for consumers (cargokit/NDK/Xcode hooks
required for native speed) against keeping the proven native-speed path
intact — see Alternatives Considered.

`rust/airo_core/src/api/m3u.rs` (925 lines) was checked and has **zero
internal `crate::` coupling** to the rest of `airo_core` — only `std` and
the external `memchr` crate. It shares no code with `airo_core`'s xmltv,
playlist_index, relational_store, or text modules. This makes a clean fork
mechanically straightforward: the risk in this extraction is packaging and
API-boundary discipline, not disentangling shared Rust internals.

## Decision

Create `packages/m3u_parser/`, a new Melos workspace member intended for
eventual `flutter pub publish` (monorepo-published packages are standard;
no separate git repo is required to publish to pub.dev).

**Scope: parser only.** M3U text in, structured channel entries out.
Playlist fetching, HTTP caching/ETag handling, BYOC source management, and
`ChannelVariantClassifier` (dedup/variant-merge ranking) all stay in
`platform_playlist_import` — those are Airo-specific business logic, not a
generically reusable parsing primitive, and keeping them out keeps the
published package's API surface small and stable.

**Rust crate:** `packages/m3u_parser/rust/` (inside the package, not
alongside it in the shared `rust/` cargo workspace) — a pub.dev plugin's
gradle/podspec build hooks reference paths relative to the package root;
anyone who `pub get`s this package outside the Airo monorepo needs the Rust
source to resolve from inside the package tree, not from a sibling
workspace that won't exist for them. Forked from `airo_core::api::m3u`
(copy, not shared — see Consequences on drift risk), own `Cargo.toml`
(`flutter_rust_bridge`, `memchr`), own FRB codegen, own cargokit wiring
under `android/`, `ios/`, `macos/` copied from the proven
`packages/core_native` pattern (build.gradle `cargokit` block, podspec
`build_pod.sh` hook).

**Public Dart API** (final shape settled during implementation, not frozen
here — see Contract Impact):

- `parseM3u(String content) -> M3uPlaylist` — synchronous, pure-Dart, no
  native bridge. This is the deterministic/test/web path today and stays
  that way; it must remain usable standalone (e.g. by a pure-Dart backend
  consumer) without pulling in Flutter.
- `parseM3uAsync(String content) -> Future<M3uPlaylist>` — Rust-preferred,
  falls back to `parseM3u` automatically when the native bridge fails to
  load (mirrors `initializeCoreNativeBridge`'s existing catch-and-fallback
  pattern, which has run in production since #1677 closed).
- Stats variants of both (`parsedCount`/`skippedCount`/`malformedCount`/
  `elapsedMillis` — aggregate-only, no playlist content, matching the
  existing privacy constraint on this telemetry).
- No file-path parsing API. File I/O is a platform/orchestration concern
  that belongs to the caller (Airo's `platform_playlist_import`), not to a
  package that must also run on web with no filesystem — this is exactly
  the constraint the same-session web bug taught us not to skip.

**Isolate/worker boundary stays in Airo, not in the package.** Per
`CLAUDE.md`, parses over ~50 KB must run off-main via `runOffMain()` /
`AiroWorkerExecutor`. The published package exposes pure functions and must
not spawn its own isolates internally — Airo wraps `parseM3u`/
`parseM3uAsync` in its worker boundary the way it already wraps
`core_native`'s equivalents. This must be stated in the package's own
README so external consumers don't get a web-only isolate crash by calling
it directly from a UI-thread hot path.

## Contract Impact

**Required. Fill every row — "none" is an answer, blank is not.**

| Question | Answer |
|---|---|
| Which runtime contracts change? | New public contract: `m3u_parser` package's Dart API (`parseM3u`/`parseM3uAsync` + stats variants), v0.1.0. `core_native`'s existing `NativeM3u*`/`parseM3uPlaylist*`/`parseM3uEntries*` symbols are deprecated in place (forward to `m3u_parser`) rather than removed in this ADR's scope — removal is #1502's job, gated on Airo fully migrating consumers first. `platform_playlist_import`'s own public API (`M3UParserService.fetchPlaylist`, `fetchPlaylistOutcome`, `fetchPlaylistWithProgress`) does not change; only its internal parse call targets move. |
| Which conformance tests become invalid? | None outright, but a new parity requirement is introduced: `m3u_parser`'s Rust path and Dart-fallback path must produce byte-identical `M3uPlaylist`/stats output to the pre-extraction `airo_core::api::m3u` output on a fixed corpus (existing `core_native` and `platform_playlist_import` M3U test fixtures, reused as the parity corpus). Existing `core_native/test/m3u_test.dart` and `platform_playlist_import` parser tests must keep passing unmodified against the deprecated forwarding shims until #1502. |
| Which benchmarks must be re-run? | `rust/airo_core/benches/m3u_parser.rs` — forked alongside the crate and re-run against the new standalone crate/dylib to confirm the cdylib boundary and separate codegen unit don't regress parse throughput. |
| Which review roles must re-review? | Chief Architect (module boundary + new package, the #1495 gate itself); `rust-architect` (new crate, cdylib/FFI surface — no `unsafe` in the forked code today, but cargokit wiring is new attack/build surface); `chief-open-source-officer` (new publicly-published dependency: license, maintenance policy, bus factor — this package will have external consumers Airo doesn't control); `media-intelligence-architect` (owns `platform_playlist*`/EPG provider adapters, the primary in-repo consumer). |
| Is G0 required again? | Yes — new crate, new public FFI surface. |

## Consequences

### Positive

- Single source of truth for M3U parsing shared cleanly by native and web,
  eliminating this bug *class* (today's web crash was two platforms
  silently diverging in how they got playlist text into the parser) rather
  than patching one instance of it.
- A genuine, reusable published artifact — the ecosystem premise in #1482
  ("Airo TV becomes the reference implementation of the stack") gets a
  first real example instead of staying aspirational.
- Incremental progress on unwinding the `airo_core` monolith flagged by the
  refactor-cycle audit: one fewer reason for `airo_core` to stay a
  single do-everything crate.

### Negative

- Two Rust build artifacts to maintain in parallel (`m3u_parser`'s crate
  and `airo_core`, until #1502 lands and Airo's own copy is deleted) — full
  duplication of cargokit wiring, CI build time, and NDK/Xcode toolchain
  surface until then.
- Downstream public consumers who want native-speed parsing must have
  cargokit/NDK/Xcode build tooling wired into their own app — a real
  adoption barrier for a public package, accepted knowingly per this
  session's explicit choice of Rust-backed over pure-Dart-only.
- pub.dev is a one-way door (per #1482) — the public API surface fixed
  above needs to be right before #1501's first publish; mistakes cost a
  new major version, not a quiet fix.

### Risks

- **Drift between the fork and `airo_core`'s copy.** Two copies of the same
  parsing logic is strictly worse than one if #1502 (Airo consumes the
  package, deletes its original) doesn't land in the same milestone wave.
  This ADR treats #1502 as a near-term follow-on, not a someday cleanup.
- **cargokit/NDK cross-compilation is already a known-fragile area in this
  repo** (Homebrew rustc shadowing rustup `PATH`, a cargokit
  android-37.0 version-parsing bug seen previously). A second crate doubles
  the exposed surface for those gotchas until the two crates converge.
- **Public semver discipline is new** — nothing in this repo has shipped to
  pub.dev before (every package here is `publish_to: none` today). The
  team has no prior track record on this specific failure mode to draw on.
- **The Rust/Dart parity test is not yet real cross-engine enforcement.**
  The parity test added in this plan
  (`packages/m3u_parser/test/m3u_parser_native_parity_test.dart`) can only
  exercise the Dart-fallback path against itself in the current CI/test
  environment — the native bridge doesn't load in a plain `flutter test`
  run, so "async (Rust-preferred)" and "sync Dart" are, in practice, the
  same code path today. An on-device test that forces the native path (
  mirroring `core_native`'s existing env-var-gated native verification test
  pattern) is the actual follow-up needed to make the parity guarantee
  real, not just asserted.
- **iOS/macOS static-link symbol collision risk for #1502.** The new crate
  and `core_native`'s `airo_core` crate each emit an unprefixed
  `frb_get_rust_content_hash` symbol (and related FRB boilerplate) via
  `flutter_rust_bridge::frb_generated_boilerplate_io!()`. On Android this is
  harmless (separate `.so` files). On iOS/macOS, both podspecs
  `-force_load` their static archive into the same app binary — an app
  depending on both `core_native` and `m3u_parser` at once will hit a
  duplicate-symbol link error. This means #1502 (Airo consumes the
  package, deletes its own copy) cannot safely be a transition period
  where both packages coexist on iOS/macOS — it needs to be a same-commit
  swap (delete `core_native`'s M3U path in the same change that adds the
  `m3u_parser` dependency), or the coexistence needs to be verified with
  an actual iOS build first. Not a problem for the current branch (nothing
  depends on both packages yet), but it constrains how #1502 must be
  sequenced.
- **The extracted crate dropped `for_each_m3u_channel_bytes`** (a
  `pub(crate)` zero-copy mmap-streaming parse path used internally by
  `airo_core::api::playlist_engine`) since it's not part of any public API
  and irrelevant to an external consumer. This was the correct scope call
  for a parser-only public package, but it means #1502 cannot simply
  delete `airo_core`'s copy of the M3U parsing code wholesale —
  `playlist_engine`'s mmap-based import path still needs *some* M3U
  parsing capability, either kept in `airo_core` alongside the (now
  largely redundant) FFI-exposed functions, or by adding a streaming API
  to the published package. Worth deciding explicitly in #1502's own
  scoping, not assumed away.

## Alternatives Considered

### Alternative 1: Pure-Dart-only extraction (issue #1496's original scope)

Ports only `core_native`'s existing Dart fallback parser (already
self-contained, already proven on web) as the published package; drops the
Rust engine entirely. Runs everywhere Flutter does, including web, with no
native build tooling required of any consumer. Rejected this session in
favor of keeping the native-speed path — the owner explicitly chose
Rust-backed knowing the adoption-barrier trade-off above.

### Alternative 2: Publish `airo_core` as-is

Publish the whole crate (m3u, xmltv, playlist_index, relational_store,
text) as one package instead of forking just the M3U module out. Rejected:
violates the parser-only scope decision, forces a public API commitment on
EPG parsing and the SQLite adapter the owner didn't ask to make public, and
inherits `airo_core`'s current monolith problems (flagged separately by the
refactor-cycle audit) into the published surface.

### Alternative 3: Internal package split, no pub.dev publish

Extract into a workspace-only package (`publish_to: none`, matching every
other package here today) without ever publishing externally. Rejected —
the owner explicitly asked for a public, open-source pub.dev library; an
internal-only split doesn't serve the ecosystem premise in #1482.

## Related Decisions

- Epic [#1482](https://github.com/DevelopersCoffee/airo/issues/1482) — Airo
  Discovery & Ecosystem milestone, the parent decision that extraction
  happens at all.
- Issue [#1495](https://github.com/DevelopersCoffee/airo/issues/1495) —
  this ADR is written to satisfy that issue's gate.
- Issue [#1496](https://github.com/DevelopersCoffee/airo/issues/1496) —
  original (pure-Dart) scoping of this exact package; this ADR supersedes
  its engine-choice framing per Alternative 1.
- Issue [#1677](https://github.com/DevelopersCoffee/airo/issues/1677)
  (closed) — the native-build-wiring decision this ADR builds on;
  `airo_core`/`core_native` went from phantom to real because of it.

## References

- `packages/core_native/lib/src/m3u.dart` — the Dart fallback parser and
  native/web dispatch logic being extracted.
- `rust/airo_core/src/api/m3u.rs` — the Rust parser being forked.
- `packages/core_native/android/build.gradle`,
  `packages/core_native/{ios,macos}/core_native.podspec` — the cargokit
  wiring pattern the new crate's build hooks copy.
- `packages/platform_playlist_import/lib/src/m3u_parser_service.dart` — the
  same-session web-fetch fix this extraction follows on from.
