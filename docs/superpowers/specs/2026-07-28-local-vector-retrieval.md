# Spec: Local Vector Retrieval Foundation

## Objective

Add the framework-owned retrieval half of GitHub issue #355 without claiming
that embedding generation, Memory Vault persistence, or meeting integration is
complete.

The first slice accepts already-generated 256- or 384-dimensional float
vectors and stable record IDs, then performs deterministic exact cosine search
locally. It is rebuildable derived state: callers retain ownership of durable
storage and raw text.

Success means the contract is correct, privacy-safe, platform-neutral, and
ready for later MediaPipe and Memory adapters.

## Assumptions

1. The user approval on 2026-07-28 authorizes work on #355 and its eventual
   MediaPipe dependency.
2. This slice intentionally adds no dependency. The issue discussion measured
   a scalar scan well inside the 1,000-row budget and withdrew the proposed
   `vector_kit` dependency.
3. A compatible real MediaPipe model with 256 or 384 output dimensions must be
   selected and reviewed separately. The official sample model is not assumed
   to satisfy that dimensional contract without device evidence.
4. SQLite and Memory Vault remain the source of truth. This slice persists
   nothing.
5. Production callers must invoke large index builds and searches through an
   existing worker/native boundary. The synchronous helper exists for
   deterministic tests and small direct calls.

## Tech Stack

- Dart 3.12 / Flutter 3.44
- `Float32List` for stable cross-platform float32 behavior
- Existing `core_ai` framework package
- No new package, native binary, network permission, or model artifact

## Commands

```sh
cd packages/core_ai
dart format lib/src/embeddings test/embeddings
flutter test test/embeddings/exact_vector_index_test.dart
flutter analyze
```

Repository checks:

```sh
python3 scripts/check-module-manifests.py
scripts/test-check-worker-offload-policy.sh
scripts/check-worker-offload-policy.sh
git diff --check
```

## Project Structure

```text
packages/core_ai/lib/src/embeddings/
  exact_vector_index.dart          exact cosine index and immutable results
packages/core_ai/test/embeddings/
  exact_vector_index_test.dart     reference, mutation, and invalid-input tests
packages/core_ai/lib/core_ai.dart  public export
```

## Contract

- Index dimensions are exactly 256 or 384.
- Record IDs are trimmed, non-empty, and unique.
- Vectors and queries must match the configured dimension.
- Values must remain finite after conversion to float32.
- Zero-norm records and queries are rejected.
- Results contain only immutable stable ID and score pairs.
- Scores sort descending; equal scores sort by stable ID ascending.
- `topK` must be positive and is capped naturally by corpus size.
- Rebuild validates a complete replacement before swapping it into the live
  index. A failed rebuild leaves the previous valid snapshot searchable.
- Empty configured indexes return no results for a valid query.
- No row index, mutable vector, raw text, model path, or private payload is
  exposed in results or diagnostics.

## Code Style

Use immutable public values, explicit validation, and stable ordering:

```dart
final results = index.search(query, topK: 5);
for (final result in results) {
  print('${result.id}: ${result.score}');
}
```

Public names describe domain behavior. Internal row indices and typed buffers
remain private.

## Testing Strategy

Follow red-green-refactor:

1. Write fixed 256- and 384-dimensional tests against an independent scalar
   cosine reference and confirm they fail before implementation.
2. Cover stable tie ordering, append, deterministic rebuild, delete-by-rebuild,
   empty corpus, and failed-rebuild preservation.
3. Cover blank/duplicate IDs, invalid dimension, non-finite values, float32
   overflow, float32 underflow to zero, zero norms, and invalid `topK`.
4. Run the focused suite, package analyzer, worker-policy checks, and manifest
   validation.

No test will claim MediaPipe inference, SQLite persistence, airplane mode, or
physical-device latency.

## Boundaries

### Always

- Preserve stable IDs independently of row positions.
- Validate before mutating the live snapshot.
- Keep production large-corpus work behind a worker/native boundary.
- Keep the implementation deterministic on Dart VM and web.

### Ask first

- Add or change a native/model dependency.
- Add a durable schema or migration.
- Bundle or download a model artifact.
- Expand supported dimensions.

### Never

- Persist row indices as source-of-truth IDs.
- Log vectors or raw source text.
- Perform network access or model inference in this slice.
- Claim #355 or #506 complete from this foundation alone.

## Success Criteria

- Exact cosine results match an independent reference for 256 and 384
  dimensions.
- Invalid inputs cannot partially mutate the index.
- A failed rebuild preserves the previous valid snapshot.
- The public API exposes stable IDs and scores only.
- Focused tests and analyzer pass with no new dependency.

## Open Questions

- Which reviewed MediaPipe-compatible 256/384-dimensional model will become
  the real Android provider?
- Which approved Memory runtime contract will own durable vectors and deletion
  semantics?

These questions block later adapters, not this retrieval foundation.
