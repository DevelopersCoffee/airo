# Airo Mind Modular App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship "Airo Mind" as a full standalone modular app (existing scribe journey + the super app's Mind tab) mirroring the Airo Coins/TV pattern: package-first extraction to `packages/feature_assistant`, a coins-style `main_mind.dart` shell, expanded `pubspec_mind.yaml`, Android `APP_VARIANT=mind`, and `scripts/build-mind.sh`.

**Architecture:** Extract `app/lib/features/assistant` + `agent_chat` + `wellbeing` + `quotes` into `packages/feature_assistant` exposing `AssistantModule implements AppModule`. Shared model-runtime services move to `core_ai`; assistant-only services move into the package; app-owned couplings enter through one `AssistantHostAdapter` seam. `packages/feature_mind` (the scribe) is untouched — an app-layer `MindScribeModule` wraps it, exactly as `CoinVaultModule` wraps `feature_coin`. Both shells consume the identical route table; super app keeps every route name.

**Tech Stack:** Flutter, Riverpod 3, go_router 17, Melos workspace, existing `core_product_shell` / `core_ai` / `core_auth` packages, `feature_mind` (flutter_rust_bridge scribe).

**Spec:** `docs/superpowers/specs/2026-08-06-airo-mind-modular-app-design.md`

## Global Constraints

- Route *names* in the super app must not change: `Assistant`, `assistant_chat`, `agent_notifications`, `profile`, `assistant_models`, `assistant_device_capabilities`, `assistant_model_advisor`, `assistant_prompt_lab`, `assistant_audio_scribe`, `assistant_agent_skills`, `assistant_mobile_actions`, `Wellbeing`. Paths under `/assistant/...` and `/wellbeing` unchanged.
- `packages/feature_assistant` must never import `package:airo_app` (`forbidden_dependencies: [app]` in `module.yaml`).
- `packages/feature_mind` (scribe) is read-only in this plan — no file inside it changes.
- No `compute()` / `Isolate.run` in presentation code (repo lint rule); moved code keeps its existing worker boundaries.
- Application id `io.airo.app.mind`, display name "Airo Mind", entrypoint `app/lib/main_mind.dart`, dart-define `APP_VARIANT=mind`.
- CI spend: narrowest local analyzer/test per task; full builds only at the phase gates listed here.
- Each phase lands as its own branch + PR off `origin/main`.
- SDK floors as in existing pubspecs: `sdk: ">=3.12.2 <4.0.0"`, `flutter: ">=3.44.4"`.

## Verified facts (origin/main 9a51c3ab)

(Re-verify only if a step contradicts them.)

- `packages/feature_mind` = scribe app package (MindService, MindHomeScreen, frb bindings). Consumed only by `app/lib/main_mind.dart` (bare MaterialApp today). `app/pubspec_mind.yaml` exists, minimal (flutter + feature_mind only). No `APP_VARIANT=mind` in gradle; no `scripts/build-mind.sh`.
- Super app Mind branch = `/assistant` routes (names in Global Constraints) built inline in `app/lib/core/routing/app_router.dart` (~lines 230–305); `Wellbeing` is a top-level `/wellbeing` route (~line 101).
- `app/lib/features/quotes` consumed only by `features/wellbeing` (`daily_quote_card.dart`).
- `features/agent_chat` external consumers: `core/app/airo_app.dart`, `core/routing/app_router.dart`, `core/services/local_runtime_preloader_service.dart` — all app-layer.
- Shared model services (outside-Mind consumers in parentheses) → move to `core_ai`:
  - `core/services/gemini_api_service.dart` (core/ai/ai_router_service)
  - `core/services/gemini_nano_service.dart` (ai_router_service, quest ×3, bill_split)
  - `core/services/litert_lm_service.dart` (bill_split)
  - `core/ai/model_learn_more_launcher.dart` (settings ×2)
- Assistant-only services → move into `feature_assistant`:
  - `core/services/voice_search_service.dart` (no outside consumers)
  - `core/services/local_runtime_preloader_service.dart` + `core/services/model_preload_preferences.dart` (outside consumer: `features/settings/presentation/intelligent_model_manager_provider.dart` — app layer, may import the package).
