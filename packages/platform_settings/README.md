# Platform Settings

`platform_settings` is the centralized configuration platform for AIRO.

This package defines the strictly-typed settings model, namespace registries, validation hooks, and migration contracts required for all configuration across the platform.

**IMPORTANT: No package may own its own settings storage or read configurations from unstructured sources like simple Maps or SharedPreferences directly.**

## Responsibilities

* **Typed Configuration:** Every setting is defined as a strongly typed class implementing `SettingDefinition<T>`, complete with defaults and validation logic.
* **Registry:** Acts as a centralized immutable registry where packages declare their settings at bootstrap.
* **Event Integration:** When a setting's value successfully changes, a `SettingsChangedEvent<T>` is automatically broadcast over the `platform_events` bus.
* **Storage Independence:** Only exposes a `SettingsService` contract. It explicitly avoids linking directly to SQLite or SharedPreferences, allowing `platform_storage` to handle persistence later.

## Public Interfaces

* `SettingDefinition<T>`: The base interface defining a setting, its namespace, and its defaults.
* `SettingsRegistry`: The central catalog where packages register their `SettingDefinition` implementations.
* `SettingsService`: The primary API for reading (`getValue`) and writing (`setValue`) settings.
* `SettingsValidator<T>`: Contracts for validating values before they are committed to storage.
* `SettingsObserver`: Contract for hooking into the setting write lifecycle (currently utilized by the EventBus integration).

## Rules
* Obtain the service or registry strictly via Riverpod (`ref.read(settingsServiceProvider)`).
* The registry is locked after bootstrap. Do not attempt to register settings dynamically at runtime.
* Settings must not overlap namespaces.
