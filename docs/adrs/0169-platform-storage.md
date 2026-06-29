# ADR 0169: Unified Storage Platform

## Status
Accepted

## Context
AIRO requires robust, offline-first persistence for settings, chat histories, vector embeddings metadata, download states, and more. A common anti-pattern in large Flutter applications is allowing every package to initialize its own database or use raw SQLite connections, leading to connection locks, split transactions, duplicate schema converters, and chaotic migration histories. 

## Decision
We introduce `platform_storage` as the single persistence backbone for the entire AIRO ecosystem.

1. **Single Database:** We maintain exactly one SQLite database. Logical separation between domains (knowledge, chat, system) is achieved via the Repository Pattern, not by physically creating multiple files.
2. **Drift Encapsulation:** Drift is the ORM of choice. However, the Drift API (`AppDatabase`, `DAOs`) must NEVER be exposed outside of `platform_storage` and feature-specific DAOs. The UI and other feature packages consume data strictly via generic `Repository` and `PlatformTransaction` interfaces.
3. **Repository Registration:** To avoid exposing DAOs, packages will register their specific Repositories with the `RepositoryFactory` during bootstrap.
4. **Audit Metadata:** We enforce standard data retention policies by using standard Drift Mixins (`AuditMetadata`, `WorkspaceIsolation`, `SoftDelete`). All user-generated content must be tied to a `workspaceId` and utilize soft deletion.
5. **Central Converters:** Complex types (UUID, DateTime, JSON, Enum, Uri) are converted using centralized TypeConverters housed in this package to prevent duplicate parsing logic across packages.

## Consequences
**Positive:**
- Centralized migrations ensure reliable schema upgrades without race conditions.
- Single database connection optimizes performance and prevents locks.
- `WorkspaceIsolation` mixin guarantees we don't accidentally leak data between workspaces.
- Changing the underlying ORM in the distant future would be isolated to this package and the DAOs.

**Negative:**
- Feature packages cannot run raw SQL easily. They must define strict Repositories.
- Boilerplate is required to map Drift DataClasses to Domain entities.
