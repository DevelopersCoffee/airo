# platform_device_profile

Runtime legacy device profile contracts for Airo TV.

This package defines:

- privacy-safe runtime device signals;
- deterministic support tier and product profile classification;
- dynamic reclassification into Legacy Receiver Mode under pressure;
- fake and no-op profilers for host-side tests.

Product code should consume these decisions instead of hard-coding device tiers
or OS-version-only checks in Airo TV screens.
