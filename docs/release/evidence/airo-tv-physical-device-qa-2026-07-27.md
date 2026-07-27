# Airo TV Physical-Device QA — 2026-07-27

## Campaign status

**Overall: INCOMPLETE**

This was a black-box, evidence-only run. No product code was read or changed.
The execution worktree was created from and verified against `origin/main` at
`3cbba0a51a79bfe27b9eb5a5466658566be52e3a` before testing. After the run,
`origin/main` advanced by one documentation-only commit; the evidence worktree
was safely fast-forwarded to
`f8f1b5ecae47e17396cd058df47de3312f668345`.

Only one physical TV device was connected. It was an Amazon Fire TV Stick 3rd
Gen (`AFTSSS`) currently outputting 1920×1080. Amazon identifies this model as
the 2020 Fire TV Stick 3rd Gen, not the Fire TV Stick Lite. It is a constrained
1 GB device, but the run did not configure or verify the required 720p output
profile. See the [Amazon device specification](https://www.developer.amazon.com/docs/device-specs/device-specifications-fire-tv-streaming-media-player.html).

ADB input was used for diagnostic exploration only. It is not credited as
physical-remote evidence. The required Fire TV 4K-at-1080p, Google/Android TV
4K, and Android TV density-1 1080p classes were unavailable.

## Run declaration

- Worktree: `airo-worktrees/qa-hardware-task2a-20260727`
- Branch: `codex/qa-hardware-task2a-20260727`
- Run-start base SHA: `3cbba0a51a79bfe27b9eb5a5466658566be52e3a`
- Final synced worktree SHA:
  `f8f1b5ecae47e17396cd058df47de3312f668345`
- Tested package: `io.airo.app.tv`
- Installed version: `0.0.5` (`versionCode 7`)
- Installed APK filename: `base.apk`
- Installed APK size: 223,971,216 bytes
- Installed APK SHA256:
  `b48c8d77eb9a0ea850c5be913d94ac17efc5b345075cf6105e7135c95b4d7e93`
- Installed APK Git SHA: EVIDENCE GAP
- Build mode: EVIDENCE GAP
- Tester: Codex black-box QA (ADB diagnostics only)
- Date: 2026-07-27

The installed artifact's Git SHA is not exposed by the observed package
metadata or tested UI. The current worktree SHA is therefore not claimed as the
artifact build SHA, and the PR-ancestor checkpoint remains unproved.

## Device metadata

| Matrix ID | Public device label | OS/build | Configured output | Logical size / DPR | Safe insets / text scale | Remote | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `fire-tv-lite-720p` | Amazon Fire TV Stick 3rd Gen (2020), `AFTSSS` constrained-device candidate | Fire OS 7 / Android 9 API 28; `PS7715.5585N` | Physical output reported 1920×1080, density 320; required 720p not configured | EVIDENCE GAP; no in-app MediaQuery diagnostic was available | EVIDENCE GAP | Physical remote type/use not observed | EVIDENCE GAP |
| `fire-tv-4k-1080p` | No device | Not available | Not available | Not available | Not available | Not available | EVIDENCE GAP |
| `google-android-tv-4k` | No device | Not available | Not available | Not available | Not available | Not available | EVIDENCE GAP |
| `android-tv-density1-1080p` | No device | Not available | Not available | Not available | Not available | Not available | EVIDENCE GAP |

The Android `wm` size/density values are recorded only as device diagnostics.
They are not substituted for Flutter logical size, DPR, safe insets, or text
scale.

## Common Issue 05 checks

| Check | Fire TV constrained candidate | Other required classes |
| --- | --- | --- |
| 32×24 safe-area budget | INCONCLUSIVE — the 1080p diagnostic capture showed no obvious outer-frame clipping, but logical insets and the required 720p profile were unavailable | EVIDENCE GAP |
| Edge focus rings visible and unclipped | INCONCLUSIVE — ADB navigation showed visible rings on Search, Share, picker rail, and picker option; not a complete edge inventory or physical-remote run | EVIDENCE GAP |
| 10-foot minimum-text legibility | NOT RUN — no physical viewing-distance assessment | EVIDENCE GAP |
| Consistent D-pad traversal intent | INCONCLUSIVE — limited ADB diagnostic traversal only | EVIDENCE GAP |
| Transport/Mini Guide/Drawer/Guide/context overlay stability | NOT RUN | EVIDENCE GAP |
| Rapid D-pad input | NOT RUN with physical remote | EVIDENCE GAP |
| Approximately 12,000-channel browsing and frame evidence | NOT RUN — authorized fixture and measured frame capture unavailable | EVIDENCE GAP |
| Back, MENU/long-press Select, media keys, channel up/down | NOT RUN with physical remote | EVIDENCE GAP |

## PR #1177 — TV long-list picker

| Check | Fire TV constrained candidate | Other required classes |
| --- | --- | --- |
| Country picker | NOT RUN | EVIDENCE GAP |
| Language picker | INCONCLUSIVE — TV-native Language picker opened under ADB diagnostics | EVIDENCE GAP |
| Category picker | NOT RUN | EVIDENCE GAP |
| Left enters A–Z rail | INCONCLUSIVE — diagnostic Left then Down exposed focus on the `B` rail entry; no physical-remote credit | EVIDENCE GAP |
| Right returns to option group | INCONCLUSIVE — diagnostic Right returned from `B` to the matching `ach` option group | EVIDENCE GAP |
| Recent value after close/reopen | NOT RUN — no selection was changed | EVIDENCE GAP |
| 500+ entry performance | NOT RUN — qualifying fixture unavailable | EVIDENCE GAP |
| No picker Favourites UI | INCONCLUSIVE — none was visible in the Language picker capture, but the full picker matrix was not run | EVIDENCE GAP |

## PR #1188 — Wi-Fi Settings

| Device class | Result | Observation |
| --- | --- | --- |
| Fire TV | NOT RUN | Disconnecting Wi-Fi would also remove the available ADB transport, and no physical-remote recovery operator was available. |
| Android/Google TV | EVIDENCE GAP | No qualifying device was connected. |

## PR #1190 — QR phone handoff

| Check | Result | Observation |
| --- | --- | --- |
| Readable QR within safe area | NOT RUN | The connected Fire TV already contained playlist state; no destructive reset was authorized. |
| Same-LAN phone form | NOT RUN | No QR session was created. |
| Authorized URL pre-fills Add Playlist | NOT RUN | No authorized onboarding fixture was supplied. |
| Five-minute expiry/regeneration | NOT RUN | No QR session was created. |
| Intentional absence of USB import | NOT RUN | Onboarding surface was not reached. |

No pairing token, QR/pairing URL, LAN address, or playlist URL was captured or
published.

## PR #1237 — sustained-stall failover

| Check | Result | Observation |
| --- | --- | --- |
| Multi-source sustained stall ≥4 seconds switches and resumes | NOT RUN | Controlled degradation and a known multi-source fixture were unavailable. |
| Failover toast | NOT RUN | No failover was induced. |
| Single-source sustained stall reaches retry/error | NOT RUN | Known single-source fixture unavailable. |
| Brief rebuffer <4 seconds does not switch | NOT RUN | Controlled transient degradation unavailable. |

## Physical D-pad evidence

- [Fire TV Stick 3rd Gen diagnostic D-pad report](./airo-tv-dpad-fire-tv-stick-3rd-gen-2026-07-27.md)
- Result: **INCONCLUSIVE**
- The report is separate for this physical device and contains no device
  serial, LAN identifier, source URL, or playlist credential.

## Sanitized visual evidence

- [Fire TV home/live playback at 1080p](./assets/airo-tv-physical-device-qa-2026-07-27/fire-tv-stick-3rd-gen-home-1080p.png)
- [Fire TV Language picker](./assets/airo-tv-physical-device-qa-2026-07-27/fire-tv-stick-3rd-gen-language-picker.png)
- [Fire TV Language picker rail-to-option return](./assets/airo-tv-physical-device-qa-2026-07-27/fire-tv-stick-3rd-gen-language-picker-right-return.png)
- [Pixel 9 Coins black-screen reproduction](./assets/airo-tv-physical-device-qa-2026-07-27/pixel-9-coins-black-screen.png)

The Pixel 9 capture is adjacent mobile-profile evidence and does not represent a
TV matrix class.

## Defects and observations

| Issue | Result | Scope |
| --- | --- | --- |
| [#1240 — Pixel 9 Android 17 Coins cold launch remains black](https://github.com/DevelopersCoffee/airo/issues/1240) | FAIL | Adjacent physical Pixel 9 black-box check; installed package was `io.airo.app.coins`, not Airo TV |
| [#1243 — Fire TV playback emits approximately 36 vendor property-denial errors/second](https://github.com/DevelopersCoffee/airo/issues/1243) | FAIL | Fire TV playback diagnostics; user-visible performance impact remains unmeasured |

No fix was attempted for either issue.

## Follow-on assignment status

| Assignment | Result | Reason |
| --- | --- | --- |
| #589 physical D-pad evidence | INCONCLUSIVE | One physical Fire TV was connected, but only ADB diagnostic input was available; the separate report is not a physical-remote pass |
| #459 Android+iOS Google Cast V1 | NOT RUN | No iPhone build/operator, authorized HLS fixture, or verified Google Cast receiver inventory was supplied |
| #889 CV-033 large local-file streaming | NOT RUN | No verified Google Cast receiver, approximately 5 GB H.264/AAC fixture, unsupported fixture, or laptop security-check setup was supplied |
| #683 exact final-artifact release qualification | NOT RUN | Release owner did not supply the exact final artifact/checksum, device inventory, Fire TV classification, or waiver rules |
| #1081/#1084 launch gate and tracker | NOT RUN | Tracker-only until the plan's software and evidence dependencies are complete |

Fire TV was used only as an installed Airo TV target. It was not represented as
a Google Cast receiver.

## Evidence gaps and next run

1. Configure and independently verify a constrained Fire TV candidate at 720p,
   or use an actual Fire TV Stick Lite.
2. Supply a Fire TV Stick 4K configured for 1080p.
3. Supply a Google/Android TV at verified 4K output.
4. Supply an Android TV box whose in-app diagnostics report approximately
   1920×1080 logical pixels at DPR/density 1.
5. Use each physical remote and record its public type.
6. Use a build that exposes Git SHA, build mode, logical size, DPR, safe
   insets, and text scale without adding instrumentation during the run.
7. Supply authorized 12k-channel, 500+ picker, multi-source, single-source,
   and controlled-network fixtures.
8. Supply a safe same-LAN QR onboarding state and phone.

The campaign must remain **INCOMPLETE** until every required physical class and
mandatory row has factual evidence.
