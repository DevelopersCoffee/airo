# ADR 0165: Platform Bootstrap and Lifecycle Contracts

## Status
Accepted

## Context
AIRO is transitioning to a scalable, offline-first monorepo architecture. To support features scaling safely and avoiding a massive monolithic "God Object" or spaghetti initialization inside the UI layer, we need a formalized bootstrap sequence.

Currently, Flutter apps often initialize heavily within `main()` or inside stateful widgets. This leads to untestable, deeply coupled initialization flows.

We need a central mechanism to orchestrate initialization phases (e.g., Environment -> Logging -> Storage -> Settings -> Runtime), manage lifecycle events, and define foundational package boundaries without introducing circular dependencies.

## Decision
We will extract all fundamental startup orchestration and capability contracts into an independent, logic-less package named `platform_core`. 

1. **Bootstrap Sequence:** `BootstrapCoordinator` handles a strict queue of `BootstrapTask` objects. Tasks define what `BootstrapPhase` they belong to and return a `BootstrapResult`.
2. **Lifecycle Model:** A predefined set of `LifecycleState` values guarantees applications only run when the `BootstrapCoordinator` has completed.
3. **Contracts:** Features will implement `FeatureModule` and `PlatformService` rather than accessing implementations directly. 
4. **Registry:** A `PlatformCapabilityRegistry` allows plugins and internal packages to register themselves dynamically.

## Consequences
**Positive:**
- Complete decoupling of UI and startup logic.
- Clear deterministic initialization flow avoiding race conditions.
- Simple, testable dependency injection through Riverpod rather than service locators.
- Strong boundaries for future features.

**Negative:**
- Adds an abstraction layer developers must learn before they can build new features.
- Requires wrapping simple initializations in `BootstrapTask` implementations.
