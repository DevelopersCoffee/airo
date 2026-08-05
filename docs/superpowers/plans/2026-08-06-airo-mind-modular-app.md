# Airo Mind Modular App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the super app's Mind tab as a standalone modular app ("Airo Mind") from the same codebase, mirroring the Airo Coins/TV pattern: package-first extraction to `packages/feature_mind`, a `main_mind.dart` entrypoint, `pubspec_mind.yaml` profile, Android `APP_VARIANT=mind`, and `scripts/build-mind.sh`.

**Architecture:** Extract `app/lib/features/mind` + `app/lib/features/agent_chat` + `app/lib/features/quotes` into `packages/feature_mind` exposing `MindModule implements AppModule` (from `core_product_shell`). Model-runtime services shared with quest/bill_split/settings move to `packages/core_ai`; mind-only services move into the package; app-owned couplings (auth, http_dog, dictionary, speech, locale, bug report) are injected through a single `MindHostAdapter` seam. Both shells consume the identical route table; super app keeps `/mind/...` paths and all route names.

**Tech Stack:** Flutter, Riverpod 3, go_router 17, Melos workspace, existing `core_product_shell` / `core_ai` / `core_auth` packages.

**Spec:** `docs/superpowers/specs/2026-08-06-airo-mind-modular-app-design.md`

## Global Constraints

- Route *names* in the super app must not change: `Mind`, `mind_chat`, `agent_notifications`, `profile`, `assistant_models`, `mind_device_capabilities`, `mind_model_advisor`, `mind_prompt_lab`, `mind_audio_scribe`, `mind_agent_skills`, `mind_mobile_actions`. Paths under `/mind/...` unchanged.
- `packages/feature_mind` must never import `package:airo_app` (`forbidden_dependencies: [app]` in `module.yaml`).
- No `compute()` / `Isolate.run` in presentation code (repo lint rule); moved code keeps whatever worker boundaries it already has.
- Applicaton id `io.airo.app.mind`, display name "Airo Mind", entrypoint `app/lib/main_mind.dart`, dart-define `APP_VARIANT=mind`.
- CI spend: run the narrowest local analyzer/test per task; full builds only at the phase gates listed here.
- Each phase lands as its own branch + PR off `main` (commit/PR cadence at every logical milestone).
- SDK floors as in existing pubspecs: `sdk: ">=3.12.2 <4.0.0"`, `flutter: ">=3.44.4"`.

## Verified facts the plan relies on

(Re-verify only if a step contradicts them.)

- `app/lib/features/quotes` (6 files) is consumed **only** by `features/mind` → moves into the package.
- `features/agent_chat` external consumers: `core/app/airo_app.dart`, `core/routing/app_router.dart`, `core/services/local_runtime_preloader_service.dart` — all app-layer, all get rewritten to `package:feature_mind` imports.
- Shared model services (consumers outside Mind in parentheses) → move to `core_ai`:
  - `core/services/gemini_api_service.dart` (core/ai/ai_router_service)
  - `core/services/gemini_nano_service.dart` (ai_router_service, quest ×3, bill_split)
  - `core/services/litert_lm_service.dart` (bill_split)
  - `core/ai/model_learn_more_launcher.dart` (settings ×2)
- Mind-only services → move into `feature_mind`:
  - `core/services/voice_search_service.dart` (no outside consumers)
  - `core/services/local_runtime_preloader_service.dart` + `core/services/model_preload_preferences.dart` (outside consumer: `features/settings/presentation/intelligent_model_manager_provider.dart` — app layer, may import `feature_mind`).
- App-core couplings confined to `chat_screen.dart` + `profile_screen.dart`: `auth_service`, `google_auth_service`, `http_dog`, `dictionary`, `airo_speech_service`, `locale_settings`, `bug_report_dialog`, `route_names`.
- Templates: `app/lib/core/coins/coin_vault_module.dart`, `app/lib/main_coins.dart`, `app/test/main_coins_shell_test.dart`, `app/pubspec_coins.yaml`, `app/pubspec_tv.yaml`, `scripts/build-coins.sh`, coins block in `app/android/app/build.gradle.kts` (lines ~42–53, ~185–192).

---

## Phase 1 — extract `packages/feature_mind` (super app behavior-neutral)

Branch: `feat/feature-mind-package`.

### Task 1: Scaffold the package

**Files:**
- Create: `packages/feature_mind/pubspec.yaml`
- Create: `packages/feature_mind/module.yaml`
- Create: `packages/feature_mind/analysis_options.yaml`
- Create: `packages/feature_mind/lib/feature_mind.dart`

