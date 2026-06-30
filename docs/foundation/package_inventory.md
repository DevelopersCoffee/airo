# Package Inventory (PFR-1)

| Name | Version | Owner | Responsibility | Dependencies | ADR References |
|---|---|---|---|---|---|
| `platform_core` | 0.1.0 | Platform Team | Lifecycle, Bootstrap DAG, Results, Core Contracts | None | ADR-005, ADR-011 |
| `platform_events` | 0.1.0 | Platform Team | Typed event bus | `platform_core` | ADR-006 |
| `platform_logging` | 0.1.0 | Platform Team | Centralized logging platform | `platform_core` | ADR-007 |
| `platform_settings` | 0.1.0 | Platform Team | Immutable typed settings registry | `platform_core` | ADR-008 |
| `platform_storage` | 0.1.0 | Platform Team | Relational data persistence | `platform_core` | ADR-009 |
| `platform_filesystem` | 0.1.0 | Platform Team | File and cache lifecycle | `platform_core` | ADR-010 |
| `platform_jobs` | 0.1.0 | Platform Team | Async job scheduling and execution | `platform_core` | ADR-011 |
| `design_system` | 0.1.0 | UI Team | Tokens, Themes, and shared Widgets | None | ADR-002 |
| `apps/mobile` | 0.0.1-dev | Core App Team | App Shell, Boots the platform | All platform packages | ADR-012 |
