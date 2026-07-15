# V2 Human-In-Loop Blocker Index

Last checked: 2026-07-15

This index lists open v2 release blockers that cannot be completed by code
alone. They require account ownership, credentials, store-console actions,
physical-device evidence, legal confirmation, or maintainer decisions.

Use this document when preparing setup work in parallel with engineering. Do
not commit secrets, signing keys, service-account JSON, private store-console
exports, playlist URLs, local IP addresses, or private device logs.

## Immediate Release Account And Credential Blockers

| Issue | Blocker | Human action needed |
| --- | --- | --- |
| #574 | Firebase Android client for TV | Add or confirm Firebase Android app/client for `io.airo.app.tv`, then regenerate the production `google-services.json` or `GOOGLE_SERVICES_JSON` secret that includes that package. |
| #756 | Firebase Android clients for mobile/tablet profiles | Add or confirm Firebase Android clients for `io.airo.app.iptv` and `io.airo.app.streaming`, then regenerate the production Firebase config/secret. |
| #576 | Android release signing | Confirm keystore owner, upload key strategy, key backup/rotation owner, and GitHub Actions signing secrets. |
| #585 | Store automation credentials | Create/confirm Play Console service account, app access, upload permissions, first tracks, and App Store Connect credentials only if iOS/iPadOS enters scope. |
| #682 | Firebase App Distribution | Create/confirm Firebase apps, app IDs, tester groups, and service account/token for internal QA uploads. |

## Store Console And Legal Submission Blockers

| Issue | Blocker | Human action needed |
| --- | --- | --- |
| #583 | Play Data Safety and App Privacy | Enter console forms from the repo docs and attach submission evidence. |
| #584 | IARC and age rating | Complete store-console rating questionnaires and attach evidence. |
| #687 | License/commercial dependency confirmation | Confirm whether any private, commercial, gated, or restricted dependency ships in v2 artifacts, and decide whether SHA256-only provenance is enough for the first wave. |
| #689 | Repository governance | Decide whether to enable GitHub Discussions, provide CODEOWNERS owner handles, and confirm whether funding/sponsor metadata is intentionally absent. |

## Release Qualification And Device Evidence Blockers

| Issue | Blocker | Human action needed |
| --- | --- | --- |
| #683 | Release qualification matrix evidence | Provide physical-device list or BrowserStack/Firebase Test Lab matrix, waiver policy, waiver approver, and final report for actual artifacts. |
| #589 | Airo TV UI/UX release audit | Provide physical Android TV / Fire TV D-pad validation and remaining viewport/accessibility evidence after repo-only hardening. |
| #590 | Cast active-receiver switching | Run physical Cast validation from Pixel 9 or equivalent Android phone to BRAVIA/Chromecast-class receiver. |
| #716 | iPad Air qualification | Run iPad Air UI/UX qualification and attach defect report or waiver. |
| #459 / #453 | Cast V1 QA matrix and epic | Provide real-device Cast QA evidence so the Cast V1 epic can close. |
| #257 | Coins receipt OCR hardening | Run Android emulator/device receipt integration against the image-only PDF fixture and itemized split tap-through UI smoke evidence. |
| #519 | UI responsiveness validation | Run manual device matrix for orientation, split screen, foldables, tablets, dynamic font scaling, dark mode, accessibility, keyboard handling, and feature-specific offline/empty/error/loading states. |
| #516 | Database reliability validation | Run device/manual migration, crash-recovery, corrupted-database, large-history, search-indexing, backup, and restore checks after the host database reliability suite. |
| #515 | Notification validation | Run notification validation on a supported physical/emulated target and attach evidence. |
| #520 | Performance benchmarks | Run benchmark matrix and attach reproducible results. |

## Repository Or Workspace Decision Blockers

| Issue | Blocker | Human action needed |
| --- | --- | --- |
| #673 | Local workspace cleanup | Decide which local stashes should be kept, backed up, applied, or dropped. |
| #568 | Kotlin Gradle Plugin future warning | Remaining third-party plugins need compatible upstream releases, dependency resolution work, or approved scoped local patches. |

## Product Or Service Setup Outside The Narrow Release Track

| Issue | Blocker | Human action needed |
| --- | --- | --- |
| #168 | Plugin CDN/object storage | Choose provider, DNS/bucket/project, access policy, credentials, and secret storage approach. |
| #250 | Coins shared-group cloud sync backend | Provide Firebase/Auth/Firestore project decisions, rules/index deployment access, and release-scope approval. |
| #249 | Cloud-only Music/Beats | Confirm licensed catalog/backend/compliance strategy before productionizing cloud playback. |
| #339 | LifeTrack template marketplace | Choose source repository/service, contribution/review policy, and token/service account strategy. |
| #342 | Premium plugin licensing | Decide monetization mechanism, product IDs/SKUs, store/test credentials, and offline entitlement policy. |

## Fastest Parallel Setup Order

1. Firebase: complete #574 and #756 first because package-specific Firebase
   configs unblock app initialization and Firebase App Distribution setup.
2. Signing and Play access: complete #576 and #585 before any real store upload.
3. Firebase App Distribution: complete #682 after Firebase app IDs and tester
   groups exist.
4. Store forms: complete #583 and #584 while engineering continues.
5. Device evidence: schedule #683, #589, #590, #716, #459/#453, #257, #519,
   #516, #515, and #520 after signed or release-candidate artifacts are
   available.
6. Governance/legal: complete #687, #689, and #673 before broad public release.