- App-core couplings confined to `chat_screen.dart` + `profile_screen.dart` (both in agent_chat): `auth_service`, `google_auth_service`, `http_dog`, `dictionary`, `airo_speech_service`, `locale_settings`, `bug_report_dialog`, `route_names`.
- `ShellId` has `mobile`, `tv`, `coins` — no `mind` yet.
- Templates: `app/lib/core/coins/coin_vault_module.dart`, `app/lib/main_coins.dart`, `app/test/main_coins_shell_test.dart`, `app/pubspec_coins.yaml`, `app/pubspec_tv.yaml`, `scripts/build-coins.sh`, coins block in `app/android/app/build.gradle.kts` (`appVariant` mapping ~lines 42–53, source-set block ~lines 185–192).

---

## Phase 1 — extract `packages/feature_assistant` (super app behavior-neutral)

Branch: `feat/feature-assistant-package` (current worktree branch may be renamed to this).

### Task 1: Scaffold the package

**Files:**
- Create: `packages/feature_assistant/pubspec.yaml`
- Create: `packages/feature_assistant/module.yaml`
- Create: `packages/feature_assistant/analysis_options.yaml`
- Create: `packages/feature_assistant/lib/feature_assistant.dart`
- Modify: `app/pubspec.yaml` (add path dep)

**Interfaces:**
- Produces: package `feature_assistant` resolvable from `app/pubspec.yaml`; barrel `package:feature_assistant/feature_assistant.dart` (empty for now).

- [ ] **Step 1: Create pubspec.yaml**

```yaml
name: feature_assistant
description: "Airo Mind tab - AI assistant, models, prompt lab, and wellbeing"
publish_to: none
version: 0.0.1

environment:
  sdk: ">=3.12.2 <4.0.0"
  flutter: ">=3.44.4"

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^3.3.2
  go_router: ^17.1.0
  core_ai:
    path: ../core_ai
  core_ui:
    path: ../core_ui
  core_product_shell:
    path: ../core_product_shell
  shared_preferences: ^2.5.5
  image_picker: ^1.2.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: 6.0.0
```

(Add further deps in Tasks 2–4 exactly as the analyzer demands them when code moves in — copy version pins from `app/pubspec.yaml`. Do not pre-add speculative deps.)

- [ ] **Step 2: Create analysis_options.yaml** — copy `packages/feature_coin/analysis_options.yaml` verbatim.

- [ ] **Step 3: Create module.yaml**

```yaml
name: feature_assistant
owner: Mind / Assistant Agent
capabilities:
  - capability.assistant.chat
  - capability.assistant.models.local
  - capability.assistant.wellbeing
supported_devices:
  - phone
  - tablet
  - desktop
ship_policy:
  tv: Never Ship
  phone: Always Ship
  tablet: Always Ship
  desktop: Optional
native_dependencies:
  - image_picker
reviewers:
  - Chief Architect
  - Chief Cloud Officer
  - Chief QA Officer
allowed_dependencies:
  - core_ai
  - core_ui
  - core_product_shell
forbidden_dependencies:
  - app
quality_gates: {}
```

- [ ] **Step 4: Create empty barrel** `lib/feature_assistant.dart` with a library doc comment only.

- [ ] **Step 5: Register in app** — add to `app/pubspec.yaml` dependencies:

```yaml
  feature_assistant:
    path: ../packages/feature_assistant
```

- [ ] **Step 6: Verify**

Run: `cd packages/feature_assistant && flutter pub get && dart analyze`
Expected: no issues.
Run: `cd app && flutter pub get`
Expected: resolves.

- [ ] **Step 7: Commit** — `feat(feature_assistant): scaffold package with module.yaml`

### Task 2: Move shared model services into `core_ai`

