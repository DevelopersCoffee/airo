# Airo TV Cross-Platform Validation Matrix

This matrix defines the v2.0.0.1 platform validation boundary for Airo TV,
companion, desktop, embedded receiver, and cloud control-plane surfaces.

Implementation contract:

- Package: `packages/platform_certification`
- Schema: `kAiroValidationSchemaVersion`
- Default matrix: `AiroCrossPlatformValidation.matrix()`
- Current release branch: `codex/next-v2.0.0.0`

## Target Classes

| Target ID | Platform | Product profile | Status | Device certification |
| --- | --- | --- | --- | --- |
| `android-tv-lite-receiver` | Android TV | Lite Receiver | Required | Yes |
| `fire-tv-lite-receiver` | Fire TV | Lite Receiver | Required | Yes |
| `android-mobile-companion` | Android mobile | Companion | Required | No |
| `ios-ipados-companion` | iOS/iPadOS | Companion | Required | No |
| `desktop-pointer-companion` | Desktop | Desktop companion | Required | No |
| `apple-tv-tvos` | tvOS | Full TV | Blocked | Yes |
| `web-embedded-receiver` | Web embedded receiver | Embedded receiver | Optional | Yes |
| `backend-cloud-control-plane` | Backend/cloud | Backend control plane | Required | No |

## Required Gate Families

| Gate | Evidence tier | Purpose |
| --- | --- | --- |
| Product capabilities | Host automation | Selected profile exposes only declared modules and permissions |
| Adaptive UI | Host automation | Interaction, density, focus, and accessibility resolve deterministically |
| Remote focus | Physical device/manual | D-pad navigation remains stable during loading |
| Touch input | Host/physical | Companion controls meet accessibility and pairing requirements |
| Pointer input | Host/manual | Desktop surfaces use pointer-safe navigation |
| Playback engine | Host/physical | Playback uses platform engine contracts, not app shortcuts |
| Media routing | Host/security review | Routing uses route handles and decision logs without raw provider auth material |
| Pairing controller | Host/physical/security review | Trusted-device pairing and scoped commands work per contract |
| Session sync | Host automation | Receiver-authoritative session revisions and conflict policy hold |
| Analytics redaction | Host/security review | Prohibited fields and local-only behavior are enforced |
| Dependency governance | Host/release review | Profile dependencies satisfy release-line governance |
| Package content scan | Host automation | No bundled playlists, provider media, raw URLs, or credentials ship |
| Local network privacy | Security/manual review | Local-network discovery and permissions are scoped and disclosed |
| Import/export data governance | Host/security review | Playlist and local data paths follow platform contracts |
| Accessibility | Host/manual/physical | Text scale, targets, focus, contrast, and motion are validated |
| Native target | Host/release review | Native target, signing, entitlements, and build path exist |
| Store policy | Store/manual review | Store metadata, permissions, and policy checks pass |
| Orchestration storage | Cloud contract/host | Cloud storage contracts are versioned, scoped, and rollback-safe |
| Cloud privacy | Security/cloud contract | Retention, redaction, identity, and access boundaries are covered |
| Physical device evidence | Physical device | Device certification claims have recent real-device evidence |

## Consumer Rule

Airo TV release checks, QA automation, and future device-lab tooling should
consume `AiroCrossPlatformValidation.matrix()` rather than hard-code per-target
rules in release scripts or app screens.

Host-only automation can satisfy deterministic package, schema, contract,
content-scan, and governance checks. It cannot advertise receiver/device
certification for Android TV, Fire TV, tvOS, or embedded receiver targets
without the physical-device gates required by the matrix.

## Out Of Scope

This issue does not run physical device labs, collect screenshots or logs,
change app screens, add platform SDK targets, submit stores, implement backend
services, or certify Apple TV/tvOS support.
