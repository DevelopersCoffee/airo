# Migration Record: `iptv_org_api`

> **Status**: Completed & Verified  
> **Original Location**: `packages/platform_iptv_org_api`  
> **New Public Repository**: [DevelopersCoffee/iptv_org_api](https://github.com/DevelopersCoffee/iptv_org_api)  
> **Consumed Remote Version**: `iptv_org_api: ^1.0.0` (Remote Git Dependency)

---

## 1. Migration Overview

1. Extracted typed API client, ETag caching transport, isolate parser wrappers, and relational dataset indexer from `packages/platform_iptv_org_api` into standalone repository [`DevelopersCoffee/iptv_org_api`](https://github.com/DevelopersCoffee/iptv_org_api).
2. Upgraded package metadata to meet pub.dev 140/140 standards (MIT License, `analysis_options.yaml`, zero analyzer warnings, 36/36 unit test pass rate, GitHub Actions CI/CD).
3. Published initial release to GitHub repository.
4. Converted local `packages/platform_iptv_org_api` into a re-exporting monorepo shim pointing to remote `iptv_org_api`.
5. Verified 100% test pass rate and clean static analysis across both public repo and monorepo shim.

---

## 2. Monorepo Integration & Dependency Update

In `packages/platform_iptv_org_api/pubspec.yaml`:

```yaml
dependencies:
  iptv_org_api:
    git:
      url: https://github.com/DevelopersCoffee/iptv_org_api.git
      ref: main
```

In `packages/platform_iptv_org_api/lib/platform_iptv_org_api.dart`:

```dart
export 'package:iptv_org_api/iptv_org_api.dart';
```

---

## 3. Verification

```bash
cd packages/platform_iptv_org_api
flutter analyze  # 0 warnings
flutter test     # 36/36 passed
```

---

## 4. Rollback Procedure

If remote dependency resolution fails during local dev:
1. Re-add path dependency in `pubspec_overrides.yaml`:
   ```yaml
   dependency_overrides:
     iptv_org_api:
       path: ../../iptv_org_api
   ```
2. Run `flutter pub get`.