**Files:**
- Move: `app/lib/core/services/gemini_api_service.dart` → `packages/core_ai/lib/src/runtime/gemini_api_service.dart`
- Move: `app/lib/core/services/gemini_nano_service.dart` → `packages/core_ai/lib/src/runtime/gemini_nano_service.dart`
- Move: `app/lib/core/services/litert_lm_service.dart` → `packages/core_ai/lib/src/runtime/litert_lm_service.dart`
- Move: `app/lib/core/ai/model_learn_more_launcher.dart` → `packages/core_ai/lib/src/runtime/model_learn_more_launcher.dart`
- Modify: `packages/core_ai/lib/core_ai.dart` (export the four files)
- Modify consumers: `app/lib/core/ai/ai_router_service.dart`, `app/lib/features/quest/domain/services/gemini_quest_service.dart`, `app/lib/features/quest/presentation/screens/quest_chat_screen.dart`, `app/lib/features/quest/presentation/widgets/device_compatibility_banner.dart`, `app/lib/features/bill_split/domain/services/receipt_parser_service.dart`, `app/lib/features/bill_split/domain/services/receipt_litert_lm_extraction_service.dart`, `app/lib/features/settings/presentation/screens/ai_models_screen.dart`, `app/lib/features/settings/presentation/screens/model_detail_screen.dart`, `app/lib/core/services/local_runtime_preloader_service.dart`, plus every `features/agent_chat` / `features/assistant` file importing them.

**Interfaces:**
- Produces: `package:core_ai/core_ai.dart` exports `GeminiApiService`, `GeminiNanoService`, `LitertLmService`, and the model-learn-more launcher API — class names, members, and provider declarations unchanged (pure move).

- [ ] **Step 1: git mv the four files** into `packages/core_ai/lib/src/runtime/`.
- [ ] **Step 2: Fix intra-file imports** — moved files' relative imports become `package:core_ai/...` or package-relative; `gemini_api_service` keeps `dio` (add `dio` to `core_ai/pubspec.yaml` if absent, pin from app). If a moved file imports app code that cannot move, stop and split that symbol instead.
- [ ] **Step 3: Add exports** to `packages/core_ai/lib/core_ai.dart`.
- [ ] **Step 4: Rewrite all consumer imports**:

```bash
grep -rln "core/services/gemini_api_service\|core/services/gemini_nano_service\|core/services/litert_lm_service\|core/ai/model_learn_more_launcher" app/lib app/test
```
Rewrite each hit to `package:core_ai/core_ai.dart`.

- [ ] **Step 5: Verify** — `cd packages/core_ai && dart analyze && cd ../../app && dart analyze` — Expected: no errors.
- [ ] **Step 6: Run affected tests** — `cd app && flutter test test/features/quest test/features/bill_split test/features/settings` (adjust to dirs that exist) — Expected: same pass rate as baseline (`git stash` not needed; baseline = these suites on clean branch head before this task, run once if unsure).
- [ ] **Step 7: Commit** — `refactor(core_ai): move shared model-runtime services out of app core`

### Task 3: Move assistant + agent_chat + wellbeing + quotes trees into the package

**Files:**
- Move: `app/lib/features/assistant/**` → `packages/feature_assistant/lib/src/assistant/`
- Move: `app/lib/features/agent_chat/**` → `packages/feature_assistant/lib/src/agent_chat/`
- Move: `app/lib/features/wellbeing/**` → `packages/feature_assistant/lib/src/wellbeing/`
- Move: `app/lib/features/quotes/**` → `packages/feature_assistant/lib/src/quotes/`
- Move: `app/lib/core/services/voice_search_service.dart` → `packages/feature_assistant/lib/src/services/voice_search_service.dart`
- Move: `app/lib/core/services/local_runtime_preloader_service.dart` → `packages/feature_assistant/lib/src/services/local_runtime_preloader_service.dart`
- Move: `app/lib/core/services/model_preload_preferences.dart` → `packages/feature_assistant/lib/src/services/model_preload_preferences.dart`
- Move tests: `app/test/features/assistant/**`, `app/test/features/agent_chat/**`, and any wellbeing/quotes test dirs → `packages/feature_assistant/test/` (mirror subdirs).
- Modify: `packages/feature_assistant/lib/feature_assistant.dart` (exports)
- Modify: `app/lib/core/app/airo_app.dart`, `app/lib/features/settings/presentation/intelligent_model_manager_provider.dart` (imports → `package:feature_assistant/feature_assistant.dart`)