**Interfaces:**
- Produces: package `feature_mind` resolvable from `app/pubspec.yaml`; barrel `package:feature_mind/feature_mind.dart` (empty for now).

- [ ] **Step 1: Create pubspec.yaml**

```yaml
name: feature_mind
description: "Airo Mind - AI assistant, models, prompt lab, and wellbeing hub"
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

- [ ] **Step 2: Create analysis_options.yaml**

Copy `packages/feature_coin/analysis_options.yaml` verbatim.

- [ ] **Step 3: Create module.yaml**

```yaml
name: feature_mind
owner: Mind / Assistant Agent
capabilities:
  - capability.mind.assistant.chat
  - capability.mind.models.local
  - capability.mind.wellbeing.hub
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

- [ ] **Step 4: Create empty barrel** `lib/feature_mind.dart` with a library doc comment only.

- [ ] **Step 5: Register in app** — add to `app/pubspec.yaml` dependencies:

```yaml
  feature_mind:
    path: ../packages/feature_mind
```

- [ ] **Step 6: Verify**

Run: `cd packages/feature_mind && flutter pub get && dart analyze`
Expected: no issues.
Run: `cd app && flutter pub get`
Expected: resolves.

- [ ] **Step 7: Commit** — `feat(feature_mind): scaffold package with module.yaml`

### Task 2: Move shared model services into `core_ai`

**Files:**
- Move: `app/lib/core/services/gemini_api_service.dart` → `packages/core_ai/lib/src/runtime/gemini_api_service.dart`
- Move: `app/lib/core/services/gemini_nano_service.dart` → `packages/core_ai/lib/src/runtime/gemini_nano_service.dart`
- Move: `app/lib/core/services/litert_lm_service.dart` → `packages/core_ai/lib/src/runtime/litert_lm_service.dart`
- Move: `app/lib/core/ai/model_learn_more_launcher.dart` → `packages/core_ai/lib/src/runtime/model_learn_more_launcher.dart`
- Modify: `packages/core_ai/lib/core_ai.dart` (export the four files)
- Modify consumers: `app/lib/core/ai/ai_router_service.dart`, `app/lib/features/quest/domain/services/gemini_quest_service.dart`, `app/lib/features/quest/presentation/screens/quest_chat_screen.dart`, `app/lib/features/quest/presentation/widgets/device_compatibility_banner.dart`, `app/lib/features/bill_split/domain/services/receipt_parser_service.dart`, `app/lib/features/bill_split/domain/services/receipt_litert_lm_extraction_service.dart`, `app/lib/features/settings/presentation/screens/ai_models_screen.dart`, `app/lib/features/settings/presentation/screens/model_detail_screen.dart`, `app/lib/core/services/local_runtime_preloader_service.dart`, plus every `features/agent_chat` / `features/mind` file importing them.

**Interfaces:**
- Produces: `package:core_ai/core_ai.dart` exports `GeminiApiService`, `GeminiNanoService`, `LitertLmService`, model-learn-more launcher API — class names, members, and provider declarations unchanged (pure move).

- [ ] **Step 1: git mv the four files** into `packages/core_ai/lib/src/runtime/`.
- [ ] **Step 2: Fix intra-file imports** — the moved files' relative imports become `package:core_ai/...` or relative within the package; `gemini_api_service` keeps its `dio` import (add `dio` to `core_ai/pubspec.yaml` if absent, pin from app). If any moved file imports app code that cannot move (check first — none expected), stop and split that symbol out instead.
- [ ] **Step 3: Add exports** to `packages/core_ai/lib/core_ai.dart`.
- [ ] **Step 4: Rewrite all consumer imports** listed above from `../../core/services/...` to `package:core_ai/core_ai.dart`:

```bash
grep -rln "core/services/gemini_api_service\|core/services/gemini_nano_service\|core/services/litert_lm_service\|core/ai/model_learn_more_launcher" app/lib app/test
```
Rewrite each hit.

- [ ] **Step 5: Verify**

Run: `cd packages/core_ai && dart analyze && cd ../../app && dart analyze`
Expected: no errors.

- [ ] **Step 6: Run existing affected tests**

Run: `cd app && flutter test test/features/mind test/ --name gemini 2>/dev/null || flutter test`
Expected: same pass rate as before the move (run `flutter test` once on clean `main` first if unsure of baseline).

- [ ] **Step 7: Commit** — `refactor(core_ai): move shared model-runtime services out of app core`

