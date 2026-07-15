# Core Remote Views

Compact remote view contracts for Airo V2 products.

This package is platform/framework code. Airo TV, Lite Receiver, mobile
companion, desktop companion, home-node, and future relay adapters consume these
models to exchange compact search, EPG, favorites, card, and ranked-stream views
without loading full datasets on constrained receivers.

## Scope

- Remote view and item models with stable IDs.
- Profile-specific render tiers and item limits.
- Expiry and cacheability validation.
- Compact item refs, thumbnail refs, playable state, and ranking.
- Redaction-oriented public maps and unsafe-reference validation.
- Fake provider for deterministic tests.

This package does not fetch datasets, render UI, open sockets, manage storage,
or call provider SDKs.
