# Core Presence

Device presence lease contracts for Airo V2.

This package is platform/framework code. Airo TV, companion apps, cloud
orchestration, backend adapters, device pickers, command routing, and QA
automation use these contracts to evaluate expiring device presence without
coupling to an app UI, provider SDK, socket, or storage engine.

## Scope

- Presence lease records with fixed clocks, sequence numbers, lifecycle, status,
  visibility, visible capabilities, heartbeat interval, and expiry.
- Heartbeat requests that update leases deterministically.
- Freshness policy for stale sequence, expired leases, heartbeat cadence, lease
  duration, registered-device matching, revocation, reset state, and visibility.
- Fake and no-op presence stores for host-side tests.

This package does not open sockets, select a cloud provider, persist backend
records, send push notifications, execute commands, render UI, or proxy media.
