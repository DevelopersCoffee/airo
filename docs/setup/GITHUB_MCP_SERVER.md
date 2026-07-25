# GitHub MCP Server For Codex

This guide documents optional local Codex MCP setup for Airo contributors who want GitHub tools available in trusted workspaces. Do not commit personal Codex config, tokens, or local credential files to this repository.

## Hosted GitHub MCP Server

GitHub's hosted MCP endpoint can be configured in your local Codex config:

```toml
[mcp_servers.github]
url = "https://api.githubcopilot.com/mcp/"
bearer_token_env_var = "GITHUB_PAT_TOKEN"
```

Why this shape:

- Codex supports project and user MCP server configuration for trusted workspaces.
- GitHub documents a hosted MCP endpoint for Codex.
- The token is read from an environment variable instead of stored in config.

## Setup

1. Create a least-privilege GitHub Personal Access Token appropriate for the repository operations you intend to perform.
2. Export it before starting Codex:

   ```bash
   export GITHUB_PAT_TOKEN=<YOUR_GITHUB_PAT>
   ```

3. Add the `mcp_servers.github` snippet to your local Codex config.
4. Restart Codex or reopen the Airo task.
5. Run `/mcp` and confirm the `github` server is listed.

Notes:

- Do not commit `.env` files with real tokens.
- Do not commit local `.codex/config.toml` files unless repository maintainers explicitly decide to track a project-scoped config.
- If you prefer local shell persistence, add the export to your shell profile or use a secret manager.

## Local Docker Server With OAuth

Use this if you do not want to manage a PAT for Codex. GitHub's Codex guide documents a local Docker flow that opens a browser for OAuth and keeps the token out of repository config. Example local config:

```toml
mcp_oauth_callback_port = 8085

[mcp_servers.github]
command = "docker"
args = ["run", "-i", "--rm", "-p", "127.0.0.1:8085:8085", "-e", "GITHUB_OAUTH_CALLBACK_PORT", "ghcr.io/github/github-mcp-server"]
env = { GITHUB_OAUTH_CALLBACK_PORT = "8085" }
```

This version is not enabled by default in Airo because it would require Docker for every trusted workspace.

## Verification

After setup:

1. Open Codex in this repository.
2. Run `/mcp`.
3. Confirm `github` is enabled.
4. Try a simple GitHub task such as listing repository context or reading an issue.

## Sources

- OpenAI Codex MCP docs: https://developers.openai.com/codex/mcp
- OpenAI Codex config reference: https://developers.openai.com/codex/config-reference
- GitHub MCP Server: https://github.com/github/github-mcp-server
- GitHub Codex installation guide: https://github.com/github/github-mcp-server/blob/main/docs/installation-guides/install-codex.md
