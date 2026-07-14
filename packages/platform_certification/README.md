# Platform Certification

Shared device certification contracts for Airo V2 products.

This package is platform/framework code. Airo TV, QA automation, release gates,
and future device-lab tooling consume these contracts to decide whether a
device class can be advertised as certified, compatible, experimental, or
unsupported.

## Scope

- Versioned certification matrix manifests.
- Cross-platform validation matrix manifests.
- Device target classes for Airo TV legacy/Lite Receiver support.
- Certification gates with required evidence kinds.
- Validation gates across TV, companion, desktop, web receiver, and cloud
  surfaces.
- Evidence records and deterministic evaluation results.
- Default Airo TV legacy certification matrix for API 26/28 and Fire TV legacy
  device classes.
- Default Airo TV legacy distribution matrix for Google Play TV, Amazon
  Appstore, direct APK, and operator-box channels.
- Default Airo cross-platform validation matrix for Airo TV v2 platform
  hardening.
- Benchmark device-class gates for constrained TV, standard TV, mobile
  companion, and desktop companion performance/support claims.
- Fake and no-op benchmark evidence providers for deterministic release
  automation.

This package does not collect device evidence, run benchmarks, upload logs,
render UI, upload store listings, or submit store releases.
