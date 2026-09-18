# `airo_notifications`

Native-first local alert, notification grouping, task follow-up & scheduling execution engine for Flutter.

## Overview

`airo_notifications` acts as the execution layer between local AI engines (Aromind) or app features and native OS notification systems. Rather than exposing basic platform APIs, it provides semantic alert models (`notification`, `reminder`, `alert`, `task`), notification grouping/summarization strategies (`stack`, `summary`, `replace`, `merge`), persistent schedule query stores, and task action routing (`complete`, `snooze`, `dismiss`, `open`).

## Features

- **Semantic Alert Types**: Distinction between Notifications, Reminders, Alerts, and Tasks.
- **Timezone-Aware Scheduling**: Persistent scheduled alert store surviving reboots.
- **Grouping Strategies**: `stack`, `summary`, `replace`, and `merge` rules.
- **Task Action Routing**: Built-in `complete`, `snooze`, `dismiss`, and `open` callback stream.
- **Deterministic Test Harness**: `FakeAiroNotificationEngine` for unit testing without native device dependencies.

## Usage

```dart
import 'package:airo_notifications/airo_notifications.dart';

final alert = AiroAlert(
  id: 'followup_123',
  type: AiroAlertType.task,
  delivery: AiroDeliveryMode.scheduled,
  priority: AiroPriority.high,
  title: 'Follow up with Rahul',
  body: 'Deployment discussion',
  scheduledAt: DateTime.now().add(const Duration(hours: 12)),
  taskId: 'task_456',
  source: 'aromind',
);

await AiroNotifications.engine.schedule(alert);
```

## Scope: what this engine does and does not own

This package is a **generic** local-notification runtime: scheduling,
grouping, permission handling, deduplication, and a stable canonical payload
for deep-linking. It deliberately does **not** compute or own any
domain-specific gamification (streaks, points, or completion history) --
`markCompleted()` only flips an alert's status and cancels a
`follow_up_policy: 'daily_until_done'` OS notification. Consumers that want
their own completion bookkeeping on top of an `AiroAlert` (e.g.
`feature_mind`'s assistant reminders) compute it themselves and persist it
with the generic `AiroNotificationEngine.persist(alert)` upsert, which saves
whatever `AiroAlert` it is given verbatim with no interpretation.

## Android setup

Android hosts must ship a `@mipmap/ic_notification` icon -- see
[`ANDROID_SETUP.md`](./ANDROID_SETUP.md) for why `@mipmap/ic_launcher` crashes
the app on API 26+.
