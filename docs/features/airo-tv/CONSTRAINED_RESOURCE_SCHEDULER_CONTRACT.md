# Airo TV Constrained Resource Scheduler Contract

Issue: ATV-054
Package: `platform_worker_jobs`
Layer: Platform framework, consumed by Airo TV application code

## Purpose

Airo TV Gen 2 must keep playback, pairing, focus navigation, and user state
responsive on constrained receiver hardware. The constrained resource scheduler
turns a receiver resource snapshot into a deterministic plan that application
code can consume before starting background work.

This contract belongs in platform code because the rules are reusable across TV,
mobile receiver mode, and future edge workers. Airo TV should consume the plan
instead of duplicating mode, budget, and cleanup decisions in screen or feature
code.

## Platform Contract

`AiroConstrainedResourcePolicy.evaluate` accepts an
`AiroWorkerResourceSnapshot` and returns an `AiroConstrainedResourcePlan`.

The plan includes:

- `mode`: stable resource mode id.
- `budget`: public heap, cache, network buffer, job, and player limits.
- `allowedJobKinds`: work the receiver can start now.
- `deferredJobKinds`: work that should wait for a healthier snapshot.
- `blockedJobKinds`: work that must not start in the current mode.
- `actions`: cleanup and preservation actions the runtime should apply.
- `reasons`: stable pressure reasons used to select the mode.
- `generatedAt`: plan generation time.

The public map intentionally contains only stable ids and numeric limits. It
must not contain media locations, local file paths, provider payloads, raw
diagnostics, or private access material.

## Modes

`normal` permits regular bounded work with a two-job cap and normal cache
budgets.

`playback_priority` activates during active playback. It preserves playback
recovery and protocol heartbeat jobs while deferring imports, indexing, and
artwork warmup.

`memory_conservation` activates for high memory or thermal pressure. It trims
artwork, clears off-screen artwork, stops enrichment, stops optional probing,
and blocks model, recording, and indexing work.

`low_storage` activates for high storage pressure. It allows cleanup and
database compaction, trims artwork and EPG caches, and blocks work that grows
local storage such as model downloads, recording preparation, and artwork
warmup.

`critical_protection` activates for critical memory, storage, or thermal
pressure. It keeps only playback recovery, protocol heartbeat, and cache cleanup
available.

## Default Budgets

| Mode | Flutter heap | Native heap | Artwork cache | EPG cache | DB cache | Network buffer | Jobs | Players |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `normal` | 256 MB | 192 MB | 48 MB | 32 MB | 48 MB | 24 MB | 2 | 1 |
| `playback_priority` | 192 MB | 160 MB | 24 MB | 16 MB | 32 MB | 16 MB | 1 | 1 |
| `memory_conservation` | 160 MB | 128 MB | 16 MB | 8 MB | 24 MB | 12 MB | 1 | 1 |
| `low_storage` | 160 MB | 128 MB | 16 MB | 8 MB | 24 MB | 12 MB | 1 | 1 |
| `critical_protection` | 128 MB | 96 MB | 8 MB | 4 MB | 12 MB | 8 MB | 1 | 1 |

## Airo TV Consumption

Airo TV app code should request a plan before starting non-playback work. If the
job kind is allowed, the app may proceed through the worker scheduler. If the
job kind is deferred, the app should enqueue the work for a later receiver
snapshot. If the job kind is blocked, the app should skip the work and surface a
recoverable state only when user action requires feedback.

Playback recovery, protocol heartbeat, and cache cleanup remain available in all
constrained modes. Favorites, progress, pairing state, and other user state must
be preserved before any cleanup action removes optional caches.

## Deterministic Use Cases

1. Active playback returns `playback_priority`, allows playback recovery and
   protocol heartbeat, and defers imports, indexing, and artwork warmup.
2. High memory pressure returns `memory_conservation`, clears optional artwork
   caches, stops enrichment and probing, and blocks model, recording, and
   indexing work.
3. High storage pressure returns `low_storage`, allows cleanup and database
   compaction, trims optional caches, and blocks downloads, recording
   preparation, and artwork warmup.
4. Critical thermal pressure returns `critical_protection`, allowing only
   playback recovery, protocol heartbeat, and cache cleanup.
5. Public plan maps expose stable ids and numeric budgets only.

## Automation Flows

- Unit tests assert the mode, budget, allowed jobs, deferred jobs, blocked jobs,
  and actions for normal, playback, memory, storage, and critical snapshots.
- Package checks run with `flutter test` and `flutter analyze --fatal-infos`
  from `packages/platform_worker_jobs`.
- Staged changes are scanned for whitespace errors and accidental sensitive
  terms before commit.
