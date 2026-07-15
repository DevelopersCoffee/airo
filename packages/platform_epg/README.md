# Platform EPG

Shared EPG contracts for Airo V2 products.

This package is platform/framework code. Airo TV, Lite Receiver, future
companion nodes, and distributed EPG workers consume these contracts to exchange
compact current/next guide slices without forcing constrained receivers to load
or parse full XMLTV datasets.

## Scope

- Compact EPG programs and channel entries.
- Current/next selection from a small program window.
- XMLTV programme summary ingestion through `core_native` into compact
  current/next repository windows.
- Compact EPG slices with availability and expiry.
- Repository boundary with no-op and in-memory fake implementations.
- Redacted EPG source references that reject raw URLs, local paths, local IP
  values, and credential-like values.
- Distributed EPG worker capability, sync request, snapshot manifest, and
  validation contracts for delegated compact guide processing.
- Fake and no-op distributed worker adapters for deterministic automation.

This package does not render guide UI, persist full guide data, import vendor
SDKs, open sockets, transfer payloads, or start playback.
