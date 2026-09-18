# Changelog

## 1.1.0

- Added `PushWakePolicyEngine` and `PushWakeOutcome` state machine (send, visibleNotification, localReconnect, userActionRequired, deny, noOp).
- Added `NotificationRouteNormalizer` for legacy route mapping and payload deep-link parsing.
- Added `module.yaml` for monorepo council ownership (`platform_core`).

## 1.0.0

- Initial release of `airo_notifications`.
- Introduced `AiroAlert`, `AiroNotificationGroup`, `AiroTaskReference`, `AiroNotificationAction`, and `AiroGroupingStrategy`.
- Built `AiroNotificationEngine` with timezone-aware scheduling, `AlertStore` persistence, `GroupingEngine`, and `FakeAiroNotificationEngine` testing harness.