**Interfaces:**
- Consumes: `package:core_ai` exports from Task 2.
- Produces: barrel exports used later: `AssistantScreen`, `WellbeingScreen`, `ChatScreen`, `NotificationsScreen`, `ProfileScreen`, `ModelLibraryScreen`, `ModelCatalog`, `DeviceCapabilityReportLoaderScreen`, `ModelAdvisorScreen`, `PromptLabScreen`, `AudioScribeScreen`, `AgentSkillsScreen`, `MobileActionsScreen`, `DailyQuoteCard`, `LocalRuntimePreloaderService`, `ModelPreloadPreferences`, plus whatever `airo_app.dart` / settings consumed.

- [ ] **Step 1: git mv the trees** (code and tests).
- [ ] **Step 2: Rewrite imports inside the package** — old `../../../../core/...` relatives become `package:core_ai/...` or intra-package relatives. The **app-core couplings** (`auth_service`, `google_auth_service`, `http_dog`, `dictionary`, `airo_speech_service`, `locale_settings`, `bug_report_dialog`, `route_names`) in `chat_screen.dart` / `profile_screen.dart` will not resolve — leave broken; Task 4 introduces the seam. Everything else must resolve.
- [ ] **Step 3: Populate barrel** with the exports listed above.
- [ ] **Step 4: Rewrite app consumers** (`airo_app.dart`, `intelligent_model_manager_provider.dart`). `app_router.dart` stays broken until Task 5.
- [ ] **Step 5: Analyzer checkpoint**

Run: `cd packages/feature_assistant && dart analyze 2>&1 | grep -v "chat_screen\|profile_screen" | tail -20`
Expected: remaining errors only in chat_screen/profile_screen.

- [ ] **Step 6: Commit (WIP allowed on branch)** — `refactor(feature_assistant): move assistant, agent_chat, wellbeing, quotes into package`

### Task 4: `AssistantHostAdapter` seam for app-owned services

**Files:**
- Create: `packages/feature_assistant/lib/src/host/assistant_host_adapter.dart`
- Create: `packages/feature_assistant/lib/src/routing/assistant_route_names.dart`
- Modify: `packages/feature_assistant/lib/src/agent_chat/presentation/screens/chat_screen.dart`
- Modify: `packages/feature_assistant/lib/src/agent_chat/presentation/screens/profile_screen.dart`
- Create: `app/lib/core/assistant/app_assistant_host_adapter.dart`
- Modify: `app/lib/core/routing/route_names.dart` (assistant entries reference the package constants)
- Test: `packages/feature_assistant/test/host/assistant_host_adapter_test.dart`

**Interfaces:**
- Produces:

```dart
/// Host-app services the assistant screens need but the package must not own.
/// Both shells (super app and Airo Mind) provide the same app-layer
/// implementation; tests provide fakes.
abstract class AssistantHostAdapter {
  // Shape the members from what chat_screen/profile_screen actually call on
  // auth_service, google_auth_service, http_dog, dictionary,
  // airo_speech_service, locale_settings, and bug_report_dialog — one member
  // per call-site cluster, minimal surface. Read both screens first and
  // define exactly what they use, nothing more.
}

final assistantHostAdapterProvider = Provider<AssistantHostAdapter>(
  (ref) => throw UnimplementedError(
    'AssistantHostAdapter must be overridden by the owning shell',
  ),
);
```

- `AssistantRouteNames`: the twelve route names from Global Constraints as `static const String` values, copied verbatim from `app/lib/core/routing/route_names.dart` / the router literals. App-side `route_names.dart` switches its assistant entries to reference these constants so they can never diverge.

- [ ] **Step 1: Read `chat_screen.dart` + `profile_screen.dart` end to end**; list every call into the eight app-core modules.
- [ ] **Step 2: Write failing test** — fake adapter, pump `ChatScreen` in `ProviderScope` overriding `assistantHostAdapterProvider`, expect build without real services.
- [ ] **Step 3: Run test** — Expected: FAIL (type missing).
- [ ] **Step 4: Implement adapter + rewrite the two screens** to consume `ref.read(assistantHostAdapterProvider)`.
- [ ] **Step 5: Implement `AppAssistantHostAdapter`** in `app/lib/core/assistant/` wrapping the real implementations.
- [ ] **Step 6: Run** `cd packages/feature_assistant && dart analyze && flutter test` — Expected: package fully clean, moved tests pass.
- [ ] **Step 7: Commit** — `refactor(feature_assistant): inject app-owned services via AssistantHostAdapter`

