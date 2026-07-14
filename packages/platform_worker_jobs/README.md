# Platform Worker Jobs

Shared resource scheduler contracts for Airo V2 worker jobs.

This package is platform/framework code. Airo TV, Lite Receiver, playback,
playlist import, distributed EPG, stream health, cache cleanup, protocol sync,
and QA automation consume these contracts to decide whether background work can
run under playback, focus, memory, storage, thermal, battery, and network
pressure.

## Scope

- Worker job descriptors with stable ids, kind, priority, execution mode,
  interruptibility, deadlines, and resource budgets.
- Resource snapshots for playback, focus/navigation, memory, storage, thermal,
  battery, network, and currently running work.
- Deterministic scheduler policy decisions with machine-readable blocker codes.
- Fake and no-op scheduler adapters for deterministic tests.

This package does not spawn isolates, run native workers, open sockets, persist
jobs, collect telemetry, request OS background permissions, execute playback,
parse playlists, process EPG data, or render UI.