### Task 3: Move mind + agent_chat + quotes trees into the package

**Files:**
- Move: `app/lib/features/mind/**` → `packages/feature_mind/lib/src/mind/`
- Move: `app/lib/features/agent_chat/**` → `packages/feature_mind/lib/src/agent_chat/`
- Move: `app/lib/features/quotes/**` → `packages/feature_mind/lib/src/quotes/`
- Move: `app/lib/core/services/voice_search_service.dart` → `packages/feature_mind/lib/src/services/voice_search_service.dart`
- Move: `app/lib/core/services/local_runtime_preloader_service.dart` → `packages/feature_mind/lib/src/services/local_runtime_preloader_service.dart`
- Move: `app/lib/core/services/model_preload_preferences.dart` → `packages/feature_mind/lib/src/services/model_preload_preferences.dart`
- Move tests: `app/test/features/mind/**` → `packages/feature_mind/test/mind/`; agent_chat + quotes test trees likewise (`ls app/test/features` to enumerate).
- Modify: `packages/feature_mind/lib/feature_mind.dart` (export screens/providers the app consumes)
- Modify: `app/lib/core/app/airo_app.dart`, `app/lib/features/settings/presentation/intelligent_model_manager_provider.dart` (imports → `package:feature_mind/feature_mind.dart`)

**Interfaces:**
- Consumes: `package:core_ai` exports from Task 2.
- Produces: barrel exports used later: `MindScreen`, `ChatScreen`, `NotificationsScreen`, `ProfileScreen`, `ModelLibraryScreen`, `ModelCatalog`, `DeviceCapabilityReportLoaderScreen`, `ModelAdvisorScreen`, `PromptLabScreen`, `AudioScribeScreen`, `AgentSkillsScreen`, `MobileActionsScreen`, `DailyQuoteCard`, `LocalRuntimePreloaderService`, `ModelPreloadPreferences`, plus whatever `airo_app.dart` / settings consumed.

- [ ] **Step 1: git mv the trees** (code and tests).
- [ ] **Step 2: Rewrite imports inside the package** — relative `../../../../core/...` imports become either `package:core_ai/...` (Task 2 services) or intra-package relatives. The **app-core couplings** (`auth_service`, `google_auth_service`, `http_dog`, `dictionary`, `airo_speech_service`, `locale_settings`, `bug_report_dialog`, `route_names`) in `chat_screen.dart` / `profile_screen.dart` will not resolve — leave them broken here; Task 4 introduces the seam. Everything else must resolve.
- [ ] **Step 3: Populate barrel** `lib/feature_mind.dart` with the exports listed above.
- [ ] **Step 4: Rewrite app consumers** (`airo_app.dart`, `intelligent_model_manager_provider.dart`) to `package:feature_mind/feature_mind.dart`. `app_router.dart` stays broken until Task 5.
- [ ] **Step 5: Analyzer checkpoint**

Run: `cd packages/feature_mind && dart analyze 2>&1 | grep -v "chat_screen\|profile_screen" | tail -20`
Expected: remaining errors only in chat_screen/profile_screen (seam) — everything else clean.

- [ ] **Step 6: Commit (WIP allowed on branch)** — `refactor(feature_mind): move mind, agent_chat, quotes trees into package`

### Task 4: `MindHostAdapter` seam for app-owned services

**Files:**
- Create: `packages/feature_mind/lib/src/host/mind_host_adapter.dart`
- Modify: `packages/feature_mind/lib/src/agent_chat/presentation/screens/chat_screen.dart`
- Modify: `packages/feature_mind/lib/src/agent_chat/presentation/screens/profile_screen.dart`
- Create: `app/lib/core/mind/app_mind_host_adapter.dart`
- Test: `packages/feature_mind/test/host/mind_host_adapter_test.dart`

**Interfaces:**
- Produces:

```dart
/// Host-app services the Mind screens need but the package must not own.
/// Both shells (super app and Airo Mind) provide the same app-layer
/// implementation; tests provide fakes.
abstract class MindHostAdapter {
  // Shape the members from what chat_screen/profile_screen actually call on
  // auth_service, google_auth_service, http_dog, dictionary,
  // airo_speech_service, locale_settings, and bug_report_dialog — one member
  // per call-site cluster, minimal surface. Read both screens first and
  // define exactly what they use, nothing more.
}

final mindHostAdapterProvider = Provider<MindHostAdapter>(
  (ref) => throw UnimplementedError(
    'MindHostAdapter must be overridden by the owning shell',
  ),
);
```

