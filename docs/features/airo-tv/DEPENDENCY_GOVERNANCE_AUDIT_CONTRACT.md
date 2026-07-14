# Airo TV Dependency Governance Audit Contract

This contract defines the v2.0.0.1 release audit layer for Airo TV dependency
governance. It builds on the platform dependency checklist and evaluates many
dependency records into one release/profile report.

Implementation contract:

- Package: `packages/platform_dependency_governance`
- Schema: `kAiroDependencyGovernanceSchemaVersion`
- Input contract: `AiroDependencyGovernanceAudit`
- Output contract: `AiroDependencyGovernanceAuditReport`
- Default checklist: `AiroDependencyGovernanceChecklist`

## Ownership Boundary

Dependency governance is platform/release behavior. Release tooling may parse
pubspecs, Gradle files, APK size evidence, and dependency review notes into
`AiroDependencyAuditRecord` values. Airo TV application code must consume the
resulting report or profile decision; it must not duplicate release policy in
app modules.

## Audit Report

An audit report contains:

- audit id;
- release line;
- target product profile;
- checklist thresholds;
- per-package pass/fail results;
- blocked package names;
- stable blocker codes;
- creation and generation timestamps.

The public report must not include local workspace paths, machine names, raw
diagnostic dumps, or provider-specific payloads.

## Required Use Cases

- A report with all passing records passes and has no blocked packages.
- A report with multiple failing dependencies returns all blocked package names
  and the stable blocker-code set.
- Empty audits are deterministic and pass because no dependency record failed.
- Single-record checklist evaluation remains backward-compatible for current
  callers.
