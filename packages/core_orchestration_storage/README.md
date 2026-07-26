# core_orchestration_storage

Provider-neutral backend orchestration storage interfaces for Airo V2.

This package defines:

- logical backend collections for devices, presence, sessions, controllers,
  commands, and progress;
- aggregate storage health and privacy-safe snapshot models;
- a session controller membership store;
- fake and no-op aggregate storage implementations for host-side tests.
- versioned relational sync entities, per-field vector-clock merge policy,
  tombstones, and a transport-neutral secure/compressed sync engine contract.

Backend adapters should implement these interfaces. Airo TV app code should
consume platform services instead of importing provider SDKs directly.
