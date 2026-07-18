# Release Device Qualification

This runbook defines the release-artifact validation gate for Airo release
candidates. It complements the normal build workflow by testing the actual
customer-facing artifacts and the Patrol native E2E suites across real devices.

## Feature Packet

**Problem:** Release artifacts can pass build checks while still failing on
customer devices because of OS permissions, screen size, native lifecycle, ABI,
or package-specific behavior.

**User / actor:** Release manager, QA automation agent, and customer devices.

**Framework or application layer:** Mixed. The owned implementation is release
automation, test organization, and documentation. App behavior changes are out
of scope except stable test IDs or deterministic test fixtures.

**Owning agent:** Release and DevEx Agent.

**Reviewing agents:** QA Automation Agent, Mobile UI Agent, Security and
Privacy Agent, and Framework Agent if platform hooks or reusable contracts
change.

**Impacted modules/files:** GitHub Actions release qualification workflow,
Patrol E2E tests, artifact smoke scripts, release device matrix, and release
checklist.

**Base branch/worktree:** Confirmed from latest `origin/main` for v1/full app
release work. Use `origin/v2` only for explicit v2 modular/TV issues.

**Decision:** Ready.

## Cross-Agent Contract

**Provider agent:** Release and DevEx Agent.

**Consumer agent:** QA Automation Agent and Release Manager.

**Interface/API:** `config/release_device_matrix.yaml`,
`.github/workflows/release-device-qualification.yml`, and scripts under
`scripts/`.

**Input shape:** Release version, artifact workflow run id, provider
(`browserstack`, `firebase`, `local`, or `host-only`), and tier (`tier1` or
`full`).

**Output shape:** Markdown report, JSONL artifact inventory, screenshots/logs
when device execution is enabled, and uploaded CI artifacts.

**State changes:** None in app data. Device runs may install/uninstall release
artifacts on test devices.

**Errors:** Missing artifacts, failed static checks, missing provider secrets,
device launch failure, crash logs, Patrol test failures, and waived long-tail
device gaps.

**Permissions:** Device-farm credentials are read from CI secrets only. Local
device runs require explicit environment opt-in.

**Privacy/redaction:** Reports must include artifact names, checksums, device
metadata, and status only. Do not include secrets, user credentials, or full
customer URLs.

**Persistence:** CI uploads reports with release artifacts. Local runs write to
`artifacts/release-qualification/`.

**Versioning/migration:** Matrix version is currently `1`. Add new matrix
fields as optional until scripts are updated to require them.

**Tests required:** Host gates, artifact smoke checks, Patrol tagged suites,
and provider-specific real-device runs for release-blocking tier 1 devices.

## Deterministic Use Cases

### UC-001: Android release APK launches on real phone

**Actor:** Release manager.

**Preconditions:** Release APK exists and target device is connected or
available in the selected device farm.

**Trigger:** Release qualification workflow runs for `tier1`.

**Happy path:** APK installs, launches, renders the first frame, and critical
Patrol smoke tests pass.

**Failure paths:** Install failure, first-frame timeout, startup crash,
permission dialog dead-end, or Patrol failure blocks release.

**Data created/updated/deleted:** Test app data only; device data is cleared
between runs where supported.

**Privacy expectations:** No real customer accounts or secrets.

### UC-002: iOS/iPad release candidate passes native device smoke

**Actor:** QA automation agent.

**Preconditions:** IPA or provider-compatible iOS test artifacts exist.

**Trigger:** Release qualification workflow runs with BrowserStack or local iOS
provider.

**Happy path:** App installs, launches on iPhone and iPad, permissions can be
handled, and responsive navigation remains usable.

**Failure paths:** IPA missing, signing/install failure, permission dead-end,
layout blocks primary actions, or crash.

**Data created/updated/deleted:** Test app data only.

**Privacy expectations:** Demo/test fixture account only.

### UC-003: Web and desktop archives are not broken

**Actor:** Release manager.

**Preconditions:** Web zip and desktop archives exist.

**Trigger:** Artifact smoke script scans release artifacts.

**Happy path:** Archives pass integrity checks; web artifact can be served and
Playwright smoke tests pass when web smoke is enabled.

**Failure paths:** Missing/empty archive, corrupt archive, missing web
`index.html`, or launch smoke failure.

**Data created/updated/deleted:** Temporary extraction directories.

**Privacy expectations:** No secrets in reports.

## Automation Flows

### AUTO-001: Host artifact smoke

**Given:** Release artifacts downloaded into `release-artifacts/`.

**When:** `scripts/release-artifact-smoke.sh` runs.

**Then:** The script inventories artifacts, records SHA-256 checksums, performs
static package/archive checks, optionally runs local device smoke checks, and
writes a Markdown report.

**Fixtures:** Release artifact files from GitHub Actions.

**Mocks/stubs:** None.

**Assertions:** Required artifacts exist for release runs; static integrity
checks pass; optional device launches do not crash.

**Cleanup:** Temporary extraction directories are removed.

### AUTO-002: Patrol real-device suites

**Given:** Tagged Patrol suites and a provider selected in workflow input.

**When:** The release qualification workflow runs provider jobs.

**Then:** The provider lane runs release-blocking tagged suites on tier 1
devices and uploads provider logs/videos/reports.

**Fixtures:** Deterministic SharedPreferences login and model selection.

**Mocks/stubs:** No real customer account. Device permission dialogs are
handled through Patrol native automation where supported.

**Assertions:** Launch, navigation, permission, responsive, lifecycle, and
finance/agent journeys pass on tier 1 devices.

**Cleanup:** Provider clears app data where supported.

## Release Blocking Rules

- Block release if any tier 1 device fails launch, navigation, permission
  handling, or crash-free smoke.
- Block release if Android TV artifact fails Leanback/package checks or D-pad
  navigation in a TV-capable environment.
- Block release if iOS/iPad artifacts cannot be produced unless the release
  explicitly waives iOS with a known issue.
- Waive non-critical long-tail devices only with device metadata, logs, and a
  release-note known issue.

## References

- Patrol device farms: https://patrol.leancode.co/documentation/ci/platforms
- Patrol BrowserStack: https://patrol.leancode.co/integrations/browserstack
- Flutter integration tests: https://docs.flutter.dev/testing/integration-tests
- Firebase Test Lab Flutter:
  https://firebase.google.com/docs/test-lab/flutter/integration-testing-with-flutter
- BrowserStack Flutter: https://www.browserstack.com/docs/app-automate/flutter
