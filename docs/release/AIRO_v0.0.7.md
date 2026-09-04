# Airo v0.0.7 — Stable Release

Status: **prepared, not tagged** until a green freeze SHA passes the device
gate. Stable cut for **GitHub Releases + APKPure / direct download**, not a
store submission. Google Play, App Store, Firebase App Distribution,
iOS/iPadOS, and macOS notarization stay out of scope for this cut.

Same four SKUs as [`v0.0.6`](./AIRO_v0.0.6.md). Standalone Airo Mind
(`io.airo.app.mind`) is not an orchestrator leg. `v0.0.7-preview` was prepared
in-tree but **never tagged**; this document supersedes it — see
[`AIRO_v0.0.7-preview.md`](./AIRO_v0.0.7-preview.md).

## Release wave (intended artifacts)

| Profile | Package / bundle | Artifact | Version line |
| --- | --- | --- | --- |
| Android TV (`tv`) | `io.airo.app.tv` | `Airo-TV-0.0.7.apk` + per-ABI APKs + AAB | `0.0.7+12` |
| Full app (`full`) | `io.airo.app` | `Airo-0.0.7-12-arm64.apk` + AAB | `0.0.7+12` |
| Airo Coins (`coins`) | `io.airo.app.coins` | `AiroCoins-0.0.7-12-arm64.apk` + AAB | `0.0.7+12` — **omitted if #1240 fails Pixel 9** |
| macOS TV | `com.developerscoffee.airo.tv` | direct-download `.zip` / `.dmg` + Homebrew Cask | `0.0.7` |

Tag: `v0.0.7`. Branch: `release/v0.0.7`. Do not mint `v0.0.7-preview` or
`airo-tv-v0.0.7`.
`versionCode` is **12** so Android upgrades over `v0.0.6+10` and Coins
dogfood `+11`. If a published `0.0.7` build must be replaced, do not reuse
versionCode 12 — cut `0.0.7+13`.

## Claim state

Classify before any public copy. Merged code is not Available. TV BACK and
playlist merge flip to Available only after the Fire TV Stick device gate
below has run against the dry-run artifacts; until then keep them Under
qualification in the working copy.

