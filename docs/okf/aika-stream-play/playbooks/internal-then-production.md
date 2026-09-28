---
type: Playbook
title: Internal then Production
description: After the human uploads the AAB, publish Internal, then Production (Save vs Send for review), and do not claim live until the Production track shows Latest.
tags: [aika-stream, play-store, console]
status: stable
generated: { by: cursor-grok-4.6/shipping-aika-stream-play, at: 2026-09-28T07:15:00Z }
verified: { by: human:Developers, at: 2026-09-28T07:15:00Z }
---

# Internal then Production

Developer `6967640737175083152`, app `4972670245912164415`.
Internal track `4701057510328186243`. Production `4698490117809651099`.

Play Console REST uses `tracks/internal-testing`, not `tracks/internal`
(the latter 404s).

## After the human uploads the AAB

1. **Internal** — prepare release, paste what's-new (last public + this
   drop), Next, **Save and publish**. Enter on the focused confirm dialog
   is enough.
2. **Production** — promote the same bundle. If the button is **Save**
   (not Save and publish), managed publishing is off: open **Publishing
   overview** and **Send N changes for review**. Confirm the review
   dialog.
3. Do not call it live until Production **Latest release** shows this
   `versionName` + `versionCode`. "In review" is not live.
4. Testers must uninstall a sideload before installing from Play
   (upload key ≠ app-signing key).

## Do not

- Re-upload an AAB whose versionCode is already Latest on Production.
- Open a second draft for the same code to "force" Production.
- Put EPGShare01, iptv-org, or "free live TV" in listing copy.
