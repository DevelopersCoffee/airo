# ADR-0018: Airo Arena as game intelligence packs on the existing edge runtime

## Status

Proposed

## Date

2026-08-01

## Context

Chess ships today with no opponent. `app/pubspec.yaml` overrides `stockfish`
with `packages/stubs/stockfish_stub`, whose `state` getter returns
`StockfishState.ready` unconditionally while `stdout` is `Stream.empty()`. The
caller sees a healthy engine, sends `go`, and waits on a stream that never
produces `bestmove` (#1407). The stub exists for a real reason, stated in its own
header comment: the native library is 108 MB.

Measured on the rig Pixel 9, arm64, release:

| build | APK |
|---|---|
| current (stub) | 106.2 MB |
| real `stockfish` 1.8.1 | 210.1 MB |

`libstockfish.so` is 108.7 MB stripped. Re-stripping saves nothing; the size is
embedded NNUE evaluation networks (`EvalFileSmall`,
`Eval::NNUE::Networks`). That is larger than the rest of the app combined and
probably exceeds Google Play's 200 MB compressed download limit, so "just bundle
it" is not available even if the size were acceptable.

So the team faces a false choice it has already resolved once by picking neither
side well: ship 108 MB, or ship a game with no opponent.

Separately, we want Arena as an independently released module covering more than
chess, with the same offline, on-device posture as Media Intelligence, on
hardware down to 1 GB RAM.

The architecture to do this already exists and is in use:

- `rust/airo_core/src/api/runtime_contracts.rs` defines `RuntimeId`,
  `CapabilityId`, `CapabilityState`, `ComputeAccelerator`, `ExecutionPriority`,
  `ExecutionTrace`, `TelemetryEvent`, `InferenceRequest`, `InferenceIr`,
  `RuntimeRegistry`, `RuntimeHealth`.
- Packs are compiled artifacts with a manifest carrying `pack.domain`,
  `capabilities`, `permissions`, `schema.domain_ir`, `runtime.minimum_sdk`,
  `checksum` and `signature` — see
  `app/assets/packs/media.iptv.airo-sample-0.1.0.pack`.
- `packages/feature_iptv/lib/application/providers/edge_intelligence_providers.dart`
  shows the consumption pattern for a domain built on that runtime.

Arena therefore needs no new runtime. It needs a new **domain**.

## Decision

Ship Arena as `game`-domain intelligence packs on the existing edge runtime.

1. **`game` becomes a pack domain.** Packs are `game.<title>.*`, starting with
   `game.chess.airo-<variant>`. Manifest shape is unchanged; `pack.domain` is
   `game` and `schema.domain_ir` versions the Game IR.

2. **Large model data ships inside packs, never inside the APK.** The NNUE
   network is a pack asset. The engine binary is built without embedded nets and
   is pointed at the pack-provided net at runtime. This is what makes both a lean
   super app and a credible 1 GB target possible, and it is the same mechanism
   Media already uses for its indexes.

3. **Engines register as runtimes.** A chess engine is a `RuntimeId` with a
   declared `CapabilityId` set, reporting `CapabilityState` and `RuntimeHealth`
   like any other. An engine that is absent reports unavailable — it does **not**
   report ready and hang. #1407 is exactly the cost of getting that wrong.

4. **`core_game_kernel` is rules-agnostic.** Session lifecycle, turn order,
   clocks, move log, persona dispatch, analysis events, and profile/memory
   hooks live there. No chess concept enters it. Chess rules, openings, tactics
   and puzzles live in the chess pack and its engine adapter.

5. **The SLM never generates moves.** The engine emits structured evaluation →
   Game IR → prompt compiler → SLM produces speech, coaching and commentary
   only. This mirrors the existing `InferenceIr` boundary rather than inventing
   one.

6. **Arena is a flavour, following the Coins precedent.** A `pubspec_arena.yaml`
   / `main_arena.dart` / dedicated activity triple, as `pubspec_coins.yaml` /
   `main_coins.dart` / `CoinsActivity` already do. The standalone app may bundle
   a starter pack; the super app installs packs on demand and stays lean.

## Contract Impact

**Required. Fill every row — "none" is an answer, blank is not.**

| Question | Answer |
|---|---|
| Which runtime contracts change? | `runtime_contracts.rs` — new `RuntimeId` and `CapabilityId` variants for game engines and game inference. Additive, but the enums are exchanged across the FFI boundary, so this is a runtime **major** version bump: `RuntimeApiVersion` increments and `runtime.minimum_sdk` in pack manifests moves with it. Pack schema gains a `game` value for `pack.domain` and a new `domain_ir` line for Game IR starting at `1.0.0`; `pack_schema` itself is unchanged. |
| Which conformance tests become invalid? | Any test asserting the closed set of `RuntimeId`/`CapabilityId` values, and any pack-loader test asserting `pack.domain == "media"` or enumerating valid domains. These stay green while no longer protecting the property they were written for, which is precisely the case the template calls out. The APK-size guardrail in `.github/apk-size-baselines.tsv` is not a test but is invalidated in the same way — see below. |
| Which benchmarks must be re-run? | The `full` and `tv` APK size baselines (`full` was corrected to 104,141,179 B this session and is enforced at 120 MB); a new `arena` baseline is required. Cold-start and memory budgets in `docs/adr/002-memory-budgets.md` must be re-measured on a 1 GB device with an engine runtime and an SLM resident, since that combination has never been measured. Pack install/load timings need a first measurement for `game` packs. |
| Which review roles must re-review? | Per `docs/agents/COUNCIL.md`: chief-architect (new package boundary and domain), platform-architect (FFI surface change), chief-performance-officer (1 GB target, size budgets, new native library), chief-security-officer (pack signature covering executable model data), chief-release-devops-officer (new flavour and release line), product-manager (Arena as an independent product), chief-open-source-officer (Stockfish licence — GPLv3 — and its implications for distribution). |
| Is G0 required again? | Yes — this changes a crate's public surface. |

The GPLv3 row is not a formality. Stockfish is GPLv3; linking it into a
proprietary APK has distribution consequences that must be settled **before**
any engine work starts, not after.

## Consequences

### Positive

- Chess gets a real opponent without a 104 MB APK increase.
- Arena can ship and update independently of the super app.
- A second domain proves the runtime is a platform rather than media-specific
  scaffolding, which is the strategic claim the pack architecture exists to
  support.
- Additional games are additive: a new pack and an engine adapter, with no
  kernel fork.
- Engine absence becomes a declared capability state instead of a hang.

### Negative

- We take on building and maintaining a Stockfish binary without embedded nets,
  across the ABIs we ship. That is a native toolchain commitment, not a
  dependency bump.
- Pack-delivered model data means a first-run download or asset-delivery step;
  Chess is not playable at zero bytes on first launch unless a small starter net
  is bundled.
- A runtime major version bump forces every pack to declare a new
  `minimum_sdk`.

### Risks

- **Licence.** Stockfish is GPLv3. This may force the engine into a separately
  distributed component, or push us to a permissively licensed engine. Unsettled
  before implementation, this risk invalidates the plan rather than delaying it.
- **1 GB target is unproven.** Engine plus INT4 SLM resident simultaneously has
  never been measured on such a device. The budget may not close, in which case
  Coach/Commentary degrade to a rules-based path on low-memory hardware.
- **Scope.** The full brief (Human vs AI, AI vs AI, analysis, puzzles, coach,
  personas, adaptive difficulty) is a product, not a feature. Shipping it as one
  release is the main delivery risk.

## Alternatives Considered

### Alternative 1: Bundle `stockfish` 1.8.1 as published

Measured: builds cleanly today — the "incompatible with the current AGP
toolchain" note in `app/pubspec.yaml` is stale — but takes the APK to 210.1 MB
and likely breaches the Play limit. Rejected on size, not on feasibility.

### Alternative 2: Keep the stub and make the UI honest

Remove the difficulty picker and present Chess as practice-only. Cheapest
option, and strictly better than today's silent hang. Rejected as the end state
because it abandons the Arena product, but it is the correct **interim** state
if the engine work slips — and it is what should ship if v1 Arena is deferred.

### Alternative 3: Pure-Dart engine only

A minimax/alpha-beta over the existing `chess.dart` (already present and
generating legal moves correctly — it is what makes the board respond today)
costs approximately zero bytes and needs no native toolchain or licence review.
Weaker than Stockfish at high difficulty, and no NNUE evaluation for analysis
depth.

Not rejected: adopted as **phase 1**. It restores the advertised feature
immediately, proves the kernel, IR, persona and prompt pipeline end to end
behind the same `RuntimeId`, and lets the Stockfish decision — including its
licence question — be taken on its own timeline without Chess staying broken in
the meantime.

### Alternative 4: Cloud inference for coaching

Rejected outright. Contradicts the local-first, offline posture that the pack
architecture and the product exist to deliver.
