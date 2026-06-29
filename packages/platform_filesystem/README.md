# Platform Filesystem

`platform_filesystem` is the centralized binary asset and cache management capability for AIRO.

This package owns directory layout, file lifecycle, cache management, integrity verification, temporary storage, and model storage. **It does not own relational persistence (`platform_storage`).**

## Responsibilities

* **Directory Layout:** Exposes predictable directories (`models`, `cache`, `workspaces`) hiding raw path strings.
* **Typed Files:** Eliminates primitive string paths at API boundaries by providing descriptors like `ModelFile`, `WorkspaceFile`, and `DocumentFile`.
* **Atomic Operations:** Forces atomic file writes via temporary directories to prevent corrupting models during sudden power-offs.
* **Integrity:** Native SHA-256 hashing to verify downloaded models and synced documents.
* **Event Publication:** Publishes filesystem lifecycle events using `platform_events`.

## Public Interfaces

* `FilesystemService`: Lifecycle container.
* `DirectoryProvider`: Exposes semantic directory access.
* `FileManager`: Primary API for creating, deleting, and atomically writing typed files.
* `CacheManager`: Contract for size-limited caching capabilities.
* `IntegrityVerifier`: Cryptographic verification contracts.

## Rules
* Feature packages must never use `dart:io` `File` directly without resolving the path through the `DirectoryProvider` or `FileManager`.
* Workspace files must always be stored beneath `DirectoryProvider.workspaceDirectory()`.
* Direct writes are prohibited for large assets. Use `FileManager.atomicWrite`.
