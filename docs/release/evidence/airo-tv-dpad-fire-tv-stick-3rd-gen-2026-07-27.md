# Midas Stream D-pad Diagnostic — Fire TV Stick 3rd Gen — 2026-07-27

## Result

**INCONCLUSIVE**

This report records ADB-driven black-box diagnostics on one physical Amazon
Fire TV Stick 3rd Gen (`AFTSSS`). It is intentionally not a physical-remote
pass and must not be used to close the #589 physical D-pad slice.

## Device and artifact

- Public device label: Amazon Fire TV Stick 3rd Gen (2020)
- OS/build: Fire OS 7 / Android 9 API 28; `PS7715.5585N`
- Reported output: 1920×1080 at Android density 320
- Required 720p constrained profile: not configured
- Package: `io.airo.app.tv`
- Version: `0.0.5` (`versionCode 7`)
- Installed APK: `base.apk`, 223,971,216 bytes
- APK SHA256:
  `b48c8d77eb9a0ea850c5be913d94ac17efc5b345075cf6105e7135c95b4d7e93`
- Git SHA/build mode: EVIDENCE GAP
- Physical remote type: EVIDENCE GAP
- Input used: ADB D-pad key events for diagnosis only
- Date/tester: 2026-07-27, Codex black-box QA

## Diagnostic traversal

| Step | Result | Observation |
| --- | --- | --- |
| Launch Midas Stream | INCONCLUSIVE | `MainActivity` was foreground and live playback was visible; launch used ADB |
| Move among Home controls | INCONCLUSIVE | Visible focus rings appeared on Search, Share, a channel-card action, and picker elements |
| Open Language picker | INCONCLUSIVE | TV-native picker opened and displayed an A–Z rail plus language option groups |
| Enter A–Z rail | INCONCLUSIVE | Diagnostic traversal exposed focus on the `B` rail entry |
| Return to option group | INCONCLUSIVE | Right returned from `B` to the matching `ach` option group |
| Back/dismiss | INCONCLUSIVE | Picker dismissed without observed crash; input was not the physical remote |
| Eight channel cards | NOT RUN | The available state did not expose a qualifying eight-card traversal |
| Help open/dismiss | NOT RUN | Help was not reached |
| Full required-control inventory | NOT RUN | Search, Playlist, Help, Refresh, category, view toggle, filter, and channel-card denominator was not measured |
| Physical Back/MENU/media/channel keys | NOT RUN | No physical-remote operator evidence |
| Focus-loss count | NOT RUN | No valid physical-remote measurement |
| Overflow count | NOT RUN | No complete traversal measurement |
| Render-error count | NOT RUN | No complete traversal measurement |

## Sanitized captures

- [Home/live playback](./assets/airo-tv-physical-device-qa-2026-07-27/fire-tv-stick-3rd-gen-home-1080p.png)
- [Language picker](./assets/airo-tv-physical-device-qa-2026-07-27/fire-tv-stick-3rd-gen-language-picker.png)
- [Rail-to-option return](./assets/airo-tv-physical-device-qa-2026-07-27/fire-tv-stick-3rd-gen-language-picker-right-return.png)

## Linked issue

- [#1243 — Fire TV live playback emits approximately 36 vendor
  property-denial errors per second](https://github.com/DevelopersCoffee/airo/issues/1243)

## Required rerun

Repeat the full #589 inventory with the real remote, the intended output
profile, a measured denominator, at least eight channel cards, and factual
focus-loss/overflow/render-error counts. Do not promote any row in this report
to `PASS`.
