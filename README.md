# Airo

[![Download Airo TV](https://img.shields.io/badge/Download-Airo%20TV-success)](https://github.com/DevelopersCoffee/airo/releases/download/airo-tv-v0.0.2/Airo-TV-v0.0.2.apk)
[![GitHub Release](https://img.shields.io/github/v/release/DevelopersCoffee/airo)](https://github.com/DevelopersCoffee/airo/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.44.4+-blue.svg)](https://flutter.dev/)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Security Policy](https://img.shields.io/badge/security-policy-brightgreen)](SECURITY.md)
[![Trust](https://img.shields.io/badge/trust-transparent-brightgreen)](TRUST.md)
[![Versioning](https://img.shields.io/badge/versioning-semver-blue)](CHANGELOG.md)
[![Android TV](https://img.shields.io/badge/Android%20TV-compatible-green)](docs/release/AIRO_TV_v0.0.2.md)

Airo is a Flutter super app for local-first AI workflows: chat, model management,
routine packs, media surfaces, and personal finance modules in one modular mobile
codebase.

The project is being shaped as an open-source playground for developers who care
about on-device AI, agent skills, privacy-aware product design, and cross-platform
Flutter architecture.

## Why Star Or Fork This Repo

- **Build local-first AI UX**: help make model routing, offline fallback, and
  privacy-forward AI interactions usable in a real app.
- **Work across the stack**: Flutter UI, Android/iOS platform bridges, package
  boundaries, CI, docs, release automation, and QA flows all live here.
- **Contribute in small slices**: docs fixes, onboarding polish, tests, issue
  reproduction, UI states, model metadata, and DevEx improvements are all useful.
- **Learn agent-driven engineering**: every non-trivial change follows the
  ownership, contract, and deterministic automation flow in
  [`docs/agents/AGENT_POLICY.md`](docs/agents/AGENT_POLICY.md).

If this direction is useful to you, star the repo to follow the work. Fork it
when you want to run experiments or send a PR.

## What You Can Work On

Good open-source entry points:

- Improve first-run setup and troubleshooting docs.
- Add or harden host-only tests for existing features.
- Reproduce and minimize open bugs.
- Improve accessibility, empty states, and responsive layout behavior.
- Document model support, privacy behavior, and release checks.
- Turn repeated setup or review steps into scripts.

Start with:

- [Issues labeled `good first issue`](https://github.com/DevelopersCoffee/airo/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22)
- [Issues labeled `help wanted`](https://github.com/DevelopersCoffee/airo/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22)
- [Contributor guide](CONTRIBUTING.md)
- [Open-source growth playbook](docs/community/GITHUB_GROWTH_PLAYBOOK.md)


## Airo TV v0.0.2

Airo TV is the Android TV variant of Airo, built from the current `main` release line (formerly `v2`) with package name `io.airo.app.tv`. The v0.0.2 release focuses on release trust, documentation, checksums, clean artifact names, and Play Store readiness.

- Bring your own authorized M3U playlist URL; Airo TV does not provide IPTV content.
- Release assets include APK, Play Store AAB, and SHA256 checksums.
- Documentation covers privacy, security, threat model, roadmap, architecture, feature matrix, and reproducible builds.
- Google Cast requires receiver discovery over `_googlecast._tcp` and port `8009` reachability on the local network.
- Release artifacts are published at https://github.com/DevelopersCoffee/airo/releases/tag/airo-tv-v0.0.2.

## V2 Release Health

The current mainline Airo TV release line is coordinated through
[`.github/workflows/v2-release-orchestrator.yml`](.github/workflows/v2-release-orchestrator.yml)
and documented in
[`docs/release/V2_RELEASE_ORCHESTRATOR.md`](docs/release/V2_RELEASE_ORCHESTRATOR.md).
Public-release setup, maintainer decisions, and local evidence gates are tracked
in
[`docs/release/V2_PUBLISHING_HUMAN_SETUP.md`](docs/release/V2_PUBLISHING_HUMAN_SETUP.md),
[`docs/release/V2_HUMAN_IN_LOOP_BLOCKERS.md`](docs/release/V2_HUMAN_IN_LOOP_BLOCKERS.md),
[`docs/release/REPOSITORY_HEALTH_STATUS.md`](docs/release/REPOSITORY_HEALTH_STATUS.md),
and [`docs/release/RELEASE_CHECKLIST.md`](docs/release/RELEASE_CHECKLIST.md).
Security and community process files live in [`SECURITY.md`](SECURITY.md),
[`CONTRIBUTING.md`](CONTRIBUTING.md), and
[`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).

## Why Trust Airo?

- Open source codebase with public issue tracking.
- No bundled IPTV channels or copyrighted content.
- User playlists remain on the device unless users load a remote playlist URL directly.
- Release APK and AAB assets publish SHA256 checksums.
- Transparent roadmap, changelog, security policy, privacy policy, and threat model.
- No hidden subscriptions or mandatory accounts for the Airo TV player flow.

## Download

### Android

[View Android releases](https://github.com/DevelopersCoffee/airo/releases)

### Airo TV

[Download Airo TV APK](https://github.com/DevelopersCoffee/airo/releases/download/airo-tv-v0.0.2/Airo-TV-v0.0.2.apk)

### iOS

[Download latest IPA](https://github.com/DevelopersCoffee/airo/releases/latest/download/app-release.ipa)

### Web

[Download web build](https://github.com/DevelopersCoffee/airo/releases/latest/download/airo-web-release.zip)

### All Platforms

[View all releases](https://github.com/DevelopersCoffee/airo/releases)

Before installing a direct-download APK, verify it with
[`SHA256SUMS`](VERIFY_DOWNLOAD.md).

## Quick Start

### First-Time Setup

```bash
git clone git@github.com:DevelopersCoffee/airo.git
cd airo
make setup
```

Platform-specific setup:

```bash
make setup-android
make setup-ios
make setup-web
```

### Run The App

```bash
make run-android
make run-ios
make run-web
make run-chrome
```

Device-targeted helpers:

```bash
make run-pixel9
make run-iphone13
```

### Airo TV Edge Intelligence

The IPTV feature consumes `slm_edge_intelligence` from the public
`DevelopersCoffee/barista-tuning` Git package. By default it uses the public
rule backend:

```bash
flutter run -t lib/main_airo_iptv.dart
```

To use the Rust FFI pack-backed runtime, bundle the native `edge-ffi` artifact
with the app and pass the media pack path by configuration:

```bash
flutter run -t lib/main_airo_iptv.dart \
  --dart-define=AIRO_EDGE_INTELLIGENCE_BACKEND=native \
  --dart-define=AIRO_MEDIA_PACK=/absolute/path/to/media.pack
```

For device builds where the pack is bundled as a Flutter asset, place it under
`app/assets/packs/` and pass the asset key instead:

```bash
flutter run -t lib/main_airo_iptv.dart \
  --dart-define=AIRO_EDGE_INTELLIGENCE_BACKEND=native \
  --dart-define=AIRO_MEDIA_PACK_ASSET=assets/packs/media.pack
```

The Flutter screen still only submits natural-language media requests and plays
the returned stream URI; pack installation and backend selection stay behind the
feature package provider layer.

Android TV builds must include `libedge_ffi.so` under
`app/android/app/src/main/jniLibs/<abi>/`. From the Edge Intelligence repo:

```bash
slm package-edge-ffi-android \
  --airo-app /absolute/path/to/airo/app \
  --build \
  --abi arm64-v8a
```

### Verify Changes

```bash
make format
make analyze
make test
```

Run `make help` to see the full command list.

## Platform Support

- **Android**: API 24+ with Pixel 9 helper targets.
- **iOS**: iOS 12.0+ with iPhone 13 Pro Max helper targets.
- **Web**: modern browsers, with Chrome as the preferred development target.

Android release builds require private signing material. Never commit
`app/android/key.properties`, keystores, tokens, API keys, or local credentials.

## Repository Map

```text
.
├── app/                  # Flutter host application
├── packages/
│   ├── airo/             # AI-oriented package surface
│   ├── airomoney/        # Personal finance package surface
│   ├── core_ai/          # AI contracts, registries, skills, model metadata
│   ├── core_auth/        # Authentication package
│   ├── core_data/        # Data and networking utilities
│   ├── core_domain/      # Domain primitives
│   └── core_ui/          # Shared UI package
├── docs/                 # Architecture, agent policy, wiki source, runbooks
├── e2e/                  # End-to-end assets and checks
├── scripts/              # Local automation
└── .github/              # CI, issue templates, PR template
```

## Contributor Workflow

1. Read [`CONTRIBUTING.md`](CONTRIBUTING.md).
2. Pick or create a GitHub issue.
3. Add the Critical Agent gate and Feature Packet required by
   [`docs/agents/AGENT_POLICY.md`](docs/agents/AGENT_POLICY.md).
4. Create a short-lived branch or worktree from the correct release-line base.
   Use `origin/main` for current work. Only use `origin/v1_bkp` when the
   linked issue explicitly targets the legacy pre-swap branch state.
5. Keep the PR scoped, run the relevant checks, and document any test gaps.

For parallel work, prefer a worktree:

```bash
git fetch origin main v1_bkp
git worktree add -b codex/my-task ../airo-my-task origin/main
cd ../airo-my-task
```

## Documentation

- [GitHub wiki source](docs/wiki/README.md)
- [Architecture docs](docs/architecture/README.md)
- [Feature docs](docs/features/README.md)
- [Security and code quality docs](docs/security/README.md)
- [Release docs](docs/release/README.md)
- [Troubleshooting docs](docs/troubleshooting/README.md)

## Community Standards

- [Contributing guide](CONTRIBUTING.md)
- [Code of conduct](CODE_OF_CONDUCT.md)
- [Security policy](SECURITY.md)
- [Trust and transparency](TRUST.md)
- [Download verification](VERIFY_DOWNLOAD.md)
- [Privacy policy](PRIVACY.md)
- [Roadmap](ROADMAP.md)
- [Changelog](CHANGELOG.md)
- [Airo TV threat model](docs/security/AIRO_TV_THREAT_MODEL.md)
- [Airo TV architecture](docs/architecture/AIRO_TV_ARCHITECTURE.md)
- [Agent policy](docs/agents/AGENT_POLICY.md)

## License

Airo is licensed under the [MIT License](LICENSE).

V2 release profiles also include third-party dependencies with their own
licenses. See [V2 Third-Party Notices](docs/release/V2_THIRD_PARTY_NOTICES.md)
and [V2 License Review](docs/release/V2_LICENSE_REVIEW.md) before public
redistribution.
