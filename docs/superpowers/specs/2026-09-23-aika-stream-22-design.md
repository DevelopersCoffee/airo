# Spec: Aika Stream 0.0.2+22

**Status:** Draft — planning only. Do not implement from the current checkout.
**Date:** 2026-09-23
**Found in:** `0.0.2+21` (`052fb63c`, Play candidate on `origin/main`)
**Ships in:** `0.0.2+22`. Do not reuse versionCode 21.
**Package:** `com.developerscoffee.tv.midas`
**Entrypoint:** `app/lib/main_tv.dart` / `app/pubspec_tv.yaml`
**Public page:** `docs/aika-stream/in/index.html`
**Worktree:** `/home/ubuntu/airo-worktrees/aika-stream-22` on `cursor/aika-stream-22-plan-2e28`

## Objective

Make Aika Stream feel like a TV product in two places that currently fight that impression:

1. The India landing page still reads as a feature list around a raw screenshot.
2. Watch still runs two D-pad systems at once: the transport rail and the Mini Guide.

22 does not add a playback engine, a channel catalog, or a second app.

## Why this is two plans

The landing page and the Watch remote contract do not share code, tests, or reviewers. Each plan produces working software on its own.

| Plan | File | Ships |
| --- | --- | --- |
| India landing | `docs/superpowers/plans/2026-09-23-aika-stream-22-india-landing.md` | Docs / Pages only |
| Watch D-pad | `docs/superpowers/plans/2026-09-23-aika-stream-22-watch-dpad.md` | `feature_iptv` in `0.0.2+22` |

Do not bump `app/pubspec_tv.yaml` in the landing PR. Bump it only in the Watch PR, after the D-pad tests pass.

## Locked decisions

| Topic | Decision |
| --- | --- |
| Visual direction | Restrained site. Almost-black navy, one accent, large type, one product visual per section. The TV UI inside the frame may stay colorful. |
| Hero | Left: “Your TV. Reimagined.” Right: CSS television with an owned UI screenshot inside the glass. No room, table, cables, bottles, books, or screen reflections. |
| Primary actions | “Watch Aika Stream” (Play) and “Explore Features”. No third hero button. |
| MultiView | Full-width demonstration that animates 1 → 2 → 4 panes. Copy names the layouts the TV app already exposes (`single`, side by side, `MultiviewLayoutKind.quad`). |
| Content rows | Categories of what a user’s own playlist can hold. Abstract tiles. No third-party logos, broadcast frames, or “channels we offer”. |
| Catalog claim | Keep the existing line: Aika Stream does not sell, host, or provide channels. |
| Watch zones | Exactly one of `video`, `controls`, `miniGuide`. Never two strong focus rings. |
| Bare video | `OK` opens controls. `Up` opens controls. `Down` opens Mini Guide. `Left` / `Right` switch channel. `Back` exits Watch. |
| Controls | `Left` / `Right` move the action rail. `Down` or `Back` returns to video. `OK` activates. `Up` stays on the rail (one group today). |
| Mini Guide | Recently watched. `Left` / `Right` move cards. `OK` switches. `Up` opens controls and closes the guide. `Down` or `Back` closes the guide. |
| Recent overlay | The separate Down → `_QuickBrowseOverlay` path goes away. Recently watched is the Mini Guide. |
| Hints | One line, for the active zone only. Hidden after 4 seconds without a key. Delete the always-on “MENU for more actions” line. |
| 19 key map | Superseded. 19/21 opened the Mini Guide on `Up`. 22 opens it on `Down`. |

## D-pad contract

| Input | Video | Player controls | Mini Guide |
| --- | --- | --- | --- |
| OK | Open controls, focus Play/Pause | Activate the focused control | Switch to the focused channel and close the guide |
| Left / Right | Previous / next channel, brief overlay | Move along the action rail | Move along channel cards |
| Up | Open controls, focus Play/Pause | Stay on the rail | Close guide, open controls, focus Play/Pause |
| Down | Open Mini Guide | Close controls, return to video | Close guide, return to video |
| Back | Exit Watch | Close controls | Close guide |
| Menu | More actions | More actions | More actions |

Locked player (`_isLocked`) and the diagnostic recovery surface keep today’s ownership. They do not enter this table.

Channel-switch overlay, while video is the zone:

```text
Channel name
Group
```

Use `IPTVChannel.name` and `IPTVChannel.group`. Do not invent a resolution. If `group` is empty or `Uncategorized`, show the name only. Reuse `_showChannelChangeOverlay`. Boundary channels stay a no-op.

Mental model:

```text
VIDEO
 ├── Left / Right → quick channel switch
 ├── OK or Up     → player controls
 └── Down         → Mini Guide (recently watched)
```

Controls and Mini Guide share one bottom surface. Cross-fading takes 200ms. `prefers-reduced-motion` (web landing) and a zero-duration Flutter switch (tests) skip the motion.

## India page structure

```text
01  Hero                         Your TV. Reimagined. + device frame
02  Trust                        Android TV · Google TV · India · your sources
03  MultiView                    Watch more. At the same time. 1 → 2 → 4
04  One screen                   Live TV, Continue Watching, MultiView, Fast & Simple
05  Continue Watching            Pick up where you left off. (animated rail)
06  TV-first                     Phone, tablet, TV. Designed for your TV.
07  Remote                       Simple enough for everyone.
08  What you can play            Live TV, Music, International — your playlist
09  Product showcase             One screen. Endless possibilities.
10  Devices                      Android TV, Google TV, Fire TV (experimental)
11  Final CTA                    Turn on your TV.
12  Trust                        Existing BYOC disclaimer, kept
```

Remove the emoji feature grid, the four Split Screen highlight cards, and the GitHub APK button from the hero. The APK link may remain in the footer as a text link to the current public release, not `v0.0.6` if a newer public tag exists. Do not link a Play-only versionCode as a GitHub release.

## Colors

Page-scoped. Do not retheme `docs/index.html` or the global Airo platform hero.

| Token | Value |
| --- | --- |
| Background | `#070A12` |
| Surface | `#101522` |
| Secondary | `#171D2B` |
| Accent | existing `--green` (Aika green). One accent. |
| Text | `#FFFFFF` |
| Muted | `#8B93A7` |

No section-wide gradients. A single soft blue/purple glow sits behind the hero television only.

## Non-goals

- Bundled channels, iptv-org presets, or scraped logos.
- A phone-app redesign. The phone/tablet/TV row is marketing art, not a new shell.
- Rewriting `TvShell`, Home, or the full Guide.
- A second preview decoder. Mini Guide keeps one muted preview.
- Changing Play listing graphics in this packet.
- Bumping `versionName` off `0.0.2`.
- Implementing either plan in the planning commit.

## Owners

Application / TV experience: `packages/feature_iptv` Watch overlays.
Public site: `docs/aika-stream/in/` and `docs/assets/airo-tv/india-22.css`.
Framework contracts stay untouched. `TvInputKey` in `core_ui` is consumed, not extended.

## Verification

- Landing: `python3 .agents/skills/airo-release-branding/scripts/audit_public_page.py`, then serve `docs/` and check `390×844` and `1280×720`. Reduced motion leaves the MultiView demo on the 4-pane frame with no timer.
- Watch: `flutter test` in `packages/feature_iptv` for the new contract test plus the existing player widget test that currently expects Up to open the Mini Guide.
- Device: Fire TV Stick when a rig is attached. This planning environment has no television. Name host-only verification on the PR.
