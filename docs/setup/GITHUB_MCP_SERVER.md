# GitHub MCP Server For Codex

This repository now includes a project-scoped Codex MCP entry at
[`.codex/config.toml`](../../.codex/config.toml). That lets trusted Airo
workspaces expose GitHub tools in Codex without committing credentials.

## What Was Added

The checked-in config uses GitHub's hosted MCP endpoint:

```toml
[mcp_servers.github]
url = "https://api.githubcopilot.com/mcp/"
bearer_token_env_var = "GITHUB_PAT_TOKEN"
```

Why this shape:

- OpenAI documents project-scoped `.codex/config.toml` files for trusted
  workspaces.
- GitHub's Codex install guide documents the hosted endpoint and PAT-based
  authentication.
- No secrets are stored in the repository.

## Option 1: Hosted GitHub MCP Server

This is the default path used by `.codex/config.toml`.

1. Create a least-privilege GitHub Personal Access Token.
2. Export it before starting Codex:

   ```bash
   export GITHUB_PAT_TOKEN=ghp_your_token_here
   ```

3. Restart Codex or reopen the Airo task.
4. Run `/mcp` and confirm the `github` server is listed.

Notes:

- Do not commit `.env` files with real tokens.
- If you prefer local shell persistence, add the export to your shell profile or
  use a secret manager.

## Option 2: Local Docker Server With OAuth

Use this if you do not want to manage a PAT for Codex.

GitHub's official Codex guide documents a local Docker flow that opens a browser
for OAuth and keeps the token out of the repository config. Example:

```toml
mcp_oauth_callback_port = 8085

[mcp_servers.github]
command = "docker"
args = ["run", "-i", "--rm", "-p", "127.0.0.1:8085:8085", "-e", "GITHUB_OAUTH_CALLBACK_PORT", "ghcr.io/github/github-mcp-server"]
env = { GITHUB_OAUTH_CALLBACK_PORT = "8085" }
```

That version is not enabled by default in Airo because it would hard-require
Docker for every trusted workspace.

## Verification

After setup:

1. Open Codex in this repository.
2. Run `/mcp`.
3. Confirm `github` is enabled.
4. Try a simple GitHub task such as listing repository context or reading an
   issue.

## Sources

- OpenAI Codex MCP docs:
  https://developers.openai.com/codex/mcp
- OpenAI Codex config reference:
  https://developers.openai.com/codex/config-reference
- GitHub MCP Server:
  https://github.com/github/github-mcp-server
- GitHub Codex installation guide:
  https://github.com/github/github-mcp-server/blob/main/docs/installation-guides/install-codex.md
