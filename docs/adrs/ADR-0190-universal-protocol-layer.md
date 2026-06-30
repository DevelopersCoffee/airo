# ADR-0190: Universal Protocol Layer

## Status
Accepted

## Context
AIRO is transitioning from direct capability invocation to a universal abstraction via `platform_tools`. However, external systems (MCP, Anthropic, REST, A2A) require a generic ingestion interface before invoking tools. Hardcoding MCP into the core platform limits future extensibility.

## Decision
We introduce `platform_protocols`, acting as the singular adapter layer to bridge the external world to the internal `ToolExecutor`.
1. **ProtocolAdapter**: Defines the ingestion contract for all external traffic.
2. **ProtocolSerializer**: Normalizes parsing and framing for varied transport requirements.
3. **Registry**: Discovers protocol adapters.

## Consequences
- **Positive**: Adding OpenAI or A2A later simply requires a new Protocol Adapter package without disturbing execution infrastructure.
- **Negative**: Increases abstraction indirection (ProtocolRequest -> ToolRequest -> ToolResult -> ProtocolResponse).
