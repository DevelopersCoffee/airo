# Airo v0.0.7-preview — Preview Release

Status: **prepared, not released** until a green freeze SHA is tagged.
Preview (release-candidate) cut for **direct download / APKPure**, not a store
submission. Google Play, App Store, Firebase App Distribution, iOS/iPadOS, and
macOS notarization stay out of scope for this cut.

Same four SKUs as [`v0.0.6`](./AIRO_v0.0.6.md). Standalone Airo Mind
(`io.airo.app.mind`) is not an orchestrator leg.

## Release wave (intended artifacts)

| Profile | Package / bundle | Artifact | Version line |
| --- | --- | --- | --- |
| Android TV (`tv`) | `io.airo.app.tv` | `Airo-TV-0.0.7-preview.apk` + per-ABI APKs + AAB | `0.0.7-preview+12` |
| Full app (`full`) | `io.airo.app` | `Airo-0.0.7-preview-12-arm64.apk` + AAB | `0.0.7-preview+12` |
| Airo Coins (`coins`) | `io.airo.app.coins` | `AiroCoins-0.0.7-preview-12-arm64.apk` + AAB | `0.0.7-preview+12` |
| macOS TV | `com.developerscoffee.airo.tv` | direct-download `.zip` / `.dmg` + Homebrew Cask | `0.0.7-preview` |

Tag: `v0.0.7-preview`. Branch: `release/v0.0.7-preview`.
`versionCode` is **12** so Android upgrades over Coins `0.0.6+11`.

## Claim state

Classify before any public copy. Merged code is not Available.

| Surface | State | Notes |
| --- | --- | --- |
| Airo TV BACK after playback (#1430) | Available after Fire TV evidence | Closed in tree; attach Stick install + D-pad + BACK proof before calling it Available on the site. |
| Unified live playlist merge (M3U / Xtream / Stalker) | Under qualification | In tree; needs Fire TV / Pixel playlist smoke. |
| Cast splice-on-keyframe, 3-tile multiview, fold crease | Under qualification | Physical Device QA #1603 / #1601 / #1588 still open. |
| Design-system pass across flavors | Under qualification | Visual, not a store listing claim. |
| Meeting Intelligence already in 0.0.6 | Available (unchanged) | Record / transcribe / summarise / search as shipped in 0.0.6. |
| New Mind work (Meeting IR, MoM, speaker learning, Indic, chat-over-meetings) | Under qualification | Rides in the full app. Do not advertise. #1592 still open. |
| Coins embeddings auto-categorize / recurrence / anomaly | Under qualification | In tree; #1240 still open. |
| Standalone Mind APK | Not adopted this wave | `ciBuild: false`, still `0.0.1+1`. |
| Play / notarized macOS / Firebase testers | Deferred | #576, #803, #756, #585. |

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

**Airo TV**

- BACK on the channel-browse grid after returning from playback (#1430).
- Unified live playlist merge across M3U, Xtream, and Stalker sources.
- Cast splice-on-keyframe, hover-chrome zones, 3-tile multiview, fold crease rule.
- Shared design-system typography, color, and spacing across flavors.

**Airo (full app)**

- Shared `AiroBootstrap` runner and a large dead-code / provider purge.
- Web wasm leak gate on unsafe `dart.library.html` conditional imports.
- Meeting Intelligence remains in the full app. New Mind surfaces listed above
  ship in the binary as Under qualification, not as Available.

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
| #1240 | Airo Coins can open to a persistent black screen on Pixel 9 / Android 17. |
| #1243 | Fire TV live playback emits repeated vendor property-denial errors in logcat; playback is unaffected. |
| #1023 | `feature_iptv`: mini-player "Watch" does not open the fullscreen player on macOS. |
| Rust ggml ODR | `airo_mind_cli` is excluded from Linux/Windows workspace CI. Local macOS `cargo build -p airo_mind_cli` remains the supported combined-engine loop. |

#1430 and #1025 were open on the 0.0.6 notes and are closed in tree. Confirm on
device before dropping them from public known-limitations copy.

## Signing and upgrade chain

Dogfood keystore (`production_signing=false` plus the four `DOGFOOD_*`
secrets). Builds upgrade over other dogfood-signed builds, including `v0.0.6`,
but **not** over production-signed releases.

## Freeze and dispatch

Do not tag until Rust Core CI and Continuous Integration are green on the
freeze SHA.

```text
version:                 v0.0.7-preview
build_name:              0.0.7-preview
build_number:            12
release_ref:             <freeze SHA>
release_branch:          release/v0.0.7-preview
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

Preview bar before flipping the GitHub Release from draft to published
prerelease: Fire TV Stick install + Leanback + BACK; Pixel 9 full-app launch
+ Coins home + Mind record/transcribe smoke; macOS TV app opens. Waive iPad
soak in writing if timeboxed.

## Related documents

- [V2 release orchestrator](./V2_RELEASE_ORCHESTRATOR.md)
- [v0.0.6 stable notes](./AIRO_v0.0.6.md)
- [Airo TV feature matrix](./AIRO_TV_FEATURE_MATRIX.md)
- [Human-in-loop blockers](./V2_HUMAN_IN_LOOP_BLOCKERS.md)
- [Release checklist](./RELEASE_CHECKLIST.md)
