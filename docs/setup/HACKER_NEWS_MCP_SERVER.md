# Hacker News MCP Server For Codex

This guide documents optional local Codex MCP setup for Hacker News research workflows in trusted Airo workspaces.

## Local STDIO Server

The `mcp-hn` server can run through Codex's STDIO MCP support:

```toml
[mcp_servers.hackernews]
command = "uvx"
args = ["mcp-hn"]
```

Why this shape:

- Codex supports STDIO MCP servers in trusted workspaces.
- The upstream `mcp-hn` README documents `uvx mcp-hn` as its runtime shape for MCP clients.
- The upstream package defines the `mcp-hn` script entrypoint and requires Python 3.12 or newer.

## Prerequisites

1. Install `uv` if it is not already available.
2. Ensure your Python environment supports Python 3.12 or newer.
3. Add the `mcp_servers.hackernews` snippet to your local Codex config.
4. Restart Codex after trusting the project.

No API key is documented for this server.

## Verification

After setup:

1. Open Codex in this repository.
2. Run `/mcp`.
3. Confirm `hackernews` is enabled.
4. Try a prompt such as "Show today's top Hacker News stories."

## Upstream Tools

The upstream README documents these tools:

- `get_stories`
- `get_story_info`
- `search_stories`
- `get_user_info`

## Sources

- OpenAI Codex MCP docs: https://developers.openai.com/codex/mcp
- OpenAI Codex config reference: https://developers.openai.com/codex/config-reference
- Hacker News MCP Server README: https://github.com/erithwik/mcp-hn/blob/main/README.md
- Hacker News MCP Server package metadata: https://github.com/erithwik/mcp-hn/blob/main/pyproject.toml
