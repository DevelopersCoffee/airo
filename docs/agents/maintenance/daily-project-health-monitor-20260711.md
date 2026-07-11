## Critical Agent Gate

**Problem:** Several direct dependencies are pinned below the latest resolvable stable versions, increasing maintenance drag without delivering compatibility benefits.
**User / actor:** Release and DevEx Agent maintaining repository health.
**Framework or application layer:** Mixed. Framework packages (`packages/core_*`) and application host (`app`) both consume the affected libraries.
**Owning agent:** Release and DevEx Agent.
**Reviewing agents:** Framework Agent, QA Automation Agent.
**Impacted modules/files:** `app/pubspec.yaml`, `packages/core_ai/pubspec.yaml`, `packages/core_auth/pubspec.yaml`, `packages/core_data/pubspec.yaml`, `packages/core_domain/pubspec.yaml`.
**Base branch/worktree:** confirmed from latest `origin/main`: yes (`c7cdf7dd90b697ed61bdf0fb0bb5fec9633b1f81`).
**Open questions:** `meta` must remain at `^1.18.0` in framework packages while `flutter_test` from Flutter `3.44.4` pins that SDK constraint.
**Decision:** Ready

## Cross-Agent Contract

- Framework packages may refresh stable dependency constraints when no public contract or storage schema changes are introduced.
- Application package may refresh stable dependency constraints when the resolver reports compatibility without requiring feature rewrites.
- QA validation for this slice is dependency resolution plus serial analyzer/test checks on the touched surface.

## Deterministic Validation Flow

1. Run `flutter pub get` in the touched packages and app.
2. Run `flutter analyze --no-fatal-infos --no-fatal-warnings` in `app`.
3. Run representative package tests serially for touched framework packages.
4. Record any validation gaps or long-running failures if the local toolchain cannot complete within the automation window.
