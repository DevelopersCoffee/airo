---
name: release-qualification-checks
description: Guidelines and topological execution order for running local release qualification, preflight checks, and merge-readiness tests to avoid expensive remote CI runs.
---

# Release Qualification Checks

This skill guides agents in running local validation checks, release preflights, and merge-readiness tests for the Airo/Airo TV release pipelines. Following these steps locally prevents unnecessary remote CI usage and protects the repository's GitHub Actions monthly minute quota.

## Independent Release Lifecycles & Target Products

The repository contains multiple components and applications that can be qualified and released under separate, independent release lifecycles:

1. **Platform**: Reusable shared frameworks, contracts, database schemas, native Rust core bridges, and worker isolates. These form the base dependencies and can have separate version tags.
2. **Airo (Mobile/Tablet)**: Standard mobile streaming/IPTV application profiles (`iptv-standalone`, `mobile-streaming`), targeting phone and tablet form factors.
3. **Airo TV**: Large-screen television player applications targeting Android TV, Google TV, Fire TV, and macOS under the `tv` profile.
4. **Airo Pro**: Premium/proprietary capabilities, subject to specific disclosure policies and modular bootstappers (e.g. `airo_pro_bootstrap`).

Always target the specific product/lifecycle scope when validating release qualification and executing preflight scripts.

## Topological Execution Order

To validate release readiness iteratively, execute qualification checks from lowest-level structural checks up to integration and preflight checks:

### 1. Component & Configuration Checks
Run the following scripts from the repository root directory:
- **Build Profiles Check**:
  ```bash
  scripts/test-check-build-profiles.sh
  scripts/check-build-profiles.py
  ```
- **Bundled Model Artifacts Check**:
  ```bash
  scripts/test-check-bundled-model-artifacts.sh
  scripts/check-bundled-model-artifacts.sh
  ```
- **Module Manifests Check**:
  ```bash
  scripts/test-check-module-manifests.sh
  python3 scripts/check-module-manifests.py
  ```
- **Module Sizes Check**:
  ```bash
  scripts/test-check-module-sizes.sh
  scripts/check-module-sizes.sh
  ```
- **Worker Offload Policy Check**:
  ```bash
  scripts/test-check-worker-offload-policy.sh
  scripts/check-worker-offload-policy.sh
  ```
- **Release Manifest Generation Check**:
  ```bash
  scripts/test-generate-release-manifest.sh
  ```
- **Release Qualification Report Check**:
  ```bash
  scripts/test-generate-release-qualification-report.sh
  ```

### 2. Package-Level Unit Tests
Run the unit test suite for the release management logic:
- **Core Release Package Tests**:
  ```bash
  cd packages/core_release
  flutter test
  ```

### 3. Integration & Merge Readiness Checks
Verify the mainline dry-merge posture and overall gate status:
- **V2 Merge-Readiness dry run**:
  ```bash
  scripts/test-check-v2-merge-readiness.sh
  ```
- **Manual Mainline dry-run**:
  ```bash
  scripts/check-v2-merge-readiness.sh --skip-fetch --base HEAD --next HEAD
  ```

---

## Release Preflight Tools

The `packages/core_release` package provides dedicated tools to verify signing and store credentials locally. These can be executed individually:

| Script / Target | Description | Local Command |
| --- | --- | --- |
| `release:fastlane-preflight` | Redacted Fastlane credential check | `dart run tool/preflight_fastlane_credentials.dart` |
| `release:content-rating-preflight` | Content-rating questionnaire posture | `dart run tool/preflight_content_rating.dart` |
| `release:data-safety-preflight` | Data Safety and App Privacy check | `dart run tool/preflight_data_safety.dart` |
| `release:firebase-android-preflight` | Firebase Android client coverage check | `dart run tool/preflight_firebase_android_clients.dart` |
| `release:firebase-distribution-preflight` | Firebase App Distribution setup | `dart run tool/preflight_firebase_distribution.dart` |
| `release:android-signing-preflight` | Android release signing check | `dart run tool/preflight_android_signing.dart` |
| `release:legal-preflight` | Legal and provenance checks | `dart run tool/preflight_legal_release.dart` |
| `release:repo-health-preflight` | Repository health and discussions check | `dart run tool/preflight_repository_health.dart` |
| `release:macos-signing-preflight` | macOS signing and notarization check | `dart run tool/preflight_macos_signing.dart` |
| `release:v2-readiness-preflight` | Top-level V2 public readiness report | `dart run tool/preflight_v2_release_readiness.dart` |

---

## CI Cost Control Policy

> [!IMPORTANT]
> GitHub Actions minutes are a shared, limited resource. Unnecessary workflows or try-and-error remote runs must be avoided.

1. **Local-First Validation**: Ensure all above checks and unit tests are fully green locally before pushing.
2. **Commit Hygiene**: Use `[skip ci]` in commit messages for intermediate iterations, documentation-only changes, or draft updates.
3. **No Direct Main Push**: Do not push main-line tags or merge branches directly to remote without first performing the local dry-merge check via `check-v2-merge-readiness.sh`.
