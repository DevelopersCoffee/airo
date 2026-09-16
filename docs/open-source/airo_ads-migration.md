# Migration Record: `airo_ads`

> **Status**: Completed & Verified  
> **Original Location**: `packages/platform_ads`  
> **New Public Repository**: [DevelopersCoffee/airo_ads](https://github.com/DevelopersCoffee/airo_ads)  
> **Consumed Remote Version**: `airo_ads: ^1.0.0` (Remote Git / Pub Dependency)

---

## 1. Migration Overview

1. Extracted Google Mobile Ads wrapper, AdMob Native cards, non-intrusive in-stream Pause Ads, lower-third overlays, VAST/VMAP ad tag parser, and pure Dart frequency policy engine from `packages/platform_ads` into standalone repository [`DevelopersCoffee/airo_ads`](https://github.com/DevelopersCoffee/airo_ads).
2. Built standalone package with zero-crash safe web/desktop stubs, comprehensive interactive `example/` app, `.github/workflows/ci.yml` and `.github/workflows/publish.yml` actions.
3. Verified zero analyzer issues (`flutter analyze` - 0 issues), 100% unit test pass rate (10/10 tests), and clean pub.dev dry-run validation (`dart pub publish --dry-run` - 0 warnings).
4. Connected monorepo `packages/platform_ads` and app entrypoints (`app/lib/aika_ads/aika_ads.dart`) to re-export and consume `airo_ads`.

---

## 2. Monorepo Integration

In `packages/platform_ads/pubspec.yaml`:

```yaml
dependencies:
  airo_ads:
    git:
      url: https://github.com/DevelopersCoffee/airo_ads.git
      ref: main
```