| Surface | State | Notes |
| --- | --- | --- |
| Aika Stream BACK after playback (#1430) | **Available** (on the hard gate) | Closed in tree; requires Stick install + D-pad + BACK-after-playback evidence before this notes file is published. |
| Unified live playlist merge (M3U / Xtream / Stalker) | **Available** (on the hard gate) | In tree; requires Fire TV playlist-merge smoke (#1605) before publish. |
| Honest TV backup failure copy (#1918) | **Available** | Covered by the same TV install check; no extra device row. |
| BACK dismisses shell overlays (#1917) | **Available** | Exercised together with #1430 on the Stick. |
| Cast splice-on-keyframe, 3-tile multiview, fold crease | **Under qualification** | Physical Device QA #1603 / #1601 / #1588 still open. |
| Design-system pass across flavors | **Under qualification** | Visual, not a store listing claim. |
| Meeting Intelligence already in 0.0.6 | **Available** (unchanged) | Record / transcribe / summarise / search as shipped in 0.0.6. |
| New Mind work (Meeting IR, MoM, speaker learning, Indic, chat-over-meetings) | In the full binary; **do not advertise** | Rides in the full app. #1592 still open. |
| Coins embeddings auto-categorize / recurrence / anomaly | Advertise only if Coins SKU ships | Still qualify #1240 closed on Pixel 9. |
| Standalone Mind APK | **Not adopted** this wave | `ciBuild: false`, still `0.0.1+1`. |
| Play / notarized macOS / Firebase testers | **Deferred** | #576, #585, #803, #756. |

## Not in this release

| Artifact / profile | Source | Status |
| --- | --- | --- |
| Airo Mind standalone (`mind`) | `app/pubspec_mind.yaml` | Not building in CI; public distribution deferred. |
| iOS / iPadOS SPM | `ios-spm` | Deferred — no Apple developer account. |
| Web validation | `web-validation` | Local/CI browser-engine validation only. |
| Linux / Windows desktop | `app/linux`, `app/windows` | No release workflow. |
| Production-signed Play upload | orchestrator Play tracks | Human blockers in `V2_HUMAN_IN_LOOP_BLOCKERS.md`. |
| Notarized macOS | `#803` | `macos_require_notarization=false`. |

## What is new since v0.0.6

**Aika Stream**

- BACK on the channel-browse grid after returning from playback (#1430).
- BACK dismisses shell overlays (#1917).
- Honest TV backup failure copy instead of a false success message (#1918).
- Unified live playlist merge across M3U, Xtream, and Stalker sources.
- Cast splice-on-keyframe, hover-chrome zones, fold crease rule — in tree,
  Under qualification (3-tile multiview toggle removed; TV cannot render it).
- Shared design-system typography, color, and spacing across flavors.

**Airo (full app)**

- Full/phone pubspec profile restored — the profile had drifted to be
  byte-identical to the Mind profile and would have shipped a Mind APK as
  `io.airo.app`.
- Shared `AiroBootstrap` runner and a large dead-code / provider purge.
- Web wasm leak gate on unsafe `dart.library.html` conditional imports.
- Meeting Intelligence remains in the full app. New Mind surfaces listed above
  ship in the binary as "do not advertise", not as Available.

**Airo Coins**

- Embeddings-first auto-categorization, recurrence and anomaly detection, and
  the shared `DraftConfirmCard` confirm step.
- Store-asset name correction from the `0.0.6+11` dogfood bump, rebased onto
  `+12`.

**Airo Mind / AI (full app only)**

- In-tree: Meeting IR, MoM generation, speaker enrollment / ECAPA, Indic
  settings, chat-over-meetings, vault UI, macOS verify scripts.
- Rust Core CI no longer links `airo_mind_cli` into the workspace `--workspace`
  jobs. That bin still combines whisper.cpp and llama.cpp ggml copies; Linux
  `lld` rejects it. The Flutter app keeps the two engines as separate cdylibs.

## Known issues

| Issue | Impact |
| --- | --- |
| #1243 | Fire TV live playback emits repeated vendor property-denial errors in logcat; playback is unaffected. |
| #1023 | `feature_iptv`: mini-player "Watch" does not open the fullscreen player on macOS. |
| Rust ggml ODR | `airo_mind_cli` is excluded from Linux/Windows workspace CI. Local macOS `cargo build -p airo_mind_cli` remains the supported combined-engine loop. |

#1240 (Coins black screen on Pixel 9) is **not** listed here as a shipped
known issue — dropping the Coins SKU for this wave (see Sequence, below) is
the mitigation if the Pixel 9 gate still fails it. #1025 is closed in tree;
drop it from notes once TV chrome is confirmed on the Stick.

## Signing and upgrade chain

Dogfood keystore (`production_signing=false` plus the four `DOGFOOD_*`
secrets). Builds upgrade over other dogfood-signed builds, including `v0.0.6`,
but **not** over production-signed releases.

## Freeze and dispatch

Do not tag until Rust Core CI and Continuous Integration are green on the
freeze SHA, and the device gate below has passed on the dry-run artifacts.

```text
version:                 v0.0.7
build_name:              0.0.7
build_number:            12
release_ref:             <freeze SHA>
release_branch:          release/v0.0.7
dry_run:                 true first, then false
publish_github_release:  false first, then true
github_release_mode:     draft
production_signing:      false
mobile_profile:          full-and-coins
macos_profile:           tv
macos_require_notarization: false
tv_play_track:           none
mobile_play_track:       none
firebase_distribution:   none
```

## Device gate (blocking, run against dry-run artifacts)

**Fire TV Stick 4K** (`io.airo.app.tv`):

- Install and Leanback launcher entry.
- BACK returns from playback to the channel-browse grid without swallowing
  the key (#1430).
- Playlist-merge smoke: one M3U, one Xtream, and one Stalker live source
  appear in a single browse list (#1605). User-supplied authorized playlists
  only.

**Pixel 9**:

- Full-app APK launches to the super-app shell (not a Mind-only home).
- Coins APK opens a usable home (not the #1240 black screen). Failure here
  drops Coins from the wave; it does not waive the full-app launch check —
  rebuild with `mobile_profile: full` and re-check Pixel 9 full launch only.

Waive in writing if timeboxed: iPad soak (#716 / #1601). macOS TV: app opens
is enough; #1023 (mini-player Watch) stays a known issue.

## Rollback

- Keep the GitHub Release **draft** until APKPure.
- If a published build is bad: unpublish `v0.0.7`, leave `v0.0.6` as latest,
  do not reuse versionCode 12, cut `0.0.7+13`.
- Dogfood-signed `0.0.7` upgrades over dogfood `0.0.6` only.

## Related documents

- [Release design spec](../superpowers/specs/2026-08-30-airo-0.0.7-release-design.md)
- [Execution plan](../superpowers/plans/2026-08-30-airo-0.0.7-release.md)
- [V2 release orchestrator](./V2_RELEASE_ORCHESTRATOR.md)
- [v0.0.6 stable notes](./AIRO_v0.0.6.md)
- [Aika Stream feature matrix](./AIKA_STREAM_FEATURE_MATRIX.md)
- [Human-in-loop blockers](./V2_HUMAN_IN_LOOP_BLOCKERS.md)
- [Release checklist](./RELEASE_CHECKLIST.md)
