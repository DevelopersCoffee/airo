# Issue 1320 — Source-management composition seam

## Objective

Add a narrow, additive extension contract to the public TV source-management
surface so product compositions can contribute per-source row actions and
replace the section widget without copying the baseline implementation.

## Ownership

- Primary: Framework Agent (`feature_iptv` UI contract)
- Review: Airo TV Application Agent, QA Automation Agent
- Layer: framework contract consumed by application composition
- Base: `DevelopersCoffee/airo@8d58b3a97d35cfb23d63e6fd13d6b00c5112affe`

## Contract

`TvSourceManagementSection` accepts an optional row-actions builder. The
builder receives only the existing non-secret `ContentSourceConfig` and returns
zero or more widgets rendered before the existing Remove action.

`tvSourceManagementSectionBuilderProvider` returns the baseline section by
default. `TvSettingsScreen` resolves its Sources detail through that provider,
allowing a product-level `ProviderScope` override.

No credentials, HTTP behavior, entitlement logic, persistence, or error
mapping enters the public framework.

## Red-green-refactor sequence

1. Add failing feature widget coverage for an injected per-source action.
2. Add failing app widget coverage for a section-builder provider override.
3. Implement the smallest additive typedefs, constructor field, row rendering,
   provider, and settings-screen consumption needed to pass.
4. Run focused tests, format, analyze affected packages/app, and execute
   repository contract checks.
5. Review correctness, clarity, consistency, duplication, tests, and
   performance before the atomic implementation commit.

## Verification

- `flutter test test/iptv/presentation/tv/settings/tv_source_management_section_test.dart`
  from `packages/feature_iptv`
- `flutter test test/features/settings/presentation/tv/tv_settings_screen_test.dart`
  from `app`
- `flutter analyze` for `packages/feature_iptv` and affected app files
- `./scripts/validate_module_manifests.sh`
- `./scripts/check_import_boundaries.sh`
- `git diff --check`

## Rollback

Revert the additive implementation commit. The default provider and null row
builder preserve baseline behavior, and there is no data migration.
