# Discord Community Automation — Setup Guide

> **Goal:** Every GitHub event in the Airo monorepo surfaces automatically in
> your DevelopersCoffee Discord server so the community stays informed without
> anyone manually posting updates.

---

## Channel Structure (recommended)

Create these channels in Discord before proceeding:

| Discord channel | Purpose | Webhook secret name |
|---|---|---|
| `#releases` | New versions, changelogs, download links | `DISCORD_RELEASES_WEBHOOK` |
| `#bugs-and-issues` | Bug reports, issue closed, milestones | `DISCORD_ISSUES_WEBHOOK` |
| `#dev-updates` | PRs opened / merged / reviewed | `DISCORD_DEV_WEBHOOK` |

---

## Step 1 — Create Discord Webhooks (one per channel)

Repeat this for **each** channel above:

1. Open Discord → your server → target channel → ⚙️ **Channel Settings**
2. **Integrations** → **Webhooks** → **New Webhook**
3. Name it (e.g. `Airo Releases Bot`) and keep the channel pre-selected
4. Click **Copy Webhook URL** — save it, you'll need it in Step 2

> ⚠️ Do **not** append `/github` to the URL. Our workflows send custom JSON
> payloads directly, so you need the raw webhook URL as-is.

---

## Step 2 — Add Webhook URLs as GitHub Secrets

1. Go to **github.com/DevelopersCoffee/airo** → **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret** for each:

| Secret name | Value |
|---|---|
| `DISCORD_RELEASES_WEBHOOK` | Webhook URL from `#releases` |
| `DISCORD_ISSUES_WEBHOOK` | Webhook URL from `#bugs-and-issues` |
| `DISCORD_DEV_WEBHOOK` | Webhook URL from `#dev-updates` |

---

## Step 3 — Workflows (already in the repo)

The following workflows are active in `.github/workflows/`:

| Workflow file | Trigger | Destination |
|---|---|---|
| [`discord-releases.yml`](../../.github/workflows/discord-releases.yml) | `release: published` | `#releases` |
| [`discord-issues.yml`](../../.github/workflows/discord-issues.yml) | `issues` · `milestone` | `#bugs-and-issues` |
| [`discord-prs.yml`](../../.github/workflows/discord-prs.yml) | `pull_request` | `#dev-updates` |

---

## What each notification looks like

### 🚀 Release Announcement (`#releases`)
```
Airo Releases  [bot]
🚀 Stable Release  ·  airo-tv-v0.0.5
Released by @uday

Full changelog text here...

📦 Repository  DevelopersCoffee/airo
⬇️ Downloads   View all assets →
```
Colour: **green** for stable, **yellow** for pre-release

---

### 🐛 Bug / Issue (`#bugs-and-issues`)
```
Airo Issues  [bot]
🐛 Bug reported  ·  #142
@username

**Channel freezes on Android TV when switching M3U**
Issue body excerpt...

📁 Repository  DevelopersCoffee/airo
🏷️ Labels      bug, android-tv
```

| Action | Colour |
|---|---|
| `opened` | 🔴 Red |
| `closed` | 🟢 Green |
| `reopened` | 🟡 Yellow |
| `labeled` | 🔵 Blurple |

---

### 🎯 Milestone (`#bugs-and-issues`)
```
Airo Milestones  [bot]
🎯 Milestone created  ·  M#6
**v2.0.0.0 Platform Hardening**

📊 Progress  0 / 0 issues done
📅 Due       2026-09-01
```

---

### 📬 Pull Request (`#dev-updates`)
```
Airo Dev  [bot]
🔀 PR Merged  ·  #89
@username

**feat(tv): add EPG timeline grid**

🌿 Branch   feat/epg-grid → main
➕ Additions  412
➖ Deletions   38
📄 Files changed  11
```

| Action | Colour |
|---|---|
| Opened | 🔵 Blurple |
| Ready for review | 🔵 Blue |
| Review requested | 🟠 Orange |
| Merged | 🟣 Purple |
| Closed (no merge) | 🔴 Red |

---

## Future ideas for the community

- **Forum channel for each release** — Discord Forum threads let members
  comment on individual changelogs. Route `#releases` as a Forum channel.
- **`/release` slash command** — use the official
  [GitHub Discord App](https://discord.com/application-directory/foo) for
  two-way interaction (close issues from Discord, etc.).
- **Airo Coin / Airo TV topics** — once dedicated product channels exist,
  add separate webhook secrets and duplicate the workflow with a channel-filter
  condition (`if: contains(github.event.issue.labels.*.name, 'airo-tv')`).
- **Community Voice digest** — a weekly scheduled workflow that summarises
  open `community-voice` issues and posts a digest to `#announcements`.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| No messages appear | Check the secret name matches exactly (case-sensitive) |
| `curl: (22)` in logs | The webhook URL may be invalid or the channel was deleted |
| Message appears but has no colour | `color` field must be a decimal integer, not hex string |
| Payload too large | Discord limit is 6000 chars total per embed; body is already truncated |
