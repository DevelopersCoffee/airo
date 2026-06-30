# ADR-0192: Platform Composition Engine

## Status
Accepted

## Context
As AIRO scales out via tools, MCPs, and plugins, components need to request capabilities (Memory, Search, AI generation) without importing concrete implementations. Furthermore, loading features must be managed structurally to support on-demand loading, hot-reloading, and robust isolation checks.

## Decision
We establish `platform_composition` and `platform_services`.
1. **Service Contracts**: `platform_services` provides empty interfaces (e.g., `MemoryService`).
2. **Service Locator**: The Composition Engine holds a central injection container where features resolve dependencies strictly by contract type.
3. **Activation Lifecycle**: Feature lifecycles are explicitly expanded to: `Discovered -> Validated -> Resolved -> Composed -> Activated -> Running -> Suspended -> Disabled -> Unloaded`.
4. **Isolation**: The `IsolationPolicy` ensures features requesting services that are not provided fail activation safely rather than crashing the runtime.

## Consequences
- **Positive**: Complete decoupling of capabilities from implementations. Features can be swapped without touching consumer logic.
- **Negative**: High degree of abstraction requires strict compliance with interface definitions. Direct imports of functional classes are strictly forbidden.
