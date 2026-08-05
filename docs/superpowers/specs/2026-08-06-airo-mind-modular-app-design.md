# Airo Mind — modular standalone app

**Date:** 2026-08-06
**Status:** Approved design, pre-implementation
**Pattern precedent:** Airo Coins (ADR-0010 package-first + `core_product_shell` SSOT contract), Airo TV (`pubspec_tv.yaml` trimmed-dependency flavor)

## Goal

Ship the super app's Mind tab as a standalone modular app ("Airo Mind"), the same
way Airo TV and Airo Coins ship: one shared codebase, a dedicated entrypoint,
pubspec profile, Android variant, and build script. The Mind experience in the
super app and the standalone app is the same code — no fork, no drift.

## Scope

Full Mind tab parity, including the account/cloud surface:

- Mind hub (`MindScreen`), Prompt Lab, Audio Scribe, Mobile Actions
  (`app/lib/features/mind`, 4 screens, ~1k LOC)
- Agent chat, Model Library, Model Advisor, Device Capabilities, Agent Skills,
  Notifications, Profile (`app/lib/features/agent_chat`, 47 files, ~11.6k LOC)
- Auth (Google sign-in), cloud Gemini, local models (LiteRT / Gemini Nano),
  notifications, profile — full parity with the super app's Mind branch.

Out of scope: the Airo Mind *runtime* (epic #1192, seven primitives,
`rust/airo_core`). This app is the existing Flutter Mind experience only. The
shell gives the runtime a home later, but nothing here depends on it.

## 1. Package: `packages/feature_mind`

Package-first extraction, mirroring `feature_coin`:

- Move `app/lib/features/mind` and `app/lib/features/agent_chat` into
  `packages/feature_mind/lib/src/`.
- Export `MindModule implements AppModule` from `core_product_shell`:
  - `id: 'mind'`
  - `supportedShells: {ShellId.mobile, ShellId.mind}`
  - Routes built from a single route-table function. Super app keeps the
    `/mind/...` paths and every existing route *name* (`mind_chat`,
    `assistant_models`, `mind_prompt_lab`, `mind_audio_scribe`,
    `mind_agent_skills`, `mind_mobile_actions`, `mind_device_capabilities`,
    `mind_model_advisor`, `agent_notifications`, `profile`) unchanged. The
    standalone shell mounts the same table at its own base path with the hub
    at `/`, the same base-path override mechanism `CoinVaultModule` uses.
- Services that only the Mind branch consumes move into the package (or
  `core_ai` where they are model-runtime shaped): `gemini_api_service`,
  `gemini_nano_service`, `litert_lm_service`,
  `local_runtime_preloader_service`, `model_preload_preferences`,
  `model_learn_more_launcher`, `voice_search_service`.
  **Pre-move check:** grep each service for consumers outside the Mind branch;
  any shared service stays in `app/lib/core` (or its core package) and is
  injected through a provider-override seam, the way `feature_coin` receives
  shell services.
- Shared dependencies come from existing packages: `core_ai`, `core_ui`,
  `core_auth`. `http_dog` and `auth_service` remain app/core-owned and are
  injected.
- `module.yaml` with council owner (flutter-architect primary; chief-cloud-officer
  for the auth/Gemini surface).
- Super app `app_router.dart` drops its direct `features/mind` and
  `features/agent_chat` imports and consumes the module's routes from the
  registry, as it already does for `iptv` and `coin_vault`.

## 2. Shell: `main_mind.dart` + `pubspec_mind.yaml`

- `ShellId` gains `static const mind = ShellId('mind')`. The contract is a data
  value by design; no consumer branches on it.
- `app/lib/main_mind.dart` mirrors `main_coins.dart`:
  `ModuleRegistry(shell: ShellId.mind)`, registers `MindModule`, routes come
  entirely from `registry.allRoutes`, hub at `/`, pro bootstrap runner after
  first frame, `buildMindModuleRegistry()` split out `@visibleForTesting`.
- `app/pubspec_mind.yaml` — trimmed profile like `pubspec_tv.yaml`:
  - Keeps: flutter_riverpod, go_router, `feature_mind`, `core_ai`, `core_ui`,
    `core_auth`, `core_product_shell`, `core_entitlements`,
    `airo_pro_bootstrap`, firebase_core, firebase_auth, google_sign_in,
    image_picker, LiteRT/model-runtime deps, flutter_local_notifications.
  - Excludes: stockfish, chess, flame, mlkit, the IPTV/media stack, and other
    super-app-only weight — via omission where possible, stub overrides from
    `packages/stubs/` where transitive compilation requires them.
- Firebase: register a new Android app `io.airo.app.mind` in the existing
  Firebase project and add its entry to `google-services.json`.

## 3. Android variant

- `app/android/app/build.gradle.kts`: extend the existing `APP_VARIANT`
  mechanism — `"mind"` → applicationId `io.airo.app.mind`, label "Airo Mind",
  `src/mind/AndroidManifest.xml` and launcher icon source set (same mechanism
  as the coins block).
- `scripts/build-mind.sh`: clone of `build-coins.sh` — pubspec swap with
  restore trap, `--target=lib/main_mind.dart`,
  `--dart-define=APP_VARIANT=mind`, `--split-per-abi` on release, artifact
  existence check.

## 4. Tests and verification gates

- Screen tests move with their code from `app/test/features/mind` and the
  agent_chat test tree into `packages/feature_mind/test/`.
- New tests:
  - `main_mind` registry test mirroring the coins registry test (module
    registered, shell id correct, routes non-empty).
  - Route-parity test asserting the super app still resolves every pre-move
    Mind route *name* — the regression guard for the extraction.
- Gates before merge (narrowest-first per CI-spend policy):
  1. `flutter analyze` on `feature_mind` + app.
  2. `feature_mind` package tests + moved tests green.
  3. `cd app && flutter build web --release` (touched native paths rule).
  4. `scripts/build-mind.sh` produces an APK.
  5. Super app APK still builds (`main.dart`, default pubspec).

## Error handling

- Standalone shell without super-app context: any Mind screen that navigates
  to a non-Mind super-app route (for example quotes' `DailyQuoteCard` deep
  links) must either carry the target into the package or degrade to a no-op
  in `ShellId.mind`; discovered case-by-case during extraction, decided per
  screen, never by branching on shell inside widgets — use the module's
  per-shell route/override seam.
- Pubspec-swap build script restores the original pubspec on any exit (trap),
  same as coins.

## Build order

1. Extract `packages/feature_mind` + `MindModule`; super app consumes it
   (behavior-neutral refactor, route-parity test proves it).
2. `ShellId.mind`, `main_mind.dart`, `pubspec_mind.yaml`.
3. Android variant + `build-mind.sh` + Firebase app id.
4. Gates, dogfood APK on Pixel 9.

Each step lands as its own PR (commit/PR cadence at every logical milestone).