- Route-name constants: create `packages/feature_mind/lib/src/routing/mind_route_names.dart` holding the eleven Mind route names as `static const String` values, values copied verbatim from `app/lib/core/routing/route_names.dart`. `route_names.dart` in the app switches its Mind entries to re-export/reference these constants so the two can never diverge.

- [ ] **Step 1: Read `chat_screen.dart` + `profile_screen.dart` end to end**; list every call into the eight app-core modules.
- [ ] **Step 2: Write failing test** — `mind_host_adapter_test.dart`: instantiate a fake adapter, pump `ChatScreen` inside a `ProviderScope` overriding `mindHostAdapterProvider`, expect it builds without touching real services.
- [ ] **Step 3: Run test** — Expected: FAIL (adapter type does not exist).
- [ ] **Step 4: Implement adapter + rewrite the two screens** to consume `ref.read(mindHostAdapterProvider)`.
- [ ] **Step 5: Implement `AppMindHostAdapter` in app** wrapping the real `auth_service`, `google_auth_service`, `http_dog`, dictionary, speech, locale, bug-report implementations.
- [ ] **Step 6: Run** `cd packages/feature_mind && dart analyze && flutter test` — Expected: package fully clean, moved tests pass.
- [ ] **Step 7: Commit** — `refactor(feature_mind): inject app-owned services via MindHostAdapter`

### Task 5: `MindModule` + super app consumes it

**Files:**
- Create: `packages/feature_mind/lib/src/mind_module.dart` (export from barrel)
- Modify: `app/lib/core/routing/app_router.dart`
- Modify: `app/lib/main.dart` (register module in the mobile registry, next to iptv/coin_vault registration)
- Test: `app/test/mind_route_parity_test.dart`

**Interfaces:**
- Consumes: `AppModule`, `ShellId`, `ModuleRegistry` from `core_product_shell`; screens from Tasks 3–4.
- Produces:

```dart
class MindModule extends AppModule {
  MindModule({this.basePath = '/mind'});
  final String basePath;
  @override String get id => 'mind';
  @override Set<ShellId> get supportedShells => {ShellId.mobile, ShellId.mind};
  @override List<Override> providerOverridesFor(ShellId shell);
  @override List<RouteBase> routesFor(ShellId shell);
}
```

`routesFor` returns the exact route tree currently in `app_router.dart` lines ~210–290 (paths `chat`, `notifications`, `profile`, `models`, `device-capabilities`, `model-advisor`, `prompt-lab`, `audio-scribe`, `skills`, `mobile-actions` under the hub route), with names from `MindRouteNames`. For `ShellId.mobile` the hub path is `basePath` (`/mind`); for `ShellId.mind` it is `/` with the same children. `providerOverridesFor` returns the `mindHostAdapterProvider` override wired by the registering shell (constructor parameter `hostAdapter`).

Note: `ShellId.mind` does not exist until Phase 2 Task 7. In this task reference it as `const ShellId('mind')` is **not** allowed to appear twice — instead add the constant in this task (it is additive and harmless before the shell exists):

- Modify: `packages/core_product_shell/lib/src/shell_id.dart` — add

```dart
  /// The Airo Mind shell (`app/lib/main_mind.dart`).
  static const mind = ShellId('mind');
```

- [ ] **Step 1: Write failing route-parity test** `app/test/mind_route_parity_test.dart`:

```dart
import 'package:airo_app/core/routing/app_router.dart';
// build the mobile registry the same way main.dart does, then:
void main() {
  test('super app keeps every Mind route name', () {
    final router = AppRouter.createRouter(moduleRegistry: buildMobileRegistry());
    const names = [
      'Mind', 'mind_chat', 'agent_notifications', 'profile',
      'assistant_models', 'mind_device_capabilities', 'mind_model_advisor',
      'mind_prompt_lab', 'mind_audio_scribe', 'mind_agent_skills',
      'mind_mobile_actions',
    ];
    for (final name in names) {
      expect(
        router.configuration.namedLocation(name),
        isNotEmpty,
        reason: 'route $name must survive the feature_mind extraction',
      );
    }
  });
}
```

(Mirror how `main_super_app_shell_test.dart` obtains the registry; parameterized routes may need `pathParameters` — none of the Mind routes have params.)

