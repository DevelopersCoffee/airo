# ADR-0179: Download Platform Architecture

## Status
Accepted

## Context
AIRO requires robust artifact delivery infrastructure to support models (LLMs, Whisper, OCR), plugin bundles, prompt packs, and future runtime updates. Downloads are long-running, error-prone operations that must support resumption, multi-mirror failover, and strict verification before becoming available to the application.

## Decision
We establish `platform_downloads` as the universal download infrastructure for AIRO.

### Key Patterns
1. **Universal Manifest**: All downloads are driven by a `DownloadManifest`. URLs are never hit directly; they must pass through manifest validation.
2. **Artifact Lifecycle**: Downloads start as raw bytes, become `DownloadedArtifact` upon successful verification, and are moved atomically to `platform_filesystem`.
3. **Sealed States**: The lifecycle is explicitly represented by a sealed class (`DownloadState`): Queued -> Downloading -> Verifying -> Installing -> Completed.
4. **Transport Separation**: The logic defining *how* we fetch bytes (e.g., HTTP `GET`, gRPC, LAN peer) is fully abstracted via `DownloadTransport`, keeping the download orchestrator clean.
5. **Job Integration**: Every download runs as a `Job` via `platform_jobs`. The download platform doesn't reinvent the wheel with a custom background executor.
6. **Multi-Mirror Strategy**: Supports fallback mirrors automatically for robust delivery.

## Consequences
- **Positive**: Separates downloading, storage (`platform_filesystem`), and usage (`platform_runtime`). Standardizes verification (SHA-256) across all artifact types.
- **Negative**: Adds indirection (Manifest -> Transport -> Verification -> Storage), which may feel heavy for trivial fetches, but guarantees consistency for critical payloads.
