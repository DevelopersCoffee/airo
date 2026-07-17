# V2 Airo TV macOS Release

**Primary owner:** Release and DevEx Agent
**Review agents:** Media Agent, Framework Agent, Security and Privacy Agent, QA
Automation Agent, Mobile UI Agent
**Layer:** Mixed. This touches release automation, native macOS target metadata,
TV app profile validation, signing/notarization, and distribution docs.

## Critical Agent Clarity Gate

**Problem:** Airo v2 currently publishes the modular Airo TV app first. macOS
needs the same scoped Airo TV release path without expanding launch scope to
the broader Streaming/mobile app.

**User / actor:** macOS user who wants the Airo TV IPTV player through a direct
GitHub Release download or Homebrew Cask, and release operators who need a
repeatable no-secret dry run plus signed/notarized public path.

**Owning agent:** Release and DevEx Agent. Release branch creation, artifact
packaging, checksums, manifest generation, Homebrew Cask metadata, and
signing/notarization are release-framework responsibilities.

**Impacted modules:** GitHub Actions release workflows, v2 release
orchestrator, build profile metadata, `core_release`, macOS Runner metadata,
Homebrew packaging template, release docs, local macOS build helper, and app
icon assets.

**Decision:** Ship macOS from the existing `tv` profile: `app/lib/main_tv.dart`
with `app/pubspec_tv.yaml`, `APP_VARIANT=tv`, and `APP_PLATFORM=androidTv`.
The `androidTv` platform define is reused because it is the current IPTV-only
TV feature gate. No new product edition or runtime public API is introduced.

## Cross-Agent Contract

**Inputs:** latest `origin/main`, release version/build inputs, optional release
branch, optional Developer ID certificate and notarytool credentials.

**Output shape:** `Airo-TV-<version>-macOS.zip`,
`Airo-TV-<version>-macOS.dmg`, `Airo-TV-<version>-macOS-Release-Manifest.json`,
`SHA256SUMS`, generated `homebrew/airo-tv.rb`, and workflow summary.

**Runtime behavior:** Firebase macOS initialization remains skipped unless real
macOS Firebase options are configured. IPTV playback/import/navigation must
remain pointer-friendly on macOS. Player fullscreen must work from cursor input
by opening the TV player into a full-window route and, on macOS, requesting the
native window fullscreen state. Cast-only behavior must be hidden or no-op on
macOS. The macOS app exposes an in-app `Update` action that checks the latest
GitHub Release and only reports an update when a newer release contains a
macOS ZIP or DMG asset.

**Error handling:** release ref not based on latest `origin/main`, unsupported
profile, macOS build failure, missing signing/notarization secrets when
required, codesign verification failure, notarytool failure, or missing release
assets fail the workflow.

## Use Cases

### UC-001: Dry-run Airo TV macOS artifact build

**Given:** Apple signing secrets are not configured.
**Trigger:** Run `Airo TV macOS Release` with `profile=tv`,
`release_ref=main`, `release_branch=release/airo-tv-v0.0.2`, and
`require_notarization=false`.
**Happy path:** The workflow cuts/updates the release branch, builds
`Airo TV.app`, uploads ZIP/DMG/checksum/manifest/Homebrew Cask artifacts, and
marks the macOS artifacts as `unsigned` and `not_notarized`.
**Failure path:** The workflow fails if the ref is stale, the TV pubspec cannot
resolve, or the macOS build does not produce `Airo TV.app`.

### UC-002: Public notarized Airo TV macOS release

**Given:** Developer ID signing and notarytool secrets are configured.
**Trigger:** Run the macOS release workflow with `require_notarization=true`.
**Happy path:** The workflow signs the app, notarizes and staples it, verifies
with `codesign` and `spctl`, then packages public release assets and generated
Homebrew metadata.
**Failure path:** Missing secrets, codesign failure, notary failure, or failed
`spctl` assessment blocks publication.

### UC-003: V2 orchestrated Airo TV release

**Given:** The `V2 Release Orchestrator` is run with `macos_profile=tv`.
**Trigger:** The orchestrator builds Android TV assets and the macOS Airo TV
assets from the same v2 release inputs.
**Happy path:** GitHub Release assets include Android TV APK/AAB plus macOS
ZIP/DMG/Cask artifacts, all covered by the top-level manifest and `SHA256SUMS`.

### UC-004: Cursor-driven fullscreen playback on macOS

**Given:** A live channel is selected in the Airo TV macOS app.
**Trigger:** The user clicks the player fullscreen control with a mouse or
trackpad.
**Happy path:** The embedded TV player opens a full-window playback route,
shows cursor-accessible playback controls, requests native macOS fullscreen,
and exits native fullscreen when the full-player route is dismissed.
**Failure path:** Missing macOS native channel support is logged as a no-op and
must not crash playback.

### UC-005: In-app macOS update check

**Given:** A user is running the macOS Airo TV app built with
`APP_VERSION=<build_name>`.
**Trigger:** The user clicks `Update` in the Airo TV header.
**Happy path:** The app checks the latest GitHub Release, detects a newer
macOS ZIP/DMG asset, and opens the release page for manual download.
**Failure path:** Android-only releases, missing macOS assets, unreadable
versions, or network failures are shown as no-update/error states without
claiming that a desktop update is available.

## Automation Flows

### AUTO-001: Release contract validation

Run workflow YAML parsing, release manifest generator tests, build profile
validation, `core_release` tests, and `git diff --check`.

### AUTO-002: Local macOS validation

Run `scripts/build-macos-tv.sh` on a macOS host. The script temporarily applies
`app/pubspec_tv.yaml`, builds `lib/main_tv.dart`, restores local pubspec and
generated plugin state, and leaves `Airo TV.app` in the Flutter release output.
Launch the app, select a channel, verify cursor hover/click states, and verify
the player fullscreen control opens the full-window player without a touch or
remote interaction.

### AUTO-003: macOS update check validation

Run targeted tests for `AiroMacosUpdateService` and the TV header. Verify a
newer GitHub Release with `macOS.zip` or `macOS.dmg` is treated as available,
newer non-macOS artifacts are ignored, and the `Update` action is only visible
on macOS.

### AUTO-004: Distribution metadata validation

Generate `SHA256SUMS`, a macOS release manifest with signing/notarization
status, and `homebrew/airo-tv.rb`. Validate the Cask Ruby syntax and ensure the
ZIP and DMG are both covered by checksums.