- [ ] **Step 2: Run it on the pre-extraction router** — Expected: PASS (this is the baseline; commit the test first so the extraction diff proves parity).
- [ ] **Step 3: Implement `MindModule`**; add `ShellId.mind`.
- [ ] **Step 4: Rewire `app_router.dart`** — delete the four `features/mind/...` + seven `features/agent_chat/...` imports and the inline Mind branch; consume `_requiredModuleRoutes(moduleRegistry, 'mind')` in the Mind `StatefulShellBranch`, same shape as iptv. Register `MindModule(hostAdapter: AppMindHostAdapter(...))` in `main.dart`'s registry builder.
- [ ] **Step 5: Run** `cd app && dart analyze && flutter test test/mind_route_parity_test.dart test/main_super_app_shell_test.dart` — Expected: PASS.
- [ ] **Step 6: Full app test sweep** `cd app && flutter test` — Expected: baseline pass rate.
- [ ] **Step 7: Commit** — `refactor(app): consume Mind via MindModule from feature_mind`

### Task 6: Phase 1 gate + PR

- [ ] **Step 1:** `cd app && flutter build web --release` — Expected: succeeds (native-path rule).
- [ ] **Step 2:** `melos exec --scope="feature_mind,core_ai" -- dart analyze` (or per-package `dart analyze`) — Expected: clean.
- [ ] **Step 3:** Push branch, open PR titled `refactor: extract feature_mind package (Mind tab, behavior-neutral)`. Body links the spec, states route-parity test as the proof. Reviewers per `module.yaml`.

## Phase 2 — Airo Mind shell

Branch (after Phase 1 merges): `feat/airo-mind-shell`.

### Task 7: `main_mind.dart` + registry test

**Files:**
- Create: `app/lib/main_mind.dart`
- Test: `app/test/main_mind_shell_test.dart`

**Interfaces:**
- Consumes: `MindModule`, `ShellId.mind`, `ModuleRegistry`, `AppMindHostAdapter`.
- Produces: `buildMindModuleRegistry()` (`@visibleForTesting`), `AiroMindApp` root widget.

- [ ] **Step 1: Write failing test** `app/test/main_mind_shell_test.dart` mirroring `main_coins_shell_test.dart`:

```dart
import 'package:airo_app/main_mind.dart';
import 'package:core_product_shell/core_product_shell.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('mind registry registers the mind module for ShellId.mind', () {
    final registry = buildMindModuleRegistry();
    expect(registry.shell, ShellId.mind);
    expect(registry.moduleIds, ['mind']);
    final paths = registry.allRoutes.whereType<GoRoute>().map((r) => r.path);
    expect(paths, contains('/'));
  });
}
```

- [ ] **Step 2: Run** — Expected: FAIL (`main_mind.dart` missing).
- [ ] **Step 3: Implement `main_mind.dart`** — copy `main_coins.dart` structure: `WidgetsFlutterBinding.ensureInitialized()`; Firebase init as `main.dart` does it (parity needs auth — copy the minimal Firebase init block from `main.dart`, not its EPG/notification wiring); `runApp(AiroMindApp(registry: buildMindModuleRegistry()))`; pro bootstrap post-frame. Registry builder registers `MindModule(basePath: '/', hostAdapter: AppMindHostAdapter(...))`. Router built from `registry.allRoutes`, `initialLocation: '/'`.
- [ ] **Step 4: Run test** — Expected: PASS. Also `flutter test test/main_coins_shell_test.dart test/main_super_app_shell_test.dart` still PASS.
- [ ] **Step 5: Commit** — `feat(app): add Airo Mind shell entrypoint`

### Task 8: `pubspec_mind.yaml`

**Files:**
- Create: `app/pubspec_mind.yaml`

**Interfaces:**
- Produces: dependency profile the build script swaps in.

- [ ] **Step 1: Author profile** — start from `app/pubspec_coins.yaml` shape, version `0.0.1+1`, description "Airo Mind - local-first AI assistant". Dependencies: flutter, flutter_riverpod 3.3.2, go_router ^17.3.0, `airo_pro_bootstrap`, `core_entitlements`, `core_product_shell`, `core_ai`, `core_ui`, `core_auth`, `feature_mind`, firebase_core 4.4.0, firebase_auth 6.1.4, google_sign_in 7.2.0, image_picker 1.2.1, shared_preferences ^2.5.5, flutter_local_notifications 20.1.0 (+ timezone 0.10.1 if it fails to resolve without), intl 0.20.2. Add stub `dependency_overrides` from `packages/stubs/` only for packages the resolver/compiler actually drags in — iterate: swap pubspec, `flutter pub get`, `flutter build apk --debug --target=lib/main_mind.dart --dart-define=APP_VARIANT=mind`, add the stub override the error names, repeat. Copy override blocks verbatim from `pubspec_tv.yaml`. Do not include stockfish/chess/flame/mlkit or the IPTV/media stack at all unless a transitive edge forces a stub.
- [ ] **Step 2: Verify debug build compiles** with the swapped pubspec (restore original pubspec + lock after, same trap discipline as the build script).
- [ ] **Step 3: Commit** — `feat(app): add pubspec_mind.yaml profile for Airo Mind builds`