### Task 5: `AssistantModule` + super app consumes it

**Files:**
- Create: `packages/feature_assistant/lib/src/assistant_module.dart` (export from barrel)
- Modify: `packages/core_product_shell/lib/src/shell_id.dart` (add `mind`)
- Modify: `app/lib/core/routing/app_router.dart`
- Modify: `app/lib/main.dart` (register module in the mobile registry, next to iptv/coin_vault)
- Test: `app/test/assistant_route_parity_test.dart`

**Interfaces:**
- Consumes: `AppModule`, `ShellId`, `ModuleRegistry` from `core_product_shell`; screens from Tasks 3–4.
- Produces:

```dart
class AssistantModule extends AppModule {
  AssistantModule({required this.hostAdapter, this.basePath = '/assistant'});
  final AssistantHostAdapter hostAdapter;
  final String basePath;
  @override String get id => 'assistant';
  @override Set<ShellId> get supportedShells => {ShellId.mobile, ShellId.mind};
  @override List<Override> providerOverridesFor(ShellId shell) =>
      [assistantHostAdapterProvider.overrideWithValue(hostAdapter)];
  @override List<RouteBase> routesFor(ShellId shell);
}
```

`routesFor` returns (a) the assistant route tree currently inlined in `app_router.dart` (~lines 230–305: children `chat`, `notifications`, `profile`, `models`, `device-capabilities`, `model-advisor`, `prompt-lab`, `audio-scribe`, `skills`, `mobile-actions`) and (b) the `/wellbeing` route, names from `AssistantRouteNames`. Hub path is `basePath` for both shells (`/assistant`).

ShellId addition:

```dart
  /// The Airo Mind shell (`app/lib/main_mind.dart`).
  static const mind = ShellId('mind');
```

- [ ] **Step 1: Write failing route-parity test** `app/test/assistant_route_parity_test.dart`:

```dart
// Build the mobile registry + router the same way main.dart does (mirror
// main_super_app_shell_test.dart's setup), then:
const names = [
  'Assistant', 'assistant_chat', 'agent_notifications', 'profile',
  'assistant_models', 'assistant_device_capabilities',
  'assistant_model_advisor', 'assistant_prompt_lab',
  'assistant_audio_scribe', 'assistant_agent_skills',
  'assistant_mobile_actions', 'Wellbeing',
];
for (final name in names) {
  expect(router.configuration.namedLocation(name), isNotEmpty,
      reason: 'route $name must survive the feature_assistant extraction');
}
```

(None of these routes take path parameters.)

- [ ] **Step 2: Run it on the pre-extraction router** — Expected: PASS (baseline; commit the test first so the extraction diff proves parity).
- [ ] **Step 3: Implement `AssistantModule`**; add `ShellId.mind`.
- [ ] **Step 4: Rewire `app_router.dart`** — delete the assistant/wellbeing feature imports and the inline route blocks; consume `_requiredModuleRoutes(moduleRegistry, 'assistant')` for the Mind `StatefulShellBranch` (and mount the wellbeing route from the same module bundle at top level, matching how the module splits them — if the module returns both in one list, split by path in the router or have `routesFor` order them hub-first and document it). Register `AssistantModule(hostAdapter: AppAssistantHostAdapter(...))` in `main.dart`'s registry builder.
- [ ] **Step 5: Run** `cd app && dart analyze && flutter test test/assistant_route_parity_test.dart test/main_super_app_shell_test.dart` — Expected: PASS.
- [ ] **Step 6: Full app test sweep** — `cd app && flutter test` — Expected: baseline pass rate.
- [ ] **Step 7: Commit** — `refactor(app): consume Mind tab via AssistantModule from feature_assistant`

### Task 6: Phase 1 gate + PR

- [ ] **Step 1:** `cd app && flutter build web --release` — Expected: succeeds.
- [ ] **Step 2:** `cd packages/feature_assistant && dart analyze; cd ../core_ai && dart analyze` — Expected: clean.
- [ ] **Step 3:** Push branch, open PR `refactor: extract feature_assistant package (Mind tab, behavior-neutral)`. Body links the spec, names the route-parity test as proof. Reviewers per `module.yaml`.

