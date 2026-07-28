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
deterministic providers and execute through `AiroWorkerExecutor`. Embeddings
use an asynchronous provider contract because Flutter method channels cannot
run in a spawned Dart isolate; the platform provider must own its native worker
boundary. Missing embedding, speaker-clustering, and Memory providers return
`unavailable`; they are never reported as completed.

The app owns redaction, domain mapping, and repository persistence. Only
redacted transcript segments cross into package stage providers. Public
diagnostics contain stable stage, state, and code values—not transcript text,
paths, prompts, vectors, credentials, or exception details.

The full app can inject the `core_ai` local provider through
`LocalMeetingEmbeddingProvider`. Until an approved model has been installed
and the provider has opened successfully, production composition leaves the
stage unavailable. Successful projections persist through the existing meeting
embedding columns, with the model artifact SHA-256 in the row identity; this
slice does not expand the database schema.

Speaker clustering has a separate asynchronous provider seam. Its input carries
redacted transcript text plus local audio metadata whose string representation
redacts the path. Results contain anonymous cluster IDs, time ranges, and
confidence only; overlapping ranges are valid. This is not speaker identity or
biometric enrollment, and the default remains unavailable until a real local
diarization provider is qualified.

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
