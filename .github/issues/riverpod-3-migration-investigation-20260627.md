## Riverpod 3 Migration Investigation - 2026-06-27

Issue: `#365` Investigate Riverpod 3 migration.

### Owning agent and scope

- Owner: Core Architecture Agent
- Supporting agents: Mobile Platform & UI Agent, Developer Experience Agent
- Layer: framework state-management migration review
- Impacted files/modules:
  - `app/pubspec.yaml`
  - `app/pubspec.lock`
  - `packages/template_feature/pubspec.yaml`
  - app/provider code under `app/lib/**`
  - template/provider code under `packages/template_feature/**`

### Current repo baseline

- `app/pubspec.yaml`
  - `riverpod: 2.6.1`
  - `flutter_riverpod: 2.6.1`
  - `riverpod_generator: 2.4.0`
  - `riverpod_lint: 2.3.10`
  - `custom_lint: 0.6.4`
- `packages/template_feature/pubspec.yaml`
  - `riverpod: ^3.3.2`
  - `flutter_riverpod: ^3.3.2`

### Inventory findings

- Riverpod usage is repo-wide, not isolated to one feature.
- Hotspot counts from `rg` inventory:
  - `StateNotifierProvider`: `19`
  - `extends StateNotifier<...>`: `25`
  - `StateProvider`: `24`
  - `ChangeNotifierProvider`: `2`
  - `@riverpod` / `@Riverpod`: `0`
- The repo is still heavily invested in the legacy provider APIs instead of the Riverpod 3 `Notifier`/generated-provider style.

Representative files:

- `app/lib/core/providers/app_theme_provider.dart`
- `app/lib/core/providers/bedtime_mode_provider.dart`
- `app/lib/features/music/application/providers/beats_provider.dart`
- `app/lib/features/games/application/blackjack_notifier.dart`
- `app/lib/features/coins/application/providers/cloud_mode_provider.dart`
- `packages/template_feature/lib/src/presentation/providers/template_provider.dart`

### Version matrix

- `flutter pub outdated --json` in `app` reports:
  - `riverpod`: current/resolvable `2.6.1`, latest `3.3.2`
  - `flutter_riverpod`: current/resolvable `2.6.1`, latest `3.3.2`
  - `riverpod_annotation`: current/resolvable `2.6.1`, latest `4.0.3`
  - `riverpod_generator`: current/resolvable `2.4.0`, latest `4.0.4`
  - `riverpod_lint`: current/resolvable `2.3.10`, latest `3.1.4`
  - `custom_lint`: current/resolvable `0.6.4`, latest `0.8.1`

### Official compatibility findings

- Riverpod 3 migration guide:
  - `StateProvider`, `StateNotifierProvider`, and `ChangeNotifierProvider` are legacy in Riverpod 3 and must move to `package:flutter_riverpod/legacy.dart` or `package:hooks_riverpod/legacy.dart` if retained.
  - Riverpod 3 also changes provider lifecycle/error behavior, including paused out-of-view providers, `ProviderObserver` interface changes, and provider failures surfacing as `ProviderException`.
- `riverpod_generator 4.0.4` metadata shows:
  - dependency on `riverpod_annotation 4.0.3`
  - dependency on `source_gen >=3.0.0 <5.0.0`
- `riverpod_lint 3.1.4` metadata shows dependency on `analyzer_plugin ^0.14.0`
- `custom_lint 0.8.1` metadata shows dependency on `analyzer_plugin ^0.13.0`

### Spike result

Temporary spike attempted in the isolated `#365` worktree by bumping:

- `riverpod` -> `3.3.2`
- `flutter_riverpod` -> `3.3.2`
- `riverpod_generator` -> `4.0.4`
- `riverpod_lint` -> `3.1.4`
- `custom_lint` -> `0.8.1`

Result:

- `flutter pub get` failed before analysis/codegen.
- Solver error:
  - `riverpod_lint >=3.1.4-dev.1` requires `analyzer_plugin ^0.14.0`
  - `custom_lint >=0.7.4` requires `analyzer_plugin ^0.13.0`
  - therefore the proposed Riverpod 3 lint/tooling stack does not currently resolve in this repo with the latest published `custom_lint`

This means the migration is blocked at the DevEx/tooling layer before source-level compile errors are even addressed.

### Recommendation

- Decision: `defer` as a one-shot migration ticket
- Reason:
  - too many legacy provider call sites for a safe low-effort bump
  - no existing `@riverpod` adoption to soften the migration
  - current template package already diverges from the app baseline
  - latest Riverpod 3 lint stack does not resolve cleanly with the latest `custom_lint`
  - even after dependency resolution, source migration would still need:
    - import splits to `legacy.dart` or refactors to `Notifier`
    - review of `ProviderObserver` implementations
    - verification of provider pause/retry/error-path behavior

### Follow-up split recommended

- Follow-up 1: align the DevEx toolchain for a resolvable Riverpod 3 lint/codegen set
- Follow-up 2: convert template and shared provider patterns to `Notifier` / generated providers
- Follow-up 3: migrate legacy providers feature-by-feature instead of repo-wide
- Follow-up 4: run targeted lifecycle/error-path QA for widget visibility, retries, and provider exceptions

### Verification commands

```bash
cd app
flutter pub outdated --json

cd /Users/udaychauhan/workspace/airo-issue-365
rg -n "package:(flutter_)?riverpod|@riverpod|ConsumerWidget|ConsumerStatefulWidget|StateNotifierProvider|NotifierProvider|AsyncNotifier|Provider<|ref\\.watch|ref\\.read" app packages -g '!**/*.g.dart'
rg -o "StateNotifierProvider<|StateNotifierProvider\\(" app packages -g '!**/*.g.dart' | wc -l
rg -o "extends StateNotifier<" app packages -g '!**/*.g.dart' | wc -l
rg -o "StateProvider<|StateProvider\\(" app packages -g '!**/*.g.dart' | wc -l
rg -o "ChangeNotifierProvider<|ChangeNotifierProvider\\(" app packages -g '!**/*.g.dart' | wc -l
rg -o "@riverpod|@Riverpod" app packages -g '!**/*.g.dart' | wc -l
```

Temporary spike command:

```bash
cd app
flutter pub get
```

### Verification results

- `flutter pub outdated --json`
  - confirmed the Riverpod 3 package line is newer but not resolvable without changing pinned constraints
- usage inventory
  - confirmed heavy legacy provider usage across app and template package
- temporary `flutter pub get` spike after bumping Riverpod 3 runtime/dev packages
  - failed on `riverpod_lint` vs `custom_lint` dependency resolution

### Official references

- https://riverpod.dev/docs/3.0_migration
- https://pub.dev/packages/flutter_riverpod/changelog
- https://pub.dev/packages/riverpod_generator/changelog
- https://pub.dev/packages/riverpod_generator
- https://pub.dev/packages/riverpod_lint
- https://pub.dev/packages/custom_lint
