# Core AI Delegation

Shared AI search delegation contracts for Airo V2 products.

This package is platform/framework code. Airo TV, Lite Receiver, mobile
companion, desktop companion, home-node, and future cloud relay adapters consume
these contracts to route AI search work without bundling AI runtimes into every
receiver build.

## Scope

- Redacted AI search input values.
- Delegation candidates, privacy modes, capabilities, and route decisions.
- Deterministic route blocker codes.
- Search result envelopes with processing-location disclosure.
- No-op provider for unavailable companion/cloud paths.

This package does not call model providers, transcribe audio, discover devices,
open sockets, encrypt transport payloads, render UI, or collect analytics.
