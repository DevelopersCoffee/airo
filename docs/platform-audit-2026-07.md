# Platform Audit — 2026-07-20

Companion to [PLATFORM_CONSTITUTION.md](PLATFORM_CONSTITUTION.md). Evidence-backed findings only; everything else marked **Needs profiling**.

## Current state (measured)

- 55 packages under `packages/`, Rust workspace at `rust/airo_core`, melos-managed. Layering (app → feature → platform → core → rust) already exists and is largely respected.
- `app/lib`: 406 Dart files. Streaming features already extracted (`app/lib/features/iptv` = 1 file, `live`, `media` tiny). Remaining bulk is **non-TV super-app domains**:
  - `features/coins` 14,240 LOC (overlaps `platform_coin_vault`, `airomoney`)
  - `features/agent_chat` 10,032 LOC
  - `features/games` 6,662 LOC (chess + stockfish + flame)
  - `features/money` 6,144 · `bill_split` 5,654 · `music` 4,486 LOC
- `app/lib/core/database`: monolithic Drift schema, 18.8 KB source + **610 KB generated** `app_database_native.g.dart`, in the app layer.
- `app/pubspec.yaml`: ~50 direct deps incl. mobile-only native plugins: `stockfish`, `flame`/`flame_audio`, `google_mlkit_text_recognition`, `flutter_contacts`, `image_picker`, `pdfx`, `screenshot`, `flutter_image_compress`, `chess`.
- `app/android/app/build.gradle.kts`: **no product flavors**. One Android module → every plugin's native code links into every entrypoint's APK, including `main_tv.dart` (target <120 MB per its own doc header). Dart tree-shaking removes Dart code but not plugin `.so`/AAR payloads.
- Rust core: `m3u.rs` (213 LOC), `xmltv.rs` (717 LOC), benches present. **Duplicate Dart M3U parser** still lives at `packages/platform_playlist_import/lib/src/m3u_playlist_parser.dart` (+ `feature_iptv` `m3u_parser_service.dart` wrapper).
- Capability primitives exist but informal: `app/lib/core/config/platform_features.dart` (`AppPlatform`, `AppFeature`, `PlatformFeatures`), `app/lib/core/features/feature_registry.dart`, `app/lib/core/platform/device_form_factor.dart`, plus `product_capabilities` and `platform_device_profile` packages.

## Findings → issues

| # | Finding | Action | Priority |
|---|---|---|---|
| 1 | TV APK links stockfish/flame/mlkit/contacts/pdfx native code | Per-variant build isolation (flavors or split app modules) | High |
| 2 | Duplicate M3U parsing (Rust + Dart) | Retire Dart parser; Rust via `core_native`, Dart stub only for web | High |
| 3 | 610 KB monolithic Drift schema in `app/lib` | Split per-domain, move to owning packages | High |
| 4 | 47 K LOC of mobile domains in `app/lib/features` | Extract to `feature_*` packages; deferred components where Play allows | Medium |
| 5 | Money domain triplicated (coins / money / bill_split vs `airomoney`, `platform_coin_vault`) | Consolidate under `airomoney` + vault | Medium |
| 6 | Capability registry informal, app-layer only | Promote to `product_capabilities`; ship-policy per device class | Medium |

**Not Worth Migrating (now):** Xtream/Stalker/Jellyfin clients to Rust (I/O-bound, fine in Dart); C++ additions (no FFmpeg-adjacent work in tree); further core_* re-layering (already clean). Search/EPG indexing to Rust: **Needs profiling** on device before any move.

## Roadmaps (consolidated)

**Migration order:** 1 → 2 → 3 → 6 → 4 → 5. Build isolation first (biggest ROI, unblocks size budgets), duplication second, schema third, registry before extraction so extracted features register capabilities on the way out.

**Estimates** (to be confirmed by CI size reports; treat as hypotheses):

- APK (TV): dropping stockfish (multi-ABI engine), flame, mlkit text-recognition, contacts, pdfx, image plugins — expect tens of MB per ABI. Measure via `flutter build apk --analyze-size` before/after.
- Startup (TV): fewer plugin registrants + smaller Drift schema → faster cold start. Measure with existing `platform_benchmarks` runner.
- Memory: per-domain DB opens less schema; mobile-only singletons never constructed on TV.
- Maintenance: one M3U parser instead of three entry points; money domain one owner instead of three.

**Rust roadmap:** keep M3U/XMLTV; candidates gated on profiling — EPG index/merge, playlist diff, search ranking. Each needs a `packages/benchmarks` bench proving ≥2× CPU or ≥30% allocation win before admission.

**Suggested trees:** see constitution §2 (layers) and §4 (placement). New packages to exist by end of migration: `feature_games`, `feature_agent_chat`, `feature_music`, money consolidation into `airomoney`. No new `core_*` packages needed.