## Phase 2 — Airo Mind shell upgrade

Branch (after Phase 1 merges): `feat/airo-mind-shell`.

### Task 7: `MindScribeModule` + `main_mind.dart` rewrite + registry test

**Files:**
- Create: `app/lib/core/mind/mind_scribe_module.dart`
- Rewrite: `app/lib/main_mind.dart`
- Test: `app/test/main_mind_shell_test.dart`

**Interfaces:**
- Consumes: `MindService`, `MindHomeScreen` from `package:feature_mind`; `AssistantModule`, `AppAssistantHostAdapter`, `ShellId.mind`.
- Produces:

```dart
/// Wraps the feature_mind scribe journey as a shell-registrable module,
/// the same way CoinVaultModule wraps feature_coin. feature_mind itself is
/// not modified.
class MindScribeModule extends AppModule {
  @override String get id => 'mind_scribe';
  @override Set<ShellId> get supportedShells => {ShellId.mind};
  // Owns the MindService lifecycle: created in initialize(), disposed in
  // dispose(). routesFor returns GoRoute(path: '/', builder: MindHomeScreen(service: _service)).
}
```

and `buildMindModuleRegistry()` (`@visibleForTesting`) in `main_mind.dart`.

- [ ] **Step 1: Write failing test** `app/test/main_mind_shell_test.dart`:

```dart
import 'package:airo_app/main_mind.dart';
import 'package:core_product_shell/core_product_shell.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('mind registry registers scribe and assistant modules', () {
    final registry = buildMindModuleRegistry();
    expect(registry.shell, ShellId.mind);
    expect(registry.moduleIds, containsAll(['mind_scribe', 'assistant']));
    final paths = registry.allRoutes.whereType<GoRoute>().map((r) => r.path);
    expect(paths, contains('/'));
    expect(paths, contains('/assistant'));
  });
}
```

- [ ] **Step 2: Run** — Expected: FAIL (`buildMindModuleRegistry` missing).
- [ ] **Step 3: Implement** — `MindScribeModule`; rewrite `main_mind.dart` on the `main_coins.dart` skeleton: `WidgetsFlutterBinding.ensureInitialized()`; minimal Firebase init copied from `main.dart` (auth parity — not its EPG/notification wiring); registry registers `MindScribeModule()` and `AssistantModule(hostAdapter: AppAssistantHostAdapter(...))`; `MaterialApp.router` with GoRouter from `registry.allRoutes`, `initialLocation: '/'`; provider overrides from `registry` applied to the root `ProviderScope`; pro bootstrap post-frame.
- [ ] **Step 4: Run tests** — `flutter test test/main_mind_shell_test.dart test/main_coins_shell_test.dart test/main_super_app_shell_test.dart` — Expected: PASS.
- [ ] **Step 5: Commit** — `feat(app): rebuild Airo Mind shell on the module registry`

### Task 8: Expand `pubspec_mind.yaml`

**Files:**
- Modify: `app/pubspec_mind.yaml`

**Interfaces:**
- Produces: dependency profile the build script swaps in; supports both `feature_mind` and `feature_assistant`.

- [ ] **Step 1: Expand profile** — keep name/description/version shape; dependencies: flutter, flutter_riverpod 3.3.2, go_router (pin from `app/pubspec.yaml`), `feature_mind`, `feature_assistant`, `core_ai`, `core_ui`, `core_auth`, `core_product_shell`, `core_entitlements`, `airo_pro_bootstrap`, firebase_core 4.4.0, firebase_auth 6.1.4, google_sign_in 7.2.0, image_picker 1.2.1, shared_preferences ^2.5.5, flutter_local_notifications 20.1.0 (+ timezone 0.10.1 only if resolution demands), intl 0.20.2. Stub `dependency_overrides` from `packages/stubs/` only where the resolver/compiler forces them — iterate: swap pubspec, `flutter pub get`, `flutter build apk --debug --target=lib/main_mind.dart --dart-define=APP_VARIANT=mind`, add the named stub, repeat. Copy override blocks verbatim from `pubspec_tv.yaml`. No stockfish/chess/flame/mlkit/IPTV weight unless a transitive edge forces a stub.
- [ ] **Step 2: Verify debug build compiles** with the swapped pubspec; restore original pubspec + lock afterwards (same trap discipline as the build script).
- [ ] **Step 3: Commit** — `feat(app): expand pubspec_mind.yaml for the full Airo Mind shell`

