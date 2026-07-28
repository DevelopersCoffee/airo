# Spec: Milestone 2 Background AI Processing

## Objective

Implement issue #506 as the first dependency-unblocking slice for GitHub
Milestone 2, "Phase 2 — Reliability".

Meeting intelligence must become a release-selectable application module whose
CPU-heavy stages execute through the shared platform worker boundary rather than
the UI isolate. Completing a meeting must return control after a durable job has
been accepted; summary generation, search indexing, embedding generation,
speaker clustering, and memory updates then run as independently observable,
cancellable stages.

This work does not treat an unavailable stage as completed. Current `main` has
deterministic summary/search logic, but no real embedding provider, speaker
clustering implementation, or Memory runtime adapter. Those stages remain
explicitly unavailable until concrete providers are implemented and verified.

## Users and Success

- A user can finish a meeting without waiting for local AI post-processing.
- A release maintainer can include meeting intelligence in the full/mobile
  profile and exclude it from TV, Coins, and other focused profiles by editing
  the build-profile manifest and profile pubspec, not feature source.
- QA can deterministically observe queued, running, completed, failed,
  cancelled, and unavailable stage outcomes without a physical device.
- Domain adapters can add model-backed embeddings, diarization, and Memory
  writes without changing the worker executor or meeting UI.

## Tech Stack

- Dart 3.12 / Flutter 3.44
- `core_product_shell` for shell-scoped module composition
- `.github/airo-build-profiles.json` plus profile pubspecs for compile-time
  release inclusion
- `platform_worker_jobs` and `AiroWorkerExecutor` for isolate-backed CPU work
- Existing meeting domain and repository contracts during additive migration
- Flutter test for package, contract, and app integration tests

No new third-party dependency is permitted for this slice.

## Commands

From the repository root:

```bash
python3 scripts/check-module-manifests.py
python3 scripts/check-build-profiles.py
./scripts/check-variant-pubspecs.sh
(cd packages/platform_worker_jobs && flutter test)
(cd packages/feature_meeting_intelligence && flutter test)
(cd app && flutter test test/features/meeting/meeting_background_processing_test.dart)
(cd app && flutter analyze lib/features/meeting test/features/meeting/meeting_background_processing_test.dart)
git diff --check
```

Run only commands covering files changed in the current increment. Do not
dispatch broad remote CI during issue iteration.

## Project Structure

```text
packages/platform_worker_jobs/
  lib/                         reusable worker kinds/execution contracts
  test/                        framework contract tests

packages/feature_meeting_intelligence/
  lib/src/domain/              serializable meeting job/stage models
  lib/src/application/         background processing coordinator
  lib/src/adapters/            summary/indexing adapters owned by the feature
  test/                        coordinator, cancellation, and failure tests
  module.yaml                  ownership, dependencies, ship policy

app/lib/features/meeting/
  infrastructure/              persistence/model/Memory adapters
  presentation/                consumers only; no heavy loops

.github/airo-build-profiles.json
app/pubspec*.yaml               compile-time release composition
```

The package name is intentionally capability-specific. Generic worker
execution remains in `platform_worker_jobs`; meeting semantics do not move
into the framework package.

## Public Contract

The feature package exposes:

- stable stage identifiers for summary, search indexing, embeddings, speaker
  clustering, and memory update;
- an immutable job request containing only sendable, local data;
- immutable progress snapshots and terminal outcomes;
- a cancellation token/handle;
- provider interfaces for each stage;
- a coordinator that accepts a job, executes eligible stages away from the UI
  isolate, and reports unavailable providers honestly.

Application adapters own:

- meeting repository persistence;
- local model selection and inference;
- Memory runtime writes;
- sensitive-data redaction before content crosses a stage boundary;
- restart recovery where an OS/background adapter is available.

No raw transcript, file path, prompt, credential, or embedding vector may be
written to diagnostics.

## Code Style

Use immutable typed state and exhaustive switches. Keep stage logic explicit:

```dart
final outcome = switch (provider) {
  null => const MeetingStageOutcome.unavailable(
    code: MeetingStageCode.providerUnavailable,
  ),
  final stageProvider => await executor.run(
    debugName: 'meeting-summary',
    kind: AiroWorkerJobKind.meetingSummary,
    computation: () => stageProvider.process(input),
  ),
};
```

