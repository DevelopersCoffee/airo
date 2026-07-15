# Worker Offload Policy Audit

Issue: #788
Date: 2026-07-15

## Policy

Airo TV presentation code must not own heavy parsing, serialization, cache
hydration, or direct isolate scheduling. Reusable work belongs behind platform
packages and must use `platform_worker_jobs` / `AiroWorkerExecutor` or a
native/Rust backend.

Run:

```bash
scripts/check-worker-offload-policy.sh
```

The check fails when:

- `compute()` or `Isolate.run()` appears outside
  `packages/platform_worker_jobs/lib/src/worker_executor.dart`.
- `jsonDecode()`, `jsonEncode()`, newline-oriented parser splitting, or M3U
  markers appear in presentation, screen, widget, or Airo TV feature UI paths.

## Current Audit

Accepted platform worker boundary:

- `packages/platform_worker_jobs` owns direct isolate execution.
- `packages/platform_playlist_import` consumes `AiroWorkerExecutor` for M3U
  parse and structured cache JSON encode/decode.
- Airo TV consumes `platform_playlist_import`; it does not parse user playlists
  in screen/widget code.

Explicitly allowed current platform/domain serialization:

- Platform cache/storage repositories may use JSON for small persisted values
  when they are not presentation hot paths.
- Platform playlist cache JSON is allowed because it runs through
  `AiroWorkerExecutor`.
- Third-party package code under `third_party` is excluded from the repository
  policy check.

## Remaining Work

- #764: Move M3U parsing from Dart worker fallback to Rust core.
- #768: Add a streaming Rust XMLTV/EPG engine.
- #778: Add benchmark harness budgets for large playlist and worker pipelines.
- #779: Add device-class memory budgets and soak tests.
- #776: Continue storage consolidation and size guards for persisted payloads.
