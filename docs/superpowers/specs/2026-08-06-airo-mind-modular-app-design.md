# Airo Mind — modular standalone app

**Date:** 2026-08-06 (revised same day against origin/main 9a51c3ab)
**Status:** Approved design, pre-implementation
**Pattern precedent:** Airo Coins (ADR-0010 package-first + `core_product_shell` SSOT contract), Midas Stream (`pubspec_tv.yaml` trimmed-dependency flavor)

## Goal

Ship "Airo Mind" as a full standalone modular app the way Midas Stream and Airo
Coins ship: one shared codebase, a shell entrypoint driven by
`core_product_shell`, a pubspec profile, an Android `APP_VARIANT`, and a build
script. The standalone app combines:

1. The existing Airo Mind **scribe** journey (`packages/feature_mind` —
   record a meeting, transcribe, minutes, search; Rust via
   flutter_rust_bridge), which already ships behind a minimal
   `app/lib/main_mind.dart`.
2. The super app's **Mind tab** (`/assistant` branch: assistant hub, chat,
   model library, model advisor, device capabilities, prompt lab, audio
   scribe, agent skills, mobile actions, notifications, profile) plus the
   **Wellbeing** destination (`/wellbeing`) it links to.

The Mind experience in the super app and the standalone app is the same code —
no fork, no drift.

## Naming reality

`packages/feature_mind` is taken by the scribe/runtime package (milestone 19/22
work). The Mind-tab extraction therefore lands in a **new package
`packages/feature_assistant`**. The product name stays "Airo Mind"; package
names follow what the code is.

## Scope

- Extract `app/lib/features/assistant` (5 screens), `app/lib/features/agent_chat`
  (~47 files), `app/lib/features/wellbeing`, and `app/lib/features/quotes`
  (wellbeing-only consumer) into `packages/feature_assistant`.
- Full parity including the account/cloud surface: Google sign-in, cloud
  Gemini, local models (LiteRT / Gemini Nano), notifications, profile.
- Upgrade `main_mind.dart` from a bare `MaterialApp` to the coins-style shell:
  `ModuleRegistry(shell: ShellId.mind)` with two modules — the scribe and the
  assistant.

Out of scope: any change to the Mind runtime's architecture or the scribe
journey itself; store icon/branding assets; iOS targets.

## 1. Package: `packages/feature_assistant`

- Moves the four feature trees above into `packages/feature_assistant/lib/src/`.
- Exports `AssistantModule implements AppModule`:
  - `id: 'assistant'`
  - `supportedShells: {ShellId.mobile, ShellId.mind}`
  - One route-table function. Super app keeps paths under `/assistant/...`
    plus `/wellbeing`, and every existing route name unchanged:
    `Assistant`, `assistant_chat`, `agent_notifications`, `profile`,
    `assistant_models`, `assistant_device_capabilities`,
    `assistant_model_advisor`, `assistant_prompt_lab`,
    `assistant_audio_scribe`, `assistant_agent_skills`,
    `assistant_mobile_actions`, `Wellbeing`.
- Services move as ownership dictates:
  - Shared model-runtime services → `packages/core_ai`: `gemini_api_service`,
    `gemini_nano_service`, `litert_lm_service`, `model_learn_more_launcher`
    (outside consumers: ai_router, quest, bill_split, settings).
  - Assistant-only services → the package: `voice_search_service`,
    `local_runtime_preloader_service`, `model_preload_preferences`.
  - App-owned couplings (auth, google auth, http_dog, dictionary, speech,
    locale, bug report) — confined to `chat_screen.dart` and
    `profile_screen.dart` — are injected through a single `AssistantHostAdapter`
    seam; the one real implementation lives in `app/lib/core/assistant/` and
    both shells register it.
- `module.yaml` with council owner; `forbidden_dependencies: [app]`.

## 2. Shell: `main_mind.dart` (rewrite) + `pubspec_mind.yaml` (expand)

- `ShellId` gains `static const mind = ShellId('mind')`.
- `packages/feature_mind` is not modified. A `MindScribeModule` wrapper in
  `app/lib/core/mind/` adapts it to `AppModule` (exactly how
  `CoinVaultModule` wraps `feature_coin`), owning the `MindService` lifecycle
  through the module's `initialize`/`dispose`.
- `main_mind.dart` mirrors `main_coins.dart`: registry scoped to
  `ShellId.mind`, registers `MindScribeModule` (scribe home at `/`) and
  `AssistantModule` (mounted at `/assistant`, wellbeing at `/wellbeing`),
  router built entirely from `registry.allRoutes`, minimal Firebase init
  (auth parity), pro bootstrap post-frame.
- `app/pubspec_mind.yaml` expands from its current minimal form: adds
  `feature_assistant`, `core_ai`, `core_ui`, `core_auth`,
  `core_product_shell`, `core_entitlements`, `airo_pro_bootstrap`,
  firebase_core/auth, google_sign_in, image_picker, notifications; stays free
  of stockfish/flame/mlkit/IPTV weight, stub overrides only where a
  transitive edge forces them.

## 3. Android variant

- `app/android/app/build.gradle.kts`: `APP_VARIANT=mind` → applicationId
  `io.airo.app.mind`, label "Airo Mind", `src/mind/AndroidManifest.xml`
  source set (same mechanism as coins).
- `scripts/build-mind.sh`: clone of `build-coins.sh` (pubspec swap with
  restore trap, `--target=lib/main_mind.dart`, `--dart-define=APP_VARIANT=mind`).
- Firebase: register `io.airo.app.mind` in the existing project;
  `google-services.json` gains the client entry.

## 4. Tests and verification gates

- Feature tests move with their trees into `packages/feature_assistant/test/`.
- New: `main_mind_shell_test` (registry: shell id, module ids, scribe route at
  `/`); route-parity test asserting the super app still resolves every
  assistant/wellbeing route name listed above.
- Gates: narrowest analyzer/test first; `cd app && flutter build web
  --release`; `scripts/build-mind.sh` artifact; super-app APK still builds.

## Error handling

- Screens navigating to super-app-only routes must degrade in `ShellId.mind`
  via the module's per-shell seam, never by branching on shell inside widgets.
  Wellbeing/quotes move into the package, which removes the known case;
  dogfood walk catches the rest.
- Build script restores pubspec on any exit (trap), same as coins.

## Build order

1. Extract `packages/feature_assistant` + `AssistantModule`; super app
   consumes it (behavior-neutral, route-parity proven). PR 1.
2. `ShellId.mind`, `MindScribeModule`, `main_mind.dart` rewrite,
   `pubspec_mind.yaml`, Android variant, `build-mind.sh`, Firebase id,
   dogfood. PR 2.