### Task 9: Android variant + build script

**Files:**
- Modify: `app/android/app/build.gradle.kts`
- Create: `app/android/app/src/mind/AndroidManifest.xml`
- Create: `scripts/build-mind.sh`

**Interfaces:**
- Produces: `APP_VARIANT=mind` → applicationId `io.airo.app.mind`, label "Airo Mind"; release APK artifact.

- [ ] **Step 1: Extend gradle variant mapping** — in the existing `when(appVariant)` blocks add `"mind" -> "io.airo.app.mind"` and `"mind" -> "Airo Mind"`; add `val isMindVariant = appVariant == "mind"` and a source-set block mirroring the coins one at lines ~185–192 (`manifest.srcFile("src/mind/AndroidManifest.xml")` — only add `kotlin.setSrcDirs` if mind actually needs variant Kotlin; coins did for FLAG_SECURE, mind does not).
- [ ] **Step 2: Create `src/mind/AndroidManifest.xml`** — copy the coins variant manifest, strip coins-specific bits (FLAG_SECURE activity attrs), keep label/icon hooks. Reuse the default launcher icon for now; store icon is a release-time task, not this plan.
- [ ] **Step 3: Create `scripts/build-mind.sh`** — copy `scripts/build-coins.sh` verbatim, replace `coins`→`mind`, `AIRO_COINS_BUILD_MODE`→`AIRO_MIND_BUILD_MODE`, target `lib/main_mind.dart`, define `APP_VARIANT=mind`. `chmod +x`.
- [ ] **Step 4: Run** `AIRO_MIND_BUILD_MODE=debug scripts/build-mind.sh` — Expected: prints artifact path, APK exists.
- [ ] **Step 5: Verify super app untouched** — `cd app && flutter build apk --debug` (default pubspec/target) — Expected: succeeds.
- [ ] **Step 6: Commit** — `feat(android): add mind APP_VARIANT and build-mind.sh`

### Task 10: Firebase app id (manual + wiring)

- [ ] **Step 1: USER ACTION** — register Android app `io.airo.app.mind` in the existing Firebase project console; download updated `google-services.json`.
- [ ] **Step 2:** Replace `app/android/app/google-services.json` with the version containing the new client entry (existing entries unchanged — diff to confirm only an addition).
- [ ] **Step 3:** `AIRO_MIND_BUILD_MODE=debug scripts/build-mind.sh` — Expected: builds; google-services plugin resolves the new package.
- [ ] **Step 4: Commit** — `chore(firebase): register io.airo.app.mind client`

### Task 11: Phase 2 gate + PR + dogfood

- [ ] **Step 1:** `cd app && flutter test test/main_mind_shell_test.dart test/mind_route_parity_test.dart && dart analyze` — Expected: PASS/clean.
- [ ] **Step 2:** `AIRO_MIND_BUILD_MODE=release scripts/build-mind.sh` — Expected: `app-arm64-v8a-release.apk` produced.
- [ ] **Step 3:** Install on Pixel 9 (`adb install -r`), launch, walk: hub → chat → model library → prompt lab → audio scribe → profile/sign-in. Record gaps as issues, do not fix inline.
- [ ] **Step 4:** Push branch, open PR `feat: Airo Mind standalone shell (main_mind, pubspec_mind, APP_VARIANT=mind)`.

---

## Self-review notes

- Spec coverage: package extraction (T1–T5), shell (T7–T8), Android+script (T9), Firebase (T10), gates+dogfood (T6, T11). Route-name parity: T5. Error-handling spec item (dead cross-feature links in standalone shell): quotes moved into package removes the known case; T11 dogfood walk is the catch-all for the rest.
- The `MindHostAdapter` member list is deliberately derived in T4 Step 1 from the two screens' real call-sites rather than invented here — the only intentionally deferred shape in the plan; everything else is concrete.
- Type consistency: `MindModule(basePath, hostAdapter)` used identically in T5, T7. `buildMindModuleRegistry()` name matches coins convention and the T7 test.
