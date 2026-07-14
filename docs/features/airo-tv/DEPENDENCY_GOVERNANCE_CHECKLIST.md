# Airo TV Dependency Governance Checklist

This checklist defines the platform dependency-governance contract for Airo TV
v2.0.0.1. Dependency decisions must preserve the API 26 Lite Receiver baseline
unless a dependency is optional and has a fallback or stub path.

Implementation contract:

- Package: `packages/platform_dependency_governance`
- Schema: `kAiroDependencyGovernanceSchemaVersion`
- Default checklist: `AiroDependencyGovernanceChecklist()`
- Android API baseline: `26`

## Required Dependency Fields

Every runtime dependency used by an Airo TV release profile must declare:

- package name and version;
- module/profile that uses it;
- required, optional, or development-only importance;
- minimum Android API floor;
- native architecture support when native code is present;
- estimated binary-size impact;
- estimated runtime-memory impact;
- background behavior, if any;
- shrinker/proguard requirement status;
- TV-specific issue review status;
- fallback or stub path when the dependency is optional or raises the API floor;
- maintenance owner.

## Deterministic Blockers

| Blocker | Release meaning |
| --- | --- |
| `missing_android_api_floor` | Dependency cannot enter a release profile until its effective Android floor is known |
| `raises_android_api_floor` | Dependency threatens the API 26 Lite Receiver baseline |
| `missing_fallback_for_raised_api` | A raised-API dependency is required or lacks a fallback/stub path |
| `missing_native_architectures` | Native code does not declare supported Android architectures |
| `binary_size_budget_exceeded` | Dependency exceeds the configured release-profile size budget |
| `memory_budget_exceeded` | Dependency exceeds the configured runtime-memory budget |
| `background_behavior_undeclared` | Background work exists but is not described for playback stress review |
| `shrinker_rules_missing` | Required shrinker/proguard rules are not validated |
| `tv_issues_not_reviewed` | Known Android TV/Fire TV/focus/playback issues were not reviewed |
| `owner_missing` | No maintainer owns upgrades, alternatives, and rollback decisions |

## Release Rule

A dependency can be accepted for a Lite Receiver or legacy Airo TV profile only
when `AiroDependencyGovernanceChecklist.evaluate(record).passed == true`.

If a dependency raises the API floor above 26, release tooling may still record
it, but it cannot be accepted for baseline profiles unless a profile-specific
fallback or stub keeps API 26 builds functional. CI wiring, pubspec parsing,
Gradle inspection, APK-size measurement, and dependency upgrades are follow-up
implementation tasks.
