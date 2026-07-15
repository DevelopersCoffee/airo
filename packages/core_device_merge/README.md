# Core Device Merge

Local and cloud device merge contracts for Airo V2.

This package is platform/framework code. Airo TV, companion apps, device
pickers, cloud orchestration, routing, presence, and QA automation consume these
contracts to merge LAN advertisements and cloud device records without
duplicating trust, visibility, or freshness rules in product UI.

## Scope

- Local device observations from connected-node advertisements.
- Cloud device observations from registered device records and presence leases.
- Deterministic merge policy for duplicate records, local/cloud preference,
  local-only mode, trust, revocation, reset, capability, visibility, and
  lifecycle blockers.
- Privacy-safe merged device summaries for device pickers.
- Fake and no-op merge sources for host-side tests.

This package does not browse the LAN, open sockets, choose a backend provider,
store records, execute routes, render UI, or proxy media.
