## Feature Packet

**Primary owner agent:** Release and DevEx Agent
**Review agents:** QA Automation Agent
**Layer:** Framework
**Sprint:** Maintenance
**Parent roadmap:** Daily Project Health Monitor

### Critical Agent Gate

**Problem:** The local version consistency health check is stale and reports
false failures after the repository moved to Flutter 3.41.4 and Dart 3.11.1.
It also misparses Flutter environment constraints, local path dependencies, and
comments as dependency versions.
**User / actor:** Maintainers and CI operators running repository health checks.
**Framework or application layer:** Framework/dev tooling.
**Owning agent:** Release and DevEx Agent.
**Reviewing agents:** QA Automation Agent.
**Impacted modules/files:** `Makefile`, `scripts/check-versions.sh`,
`app/pubspec.yaml`, `packages/core_data`.
**Open questions:** None for this scoped DevEx repair.
**Decision:** Ready.

### Cross-Agent Contract

**Provider agent:** Release and DevEx Agent.
**Consumer agent:** QA Automation Agent.
**Interface/API:** `scripts/check-versions.sh`.
**Input shape:** Repository checkout containing pubspec files, GitHub workflows,
and Android Gradle configuration.
**Output shape:** Human-readable version consistency report and exit status.
**State changes:** No runtime state changes; Android secure storage now uses the
current `storageNamespace` option with the existing namespace value.
**Errors:** Non-zero exit for true version inconsistencies.
**Permissions:** Local repository read-only execution.
**Privacy/redaction:** No secrets or user data read.
**Persistence:** None.
**Versioning/migration:** Update expected Flutter/Dart baselines to current
repository minimums and align `path_provider` constraints.
**Tests required:** Run `bash scripts/check-versions.sh` and targeted Flutter
package validation.

### Deterministic Use Cases

#### UC-001: Current Flutter Baseline Passes

**Actor:** Maintainer.
**Preconditions:** Repo requires Flutter 3.41.4 and Dart 3.11.1.
**Trigger:** Maintainer runs `bash scripts/check-versions.sh`.
**Happy path:** Makefile and CI workflow versions are compared against 3.41.4.
**Alternate paths:** Packages with older minimums are warned but do not block.
**Failure paths:** Real mismatches produce errors and a non-zero exit.
**Data created/updated/deleted:** None by the script; secure storage keeps the
same namespace string under the current Android option.
**Privacy expectations:** No repository secrets are inspected.

### Automation Flow

#### AUTO-001: Version Health Script

**Given:** A clean checkout on the maintenance branch.
**When:** `bash scripts/check-versions.sh` is executed.
**Then:** The report reflects the current Flutter/Dart baseline, ignores comments
and path dependency internals, and exits according to true inconsistencies.
**Fixtures:** Existing repository files.
**Mocks/stubs:** None.
**Assertions:** Exit status and report output.
**Cleanup:** None.

### Implementation Boundaries

- Framework files: `scripts/check-versions.sh`, `Makefile`,
  `packages/core_data`
- Application files: `app/pubspec.yaml`
- Tests: run the version script and targeted Flutter validation
- Docs: this issue packet
