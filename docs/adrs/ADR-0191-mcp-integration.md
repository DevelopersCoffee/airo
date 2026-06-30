# ADR-0191: MCP Integration Layer

## Status
Accepted

## Context
Model Context Protocol (MCP) provides standard definitions for exposing resources and prompts to LLMs. However, we do not want MCP concepts leaking deeply into the AIRO ecosystem.

## Decision
`platform_mcp` is instituted strictly as a Protocol Adapter (via `platform_protocols`).
1. **Translation**: It translates `CallToolRequest` to `ToolRequest` losslessly.
2. **Dumb Pipe**: It executes no business logic and owns no permission or schema checking.
3. **Concept Mapping**: MCP prompts map to standard `ExtensionManifest` objects, and resources map to `ToolDescription` resources.

## Consequences
- **Positive**: Clean separation of protocol parsing and tool execution.
- **Negative**: Additional code overhead mapping properties strictly to `platform_schemas`.
