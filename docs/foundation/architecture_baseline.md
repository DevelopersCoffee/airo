# Architecture Baseline (PFR-1)

## Package Registry
- **Total Platform Packages**: 8
- **Platform Packages**: `platform_core`, `platform_events`, `platform_logging`, `platform_settings`, `platform_storage`, `platform_filesystem`, `platform_jobs`, `design_system`.
- **Application Packages**: `apps/mobile` (Shell Application).

## Bootstrap Tasks
The following tasks are officially registered in the DAG:
1. `LoggingBootstrapTask` (No dependencies)
2. `StorageBootstrapTask` (Depends on Logging)
3. `FilesystemBootstrapTask` (Depends on Logging)
4. `JobsBootstrapTask` (Depends on Storage, Filesystem)

## Core Platform Services
- `BootstrapCoordinator`: Executes tasks safely.
- `EventBus`: Centralized event routing via `PlatformEvent`.
- `SettingsRegistry`: Immutable typed configuration map.
- `StorageService`: Relational storage persistence.
- `FilesystemService`: Binary storage persistence.
- `JobScheduler`: Asynchronous task execution.

## Settings & Filesystem Roots
- **Database**: Initialized using `drift`.
- **Filesystem**: Directories initialized for `cache`, `models`, `exports`, and `temp`.

*This becomes the reference for future architectural reviews.*
