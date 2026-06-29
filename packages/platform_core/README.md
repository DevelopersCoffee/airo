# Platform Core

`platform_core` is the foundational package of the AIRO repository.

This package establishes the contracts, lifecycle management, dependency registration, and bootstrap orchestration that every other platform capability relies on.

**IMPORTANT: This package must NEVER contain business logic or concrete feature implementations.**

## Responsibilities

* **Bootstrap Orchestration:** Defines how the application initializes in a deterministic, phased approach.
* **Lifecycle Management:** Tracks the current state of the platform (initializing, ready, paused, failed).
* **Contracts:** Defines interfaces for `PlatformService`, `BootstrapTask`, `FeatureModule`, and `HealthCheck`.
* **Platform Capability Registry:** Exposes interfaces for registering capabilities.
* **Standard Types:** Provides `Result<T>` and `PlatformException` base classes used across the monorepo.
* **Environment:** Exposes immutable information about the environment, version, and capabilities.

## Rules
* No direct access to UI frameworks.
* No service locators. Use `flutter_riverpod` strictly.
* Do not expose global state.
* Other packages depend on `platform_core`, `platform_core` depends on nothing (except fundamental Dart libraries).
