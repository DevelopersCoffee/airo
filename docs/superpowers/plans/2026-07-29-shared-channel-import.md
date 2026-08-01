# Shared Channel Import and App-Link Opening — Execution Plan

> **Design:** `docs/superpowers/specs/2026-07-29-shared-channel-import-design.md`
> **Base:** rebased onto `origin/main` at `dc7406d6`
> **Branch:** `agent/airo-tv/shared-channel-import`
> **Scope:** Standard Community Edition feature; no bundled channel catalog.
> **Implementation:** Complete locally; root-domain association deployment and
> physical-device qualification remain release tasks.

## Delivery slices

### 1. Share-safe URL policy

Add typed share validation to `AiroPlaylistUrlPolicy` in
`platform_channels`. Accept only bounded public HTTP(S) URLs without userinfo,
private/local hosts, or credential-like query parameters. Return a reason code
that UI can map to safe copy without returning the rejected URL.

Tests:

- safe public HLS URL
- token/auth/signature/session query keys
- userinfo, LAN/localhost, unsupported scheme
- oversized URL and name
- error string contains no rejected secret

### 2. Personal-channel persistence

Add `PersonalChannelRepository` in `platform_playlist`, backed by the existing
local key-value abstraction:

- `personal_channels.index.v1` contains an ordered bounded fingerprint list
- `personal_channels.record.v1.<sha256>` contains one versioned JSON record
- stable id is `personal:<sha256(normalizedStreamUrl)>`
- upsert deduplicates by normalized stream URL
- remove updates record and index atomically from the caller's perspective
- list tolerates and removes corrupt orphan records
- maximum 100 records

Use a direct `crypto` dependency in `platform_playlist` only after dependency
review. Do not use `String.hashCode` as a persisted identifier.

Tests:

- empty list, create, read, update, remove
- duplicate URL with different display name
- corrupt record/index recovery
- cap reached
- web-compatible store path

### 3. Versioned link intent

Replace the single-shape parser with backward-compatible intents:

- v1/id-only → `ExistingChannelIntent`
- v2/id + name + safe stream → `ImportSharedChannelIntent`
- unknown/invalid → typed rejection

Keep `/iptv`, `airo://iptv`, legacy `/airo/iptv`, and canonical
`/airo/iptv/` parsing. Add canonical serialization tests and enforce bounded
decoded values.

### 4. Merge Personal channels into Airo TV

Expose the repository through Riverpod and merge its records into
`iptvChannelsProvider` after playlist/provider channels. Deduplicate by exact
normalized stream URL and stable personal id. Invalidate search, rails,
favorites, and current deep-link resolution after upsert/remove.

Tests:

- no source + one Personal channel
- playlist duplicate + Personal duplicate
- saved channel resolves on a fresh provider container
- removal clears derived browse/search state

### 5. Import preview and Personal channels UI

Add a responsive import preview in `feature_iptv`:

- no network/playback/write on initial render
- show channel name and source host
- optional bounded HEAD/HLS inspection after explicit validation action or
  as a cancellable preview task
- Save & play, Play once, Cancel
- already-saved state becomes Play + Remove from Personal channels
- offline, timeout, invalid media, persistence failure, and cap-reached states
- `TvFocusable`, semantics, visible focus, and Back/Cancel on ten-foot UI

The 9XM acceptance fixture uses an injected fake inspector returning
**Adaptive stream (up to 1080p)**. Automated tests never depend on the live
third-party URL.

### 6. Native share action

Change ChannelInfoBar Share from clipboard-only behavior to a testable
share gateway:

- **Share playable link** when the URL passes share-safe policy
- **Share channel reference** when it does not
- `ChannelShareMessageComposer` adds a short, inclusive humorous invitation
  around the literal channel name and Airo link
- production rotates only the approved template set; tests inject a fixed
  selector
- Copy link secondary action
- no full URL in diagnostics
- TV stub remains functional and offers QR/copy where native sharing is
  unavailable

