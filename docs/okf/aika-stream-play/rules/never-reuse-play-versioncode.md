---
type: Rule
title: Never reuse a Play versionCode
description: A versionCode Play has seen is spent, even if the AAB was removed from a draft or never reached Production.
tags: [aika-stream, play-store, versioning]
status: stable
generated: { by: cursor-grok-4.6/shipping-aika-stream-play, at: 2026-09-28T07:15:00Z }
verified: { by: human:Developers, at: 2026-09-28T07:15:00Z }
sources:
  - id: play-gate
    resource: /docs/release/AIKA_STREAM_PLAY_STORE_GATE.md
    description: First-listing gate; Play already consumed 13 on the first attach.
  - id: notes-003
    resource: /docs/release/AIKA_STREAM_v0.0.3.md
    description: Live drop 0.0.3+25; do not reuse 24.
---

# Never reuse a Play versionCode

`versionName` (`0.0.3`) is cosmetic. Android and Play upgrade on
**package + signing cert + versionCode**.

- Do not reuse a `versionCode` that appears as Latest on Internal or
  Production, or that was attached to a draft and later deleted.
- Do not re-upload the same AAB to "push Production" after that code is
  already Latest on Production.
- Next unused code is **one higher than the max** Play has seen on this
  listing. As of 2026-09-28, 21–25 are spent; the next drop is **26**.
- Sideload APKs that stamped the phone pubspec (missing `--build-number`)
  can collide with Play. Always pass `--build-name` / `--build-number`
  from [`version SSOT`](/references/version-ssot.md).

Pixel sideload uses the **upload** key. Play-installed APKs use Google's
**app signing** key. Uninstall the sideload before installing from Play.
