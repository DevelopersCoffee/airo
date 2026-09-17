# Migration Record: `airo_notifications`

> **Status**: Completed & Verified  
> **Original Location**: Created Standalone Library & `packages/platform_notifications`  
> **New Public Repository**: [DevelopersCoffee/airo_notifications](https://github.com/DevelopersCoffee/airo_notifications)  
> **Published pub.dev Package**: [`airo_notifications`](https://pub.dev/packages/airo_notifications) (v1.1.0)

---

## 1. Migration Overview

1. Created native-first local alert runtime, task follow-up scheduling, and notification grouping/summarization engine as standalone public repository [`DevelopersCoffee/airo_notifications`](https://github.com/DevelopersCoffee/airo_notifications).
2. Defined `AiroAlert`, `AiroNotificationGroup`, `AiroGroupingStrategy`, `AiroTaskReference`, `AiroNotificationAction`, and `AlertStore` persistence interfaces.
3. Created `FakeAiroNotificationEngine` for 100% deterministic test coverage without native device dependencies.
4. Published release `v1.0.0` and upgraded to `v1.1.0` incorporating push-wake policy engine (`PushWakeOutcome` state machine: `send`, `visibleNotification`, `localReconnect`, `userActionRequired`, `deny`, `noOp`) and `NotificationRouteNormalizer`.
5. Created monorepo shim `packages/platform_notifications` re-exporting published `airo_notifications` contracts with `module.yaml` council ownership (`platform_core`).
6. Verified 100% test pass rate and clean static analysis across monorepo shims and standalone package.
