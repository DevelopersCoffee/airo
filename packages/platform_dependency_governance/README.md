# Platform Dependency Governance

Shared dependency governance contracts for Airo release profiles.

This package is platform/framework code. Airo TV, release tooling, package
maintainers, and future CI checks consume these contracts to keep Lite Receiver
and legacy-device support from being broken by unnecessary dependency choices.

## Scope

- Dependency audit records with Android API, native architecture, size, memory,
  background behavior, shrinker, TV-issue, and ownership fields.
- A reusable checklist for API 26 baseline governance.
- Audit reports that capture profile, timestamp, checklist thresholds,
  dependency results, and aggregate blocker codes.
- Deterministic blocker codes for release checks.

This package does not edit pubspecs, inspect Gradle output, download packages,
measure APK size, run CI jobs, or store release credentials.
