# Hacker News MCP Server For Codex

This repository now includes a project-scoped Codex MCP entry for Hacker News
at [`.codex/config.toml`](../../.codex/config.toml).

## What Was Added

The checked-in config uses the upstream `mcp-hn` CLI through Codex's STDIO MCP
support:

```toml
[mcp_servers.hackernews]
command = "uvx"
args = ["mcp-hn"]
```

Why this shape:

- OpenAI documents STDIO MCP servers in project-scoped `.codex/config.toml`
  files for trusted workspaces.
- The upstream `mcp-hn` README documents `uvx mcp-hn` as its production
  runtime shape for MCP clients.
- The upstream `pyproject.toml` defines the `mcp-hn` script entrypoint and
  requires Python `>=3.12`.

## Prerequisites

1. Install `uv` if it is not already available.
2. Ensure your Python environment supports Python 3.12 or newer.
3. Restart Codex after trusting the project.

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

- OpenAI Codex MCP docs:
  https://developers.openai.com/codex/mcp
- OpenAI Codex config reference:
  https://developers.openai.com/codex/config-reference
- Hacker News MCP Server README:
  https://github.com/erithwik/mcp-hn/blob/main/README.md
- Hacker News MCP Server `pyproject.toml`:
  https://github.com/erithwik/mcp-hn/blob/main/pyproject.toml
