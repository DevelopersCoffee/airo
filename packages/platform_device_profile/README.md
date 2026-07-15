# platform_device_profile

Runtime legacy device profile contracts for Airo TV.

This package defines:

- privacy-safe runtime device signals;
- deterministic support tier and product profile classification;
- dynamic reclassification into Legacy Receiver Mode under pressure;
- memory budgets for Android TV device classes;
- fake and no-op profilers for host-side tests.

Product code should consume these decisions instead of hard-coding device tiers
or OS-version-only checks in Airo TV screens.

## Memory Budgets

`AiroRuntimeMemoryBudgetPolicy` maps runtime device profiles or raw runtime
signals to stable memory ceilings that Airo TV, shared UI, and performance
harnesses can consume:

- 1 GB constrained TV: `<250 MB` steady RSS, `<350 MB` peak RSS, `128 MB`
  Dart heap, `16 MB` image cache, at most two retained channel-list copies,
  and `<1 MB/h` playback soak drift.
- 2 GB standard TV: `<384 MB` steady RSS, `<512 MB` peak RSS, `192 MB`
  Dart heap, and `32 MB` image cache.
- 3 GB+ expanded TV: `<512 MB` steady RSS, `<768 MB` peak RSS, `256 MB`
  Dart heap, and `64 MB` image cache.

High runtime memory pressure forces the constrained budget. Critical pressure
or sub-1 GB memory maps to an unsupported budget so certification and soak
harnesses can fail fast.
