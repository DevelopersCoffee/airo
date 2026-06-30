# ADR-0188: Universal Extension Registry

## Status
Accepted

## Context
AIRO manages a diverse ecosystem of capabilities: Tools, Plugins, Engines, Features, and Delegates. If every platform tier attempts to discover and catalog these items independently, we risk duplicating dependency resolution, index management, and version conflict logic.

## Decision
We establish a central `platform_registry` package responsible for parsing `ExtensionManifest` objects from across the platform. The registry owns:
1. **Capability Indexing**: Queries like `findByCapability('supports_vision')` return manifests dynamically, freeing components from coupling to specific implementations.
2. **Dependency Resolution**: Performs topological sorting to produce safe initialization orders and proactively rejects dependency cycles.
3. **Version Validation**: Asserts that loaded extensions meet platform constraints.

The registry is explicitly stripped of execution logic; it manages declarative descriptors, not lifecycle transitions.

## Consequences
- **Positive**: Subsystems like Chat or Memory no longer need hardcoded lists of tools or engines; they simply query the capability index.
- **Negative**: Increases the upfront boilerplate in defining dependencies across components, though this guarantees stable startup paths.
