# ADR 0168: Centralized Typed Settings Platform

## Status
Accepted

## Context
As an offline-first AI workspace, AIRO will accumulate hundreds of settings: model configurations, download limits, theme preferences, developer toggles, and UI tweaks. If each package handles its own settings using `SharedPreferences` or direct database queries, we will end up with undocumented configurations, duplicate keys, and missing defaults. Furthermore, other systems (like the UI or the runtime) need to react instantly when a setting changes.

## Decision
We introduce `platform_settings` as the sole authority for application configuration.

1. **Typed Definitions:** No setting is accessed via raw strings like `getString('theme')`. Every setting must be a dedicated class implementing `SettingDefinition<T>`. This class defines the key, namespace, default value, metadata (e.g., introduced version), and validation rules.
2. **Registry Architecture:** During the bootstrap phase, every package registers its `SettingDefinition`s with the `SettingsRegistry`. Once bootstrap finishes, the registry is locked, ensuring the configuration schema is immutable at runtime.
3. **Event Integration:** The settings package does not invent its own observer system. Instead, when a setting is successfully updated, a `SettingsChangedEvent<T>` is dispatched over the `platform_events` bus. This allows decouple features to react to configuration changes automatically.
4. **Validation:** Validators are attached directly to the `SettingDefinition`. The `SettingsService` enforces these validators on every write operation. Invalid settings are rejected before reaching storage.
5. **Storage Independence:** `platform_settings` does *not* persist anything. It defines the contracts. A later package (`platform_storage`) will provide the persistent implementation of `SettingsService` by backing it with Drift.

## Consequences
**Positive:**
- Complete compile-time safety for settings access.
- Validation prevents corrupt states from entering the database.
- Centralized registry makes it trivial to generate a "Settings UI" or export user configurations.
- Changing storage backends requires zero changes to feature code.

**Negative:**
- Adding a single setting requires creating a new class (boilerplate). This is an acceptable trade-off for type safety and validation.