### Task 9: Android variant + build script

**Files:**
- Modify: `app/android/app/build.gradle.kts`
- Create: `app/android/app/src/mind/AndroidManifest.xml`
- Create: `scripts/build-mind.sh`

**Interfaces:**
- Produces: `APP_VARIANT=mind` → applicationId `io.airo.app.mind`, label "Airo Mind"; APK artifact.

- [ ] **Step 1: Extend gradle mapping** — in the existing `when(appVariant)` blocks add `"mind" -> "io.airo.app.mind"` and `"mind" -> "Airo Mind"`; add a source-set block mirroring the coins one (`manifest.srcFile("src/mind/AndroidManifest.xml")`; no variant Kotlin dir — mind needs no FLAG_SECURE).
- [ ] **Step 2: Create `src/mind/AndroidManifest.xml`** — copy the coins variant manifest, strip coins-specific attrs (FLAG_SECURE), keep label/icon hooks; add RECORD_AUDIO permission if the base manifest does not already carry it (scribe records meetings — check `app/android/app/src/main/AndroidManifest.xml` first).
- [ ] **Step 3: Create `scripts/build-mind.sh`** — copy `scripts/build-coins.sh` verbatim; replace `coins`→`mind`, `AIRO_COINS_BUILD_MODE`→`AIRO_MIND_BUILD_MODE`, target `lib/main_mind.dart`, define `APP_VARIANT=mind`. `chmod +x`.
- [ ] **Step 4: Run** `AIRO_MIND_BUILD_MODE=debug scripts/build-mind.sh` — Expected: artifact path printed, APK exists.
- [ ] **Step 5: Verify super app untouched** — `cd app && flutter build apk --debug` — Expected: succeeds.
- [ ] **Step 6: Commit** — `feat(android): add mind APP_VARIANT and build-mind.sh`

### Task 10: Firebase app id (manual + wiring)

- [ ] **Step 1: USER ACTION** — register Android app `io.airo.app.mind` in the existing Firebase project console; download updated `google-services.json`.
- [ ] **Step 2:** Replace `app/android/app/google-services.json`; diff to confirm the change is only an added client entry.
- [ ] **Step 3:** `AIRO_MIND_BUILD_MODE=debug scripts/build-mind.sh` — Expected: google-services plugin resolves the new package.
- [ ] **Step 4: Commit** — `chore(firebase): register io.airo.app.mind client`

### Task 11: Phase 2 gate + PR + dogfood

- [ ] **Step 1:** `cd app && flutter test test/main_mind_shell_test.dart test/assistant_route_parity_test.dart && dart analyze` — Expected: PASS/clean.
- [ ] **Step 2:** `AIRO_MIND_BUILD_MODE=release scripts/build-mind.sh` — Expected: `app-arm64-v8a-release.apk`.
- [ ] **Step 3:** Install on Pixel 9 (`adb install -r`), walk: scribe home → record flow entry → `/assistant` hub → chat → model library → prompt lab → wellbeing → profile/sign-in. Record gaps as issues, do not fix inline.
- [ ] **Step 4:** Push branch, open PR `feat: Airo Mind standalone shell (registry, APP_VARIANT=mind, build-mind.sh)`.

---

## Self-review notes

- Spec coverage: package extraction T1–T5, shell T7–T8, Android+script T9, Firebase T10, gates+dogfood T6/T11, route parity T5, scribe wrapped not modified T7. Wellbeing/quotes inside the package removes the known dead-link case; T11 walk is the catch-all.
- `AssistantHostAdapter` member list deliberately derived in T4 Step 1 from real call-sites — the only deferred shape.
- Type consistency: `AssistantModule(hostAdapter, basePath)` identical in T5/T7; `buildMindModuleRegistry()` matches coins convention and T7 test; `MindScribeModule.id == 'mind_scribe'` matches T7 test.
