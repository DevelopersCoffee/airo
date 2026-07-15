# core_watch_progress

Reusable Airo V2 continue-watching progress contracts.

This package defines:

- stable profile/media/source progress keys;
- local-only, opt-in, cloud-enabled, and disabled sync modes;
- deterministic revision, retention, deletion, and validation decisions;
- fake and no-op progress repositories for host-side tests.

Product packages should consume these contracts and keep only UX-specific
continue-watching layout, settings, and copy in app code.
