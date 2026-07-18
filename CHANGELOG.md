# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html) for public release tags.

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

[Airo TV v0.0.4-rc.1]: https://github.com/DevelopersCoffee/airo/compare/airo-tv-v0.0.3...airo-tv-v0.0.4-rc.1
[Airo TV v0.0.2]: https://github.com/DevelopersCoffee/airo/compare/airo-tv-v0.0.1...airo-tv-v0.0.2
[Airo TV v0.0.1]: https://github.com/DevelopersCoffee/airo/releases/tag/airo-tv-v0.0.1
