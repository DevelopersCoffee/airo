# Airo Cyber Theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an extensible theme system and make an original Hermes-inspired `Airo Cyber` theme the default.

**Architecture:** `core_ui` owns theme IDs, definitions, tokens, and registry lookup. The app owns persisted theme selection through Riverpod and wires the selected theme into `MaterialApp.router`. Bedtime remains an app-level override because it is mode-driven, not just a static visual preference.

**Tech Stack:** Flutter, Material 3 `ThemeData`, `ThemeExtension`, Riverpod `StateNotifierProvider`, `SharedPreferences`, Flutter widget tests.

---

### Task 1: Core Theme Registry

**Files:**
- Create: `packages/core_ui/lib/src/theme/app_theme_id.dart`
- Create: `packages/core_ui/lib/src/theme/airo_theme_tokens.dart`
- Create: `packages/core_ui/lib/src/theme/app_theme_definition.dart`
- Modify: `packages/core_ui/lib/src/theme/app_theme.dart`
- Modify: `packages/core_ui/lib/core_ui.dart`
- Test: `packages/core_ui/test/core_ui_test.dart`

- [ ] Write failing tests for default theme ID, registry lookup, and token availability.
- [ ] Run `flutter test` in `packages/core_ui` and verify the new tests fail because the registry does not exist.
- [ ] Add theme ID, token extension, theme definitions, and registry lookup.
- [ ] Keep `AppTheme.light` and `AppTheme.dark` as compatibility getters for Classic.
- [ ] Run `dart format .` and `flutter test` in `packages/core_ui`.

### Task 2: Airo Cyber Theme

**Files:**
- Modify: `packages/core_ui/lib/src/theme/app_colors.dart`
- Modify: `packages/core_ui/lib/src/theme/app_typography.dart`
- Modify: `packages/core_ui/lib/src/theme/app_theme.dart`
- Test: `packages/core_ui/test/core_ui_test.dart`

- [ ] Add failing assertions for the Cyber color scheme, dark mode preference, low-radius cards, and zero letter spacing on display styles.
- [ ] Run `flutter test` in `packages/core_ui` and verify the assertions fail.
- [ ] Implement the Cyber `ThemeData` with dark teal surface colors, amber primary, cyan secondary, cream text, outlined cards, navigation, inputs, chips, and buttons.
- [ ] Run `dart format .` and `flutter test` in `packages/core_ui`.

### Task 3: Persisted Theme Selection

**Files:**
- Create: `app/lib/core/providers/app_theme_provider.dart`
- Modify: `app/lib/core/app/airo_app.dart`
- Test: `app/test/core/providers/app_theme_provider_test.dart`
- Test: `app/test/widget_test.dart`

- [ ] Write failing provider tests for default `Airo Cyber`, persisted restore, and saving a selected theme.
- [ ] Run `flutter test test/core/providers/app_theme_provider_test.dart` and verify failure.
- [ ] Implement `AppThemeNotifier` backed by `SharedPreferences`.
- [ ] Convert `AiroApp` to a `ConsumerStatefulWidget` and read the selected theme definition.
- [ ] Run the provider test and app smoke test.

### Task 4: Appearance Picker and Shell Polish

**Files:**
- Modify: `app/lib/features/agent_chat/presentation/screens/profile_screen.dart`
- Modify: `app/lib/core/app/app_shell.dart`
- Test: `app/test/features/agent_chat/presentation/screens/profile_theme_picker_test.dart`

- [ ] Write a failing widget test that renders the profile screen, finds `Appearance`, and switches from Cyber to Classic.
- [ ] Run that test and verify failure.
- [ ] Add an Appearance section using radio list tiles from the theme registry.
- [ ] Add a subtle shell backdrop/grid surface using current theme tokens without blocking feature content.
- [ ] Run the new widget test, app smoke test, and targeted Coins smoke tests if affected.

### Task 5: Verification and Commit

**Files:**
- All changed files.

- [ ] Run `flutter analyze` from `app`.
- [ ] Run `flutter test` from `packages/core_ui`.
- [ ] Run `flutter test test/core/providers/app_theme_provider_test.dart test/widget_test.dart` from `app`.
- [ ] Run `flutter test test/features/coins` from `app`.
- [ ] Review `git diff --check` and `git status --short`.
- [ ] Commit the branch with `feat(theme): add Airo Cyber theme system`.
