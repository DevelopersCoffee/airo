# Flutter SDK Baseline Alignment

## Critical Agent Gate

**Problem:** The workspace packages already require Flutter `>=3.44.4` and Dart `>=3.12.2`, but several build entry points still declare Flutter `3.41.4` and Dart `3.11.1`, creating a mismatched local/CI contract.
**User / actor:** Release and DevEx maintainers, CI runners, local contributors.
**Framework or application layer:** Framework/build infrastructure.
**Owning agent:** Release and DevEx Agent.
**Reviewing agents:** Framework Agent, QA Automation Agent.
**Impacted modules/files:** `Makefile`, `.github/workflows/*`, `scripts/check-versions.sh`, `app/pubspec_streaming.yaml`, `app/pubspec_tv.yaml`, `app/pubspec_ios_spm.yaml`, `docs/DEPENDENCY_UPDATE_RUNBOOK.md`.
**Base branch/worktree:** confirmed from latest `origin/main`: yes (`e8096cbf670d418cab2c43115b1f0ca9049da112` at worktree creation).
**Open questions:** None for this alignment pass; no runtime behavior or public API changes are planned.
**Decision:** Ready

## Cross-Agent Contract

**Provider agent:** Release and DevEx Agent
**Consumer agent:** Framework Agent and app/package maintainers
**Interface/API:** Repository-wide SDK/toolchain baseline declarations
**Input shape:** Declared Flutter and Dart minimum versions in workflow env, local tooling, and alternate pubspec entry points
**Output shape:** Consistent Flutter `3.44.4` and Dart `>=3.12.2 <4.0.0` declarations across supported entry points
**State changes:** Tooling metadata only; no product runtime behavior changes
**Errors:** Version guard script should fail when a file drifts from the baseline
**Permissions:** None beyond repository file edits

## Deterministic Use Cases

1. A CI job using the declared Flutter version can resolve workspace dependencies without conflicting with package-level Flutter constraints.
2. A developer using `make` sees the same Flutter baseline documented in the app README and enforced by the version check script.
3. Alternate app pubspecs for iOS simulator, streaming, and TV builds resolve against the same Dart/Flutter baseline as `app/pubspec.yaml`.

## Automation Flow

1. Update all stale baseline declarations to the current workspace SDK versions.
2. Run `bash scripts/check-versions.sh` and verify the baseline passes.
3. Re-run host validations already used in this maintenance session: `flutter analyze` in `app`, plus representative core package tests.
