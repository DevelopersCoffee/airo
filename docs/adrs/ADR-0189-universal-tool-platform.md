# ADR-0189: Universal Tool Platform

## Status
Accepted

## Context
AIRO is transitioning from a framework where capabilities (like search, file reading, code execution) are invoked directly, to one where these are abstracted. AI agents, workflows, and MCP layers all need a uniform way to interact with underlying functionality, including permissions, validation, and lifecycle metadata.

## Decision
We establish `platform_tools` as the universal execution abstraction for all functional extensions.
1. **Metadata vs Execution**: A `ToolManifest` handles declarative metadata, while a `Tool` interface handles actual code execution, separating the two completely.
2. **Separation of Planning and Execution**: `ToolDescriptorProvider` allows the LLM to inspect capabilities without instantiating objects.
3. **Validation Pipeline**: The `ToolExecutor` is a strict pipeline guaranteeing: Schema Validation -> Permission Checks -> Capability Verification -> Execution.
4. **Data Schemas**: `platform_schemas` is created to hold `ToolRequest`, `ToolResult`, and domain-specific schemas universally used by Tools and MCP adapters, eliminating raw JSON map spaghetti.

## Consequences
- **Positive**: Uniform interface for local functions, web tools, MCP servers, and LLM generated tools. Planners can evaluate tools statically. 
- **Negative**: Implementing a simple tool requires defining a manifest, validation constraints, schemas, and a discrete execution class.
