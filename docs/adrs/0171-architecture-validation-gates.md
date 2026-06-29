# ADR 0171: Architecture Validation Gates

## Status
Accepted

## Context
As the AIRO monorepo scales, many developers and AI agents will contribute new capabilities. Without strict architectural enforcement, the boundaries between domains inevitably erode. A common failure mode is feature packages bypassing abstractions (e.g., calling `dart:io` to read a model file directly, or calling `drift` to write a custom query). This couples feature logic to specific physical infrastructure, making migration, testing, and caching incredibly difficult. 

To preserve the integrity of Program 0 (the foundation platform), we need automated, build-breaking gates that prevent architectural drift.

## Decision
We establish **Architecture Validation Gates** that run statically against the repository in CI.

1. **Forbidden Imports List:** A strict whitelist governs low-level capabilities. For example, `dart:io` may only be imported by `platform_filesystem` and `platform_storage`.
2. **Implementation Hiding:** Core platform types must be exported as `abstract interface class`. Concrete implementations (like `DefaultFileManager` or `AppDatabase`) must not be exported via barrel files.
3. **CI Integration:** We introduce a custom Dart analyzer script (`scripts/verify_architecture.dart`) which parses package imports. If a forbidden import is detected outside its permitted boundary, the CI build will fail.

## Consequences
**Positive:**
- Platform boundaries are mathematically enforced. It is impossible to accidentally couple a UI widget to an SQLite transaction.
- Promotes dependency injection through Riverpod.
- Forces all teams to collaborate on platform capabilities rather than building ad-hoc local solutions (e.g. if you need to zip a file, it must be added to `platform_filesystem` rather than your feature package).

**Negative:**
- Occasionally slows down development when an engineer needs a primitive capability that hasn't been abstracted yet, forcing them to contribute to the platform package first.
