# Core Cloud Orchestration

Optional cloud coordination boundary contracts for Airo V2.

This package is platform/framework code. Airo TV, companion apps, home nodes,
command routing, session sync, device registry, presence, recovery, backend
adapters, and QA automation consume these contracts to coordinate devices,
commands, state, and recovery without turning cloud into a media path.

## Scope

- Cloud orchestration capability manifests.
- Redacted orchestration requests for device registry, presence, command
  routing, state distribution, playback-ticket brokering, notification wake,
  recovery, and progress sync.
- Deterministic policy decisions for local-first behavior, trust/scopes,
  retention, payload size, revisions, duplicate commands, and no-media-proxy
  enforcement.
- Fake and no-op coordinators for host-side tests.

This package does not open sockets, choose a cloud provider, store backend
records, proxy media, issue real playback tickets, persist progress, send push
notifications, run entitlement checks, or render UI.
