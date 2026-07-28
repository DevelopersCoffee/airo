# Implementation Plan: #355 Telemetry-Free MediaPipe Provider

## Phase 1: Governance and Contracts

1. Record the dependency/model audit and cross-agent Feature Packet.
2. Freeze typed model/provider/failure contracts in `core_ai` with failing
   tests.
3. Implement immutable contracts and focused analysis.

## Phase 2: Telemetry-Free Dependency

4. Add a deterministic derivation script for the pinned upstream core AAR.
5. Replace only the stats factory and remove remote logger/proto classes.
6. Add license/NOTICE/modification records.
7. Add a security script that verifies hashes, classes, strings, and dependency
   exclusions.

## Phase 3: Platform Package

8. Create `platform_text_embeddings` with module ownership and profile policy.
9. Add failing Dart tests for channel mapping, integrity failures, redaction,
   input limits, and lifecycle.
10. Implement the injectable Dart adapter and unsupported-platform behavior.
11. Add the Android plugin using a background executor and opaque sessions.
12. Add focused Kotlin compilation/build validation.

## Phase 4: Release Composition

13. Include the package in the full profile only.
14. Explicitly exclude it from TV and Coins.
15. Run manifest, build-profile, pubspec variant, worker, dependency, and APK
    symbol gates.

## Phase 5: Physical Qualification

16. Reconnect the approved Pixel 9 and finish the pending reboot audit.
17. Install a current full-profile build replace-in-place.
18. Supply the verified model as test-only device state without clearing app
    data.
19. Run airplane-mode inference, deterministic fixtures, latency/memory,
    cleanup, redacted log, and network-stat checks.
20. Record evidence on #355 and keep it open until model distribution and
    consumer integration are complete.

## Checkpoints

- Contract checkpoint: no native or dependency changes.
- Security checkpoint: derived AAR has no remote logger/DataTransport.
- Platform checkpoint: focused tests and Android build pass.
- Device checkpoint: real 384-dimensional offline inference on Pixel 9.

## Rollback

- Remove the full-profile dependency.
- Delete the derived AAR and provider package.
- Leave `core_ai` provider interfaces available for an alternate runtime.
- Model deletion remains owned by the future model-lifecycle service.
