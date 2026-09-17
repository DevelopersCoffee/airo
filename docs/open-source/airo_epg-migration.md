# Migration Record: `airo_epg`

> **Status**: Completed & Verified  
> **Original Location**: `packages/platform_epg`  
> **New Public Repository**: [DevelopersCoffee/airo_epg](https://github.com/DevelopersCoffee/airo_epg)  
> **Published pub.dev Package**: [`airo_epg`](https://pub.dev/packages/airo_epg) (v1.0.0)

---

## 1. Migration Overview

1. Extracted compact EPG contracts, XMLTV ingest, program reminders, sports desk models, and multi-source EPG resolution from `packages/platform_epg` into standalone repository [`DevelopersCoffee/airo_epg`](https://github.com/DevelopersCoffee/airo_epg).
2. Published release v1.0.0 to [`pub.dev/packages/airo_epg`](https://pub.dev/packages/airo_epg).
3. Converted local `packages/platform_epg` into a re-exporting monorepo shim pointing to `airo_epg`.
4. Verified 100% test pass rate (64/64) and 0 analyzer issues across both standalone repo and monorepo shim.
