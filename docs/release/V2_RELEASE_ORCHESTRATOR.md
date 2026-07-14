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
Airo TV release workflow through `workflow_call`, downloads the TV artifacts,
generates the top-level evidence bundle, and writes the release summary.

The TV leg reuses `.github/workflows/airo-tv-release.yml` so package checks,
Leanback validation, release artifact naming, checksums, manifest generation,
debug-symbol retention, optional GitHub Release publication, and optional Play
track upload remain owned by the TV workflow.

Mobile/tablet publishing is intentionally not enabled yet. Selecting
`iptv-standalone` or `mobile-streaming` in the orchestrator fails with a pointer
to #677 until signed APK/AAB jobs and store/Firebase destinations are ready.

## Release Evidence

Successful TV orchestrator runs upload:

- `airo-tv-release-<version>` from the TV workflow;
- `v2-release-evidence-<version>` from the orchestrator.

The top-level evidence bundle includes TV artifacts, `SHA256SUMS`, the release
manifest, and a qualification report generated from the manifest. Public
qualification mode fails when required device evidence or an approved waiver is
missing.

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
- Mobile/tablet package IDs, Firebase apps, Play tracks, and release signing
  secrets for #677, #681, and #682.
