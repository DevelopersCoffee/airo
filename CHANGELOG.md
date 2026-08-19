# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html) for public release tags.

## v0.0.7-preview — unreleased

Preview cut of the `0.0.7` line across Airo TV, the full app, Airo Coins, and
macOS TV. Prepared notes: [docs/release/AIRO_v0.0.7-preview.md](docs/release/AIRO_v0.0.7-preview.md).
Not tagged until Rust Core CI is green on the freeze SHA.

### Added

- Unified live playlist merge across M3U, Xtream, and Stalker sources.
- Coins embeddings auto-categorization, recurrence/anomaly detection, and
  `DraftConfirmCard`.
- Meeting IR / MoM / speaker enrollment land in the full app behind
  Under-qualification copy. No standalone Mind APK.

### Fixed

- Airo TV BACK on the channel-browse grid after playback (#1430).
- Rust Core CI no longer links `airo_mind_cli` into Linux workspace
  `--workspace` jobs (whisper.cpp / llama.cpp ggml duplicate symbols).

### Known issues

- #1240 Airo Coins can open to a persistent black screen on Pixel 9 / Android 17.
- #1243 Fire TV live playback emits repeated vendor property-denial log errors.
- #1023 macOS mini-player Watch does not open fullscreen.

## v0.0.6 — 2026-08-04

Stable cut of the `0.0.6` line across Airo TV, the full app, Airo Coins, and
macOS TV. Full notes: [docs/release/AIRO_v0.0.6.md](docs/release/AIRO_v0.0.6.md).

### Added

- Airo Coins is a first-class release-orchestrator leg (`coins_profile`), so the
  TV, full, Coins, and macOS artifacts all ship from one reproducible wave
  instead of a hand-published Coins upload.
- Offline Meeting Intelligence MVP — record, transcribe, summarise, search.
- Airo Mind Vault phase 1 and the `MindRuntime` port frozen into eight sub-ports.
- Copyable device-capability, runtime-health, and model-advisor diagnostics, plus
  chat transcript export.
- Portable shared channel imports for Airo TV.

### Fixed

- Fire TV D-pad focus and BACK paths restored after the #1244 regression.
- TV shell held inside both horizontal and vertical title-safe bands.
- Chess moves are applied instead of silently rejected.
- Playlist source removal is consistent; local media IDs are web-safe.
- Model download queue position, stalled-download recovery, and setup-failure
  detail.

### Known issues

- #1240 Airo Coins can open to a persistent black screen on Pixel 9 / Android 17.
- #1430 Airo TV BACK intermittently swallowed on the channel-browse grid.
- #1243 Fire TV live playback emits repeated vendor property-denial log errors.

### Also in this line, since v0.0.6-rc.1

#### Added

- Direct, permission-scoped USB/removable-media browsing on Android TV without
  converting local files into playlists, including deterministic sidecar
  subtitle association.
- Runtime-backed Xtream live/EPG/VOD and Stalker live source loading, with an
  explicit active-source selector and credential-safe failures.
- Reproducible Play Store screenshot capture and RGB/size validation from the
  live Flutter web runtime, plus an original text-free feature graphic.
- Production Android signing setup, release provenance attestations, and
  repository license/notices preflight coverage.

#### Changed

- The version line is promoted from `0.0.6-rc.1` to `0.0.6` across
  `pubspec.yaml`, `pubspec_tv.yaml`, and `pubspec_coins.yaml`, all at build
  `+10`.
- TV first-run setup offers URL, expiring phone QR, and USB only when the
  corresponding platform capability is real.
- TV rail traversal now has a deterministic leading-edge focus bridge from
  Search, Name sort, and the first channel.

#### Fixed

- Coins uses one launcher activity and validates the resolved component before
  artifact smoke tests, preventing the Pixel 9 black-screen launch path.
- Player error, loading, buffering, and controls overlays are mutually
  exclusive; desktop/macOS hover and fullscreen mini-player transitions are
  deterministic.
- Fire TV playback log capture is process-scoped, bounded, classified, and
  redacts stream URLs.
- Generated Pigeon/build-runner outputs and model warmup/activation boundaries
  compile and carry focused test coverage.

#### Qualification status

- Automated source, player, TV navigation, legal, provenance, native-media,
  screenshot, and artifact checks run in CI on every release wave.
- Pixel 9, Fire TV Stick, and iPad physical-device sign-off was not repeated for
  this cut; the known issues above are the outstanding device-verified defects.

## [Airo v0.0.6-rc.1] - 2026-07-30

Preview (release-candidate) cut for direct download / APKPure across the Android
TV, full-app, and macOS TV profiles. Store submission, iOS/iPadOS, and macOS
notarization are out of scope. See
[docs/release/AIRO_v0.0.6-rc.1.md](docs/release/AIRO_v0.0.6-rc.1.md).

### Added

- Apple picture-in-picture wiring and player-layer lifecycle in
  `platform_player`.
- EPG programme-enrichment metadata contract and a programme-details dialog.
- IPTV source-management extension seam and a source-diagnostics entitlement.
- Airo Coins (`io.airo.app.coins`) promoted into the CI build matrix for
  package-size and architecture qualification (25 MiB budget). Qualification
  only — not a published artifact in this release.

### Changed

- Agent chat prefers an installed Gemma model when present.
- Bootstrap accepts provider overrides.
- CI hardening: deterministic cross-platform validation, safe partial
  APK-size-baseline merges, and the physical-device rig as the default run path.

### Known Issues

- Preview APKs signed without a stable dogfood keystore use an ephemeral CI
  cert and will not upgrade over a prior build.
- Fire TV D-pad focus regressions from #1244 remain open (#1272).

## [Airo TV v0.0.5] - 2026-07-22

### Added

- First-run country selection and a Settings path for changing the country
  filter after onboarding.
- TV Explorer-inspired browse controls for search, category, country, and
  language filtering, including clearer country labels and deduplicated
  category values.
- Bounded visible-channel health warmup and adaptive nearby-channel warming so
  channel switching can avoid known-unavailable streams without scanning the
  full playlist on the UI path.

### Changed

- Airo TV is the focused IPTV product surface. Obsolete Airo Streaming and Airo
  IPTV product-target wiring was removed from build profiles, package IDs,
  Firebase/preflight expectations, scripts, and release documentation.
- Compact phone/tablet and fullscreen player controls now keep a single Airo TV
  overlay layer instead of falling back to mixed legacy/native overlay buttons.
- Channel rows prioritize channel and category space, move country to a compact
  flag/metadata position, and keep list scrolling virtualized for large
  playlists.

### Fixed

- Restored Settings entry points for theme and playback/PiP preferences.
- Corrected player lock/unlock behavior and fullscreen escape affordances.
- Fixed no-op player actions by either wiring supported controls or removing
  unsupported affordances from the active Airo TV product surface.

### Known limitations

- Airo TV remains BYOC: it does not bundle playlists, channels, subscriptions,
  or media content.
- Production signing, Play upload, Firebase distribution, and macOS
  notarization require maintainer-owned credentials.
- Fire TV and legacy Android TV support remain compatible/experimental until
  dedicated physical-device evidence is attached.

## [Airo TV v0.0.4] - 2026-07-22

### Added

- Local, deterministic search across imported channels and available guide data, including live TV search results.
- Smart-playlist rules and persistent canonical channel identities to keep personal lists resilient across re-imports.
- A bring-your-own XMLTV source flow, guide timeline improvements, favorites, captions, VOD resume/seek, and provider add-flows for Xtream, Stalker, and Jellyfin.
- Aggregate M3U import counters for parsed, skipped, malformed, and elapsed values, processed through the existing Rust/worker parser boundary.

### Changed

- Airo TV uses a virtualized, paged playlist path for large user-provided playlists and a unified browse experience across TV and compact layouts.
- Playback diagnostics and bounded retries now explain unavailable streams more clearly while keeping playlist credentials out of diagnostics.

### Fixed

- A channel is added to Recently Watched only after playback starts.
- Favorites are discoverable from browse cards and the player, and the Guide's source action leads to a working XMLTV setup flow.
- System picture-in-picture renders a video-only surface and restores the full interface when it closes.

### Known limitations

- Airo TV remains BYOC: it does not bundle playlists, channels, subscriptions, or media content.
- Android TV/Google TV artifact verification is recorded with the release; Fire TV remains compatible/experimental pending dedicated device evidence.
- Phone-hosted media streaming and its real-device receiver matrix remain under qualification.
- macOS artifacts are unsigned and not notarized; they are release evidence, not a notarized macOS distribution.
- Production Android signing and Firebase runtime secrets are not configured;
  the release manifest discloses the non-production signing profile for each
  direct-install artifact.

## [Airo TV v0.0.4-rc.3] - 2026-07-19

### Added

- Favorite marking: long-press any browse card to add/remove a favorite, with snackbar feedback (#935).
- "Recently Watched" browse rail, recency-ordered, hidden until there is watch history (#934).
- "Entertainment" and "Music" browse rails so every former category chip is represented as a card rail (#936).
- Search sheet now lists matching channels live as you type; tapping a result plays it. Keyboard submit applies the filter instead of auto-playing the single match (#928).

### Changed

- Top category chip row (All/News/Sports/Entertainment/Music) removed from the mobile IPTV screen; category browsing lives in the rails (#936).
- Mobile IPTV app bar title rebranded from "Stream" to "Airo TV" (#931).
- Phone-sized TV builds now open the mobile settings hub (theme picker, audio/playback links) instead of the clipped two-pane TV settings screen (#933).

### Fixed

- Casting regression on phones running the TV build: `realIptvCastControllerOverride()` restored in the TV entrypoint — compact layouts render the mobile IPTV screen whose cast UI silently no-oped against the unavailable-controller fallback (#926).
- EPG guide timeline always appeared to start at 11 AM in IST: the time ruler formatted UTC directly; ticks now convert to local time (#929).
- Display slept during playback: wakelock ownership moved from `VideoPlayerWidget` (disposed when the featured player scrolls off-screen or playback continues under the mini player) to a screen-scoped, debounced `WakelockPlaybackCoordinator` (#930).
- Favorite toggle silently no-oped on every second toggle of the same channel: cached `FutureProvider.family` replaced with a plain callable provider (#935).

### Known issues

- Deferred to next cycle: portrait/landscape floating player-control inconsistency, idle featured-player placeholder (should use full asset area), picture-in-picture, playlist management.
- Casting and wakelock fixes are test-verified; on-device Pixel 9 dogfood pending this RC.
- Two pre-existing `firebase_options_test.dart` failures in `test-app` remain tracked from rc.2 (the settings hub sheet-title failure was fixed in #932).

## [Airo TV v0.0.4-rc.2] - 2026-07-19

### Added

- Unified Netflix-style browse experience across phone/tablet/TV/desktop.
- CV-017 canonical channel identity matching (Drift/SQLite) plus favorite reimport review banners (mobile + TV).
- TV player gesture gating: touch-only affordances (swipe-channel, tap gestures) now hidden on TV builds.

### Changed

- Removed dead cast controller override from TV entrypoint; unused `AdaptiveIptvUI` and `ImportPipeline` deleted (zero consumers).
- `AiroRail.railHeight` now derives from `MediaCardVariant` instead of a hardcoded value.
- Airo TV pubspec bumped to `0.0.4-rc.2+5`.

### Fixed

- `sqlite3_flutter_libs` version conflict between `airo_app` and `platform_playlist` that broke `pub get` repo-wide (lint/analyze/snyk/variant-dependencies CI jobs). App no longer pins its own version; `platform_playlist` owns the constraint and its `sqlite3` core-package range was widened to admit the 3.x line `drift_dev` needs.
- Five files committed with incorrect `dart format` output, failing the CI format-check step.
- `feature_iptv` EPG compact-view test (`renders compact current EPG from platform repository`) failed at the default test viewport because the hero+rails layout left the EPG-aware channel grid/list no room to lazily build any items — not a rendering bug, just insufficient test viewport height. Fixed by giving that test a taller surface.

### Known issues

- Three pre-existing `test-app` failures, unmasked by the sqlite3 dependency fix above (this job was `skipped` on every recent CI run because earlier jobs failed first, so these were never actually exercised until now): `firebase_options_test.dart` (`marks real Firebase app ids as configured`, `uses the registered Android TV Firebase app id`) and `settings_hub_screen_test.dart` (`tapping Playlist Source opens the playlist source sheet`). Not caused by this release's changes — tracked for follow-up.

## [Airo TV v0.0.4-rc.1] - 2026-07-19

### Added

- Structured playback diagnostics taxonomy with bounded retry state machine and in-player diagnostic surface (CV-001).
- Provider health tracker wired to Xtream/Stalker/Jellyfin adapters, with add-flow UI in provider management (CV-012, CV-032).
- Local IPTV search index over channels + EPG, live-provider wiring, and TV search results panel (CV-006).
- Persisted caption preference (CV-008) and external-subtitle track catalog projection (CV-016).
- VOD seek bar with drag-to-seek (CV-016).
- Hidden-groups favorites storage and wiring into local search (CV-021).
- Smart playlist rule model + evaluator (CV-017 slice 1).
- Phone-hosted LAN media streaming debug entry point for storage-limited receivers (CV-033).
- Airo TV design-system revamp: spacing rhythm, typography hierarchy, theme picker.
- Release device-qualification workflow and release-artifact smoke tests.

### Changed

- `feature_iptv` playback now routed through `AiroPlaybackEngine` (CV-016/CV-031).
- TV source management screen polish and cleanup (CV-022-nit).
- Airo TV pubspec bumped to `0.0.4-rc.1+4`.

### Fixed

- Phone-media LAN server no longer torn down while the receiver is paused.

## [Airo TV v0.0.2] - 2026-07-14

### Added

- Professional Airo TV release-note template.
- SHA256 checksum publishing for Airo TV release assets.
- Privacy policy, threat model, roadmap, architecture overview, feature matrix, and media asset checklist.
- README trust section for Airo and Airo TV.

### Changed

- Airo TV release assets use clean user-facing names.
- Airo TV release notes now follow a mature open-source format.
- Airo TV version updated to `0.0.2+2`.

### Fixed

- Broken or misleading Airo TV download links that pointed to generic release assets.

## [Airo TV v0.0.1] - 2026-07-14

### Added

- Initial Airo TV release from the v2 release line.
- Android TV package `io.airo.app.tv`.
- IPTV playlist import, search, playback, Cast controls, and Play Store readiness notes.

[Airo TV v0.0.5]: https://github.com/DevelopersCoffee/airo/compare/airo-tv-v0.0.4...airo-tv-v0.0.5
[Airo TV v0.0.4]: https://github.com/DevelopersCoffee/airo/compare/airo-tv-v0.0.3...airo-tv-v0.0.4
[Airo TV v0.0.4-rc.1]: https://github.com/DevelopersCoffee/airo/compare/airo-tv-v0.0.3...airo-tv-v0.0.4-rc.1
[Airo TV v0.0.2]: https://github.com/DevelopersCoffee/airo/compare/airo-tv-v0.0.1...airo-tv-v0.0.2
[Airo TV v0.0.1]: https://github.com/DevelopersCoffee/airo/releases/tag/airo-tv-v0.0.1
