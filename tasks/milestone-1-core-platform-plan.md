# Implementation Plan: Milestone 1 — Core Platform

## Outcome

Complete GitHub Milestone 1 by closing #499 and #496 on top of the already
merged #507, while extracting a reusable progressive-download plugin that Airo,
Airo Coin, and Airo Mind can import without depending on each other.

## Architecture Decisions

- Create `platform_downloads` as the single app-facing Flutter plugin for
  progressive/background artifact transfer. Flutter's official plugin guidance
  defines plugin packages as the modular boundary for a Dart API backed by
  platform implementations:
  https://docs.flutter.dev/packages-and-plugins/developing-packages
- Keep generic transfer requests, state transitions, queue operations, and
  failure codes independent of AI/model types.
- Make `core_ai` an adapter/consumer of `platform_downloads`; keep the model
  catalog, install receipts, update detection, activation, residency, and
  preload policy in `core_ai`.
- Keep widgets product-shaped: they render immutable manager state and invoke
  controller actions, but do not implement transfer, hashing, or model
  lifecycle rules.
- On Android, retain WorkManager for persistent background work and unique job
  identity. Android documents WorkManager as persistent across app restarts and
  supports long-running downloads:
  https://developer.android.com/develop/background-work/background-tasks/persistent
  and
  https://developer.android.com/develop/background-work/background-tasks/persistent/how-to/long-running
- On iOS, retain background `URLSessionDownloadTask` and use resume data for
  explicit pause/retry. Apple documents that background download tasks continue
  while the app is suspended and that resume data can continue a supported
  transfer:
  https://developer.apple.com/documentation/foundation/urlsessiondownloadtask
  and
  https://developer.apple.com/documentation/foundation/pausing-and-resuming-downloads

## Dependency Graph

```text
platform_downloads v1 typed contract
├── fake adapter + contract tests
├── Android WorkManager adapter
└── iOS background URLSession adapter
        │
        ▼
core_ai progressive model adapter
├── install receipts / update detection
├── model-manager immutable snapshot + actions
└── warm/frequent-preload policy
        │
        ▼
Airo settings providers and manager screen
        │
        ├── future Airo Mind consumer (core_ai + platform_downloads)
        └── future Airo Coin consumer (platform_downloads only)
```

## Phases

### Phase 1: Contract and package foundation

- Define `background-download-contract/v1` types and stable failure semantics.
- Add the `platform_downloads` package/module manifest/docs without new
  third-party Dart dependencies.
- Add deterministic fake-adapter contract tests.

### Checkpoint: Contract

- Package format/analyze/tests pass.
- Module manifest and dependency checks pass.
- No AI, Coin, Mind, or app imports exist in `platform_downloads`.

### Phase 2: Native progressive transfer

- Move Android/iOS implementation from the app host into the plugin.
- Add pause/resume/retry/cancel/recovery APIs.
- Preserve partial/resume state; restart only after an explicit unsupported
  resume reason.
- Verify expected size/SHA-256 before atomic promotion.

### Checkpoint: Native

- Android native unit/build checks pass.
- iOS plugin compiles and focused native tests pass where supported.
- Flutter channel tests prove the v1 payload/state contract.

### Phase 3: Model-management framework

- Adapt `ModelDownloadService` to `platform_downloads`.
- Replace minimal `ModelEntry` with immutable complete manager state.
- Add install receipts and update-available detection.
- Add typed actions for queue control, activation, deletion, warm now, and
  frequent preload.

### Checkpoint: Framework

- Focused `core_ai` tests cover every #496 capability and #499 delegation.
- Failed update leaves the current verified install usable.
- Delete clears receipts and related selection/preload state through consumers.

### Phase 4: Airo product surface

- Consolidate duplicate download providers.
- Render installed, active, recommended, queue, storage, updates, delete, warm,
  and frequent preload in the manager screen.
- Add pause/resume/retry/cancel/update actions and accessible status/error
  states.

### Checkpoint: Product

- Focused provider/widget tests cover happy and failure paths.
- No framework logic exists in widgets.
- No local filesystem path or credential is shown.

### Phase 5: Qualification and milestone closure

- Run focused format, analyze, test, native build/unit, manifest, docs, and
  `git diff --check` gates.
- Audit #507’s merged evidence on current `origin/main`.
- Record validation evidence on #499 and #496, remove stale `blocked` labels,
  close both with `state_reason=completed`, and verify Milestone 1 is closed or
  has zero open issues.

## Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Remote server rejects byte ranges/resume tokens | High | Emit `resume_not_supported`; preserve evidence and restart only through the explicit fallback branch. |
| Platform background behavior diverges | High | One typed state machine plus adapter contract tests and native fixtures. |
| Existing verified model lost during update | High | Download to a versioned partial and atomically replace only after verification. |
| New package leaks product concepts | Medium | Dependency and import tests forbid `core_ai`, app, Coin, and Mind imports. |
| Large hashing blocks UI | High | Hash in native worker/background delegate; never in widget/provider code. |
| Android 16 long-running worker quotas | Medium | Document/test current WorkManager behavior and keep adapter boundary replaceable by user-initiated transfer jobs. |
| iOS resume data unavailable | Medium | Surface structured unsupported state; do not pretend a resume occurred. |

## Completion Evidence

- GitHub: issues #496, #499, #507 and Milestone 1 state.
- Framework: `platform_downloads` and `core_ai` public APIs plus module manifests.
- Runtime: Android/iOS plugin implementations and native tests/builds.
- Product: focused manager widget/provider tests.
- Quality: repository manifest/docs checks, package analyze/tests, and clean
  diff/worktree.

