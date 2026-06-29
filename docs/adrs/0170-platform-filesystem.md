# ADR 0170: Platform Filesystem

## Status
Accepted

## Context
As AIRO scales, binary assets (LLM weights, whisper models, embedded documents, images, diagnostics) will vastly outpace relational metadata in size. If feature packages attempt to manage paths themselves using `path_provider`, we will face file orphans, cache bloat, corrupted partial downloads, and path collisions. Keeping relational storage (`platform_storage`) separated from binary storage (`platform_filesystem`) simplifies both architectures.

## Decision
We introduce `platform_filesystem` to own all physical file operations in AIRO.

1. **Storage Separation:** `platform_storage` handles SQLite. `platform_filesystem` handles `.gguf`, `.wav`, `.png`, and `.tmp`. They do not mix.
2. **Directory Provider:** A centralized `DirectoryProvider` dictates the exact physical hierarchy (e.g. `/AIRO/models/llm`, `/AIRO/workspaces/<id>`). Feature packages are never allowed to concatenate string paths blindly.
3. **Typed Descriptors:** We enforce types like `ModelFile` and `WorkspaceFile`. These encapsulate their relative constraints so that a workspace file cannot accidentally escape the workspace root.
4. **Atomic Writes:** Because models are massive (gigabytes), partial writes are dangerous. `FileManager` forces `atomicWrite` which writes to a scratch space first, then executes an OS-level atomic rename.
5. **Event Emission:** Like Settings, file creation and deletion natively publish telemetry over `platform_events` for observability and UI updates.

## Consequences
**Positive:**
- Zero chance of corrupted models due to power failures (atomic writes).
- Easy cache clearing (we own the cache dir entirely).
- Strict workspace isolation prevents users from accessing files of another workspace context.
- Allows for scoped virtual storage in tests without mocking `dart:io` deeply.

**Negative:**
- Adds a small abstraction tax over standard `dart:io` operations.
