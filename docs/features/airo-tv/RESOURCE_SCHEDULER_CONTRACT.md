# Resource Scheduler Contract

Status: v2 platform contract for ATV-035.

## Ownership

Resource scheduling is platform/framework behavior. Airo TV, Lite Receiver,
playback, playlist import, distributed EPG, stream health, cache cleanup,
protocol sync, and QA automation consume this contract instead of creating
feature-specific background job rules.

The contract lives in `packages/platform_worker_jobs` because the v2 plan names
worker-job infrastructure separately from playback, EPG, imports, analytics, and
background sync. Playback, playlist import, EPG, protocol, and cache modules own
their work payloads; this package only decides whether work can run under the
current resource snapshot.

## Non-Goals

This issue does not implement:

- isolate pools
- native worker execution
- OS background schedulers
- persistence
- telemetry export
- playlist parsing
- EPG processing
- stream probing
- playback execution
- app UI

## Contract Shape

`AiroWorkerJobDescriptor` describes a unit of work by stable id, job kind,
priority, execution mode, interruptibility, resource budget, creation/expiry
time, and network/charging/playback requirements.

`AiroWorkerResourceSnapshot` describes the receiver state at decision time:
playback state, focus/navigation activity, memory pressure, storage pressure,
thermal pressure, battery, charging, network state, and currently running jobs.

`AiroWorkerSchedulerPolicy` evaluates a descriptor against a snapshot and
returns an `AiroWorkerSchedulerDecision`.

Decision actions are:

- schedule
- defer
- throttle
- cancel
- reject

Decision codes cover schema/protocol mismatch, unsupported job kind, unsafe ids,
expired jobs, playback contention, focus contention, memory/storage/thermal
pressure, low battery, network limits, concurrency limits, budget overruns,
non-interruptible conflicts, unavailable adapters, and cancellation.

`AiroWorkerJobScheduler` is the provider boundary. `AiroNoOpWorkerJobScheduler`
rejects work for products without worker scheduling support.
`AiroFakeWorkerJobScheduler` records accepted or preemptive decisions for
deterministic host-side tests without spawning isolates or OS jobs.

## Privacy

Scheduler descriptors, snapshots, decisions, and diagnostics expose only stable
ids, job kinds, priorities, pressure levels, resource counts, resource budgets,
and decision codes. They must not expose raw media URLs, playlist URLs, EPG
URLs, request headers, local paths, local addresses, provider payloads,
credentials, media titles, viewing history, analytics payloads, or diagnostic
dumps.

## Automation

- Unit tests use fixed clocks and fixed resource snapshots.
- Policy tests cover accepted, deferred, throttled, cancelled, and rejected
  decisions.
- Adapter tests cover no-op unavailable behavior and fake scheduler recording.
- Diagnostics tests verify redacted stable output.
