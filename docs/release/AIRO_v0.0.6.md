# Airo v0.0.6 — Stable Release

Stable cut for **direct download / APKPure**, promoting the `v0.0.6-rc.1`
preview line. Google Play, App Store, Firebase App Distribution, iOS/iPadOS, and
macOS notarization remain out of scope for this cut.

## Release wave (published artifacts)

| Profile | Package / bundle | Artifact | Version line |
| --- | --- | --- | --- |
| Android TV (`tv`) | `io.airo.app.tv` | `Airo-TV-0.0.6.apk` + per-ABI APKs + AAB | `0.0.6+10` |
| Full app (`full`) | `io.airo.app` | `Airo-0.0.6-10-arm64.apk` + AAB | `0.0.6+10` |
| Airo Coins (`coins`) | `io.airo.app.coins` | `AiroCoins-0.0.6-10-arm64.apk` + AAB | `0.0.6+10` |
| macOS TV | `com.developerscoffee.airo.tv` | direct-download `.zip` / `.dmg` + Homebrew Cask | `0.0.6` |

All four profiles ship from a single `release-orchestrator.yml` wave. Airo Coins
was published by hand for `v0.0.6-rc.1`; it is now a first-class orchestrator leg
(`coins_profile`), so the wave is reproducible end to end.

Tag: `v0.0.6`.

## Not in this release

| Artifact / profile | Source | Status |
| --- | --- | --- |
| iOS / iPadOS SPM | `ios-spm` | Deferred — no Apple developer account. |
| Web validation | `web-validation` | Local/CI browser-engine validation only; no public web deploy. |
| Linux / Windows desktop | `app/linux`, `app/windows` | Build targets exist; no release workflow, no published artifact. |
| Airo Mind runtime | `packages/feature_mind` | Milestone 22 work is in-tree behind the `MindRuntime` port; no separate shippable artifact. |
| Raw gradle APKs | `app-release.apk`, `app-arm64-v8a-release.apk` | Renamed to `Airo-*` / `Airo-TV-*` / `AiroCoins-*` before publish. |
| Debug symbols / obfuscation maps | `.symbols`, `.map` | Retained privately as a restricted workflow artifact for symbolication. |
| Credentials & secrets | `*.jks`, `google-services.json`, service accounts | Never attached to public assets or the release manifest. |

## What is new since v0.0.6-rc.1

**Airo TV**

- Fire TV D-pad focus and BACK paths restored after the #1244 regression.
- The TV shell is held inside both the horizontal and vertical title-safe bands,
  fixing overscan clipping on real Fire TV hardware.
- Help stays reachable in the grid-first layout; settings focus survives
  retained playback.
- Local-file cast release and Fire TV release qualification hardened, including
  ABI splits and physical-log classification.
- Portable shared channel imports for moving a channel set between devices.

**Airo (full app)**

- Guide and Favorites moved into IPTV; Settings moved under Profile.
- Chess moves are applied instead of being silently rejected.
- Playlist source removal is now consistent; local media IDs are web-safe.

**Airo Mind / AI**

- Offline Meeting Intelligence MVP — record, transcribe, summarise, search.
- Airo Mind Vault phase 1, and the `MindRuntime` port frozen into eight
  sub-ports with fixture and partial Rust implementations behind it.
- Device runtime readiness explained in-app, with copyable device-capability,
  runtime-health, and model-advisor diagnostics plus chat transcript export.
- Model download queue position, stalled-download recovery, and clearer setup
  failure messages.

**Airo Coins**

- The standalone shell opens on a content-first money home.

## Known issues

| Issue | Impact |
| --- | --- |
| #1240 | Airo Coins can open to a persistent black screen on Pixel 9 / Android 17. Not re-verified against the new coins shell in this cut. |
| #1430 | Airo TV: BACK is intermittently swallowed on the channel-browse grid after returning from playback. |
| #1243 | Fire TV live playback emits repeated vendor property-denial errors in logcat; playback is unaffected. |
| #1025 | `platform_player` overlays can stack — error state, idle play button, and hover controls render together. |
| #1023 | `feature_iptv`: mini-player "Watch" does not open the fullscreen player on macOS. |

## Signing and upgrade chain

This cut uses the stable dogfood keystore (`production_signing=false` plus the
four `DOGFOOD_*` secrets). Builds upgrade cleanly over other dogfood-signed
builds, including `v0.0.6-rc.1`, but **not** over production-signed releases.
The per-artifact signing certificate is recorded in the generated release notes
and manifest.

## Verification

`SHA256SUMS` and `Airo-0.0.6-Release-Manifest.json` are published as release
assets. The manifest maps every checksum to its profile, package ID, version,
build number, source ref, and workflow run.

## Related documents

- [V2 release orchestrator](./V2_RELEASE_ORCHESTRATOR.md)
- [v0.0.6-rc.1 preview notes](./AIRO_v0.0.6-rc.1.md)
- [Airo TV release template](./AIRO_TV_RELEASE_TEMPLATE.md)
- [Release checklist](./RELEASE_CHECKLIST.md)
