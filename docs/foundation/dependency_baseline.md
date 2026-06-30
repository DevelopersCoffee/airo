# Dependency Baseline (PFR-1)

## Package Dependency Graph
The platform packages exhibit a strict acyclic dependency graph flowing top-down.

```mermaid
graph TD
    apps/mobile --> platform_core
    apps/mobile --> platform_logging
    apps/mobile --> platform_events
    apps/mobile --> platform_settings
    apps/mobile --> platform_storage
    apps/mobile --> platform_filesystem
    apps/mobile --> platform_jobs
    apps/mobile --> design_system

    platform_jobs --> platform_core
    platform_filesystem --> platform_core
    platform_storage --> platform_core
    platform_settings --> platform_core
    platform_events --> platform_core
    platform_logging --> platform_core
```

## Bootstrap Dependency Graph
Tasks are executed by the `BootstrapCoordinator` based on their declared dependencies.

```mermaid
graph TD
    JobsBootstrapTask --> StorageBootstrapTask
    JobsBootstrapTask --> FilesystemBootstrapTask
    StorageBootstrapTask --> LoggingBootstrapTask
    FilesystemBootstrapTask --> LoggingBootstrapTask
    LoggingBootstrapTask --> Core
```

## Verification
- **Acyclic Graph**: Verified.
- **Ownership Rules**: Feature packages are not allowed to depend on other feature packages. Platform packages do not depend on feature packages.
- **No Forbidden Imports**: No `package:airo/` references exist in platform logic.
- **Implementation Leakage**: Public APIs are constrained in `api_baseline.md`.
