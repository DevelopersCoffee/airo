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
mobile/tablet release workflow when a mobile profile is selected, downloads the
selected profile artifacts, generates the top-level evidence bundle, and writes
the release summary.

The TV leg reuses `.github/workflows/airo-tv-release.yml` so package checks,
Leanback validation, release artifact naming, checksums, manifest generation,
debug-symbol retention, optional GitHub Release publication, and optional Play
track upload remain owned by the TV workflow.

When `mobile_profile` is `iptv-standalone` or `mobile-streaming`, the
orchestrator calls `.github/workflows/airo-mobile-tablet-release.yml` to build
the selected profile's APK and Play Store AAB, generate `SHA256SUMS`, write a
release manifest, retain obfuscation symbols, and contribute mobile/tablet
qualification evidence. Real store or Firebase publication still depends on
the credential and destination setup tracked in #681 and #682.

## Release Evidence

Successful orchestrator runs upload:

- `airo-tv-release-<version>` from the TV workflow;
- `airo-mobile-tablet-<profile>-<version>` from the mobile/tablet workflow when
  `mobile_profile` is not `none`;
- `v2-release-evidence-<version>` from the orchestrator.

The top-level evidence bundle includes selected profile artifacts,
`SHA256SUMS`, release manifests, and qualification reports generated from the
manifests. Public qualification mode fails when required device evidence or an
approved waiver is missing.

## Public Publishing Controls

Public/store publishing requires:

- `dry_run` set to `false`;
- `publish_github_release` set to `true` for GitHub Release publication;
- `production_signing` set to `true` for production-signed Android artifacts;
- `tv_play_track` set to a Play testing track for TV Play uploads.

When `dry_run` is `true`, the orchestrator forces GitHub Release publication
off and sets the TV Play track to `none`.

## Human Decisions Still Needed

- Final v2 tag naming policy beyond the current `v2*` automation trigger.
- Whether public releases should publish immediately or always start as draft
  GitHub Releases.
- Whether optional channels should block the whole release or report warnings.
- Mobile/tablet Firebase apps, Play tracks, release signing secrets, and upload
  credentials for #681 and #682. Package IDs are registered under
  `io.airo.app.*`.
