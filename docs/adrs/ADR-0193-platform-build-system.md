# ADR-0193: Platform Build System

## Status
Accepted

## Context
Code generation historically occurred through standalone scripts or scattered CLI commands. As AIRO matures into an OS-like platform with structured templates and rigid architecture boundaries, we need a unified build system to govern generation, validation, and migration.

## Decision
We introduce `platform_build`.
1. **Governance**: It hosts `ArchitectureValidator` implementations that analyze dependencies, manifests, and API baselines, proving architectural integrity.
2. **Generators**: Strongly typed `ProjectGenerator` classes render structural templates.
3. **Migrations**: Automatic project migrations (`PlatformMigration`) are defined here, making platform upgrades mechanical.
4. **Separation of Concerns**: The CLI orchestrates commands (`airo create`, `airo migrate`) but all actual logic is securely executed inside `platform_build`.

## Consequences
- **Positive**: Strict standardization of boilerplate, templates, and migrations. Validation rules share code directly with the runtime APIs.
- **Negative**: High initial investment in template abstractions vs simple shell scripts.
