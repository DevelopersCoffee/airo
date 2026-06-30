# ADR-0180: Platform Validation

## Status
Accepted

## Context
As artifacts (models, whisper weights, plugin bundles) are downloaded into the platform via `platform_downloads`, they cannot be immediately executed. Runtimes must not be burdened with the complex logic of parsing file headers, validating integrity, assessing hardware compatibility, and extracting metadata. If they are, that logic will be redundantly implemented across every backend provider (LiteRT, CoreML, etc.).

## Decision
We establish `platform_validation` as the dedicated bridging layer between the download infrastructure and the runtime execution engine.

### Key Patterns
1. **Validation Before Runtime**: No downloaded artifact becomes executable until it is mathematically and structurally verified by this platform.
2. **Installed Artifact Abstraction**: Runtimes do not consume raw paths or `DownloadedArtifact` objects. They consume only `InstalledArtifact` instances, which guarantee validity and encapsulate execution metadata.
3. **Compatibility Reporting**: The `ValidationReport` explicitly records hardware compatibility decisions, quantization limits, and context sizes.
4. **Deterministic Installation**: An `InstallationPlanner` orchestrates the final atomic placement of validated artifacts, mapping multi-file requirements (e.g. tokenizer + GGUF + mmproj) into a single logical execution unit.

## Consequences
- **Positive**: Execution providers (WP-1.6) can remain completely stateless and oblivious to filesystems or file structure validation.
- **Negative**: Adds another orchestration step before a model is usable by the end-user.
