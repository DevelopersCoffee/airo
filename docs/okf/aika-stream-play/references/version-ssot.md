---
type: Reference
title: Aika Stream version SSOT
description: Humans edit only app/pubspec_tv.yaml; the stub and the AAB stamps must be derived from it.
resource: /app/pubspec_tv.yaml
tags: [aika-stream, versioning]
status: stable
generated: { by: cursor-grok-4.6/shipping-aika-stream-play, at: 2026-09-28T07:15:00Z }
verified: { by: human:Developers, at: 2026-09-28T07:15:00Z }
sources:
  - id: version-script
    resource: /scripts/aika_stream_version.sh
    description: Parses version: name+code and rewrites the TV package_info stub.
---

# Version SSOT

Edit **only** `app/pubspec_tv.yaml` `version: <name>+<code>`.

Then:

```bash
scripts/aika_stream_version.sh --sync-stub
```

`--target=lib/main_tv.dart` does not swap pubspecs. Any TV AAB/APK that
omits `--build-name` / `--build-number` stamps the **phone** app version.

`scripts/build-tv.sh` takes space-separated flags, not equals:

```bash
GRADLE_USER_HOME="$HOME/.gradle" \
  bash scripts/build-tv.sh --aab-only --build-name 0.0.3 --build-number 26
```

`--build-name=0.0.3` is `Unknown option`.

Do not bump past the current live OBB unless this drop is the one being
shipped. Do not mix leftover worktrees (`agent/iptv/aika-stream-002-21`
and similar) into the Play SHA.
