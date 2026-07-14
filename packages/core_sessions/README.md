# Core Sessions

Playback session sync and handoff contracts for Airo connected devices.

This package is platform/framework code. Airo TV, companion apps, local LAN
adapters, command routing, playback engines, cloud coordination, and QA
automation consume these contracts instead of defining app-specific session or
handoff state.

## Scope

- Receiver-authoritative playback session snapshots.
- Playback ownership, operation authority, and ownership transfer policy.
- Route health event schema for event-driven playback state, buffer, volume,
  track, speed, health, and typed failure updates.
- Monotonic revisions and deterministic conflict policy.
- Privacy-safe local sync deltas with redacted payload handles.
- Two-phase handoff preflight and phase records.
- No-op and fake session repositories and route health sinks for host-only
  tests.

This package does not implement cloud orchestration, WebSocket transport,
encrypted persistence, playback execution, route health collection, device
picker UI, or Airo TV screens.
