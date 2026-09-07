# Migration Record: `run_off_main`

> **Status**: Completed & Verified  
> **Original Location**: `packages/core_workers`  
> **New Public Repository**: [DevelopersCoffee/run_off_main](https://github.com/DevelopersCoffee/run_off_main)  
> **Consumed Remote Version**: `run_off_main: ^1.0.0` (Remote Git Dependency)

---

## 1. Migration Overview

1. Extracted isolate engine logic from `packages/core_workers` into standalone repository [`DevelopersCoffee/run_off_main`](https://github.com/DevelopersCoffee/run_off_main).
2. Added `TimelineTask` DevTools microsecond task tracing, `forceInline` deterministic test flag, and `OffMainWorkerExecutor` dependency injection class.
3. Published initial release `v1.0.0` to GitHub.
4. Updated `packages/core_workers/pubspec.yaml` to depend on `run_off_main` remotely.
5. Re-exported `package:run_off_main/run_off_main.dart` from `core_workers` to preserve full backwards-compatibility across the monorepo.

---

## 2. Monorepo Integration

In `packages/core_workers/pubspec.yaml`:

```yaml
dependencies:
  run_off_main:
    git:
      url: https://github.com/DevelopersCoffee/run_off_main.git
      ref: main
```
