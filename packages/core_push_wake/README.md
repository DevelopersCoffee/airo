# core_push_wake

Provider-neutral push wake and notification fallback contracts for Airo V2.

This package defines:

- platform wake capability profiles;
- push wake requests and deterministic policy decisions;
- visible-notification, local-reconnect, user-action, denied, and no-op paths;
- fake and no-op wake dispatchers for host-side tests.

Backend/provider adapters should implement these interfaces. Product packages
should consume decision codes instead of assuming remote wake availability.
