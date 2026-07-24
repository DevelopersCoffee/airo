# 🔧 Setup & Configuration

Detailed setup and configuration guides.

---

## 📖 Documentation

### [GITHUB_ACTIONS_SETUP.md](./GITHUB_ACTIONS_SETUP.md)
**GitHub Actions configuration**:
- Required secrets
- Workflow triggers
- Build matrix
- Troubleshooting

### [SONAR_SNYK_SETUP.md](./SONAR_SNYK_SETUP.md)
**SonarQube & Snyk setup reference**:
- Account creation
- Token generation
- GitHub secret setup
- Dashboard access

### [GITHUB_MCP_SERVER.md](./GITHUB_MCP_SERVER.md)
**GitHub MCP server for Codex**:
- Project-scoped Codex setup
- PAT and Docker/OAuth options
- Safe credential handling
- Verification steps

### [HACKER_NEWS_MCP_SERVER.md](./HACKER_NEWS_MCP_SERVER.md)
**Hacker News MCP server for Codex**:
- Project-scoped Codex setup
- `uvx` runtime shape
- Python/`uv` prerequisites
- Verification steps

---

## 🎯 Setup Guides

### GitHub Actions
1. Read [GITHUB_ACTIONS_SETUP.md](./GITHUB_ACTIONS_SETUP.md)
2. Add required secrets
3. Test workflows
4. Monitor builds

### SonarQube & Snyk
1. Read [SONAR_SNYK_SETUP.md](./SONAR_SNYK_SETUP.md)
2. Create accounts
3. Generate tokens
4. Add GitHub secrets

### GitHub MCP Server
1. Read [GITHUB_MCP_SERVER.md](./GITHUB_MCP_SERVER.md)
2. Choose hosted PAT or local Docker/OAuth
3. Restart Codex
4. Verify the `github` server appears in `/mcp`

### Hacker News MCP Server
1. Read [HACKER_NEWS_MCP_SERVER.md](./HACKER_NEWS_MCP_SERVER.md)
2. Install `uv` if needed
3. Restart Codex
4. Verify the `hackernews` server appears in `/mcp`

---

## 📋 Checklist

- [ ] GitHub Actions configured
- [ ] Secrets added
- [ ] Workflows tested
- [ ] SonarQube account created
- [ ] Snyk account created
- [ ] Tokens generated
- [ ] GitHub secrets added
- [ ] GitHub MCP server configured in Codex
- [ ] Hacker News MCP server configured in Codex
- [ ] First build successful

---

## 🔗 Links

- **GitHub Actions**: https://docs.github.com/en/actions
- **GitHub MCP Server**: https://github.com/github/github-mcp-server
- **Hacker News MCP Server**: https://github.com/erithwik/mcp-hn
- **SonarCloud**: https://sonarcloud.io
- **Snyk**: https://app.snyk.io

---

**Ready?** → [Start Setup](./GITHUB_ACTIONS_SETUP.md)
