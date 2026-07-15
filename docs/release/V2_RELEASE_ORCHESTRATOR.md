# V2 Release Orchestrator

This document defines the top-level v2 release orchestration workflow in
`.github/workflows/v2-release-orchestrator.yml`.

Implementation work for this release line must start from latest `origin/v2`.

## Entry Points

The orchestrator runs from:

- tags matching `v2*`;
- manual `workflow_dispatch` runs.

Manual runs default to dry-run mode. Dry-run builds and uploads workflow
artifacts without creating public GitHub Releases or uploading to Google Play.

## Current Scope

The orchestrator currently validates the release contract, calls the existing
Airo TV release workflow through `workflow_call`, optionally calls the
mobile/tablet release workflow when a mobile profile is selected, optionally
calls the macOS release workflow when `macos_profile` is selected, downloads
the selected profile artifacts, generates the top-level evidence bundle,
optionally publishes a single aggregate GitHub Release, and writes the release
summary.

The TV leg reuses `.github/workflows/airo-tv-release.yml` so package checks,
Leanback validation, release artifact naming, checksums, manifest generation,
debug-symbol retention, and optional Play track upload remain owned by the TV
workflow. The orchestrator disables the TV-only GitHub Release publisher and
owns the aggregate multi-profile GitHub Release asset set.

When `mobile_profile` is `iptv-standalone` or `mobile-streaming`, the
orchestrator calls `.github/workflows/airo-mobile-tablet-release.yml` to build
the selected profile's APK and Play Store AAB, generate `SHA256SUMS`, write a
release manifest, retain obfuscation symbols, optionally upload the AAB to a
selected Play track, and contribute mobile/tablet qualification evidence. Real
store or Firebase publication still depends on the credential and destination
setup tracked in #681 and #682.

When `firebase_distribution` is `upload`, the reusable TV and mobile/tablet
release workflows upload the final named APK artifacts to Firebase App
Distribution after release artifacts are staged. Firebase release notes include
the artifact name, package ID, version/build number, checksum, and source ref
from the generated release manifest.

When `macos_profile` is `tv`, the orchestrator calls
`.github/workflows/airo-macos-release.yml` to build `Airo TV.app`, produce ZIP
and DMG artifacts, generate `SHA256SUMS`, write a macOS release manifest, and
generate Homebrew Cask metadata. `macos_require_notarization`
controls whether the macOS leg may complete with unsigned/non-notarized
validation artifacts or must fail unless Developer ID signing and notarization
succeed. The macOS build passes `APP_VERSION=$BUILD_NAME` so the in-app update
check can compare the installed version against GitHub Release assets.

## Release Evidence

Successful orchestrator runs upload:

- `airo-tv-release-<version>` from the TV workflow;
- `airo-mobile-tablet-<profile>-<version>` from the mobile/tablet workflow when
  `mobile_profile` is not `none`;
- `airo-macos-<profile>-<version>` from the macOS workflow when
  `macos_profile` is not `none`;
- `v2-release-evidence-<version>` from the orchestrator.

The top-level evidence bundle includes selected profile artifacts,
`SHA256SUMS`, release manifests, and qualification reports generated from the
manifests. Public qualification mode fails when required device evidence or an
approved waiver is missing.

When `publish_github_release` is enabled and `dry_run` is false, the
orchestrator prepares a flat GitHub Release asset directory that contains:

- every required APK and Play Store AAB for TV and the selected mobile/tablet
  profile;
- every required macOS ZIP/DMG artifact and generated Homebrew Cask file for
  the selected macOS profile;
- a combined `SHA256SUMS` generated after final asset naming;
- a combined `Airo-<version>-Release-Manifest.json`;
- generated release notes derived from the selected artifact set.

`github_release_mode` controls whether a newly created GitHub Release starts as
`draft` or `published`. The default is `draft`.

## Public Publishing Controls

Public/store publishing requires:

- `dry_run` set to `false`;
- `publish_github_release` set to `true` for GitHub Release publication;
- `github_release_mode` set to `draft` or `published`;
- `production_signing` set to `true` for production-signed Android artifacts;
- `tv_play_track` set to a Play testing or production track for TV Play
  uploads;
- `mobile_play_track` set to a Play testing or production track for the
  selected mobile/tablet profile;
- `packages/core_release` used to preflight the selected profile, expected AAB,
  package ID, track mode, and Play Console URL before upload tools run;
- `firebase_distribution` set to `upload` for Firebase App Distribution,
  alongside the required Firebase app IDs and tester groups.
- `macos_profile` set to `tv` for macOS artifacts;
- `macos_require_notarization` set to `true` for public direct-download macOS
  releases, alongside the Developer ID and notarytool secrets documented in
  `docs/release/MACOS_AIRO_TV_RELEASE.md`.

Before any public release dispatch, generate the top-level readiness rollup:

```bash
dart pub global run melos run release:v2-readiness-preflight
```

Set `AIRO_V2_RELEASE_GATES` with comma-separated `gate_id=status` values when
human setup or waiver evidence is available. The report writes redacted JSON and
Markdown under `artifacts/release/` and fails while required account,
credential, store-console, device-evidence, legal, governance, or maintainer
decision gates remain `unknown`, `blocked`, or required-and-`deferred`.
The device-evidence gates include the TV D-pad/UI audit, Cast active-receiver
switching, Cast V1 real-device QA matrix, iPad Air qualification, and constrained
TV memory playback-soak evidence tracked in
`docs/release/V2_HUMAN_IN_LOOP_BLOCKERS.md`.

When `dry_run` is `true`, the orchestrator forces GitHub Release publication
off and sets the TV and mobile/tablet Play tracks plus Firebase distribution to
`none`.

## Human Decisions Still Needed

- Final v2 tag naming policy beyond the current `v2*` automation trigger.
- Whether public releases should publish immediately or always start as draft
  GitHub Releases. The workflow supports both and defaults to draft.
- Whether optional channels should block the whole release or report warnings.
- Play Console apps/tracks, release signing secrets, and
  `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` for #681.
- Play upload jobs should pass only credential availability into
  `AiroPlayUploadPlanner`; service-account JSON stays inside the workflow step
  that invokes the upload tool.
- Mobile/tablet and TV Firebase apps, tester groups, and
  `FIREBASE_SERVICE_ACCOUNT_JSON` for #682. Package IDs are registered under
  `io.airo.app.*`.
- Apple Developer ID certificate/notarytool credentials for public macOS
  direct downloads.
- Whether to submit the generated `airo-tv.rb` to Homebrew immediately
  or attach it as release evidence first.
