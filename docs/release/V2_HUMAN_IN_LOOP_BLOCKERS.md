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
| #574 | Firebase Android client for TV | `io.airo.app.tv` is registered; regenerate the production `google-services.json` or `GOOGLE_SERVICES_JSON` secret so it includes that package. |
| #756 | Firebase Android clients for mobile/tablet profiles | The checked-in Firebase config currently only contains `io.airo.app`; add or confirm Firebase Android clients for the v2 `io.airo.app.*` mobile/tablet profiles, then regenerate the production Firebase config/secret. |
| #576 | Android release signing | Confirm keystore owner, upload key strategy, key backup/rotation owner, and GitHub Actions signing secrets. |
| #585 | Store automation credentials | Create/confirm Play Console service account, app access, upload permissions, first tracks, and App Store Connect credentials only if iOS/iPadOS enters scope. |
| #682 | Firebase App Distribution | Create/confirm Firebase apps, app IDs, tester groups, and service account/token for internal QA uploads. |

### Exact Secret And Input Names

Do not commit these values. Add secrets only through GitHub repository or
environment secret settings, and provide workflow inputs only when an approved
release or distribution run is intentionally started.

| Purpose | GitHub secret or workflow input | Issues |
| --- | --- | --- |
| Firebase Android config for `io.airo.app`, `io.airo.app.iptv`, `io.airo.app.streaming`, and `io.airo.app.tv` | Secret: `GOOGLE_SERVICES_JSON` containing the base64-encoded regenerated `google-services.json` | #574, #756 |
| Android release keystore | Secret: `ANDROID_RELEASE_KEYSTORE_BASE64` | #576 |
| Android keystore password | Secret: `KEYSTORE_PASSWORD` | #576 |
| Android key alias | Secret: `KEY_ALIAS` | #576 |
| Android key password | Secret: `KEY_PASSWORD` | #576 |
| Google Play upload service account | Secret: `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | #585 |
| Play package selection | Fastlane/env value: `SUPPLY_PACKAGE_NAME`; use `io.airo.app.tv`, `io.airo.app.iptv`, or `io.airo.app.streaming` | #585 |
| Firebase App Distribution service account | Secret: `FIREBASE_SERVICE_ACCOUNT_JSON` | #682 |
| Firebase App Distribution app IDs | Workflow inputs: `firebase_app_id`, `mobile_firebase_app_id`, `tv_firebase_app_id` depending on release workflow | #682 |
| Firebase App Distribution tester groups | Workflow inputs: `firebase_tester_groups`, `mobile_firebase_tester_groups`, `tv_firebase_tester_groups` depending on release workflow | #682 |
| iOS/App Store Connect if iOS enters scope | Secrets: `MATCH_PASSWORD`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_CONTENT`; env: `APP_IDENTIFIER`, `APPLE_ID`, `TEAM_ID`, `ITC_TEAM_ID` | #585 |

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
| #514 | Audio playback validation | Run physical Android audio-route and interruption checks for seek accuracy, playback speed, background playback, headphones, Bluetooth, incoming calls, resume, and audio-focus changes. |
| #510 | Downloads edge-case validation | Run Android download lifecycle checks for restart/reboot recovery, network transport changes, corruption recovery, storage pressure, verification, and queue/progress behavior. |
| #511 | Whisper robustness validation | Provide native/runtime evidence for long meetings, silence/background noise, large audio, interruption, low-RAM, rotation, model switching, and memory-leak behavior. |
| #512 | Speaker diarization validation | Provide implemented/native evidence for similar voices, fast switching, overlaps, unknown speakers, rename/merge, speaker persistence, and meeting continuation. |
| #513 | LLM stability validation | Run on-device/local-runtime validation for context overflow, memory exhaustion, model switching, cancellation, summary generation, long meetings, large prompts, offline mode, and low-battery mode. |

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
| #15 | Observability and crash reporting | Deferred for this fast-close pass. If later included, choose provider, privacy/consent policy, DSN/API keys, dashboard access, and release token strategy. |

## Blocked But Not Credential Or Account Creation

| Issue | Blocker | Why it is not a credential/account task |
| --- | --- | --- |
| #337 | Calendar integration and export sync | Current scope can use native device-calendar export. It is blocked on the missing LifeTrack app/module boundary and settings surface, not Google or Apple account credentials. |
| #287 | Remote model servers | Remote server support should be opt-in with user-provided LAN/API endpoints. It is blocked on privacy/security architecture and UI, not a project account setup task. |
| #312 | Community Skills gallery | Built-in skill metadata and tests are healthy. Production community install/update/remove remains blocked on governance, trusted source policy, quarantine/removal policy, and #307 alignment. |
| #498 | Model warm-up | Meeting-specific preload orchestration for Whisper, diarization, embeddings, and LLM readiness is missing. It is larger AI runtime/product work, not a credential task. |
| #497 | Model routing | The app has partial task-aware selection, but the requested dedicated routing matrix for chat, meetings, STT, TTS, OCR, embeddings, and translation is larger AI runtime architecture work, not account setup. |
| #350 | LifeTrack deadline notifications and digests | Notification primitives exist elsewhere, but LifeTrack-specific scheduling, postponed-state suppression, and morning digest orchestration are missing. This is product/framework integration work, not credential setup. |

## Fastest Parallel Setup Order

1. Firebase: complete #574 and #756 first because the repo currently proves
   only `io.airo.app` in `app/android/app/google-services.json`; regenerated
   package-specific Firebase configs unblock app initialization and Firebase
   App Distribution setup.
2. Signing and Play access: complete #576 and #585 before any real store upload.
3. Firebase App Distribution: complete #682 after Firebase app IDs and tester
   groups exist.
4. Store forms: complete #583 and #584 while engineering continues.
5. Device evidence: schedule #683, #589, #590, #716, #459/#453, #257, #519,
   #516, #515, #520, #514, #510, #511, #512, and #513 after signed or
   release-candidate artifacts are available.
6. Governance/legal: complete #687, #689, and #673 before broad public release.
7. Deferred service/product setup: handle #168, #250, #249, #339, #342, and
   #15 only after the first release wave scope is confirmed.
