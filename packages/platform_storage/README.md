# Platform Storage

`platform_storage` is the centralized persistence platform for AIRO.

This package owns database initialization, migrations, repositories, transactions, persistence lifecycle, and indexing support. **No feature package communicates directly with Drift or SQLite.**

## Responsibilities

* **Single Database:** We use exactly one SQLite database across the platform, utilizing the `Drift` ORM.
* **Storage Encapsulation:** Feature packages (e.g. Chat, Knowledge) never depend on Drift directly. They depend only on the Repository interface and `PlatformTransaction`.
* **Central Converters:** Shared Drift converters (UUID, DateTime, Uri) are maintained here to avoid duplication.
* **Audit Metadata:** Provides reusable Drift table mixins (`AuditMetadata`, `WorkspaceIsolation`, `SoftDelete`) ensuring all data rows contain standardized audit fields (e.g. `createdAt`, `workspaceId`).
* **Migrations:** Acts as the migration orchestrator holding the single `AppDatabase` schema version map.

## Public Interfaces

* `StorageService`: Core service to initialize and close the storage subsystem.
* `RepositoryFactory`: Strongly typed repository container. 
* `TransactionManager`: Safely encapsulates Drift transactions.
* `DatabaseHealthChecker`: Exposes PRAGMA integrity checks.
* `DatabaseMigration`: Contract for versioned up/down schema adjustments.

## Rules
* Feature packages **must not** define their own `@DriftDatabase`. They define their tables and DAOs, which are then assembled by the Storage package.
* Ensure all persistent entities implement the `WorkspaceIsolation` mixin unless they are strictly global platform metadata.
