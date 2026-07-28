# Feature Meeting Intelligence

This release-selectable package owns meeting-specific background intelligence
contracts and orchestration. Generic isolate execution and resource policy
remain in `platform_worker_jobs`.

## Release composition

- Full mobile, iOS, and web validation profiles include this package.
- TV and Coins profiles declare it in `excludedPackages`.
- `scripts/check-build-profiles.py` rejects an excluded package if it leaks
  into a variant pubspec.

Removing the package from the full profile and full-profile pubspec disables
the capability without editing TV or Coins source.

## Stage behavior

The coordinator exposes stable summary, search-index, embedding,
speaker-clustering, and Memory-update stages. Summary and search indexing have
deterministic providers and execute through `AiroWorkerExecutor`. Missing
embedding, speaker-clustering, and Memory providers return `unavailable`;
they are never reported as completed.

The app owns redaction, domain mapping, and repository persistence. Only
redacted transcript segments cross into package stage providers. Public
diagnostics contain stable stage, state, and code values—not transcript text,
paths, prompts, vectors, credentials, or exception details.

## Current lifecycle boundary

`MeetingBackgroundJobHandle` represents an accepted in-process job with
observable completion and cancellation checkpoints. It does not claim
process-death or reboot recovery. Durable OS rescheduling and lifecycle
validation remain owned by issue #518.

## Local verification

```bash
flutter test
flutter analyze
```
