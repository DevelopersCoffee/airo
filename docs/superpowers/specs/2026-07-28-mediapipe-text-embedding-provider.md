# Spec: Telemetry-Free MediaPipe Text Embedding Provider

## Objective

Add the real Android inference half of GitHub issue #355 as a
release-selectable platform package. The provider must generate real,
unit-normalized 384-dimensional embeddings locally without sending text,
vectors, model identifiers, app identifiers, or invocation telemetry over the
network.

This slice supplies framework contracts, an Android MediaPipe adapter, and
deterministic host/device verification. Durable vector storage, Memory Vault
wiring, and meeting-product orchestration remain separate consumers.

## Ownership and Layering

- Primary package owner: Platform Architect.
- Framework contract owner: Framework Agent (`core_ai`).
- Required reviewers: Chief Architect, Chief Security Officer, Chief
  Performance Officer, Chief QA Officer, Chief Open Source Officer, Chief
  Documentation Officer.
- Layer: framework/platform plus release composition; no user-facing workflow.
- Provider package: `platform_text_embeddings`.
- Consumer contract: `core_ai`.
- Application composition: full and iOS source profiles may resolve the Dart
  package; Android is the only native provider in this slice.
- TV and Coins profiles explicitly exclude the package.

## Verified Feasibility Evidence

### Model

- Source: `sentence-transformers/all-MiniLM-L6-v2`.
- Pinned revision:
  `1110a243fdf4706b3f48f1d95db1a4f5529b4d41`.
- License: Apache-2.0.
- Source contract: sentence/paragraph encoder with 384-dimensional output.
- Conversion: fixed `[1, 128]` BERT inputs, mean pooling over the attention
  mask, and native L2 normalization.
- Tokenizer vocabulary: 30,522 entries, SHA-256
  `07eced375cec144d27c900241f3e339478dec958f92fddbc551f295c992038a3`.
  It is byte-identical to the vocabulary embedded in the official MediaPipe
  Android BERT sample.
- Disposable converted artifact: 89,970,492 bytes, SHA-256
  `f1c6526c0d31cb222f179e1897e6d64d5e9617053261f1345f8536a4eb92b870`.
- MediaPipe 1.0.0 host proof: 384 values, unit norms within `1e-5`, synthetic
  fixture cosine `0.7375631557864626`.
- Host inference proof: median `43.5469 ms`, p95 `43.5975 ms`, maximum
  `43.5989 ms` over 20 measured runs after five warmups.

The generated model is intentionally not committed to git. Redistribution,
hosting, download receipts, attribution, and reproducible conversion must be
qualified before it becomes a release artifact.

### SDK

- Android dependency target: `com.google.mediapipe:tasks-text:0.10.29`, the
  version pinned by the official Android sample.
- Upstream AAR SHA-256:
  `50f466bdc034fd32213cccdbf229b9b106909d6c4d6c89210ba322bbbd0af727`.
- Upstream `tasks-core:0.10.29` AAR SHA-256:
  `7c9f935c6e60f2d612ba3240991863fc12a48a25d67dc4373a52ce8c3b0c2232`.
- Android minimum API: 24, below Airo's API 26 baseline.
- Native ABIs: arm64-v8a, armeabi-v7a, x86, x86_64.
- The arm64 text JNI library is 6,592,712 bytes before APK compression.

## Security Finding and Required Remediation

Both inspected Maven releases, `0.10.29` and `1.0.0`, include
`TasksStatsLoggerFactory` bytecode that always constructs
`TasksStatsProtoLogger`. That logger constructs `RemoteLoggingClient`, uses
Google DataTransport CCT, and submits app ID/version plus session, invocation,
latency, and error statistics.

This violates Airo's no-hidden-network and local-first boundary even though raw
text and vectors were not observed in the logging proto.

The open-source MediaPipe BUILD contract defaults to
`TasksStatsDummyLogger`; remote logging is enabled only by the internal
`ENABLE_TASKS_USAGE_LOGGING=1` build define. Therefore this slice must:

1. reproducibly derive a local `tasks-core:0.10.29` AAR from the verified
   upstream AAR;
2. replace `TasksStatsLoggerFactory` with the upstream-equivalent no-op factory;
3. remove remote/proto logger classes;
4. exclude DataTransport dependencies from the resolved graph;
5. retain upstream Apache-2.0 license/NOTICE and record the modification;
6. fail a repository security check if remote logger classes, the CCT backend,
   or its log-source string appear in the provider artifact/dependency graph.

If these checks cannot be made deterministic, implementation stops and the
published SDK remains blocked.

## Cross-Agent Contract

### Core provider API

The `core_ai` contract exposes:

- a stable model descriptor with model ID, revision, dimensions, and SHA-256;
- a provider interface with asynchronous `embed` and `close`;
- immutable success values containing only the generated vector and descriptor;
- typed failure codes for unavailable platform, missing model, integrity
  mismatch, unsupported dimensions, invalid input, initialization failure,
  inference failure, cancellation, and closed provider.

