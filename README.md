# Airo

[![Download APK](https://img.shields.io/github/v/release/DevelopersCoffee/airo?label=Download%20APK&color=success)](https://github.com/DevelopersCoffee/airo/releases/latest/download/app-release.apk)
[![GitHub Release](https://img.shields.io/github/v/release/DevelopersCoffee/airo)](https://github.com/DevelopersCoffee/airo/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.44.4+-blue.svg)](https://flutter.dev/)
[![License: pending](https://img.shields.io/badge/license-pending-lightgrey)](#license)

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

## Download

### Android

[Download latest APK](https://github.com/DevelopersCoffee/airo/releases/latest/download/app-release.apk)

### iOS

[Download latest IPA](https://github.com/DevelopersCoffee/airo/releases/latest/download/app-release.ipa)

### Web

[Download web build](https://github.com/DevelopersCoffee/airo/releases/latest/download/airo-web-release.zip)

### All Platforms

[View all releases](https://github.com/DevelopersCoffee/airo/releases)

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
4. Create a short-lived branch or worktree from the latest `origin/main`.
5. Keep the PR scoped, run the relevant checks, and document any test gaps.

For parallel work, prefer a worktree:

```bash
git fetch origin main
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
- [Agent policy](docs/agents/AGENT_POLICY.md)

## License

The repository currently has public docs that reference MIT licensing, but the
root `LICENSE` file is not present and package license files still need maintainer
confirmation. Treat the license as **pending** until maintainers add the confirmed
root license file.

If you plan to reuse code outside this repository, wait for the license cleanup or
ask in a GitHub issue first.
