# Daily Project Health Monitor: V2 Dependency Patch Refresh

## Critical Agent Gate

**Problem:** The v2 app profiles have safe dependency drift versus the latest resolvable stable releases, which increases lockfile churn and validation variance across full, TV, streaming, and iOS-SPM builds.
**User / actor:** Release and DevEx Agent maintaining build health on the v2 release line.
**Framework or application layer:** Mixed. The application host owns the build profiles, while shared media packages consume the same player dependency surface.
**Owning agent:** Release and DevEx Agent.
**Reviewing agents:** Framework Agent, QA Automation Agent.
**Impacted modules/files:** `app/pubspec.yaml`, `app/pubspec_streaming.yaml`, `app/pubspec_tv.yaml`, `app/pubspec_ios_spm.yaml`, `packages/feature_iptv/pubspec.yaml`, `packages/platform_media/pubspec.yaml`, `packages/platform_streams/pubspec.yaml`, `app/pubspec.lock`.
**Base branch/worktree:** confirmed from latest `origin/v2`: yes (`22eab8a2a44b9354f2571e339b673e86c6b33eef`).
**Open questions:** Major dependency lines still blocked by current toolchain or migration scope (`riverpod` 3.x, `drift` 2.34.x, `custom_lint` 0.8.x). This slice intentionally limits itself to resolvable stable updates with no feature rewrites.
**Decision:** Ready

## Cross-Agent Contract

- Release and DevEx may refresh stable dependency constraints when the resolver confirms compatibility across v2 build profiles.
- Shared media packages may align on the same `video_player` minor line as the app profiles when no public API or storage contract changes are introduced.
- QA validation for this slice is variant profile contract checks, dependency resolution, app analyze, and representative package tests.

## Deterministic Validation Flow

1. Run `scripts/check-build-profiles.py`, `scripts/check-variant-pubspecs.sh`, and `scripts/check-bundled-model-artifacts.sh`.
2. Run `flutter pub get` in the touched workspaces and regenerate `app/pubspec.lock`.
3. Run `flutter analyze --no-fatal-infos --no-fatal-warnings` in `app`.
4. Run a representative package suite for a touched shared package: `cd packages/core_data && flutter test --reporter=compact`.
