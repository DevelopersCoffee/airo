---
type: Playbook
title: Ship a Play drop
description: Version bump, production-signed AAB, human Console upload, Internal then Production, then cut the release branch from that OBB.
tags: [aika-stream, play-store, release]
status: stable
generated: { by: cursor-grok-4.6/shipping-aika-stream-play, at: 2026-09-28T07:15:00Z }
verified: { by: human:Developers, at: 2026-09-28T07:15:00Z }
sources:
  - id: play-gate
    resource: /docs/release/AIKA_STREAM_PLAY_STORE_GATE.md
  - id: notes-003
    resource: /docs/release/AIKA_STREAM_v0.0.3.md
  - id: never-reuse
    resource: /rules/never-reuse-play-versioncode.md
  - id: keystore
    resource: /rules/production-keystore-only.md
---

# Ship a Play drop

Package `com.developerscoffee.tv.midas`. Flavor `main_tv.dart` /
`pubspec_tv.yaml`. GitHub secret `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` is
still missing — the human drops the AAB in Console; the agent prepares,
builds, and publishes tracks after upload.

## 1. Branch

Worktree from `origin/main`. Do not merge unrelated leftover IPTV
worktrees. Do not bump `versionCode` until this drop ships.

## 2. Stamp

1. Confirm the next unused code on Internal **and** Production
   ([never reuse](/rules/never-reuse-play-versioncode.md)).
2. Set `app/pubspec_tv.yaml`, then `scripts/aika_stream_version.sh --sync-stub`.
3. Update `docs/release/AIKA_STREAM_v*.md`, Play gate notes, store listing
   "what's new", and `docs/release/README.md` as needed.
4. Play dart-defines stay **unset** (`IPTV_DATA_MANIFEST_URL`,
   `IPTV_DATA_PLAYLIST_URL`). Do not enable extra `airo_ads` formats.

## 3. Build

[Production keystore](/rules/production-keystore-only.md) in this worktree.

```bash
GRADLE_USER_HOME="$HOME/.gradle" \
  bash scripts/build-tv.sh --aab-only --build-name <name> --build-number <code>
```

Copy to `~/Downloads/Aika-Stream-<name>-<code>.aab`. Record SHA-256 in the
release notes (`[skip ci]` only if that commit is notes-only).

## 4. Upload and publish

Follow [Internal then Production](/playbooks/internal-then-production.md).

## 5. Cut the line

Follow [cut the release branch](/playbooks/cut-release-branch.md).

## Common mistakes

| Trap | Fix |
|---|---|
| `--build-name=0.0.3` | Space-separated flags. |
| Gradle daemon timeout | `GRADLE_USER_HOME="$HOME/.gradle"`. |
| Validation keystore | Kill the build; copy `release.keystore`. |
| Re-upload live 25 "to prod" | Production already Latest 25; next is 26. |
| `[skip ci]` on a version bump | Hook rejects it. |
| Merge leftover 002-21 | Leave it. Ship from `origin/main`. |
