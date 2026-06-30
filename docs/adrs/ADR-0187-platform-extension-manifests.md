# ADR-0187: Platform Extension Manifests

## Status
Accepted

## Context
AIRO is transitioning to an extensible framework where Engines, Plugins, Tools, Features, and Workflows are dynamically loaded at runtime. If each of these concepts defines its own lifecycle and bootstrap format, dependency resolution and capability discovery become fragmented. The host application cannot reliably validate an extension without actually running its code.

## Decision
We introduce `platform_manifest` as a unified declarative boundary. Every single extension—whether it is an engine backend, an MCP tool, or a RAG feature—MUST expose an `ExtensionManifest`.

A manifest statically declares:
- `identifier` and `version`
- `dependencies`
- `capabilities`
- `permissions`
- `bootstrapTasks`
- `settings`
- `minPlatformVersion`

## Consequences
- **Positive**: Registries can build dependency graphs and validate compatibility BEFORE executing any third-party code. Extensions become purely declarative entities that bind to cross-cutting lifecycles (e.g. `Discovered -> Validated -> Registered`).
- **Negative**: Adds a boilerplate layer to even the simplest internal tools, but this is mitigated by future code-generation tools (`platform_codegen`).