Tests:

- every template includes the exact channel name and link
- copy stays within the 180-character pre-URL limit
- one emoji maximum and message remains understandable without it
- unsafe/reference-only share uses the direct non-humorous fallback
- fixed selector makes share-sheet tests deterministic
- screen-reader semantics announce the action as “Share channel”

### 7. App Links, Universal Links, and fallback page

Add:

- Android verified HTTPS filters to both product and TV manifests
- iOS Associated Domains entitlement and project wiring
- `/docs/iptv/index.html` non-playing fallback
- static contract fixtures for both association documents
- deployment instructions for the organization Pages root

Release engineering must fill the real Android release certificate
fingerprints. Do not commit guessed fingerprints.

Hard gate: do not mark app-link acceptance complete until the association
files return HTTP 200 from the domain root and physical devices open Airo.

### 8. Focused validation

Run the narrowest checks after each slice:

1. format changed Dart files
2. `platform_channels` tests
3. `platform_playlist` tests
4. focused `feature_iptv` intent/provider/widget tests
5. focused app route tests
6. `flutter analyze` for touched packages
7. `git diff --check`
8. static link/fallback checks

Then qualify the same release-signed link on Pixel 9, iPad Air 4, and Fire TV
Stick 4K. Record whether Fire TV supports direct app-link dispatch or uses the
documented browser fallback.

## File map

Expected additions/changes:

- `packages/platform_channels/lib/src/security/playlist_url_policy.dart`
- `packages/platform_channels/test/security/playlist_url_policy_test.dart`
- `packages/platform_playlist/lib/src/persistence/personal_channel_repository.dart`
- `packages/platform_playlist/lib/platform_playlist.dart`
- `packages/platform_playlist/pubspec.yaml`
- `packages/platform_playlist/test/personal_channel_repository_test.dart`
- `packages/feature_iptv/lib/application/iptv_deep_link.dart`
- `packages/feature_iptv/lib/application/channel_share_message_composer.dart`
- `packages/feature_iptv/lib/application/providers/iptv_providers.dart`
- `packages/feature_iptv/lib/application/providers/personal_channel_providers.dart`
- `packages/feature_iptv/lib/presentation/screens/shared_channel_import_screen.dart`
- `packages/feature_iptv/lib/presentation/tv_ux/sections/channel_info_bar.dart`
- focused tests under `packages/feature_iptv/test/`
- `app/lib/features/iptv/iptv_feature_module.dart`
- `app/android/app/src/main/AndroidManifest.xml`
- `app/android/app/src/tv/AndroidManifest.xml`
- `app/ios/Runner/Airo.entitlements`
- `app/ios/Runner.xcodeproj/project.pbxproj`
- `docs/iptv/index.html`
- root-domain association deployment documentation/fixtures

## Review gates

1. Product Manager: standard feature, BYOC positioning, success metric.
2. Media Intelligence Architect: descriptor, dedupe, and provider merge.
3. Platform Architect + Chief Architect: app-link and persistence boundaries.
4. Chief Security Officer: URL redaction and association files.
5. Chief UX Officer: preview, consent, D-pad, and accessibility.
6. Chief QA Officer: deterministic and physical-device flows.
7. Chief Documentation + Release/DevOps: fallback deployment and signing
   fingerprints.

## Definition of done

- A sender can share a safe Airo channel link through the native share sheet.
- The share text includes the channel name, Airo link, and one approved
  friendly message; sensitive/reference-only sharing remains direct.
- A recipient can open, preview, play once, or locally save the channel.
- Repeated import never duplicates the channel.
- 9XM works as a user-imported adaptive stream and exposes the current 1080p
  variant without being bundled in Airo.
- Installed-app links work on qualified phone/tablet devices; browser fallback
  returns 200 when the app is absent.
- Unsafe URLs never become portable share links and never leak through logs.
- Every acceptance behavior has host-only automated proof; platform dispatch
  has named physical-device evidence.