Failure diagnostics contain stable codes only. They never include input text,
vectors, filesystem paths, stack traces, or model bytes.

### Platform adapter

`platform_text_embeddings` accepts a caller-owned local model path and expected
descriptor. It does not download, persist, or delete the model.

Android method-channel methods:

- `initialize`: validate model presence, SHA-256, and output dimension on a
  background executor; return an opaque session handle.
- `embed`: accept a session handle and non-blank UTF-8 text no larger than
  50 KB; run MediaPipe inference on the session executor.
- `close`: close and remove the session; repeated close is safe.

The channel returns stable primitive maps only. It never logs arguments or
includes input text/path/vector data in errors.

The native plugin owns executor shutdown and closes every active TextEmbedder
on engine detach.

## Release Composition

- The package is required only by the full Android profile when the provider
  is composed.
- The TV and Coins pubspecs do not reference it and declare it excluded.
- No model is bundled in any APK.
- Unsupported platforms return a typed unavailable result without channel
  invocation.
- Rollback is removal from the full profile plus deletion of the downloaded
  model through its future model-lifecycle owner.

## Deterministic Use Cases

### UC-355-P1: Local semantic embedding

Given a verified 384-dimensional model on disk, embedding a synthetic sentence
returns exactly 384 finite, unit-normalized float values with no network
requirement.

### UC-355-P2: Integrity rejection

Given a missing or tampered model, initialization returns the matching typed
failure and creates no live session.

### UC-355-P3: Contract mismatch

Given a valid MediaPipe model with 100 or 512 output dimensions, initialization
returns `unsupported_dimensions` and exposes no vector.

### UC-355-P4: Privacy-safe failure

Given input containing a unique canary, every public failure, log capture, and
diagnostic omits the canary, model path, and vector values.

### UC-355-P5: Release exclusion

TV and Coins dependency graphs and APKs contain neither the provider package,
MediaPipe text JNI libraries, nor the converted model.

### UC-355-P6: Lifecycle cleanup

Closing a session releases MediaPipe resources; further embedding returns
`provider_closed`. Engine detach closes remaining sessions and stops executors.

## Automation Flows

### AUTO-355-P1: Host contract tests

Use fakes to prove success, every failure mapping, immutability, input limits,
idempotent close, and redaction without loading Flutter engine/native code.

### AUTO-355-P2: Dependency security audit

Rebuild the patched AAR from pinned input, verify input/output hashes, inspect
classes and Gradle dependencies, and fail on remote logging or DataTransport.

### AUTO-355-P3: Profile gates

Run module manifests, build-profile checks, variant pubspec checks, and worker
offload policy. Assert full inclusion and TV/Coins exclusion.

### AUTO-355-P4: Physical Pixel 9 inference

On the user-approved Pixel 9, use a current full-profile build and the verified
model. In airplane mode, run fixed synthetic embeddings, validate 384
dimensions/norm/determinism/latency, inspect redacted logs and network stats,
then clean up the test model/session without clearing unrelated app data.

## Testing Strategy

Follow red-green-refactor:

1. Fail contract tests before types exist.
2. Implement the minimal immutable framework contract.
3. Fail platform tests before channel mapping exists.
4. Implement the Dart adapter with an injectable client.
5. Derive and audit the telemetry-free AAR.
6. Implement Android sessions on a background executor.
7. Run focused Dart/Kotlin analysis/tests and build the full APK.
8. Complete the Pixel 9 physical acceptance flow.

Package-wide baseline failures outside the touched provider remain recorded,
not silently repaired in this slice.

## Boundaries

### Always

- Keep text/model work off the UI isolate and Android main thread.
- Verify model SHA-256 before initialization.
- Keep model lifecycle caller-owned.
- Preserve typed redacted failures.
- Keep the provider release-selectable.

### Ask first

- Publish or upload the 90 MB model artifact.
- Add another model/source/license.
- Add durable storage or a schema migration.
- Enable remote telemetry or network inference.

### Never

- Ship the inspected Maven SDK with its remote logger intact.
- Log raw text, vectors, model paths, or model bytes.
- Bundle the model in TV or Coins.
- Claim Memory Vault, meeting integration, or #355 complete from the provider
  package alone.

## Success Criteria

- MediaPipe generates real 384-dimensional unit vectors from the reviewed
  model.
- The Android provider works offline on the Pixel 9 and stays below the
  issue's 150 ms target for the accepted corpus flow.
- Dependency and artifact audits prove no remote usage logger/DataTransport.
- Full/TV/Coins release composition is deterministic.
- Missing, tampered, unsupported, failed, cancelled, and closed paths are
  typed and redacted.
- No model artifact is published without explicit supply-chain approval.
