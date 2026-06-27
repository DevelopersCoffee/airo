## Drift Lockfile Upgrade Review - 2026-06-27

Issue: `#364` Optional: upgrade Drift lockfile entries to 2.34.0.

### Owning agent and scope

- Owner: Offline & Sync Agent
- Supporting agent: Core Architecture Agent
- Layer: framework/storage dependency review
- Impacted files/modules:
  - `app/pubspec.yaml`
  - `app/pubspec.lock`
  - `app/lib/core/database/**`
  - Drift-generated sources under `app/lib/**.g.dart`
  - storage-oriented tests under `app/test/features/money/**` and `app/test/features/coins/**`

### Current repo baseline

- `app/pubspec.yaml`
  - `drift: ^2.18.0`
  - `drift_dev: ^2.18.0`
  - `build_runner: 2.4.13`
  - `hive_generator: 2.0.1`
  - `riverpod_generator: 2.4.0`
- `app/pubspec.lock`
  - `drift: 2.21.0`
  - `drift_dev: 2.21.2`
  - `sqlite3: 2.9.4`
  - `sqlparser: 0.39.2`
  - `source_gen: 1.5.0`
  - `build_runner: 2.4.13`
  - `hive_generator: 2.0.1`
  - `riverpod_generator: 2.4.0`

### Version matrix

`flutter pub outdated --json` in `app` reports:

- `drift`: current/resolvable `2.21.0`, latest `2.34.0`
- `drift_dev`: current/resolvable `2.21.2`, latest `2.34.1+1`
- `sqlite3`: current/resolvable `2.9.4`, latest `3.3.3`
- `sqlparser`: current/resolvable `0.39.2`, latest `0.44.5`
- `source_gen`: current/resolvable `1.5.0`, latest `4.2.3`
- `riverpod_generator`: current/resolvable `2.4.0`, latest `4.0.4`
- `build_runner`: current/resolvable `2.4.13`, latest `2.15.0`

### Spike result

Temporary spike attempted in the isolated `#364` worktree by trying to bump the Drift line only:

```bash
cd app
flutter pub add 'drift:^2.34.0' 'dev:drift_dev:^2.34.0' --dry-run
flutter pub add 'drift:^2.34.0' --dry-run
flutter pub upgrade drift drift_dev --dry-run
```

Result:

- `drift` / `drift_dev` did not resolve to `2.34.x` under the current workspace toolchain.
- The targeted dry-run with `drift:^2.34.0` and `drift_dev:^2.34.0` failed because:
  - `hive_generator 2.0.1` depends on `source_gen ^1.0.0`
  - `drift_dev >=2.28.2` depends on `source_gen >=3.0.0 <5.0.0`
- The runtime-only dry-run with `drift:^2.34.0` also failed because the existing `drift_dev`, `riverpod_generator 2.4.0`, and `build_runner 2.4.13` analyzer/macros constraints cannot satisfy the newer Drift/sqlite3/tooling graph.
- `flutter pub upgrade drift drift_dev --dry-run` confirmed that no dependency changes are possible while keeping current constraints; `drift` remains resolvable only to `2.21.0`, and `drift_dev` remains resolvable only to `2.21.2`.

### Decision

Decision: `defer` the Drift `2.34.x` lockfile upgrade as a standalone low-risk change.

Reason:

- The candidate is blocked by the shared code-generation stack, not by a local Drift API compile error.
- Upgrading `drift_dev` to `2.34.x` requires moving the repo beyond `source_gen 1.x`, which conflicts with the current `hive_generator` line.
- Upgrading runtime `drift` to `2.34.x` requires a broader analyzer/build_runner/Riverpod generator resolution than this optional lockfile ticket should include.
- Pulling those changes into `#364` would mix storage, Hive codegen, Riverpod codegen, and analyzer/tooling concerns, violating the narrow dependency-review scope.

### Follow-up split recommended

- Follow-up 1: decide whether Hive generation remains required; replace or remove `hive_generator` before moving `source_gen` to `3.x+`.
- Follow-up 2: align the Riverpod/build_runner/analyzer tooling line, likely with the Riverpod 3 migration work, before retrying newer Drift codegen.
- Follow-up 3: after toolchain alignment, retry `drift:^2.34.0` / `drift_dev:^2.34.0`, regenerate Drift sources, and run the storage test subset.

### Verification commands

```bash
cd /Users/udaychauhan/workspace/airo-issue-364/app
flutter pub outdated --json
flutter pub get
flutter pub add 'drift:^2.34.0' 'dev:drift_dev:^2.34.0' --dry-run
flutter pub add 'drift:^2.34.0' --dry-run
flutter pub upgrade drift drift_dev --dry-run
```

### Verification results

- `flutter pub outdated --json`
  - confirmed `drift 2.34.0` and `drift_dev 2.34.1+1` are published but not currently resolvable.
- `flutter pub get`
  - succeeded on the current lockfile/toolchain baseline.
- `flutter pub add 'drift:^2.34.0' 'dev:drift_dev:^2.34.0' --dry-run`
  - failed on `hive_generator 2.0.1` / `source_gen ^1.0.0` versus `drift_dev >=2.28.2` / `source_gen >=3.0.0 <5.0.0`.
- `flutter pub add 'drift:^2.34.0' --dry-run`
  - failed on the broader `drift_dev` + `riverpod_generator 2.4.0` + `build_runner 2.4.13` analyzer/macros constraint graph.
- `flutter pub upgrade drift drift_dev --dry-run`
  - confirmed no Drift dependency changes would be made under current constraints.

### Official references

- https://pub.dev/packages/drift/changelog
- https://pub.dev/packages/drift_dev/changelog
- https://pub.dev/packages/hive_generator
- https://pub.dev/packages/source_gen
- https://pub.dev/packages/riverpod_generator
- https://pub.dev/packages/build_runner