Stable IDs use lowercase snake case. Product-specific terms stay out of
`platform_worker_jobs` except generic job-kind identifiers needed for resource
policy and telemetry.

## Testing Strategy

- Worker package unit tests freeze new stable job-kind IDs and prove errors
  propagate across inline/isolate execution.
- Feature package tests use the deterministic inline executor, fake providers,
  and a controlled cancellation token.
- Tests prove stage independence: one failed or unavailable stage does not
  erase successful outcomes from other stages.
- App integration tests prove `completeMeeting` does not synchronously execute
  heavy processing and that accepted work persists only redacted final chunks.
- Build-profile tests prove the feature package is present in the full profile
  and absent from TV/Coins profiles.
- At least one failure-path test is required for provider failure, persistence
  failure, and cancellation.

Physical-device process-death/reboot evidence is tracked separately by the
release validation runbook; host tests cannot prove OS lifecycle behavior.

## Boundaries

### Always

- Preserve the `AiroWorkerExecutor` boundary for production CPU-heavy work.
- Keep synchronous helpers only for deterministic tests and small pure logic.
- Redact before persistence, diagnostics, or Memory writes.
- Keep each release profile compilable after every increment.
- Add a rollback/disable path through release-profile exclusion.

### Ask First

- Add a third-party dependency.
- Change the meeting database schema or migrate durable user data.
- Enable network/cloud processing.
- Change public routes or user-visible meeting UX.
- Dispatch remote CI, release, signing, or store workflows.

### Never

- Run parsing, serialization, indexing, or AI transforms on a widget/provider
  UI path.
- Represent an unavailable embedding, clustering, or Memory provider as a
  successful stage.
- Put app imports in framework/feature packages.
- Include meeting intelligence in TV or Coins profiles by default.
- Log transcript content, local paths, prompts, credentials, or vectors.

## Success Criteria

1. A clean issue branch/worktree is based on the fetched `origin/main`.
2. Issue #506 contains a Ready Critical Agent gate, ownership, cross-agent
   contract, deterministic use cases, automation flows, privacy posture, and
   rollback.
3. `feature_meeting_intelligence` is a manifest-owned package with no `app`
   dependency and an explicit phone/tablet/desktop ship policy.
4. Build-profile validation proves compile-time inclusion in the full profile
   and exclusion from TV/Coins.
5. Completing a meeting accepts background work without executing the current
   summary/indexing pipeline synchronously on the caller/UI isolate.
6. Summary and search-index stages have real implementations and deterministic
   happy/failure/cancellation tests.
7. Embedding, speaker-clustering, and Memory stages either have verified real
   providers or return typed `unavailable` outcomes. Issue #506 remains open
   until all five have verified real providers.
8. Focused format, analyze, tests, module/build-profile validation, docs checks,
   and `git diff --check` pass with evidence recorded on the issue.

## Rollback

- Remove `feature_meeting_intelligence` from the full profile and its profile
  pubspec to disable the capability without editing TV/Coins code.
- Keep the existing synchronous pure pipeline available only as a deterministic
  test adapter during migration.
- Do not delete existing meeting storage or generated database code in this
  slice.

## Dependency Decisions

Repository and GitHub evidence resolves the ownership map:

1. A reusable local embedding provider has no clearly scoped implementation
   issue. #277 owns the model/runtime foundation and #288 consumes semantic
   embeddings for RAG, but neither owns a product-neutral embedding service.
   Search for duplicates again immediately before creating that framework issue.
2. Speaker clustering/identity implementation belongs under #267 and #504.
   #512 remains the validation issue and must not become the implementation
   owner.
3. Meeting Memory product behavior belongs under #268, but durable Memory
   writes depend on the Airo Mind runtime chain #1193 -> #1194 -> #1195. Do not
   expand the current feature-owned meeting SQLite schema while that contract is
   unresolved.
4. #506 owns isolate-backed non-blocking stage execution. Process-death,
   reboot, battery-restriction, and rescheduling evidence remains under #518's
   background lifecycle validation contract.

The maintainer still needs to approve this dependency mapping and decide
whether the missing embedding provider should be a sub-issue of #506 or a
framework issue linked as a blocker.

Implementation is blocked on human review of this scope and dependency
mapping. The first additive package/contract slice can proceed once the scope
is approved; #506 cannot close until all success criteria are proven.
