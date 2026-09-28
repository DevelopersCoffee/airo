---
type: Playbook
title: Cut the release branch from the live OBB
description: Point release/aika-stream-v{versionName} at the git SHA that produced the AAB now Latest on Production, not at later main.
tags: [aika-stream, git, release]
status: stable
generated: { by: cursor-grok-4.6/shipping-aika-stream-play, at: 2026-09-28T07:15:00Z }
verified: { by: human:Developers, at: 2026-09-28T07:15:00Z }
---

# Cut the release branch from the live OBB

After Production Latest matches the uploaded AAB:

```bash
git branch release/aika-stream-v<versionName> <sha-that-built-the-aab>
git push -u origin release/aika-stream-v<versionName>
```

The SHA is the merge (or build) commit whose tree was used for
`scripts/build-tv.sh --aab-only`, not whatever `origin/main` is an hour
later.

A GitHub tag `aika-stream-v<versionName>` is optional and is not the
Play versionCode. Do not retag if the tag already exists.

`origin/main` may move independently (other PRs). The release branch
stays pinned to the OBB.
