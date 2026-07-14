# core_remote_control

Reusable Airo V2 remote-control permission contracts.

This package defines:

- remote-control mode settings including local-only and approval-required mode;
- policy decisions for same-network, cloud, and recovery command routes;
- trusted-device, command envelope, receiver capability, profile, and optional
  session membership checks;
- fake and no-op permission sources for deterministic tests.

Product packages should consume these contracts and keep only UX-specific
settings, prompts, and copy in app code.
