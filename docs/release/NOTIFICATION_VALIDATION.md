# Notification Validation

Deterministic validation runbook for issue `#515`.

This runbook covers the framework-owned notification scheduler contract that can
be verified on the host, and separates the remaining Android/device-only cases
that still depend on OS presentation and tap-routing behavior.

## Automated Checks

Run the focused notification validation suite from the repository root:

```sh
make test-notification-validation
```

This command currently covers:

- `app/test/features/agent_chat/data/services/agent_notification_scheduler_test.dart`
  - duplicate reminder suppression at the scheduler layer
  - stable notification payload generation for deep-link metadata
  - completion bookkeeping for reminders that repeat until done
  - persistence recovery and scheduled ordering
- `app/test/features/agent_chat/data/services/notification_navigation_service_test.dart`
  - payload-to-route resolution for explicit deep links
  - fallback routing for category-only payloads
  - launch-payload and live-tap navigation handling
- `app/test/features/agent_chat/presentation/screens/notifications_screen_test.dart`
  - route-state filtering for category-specific notification views

## Host-Runnable Acceptance

The automated portion passes when:

- the test command succeeds with no failing tests
- scheduling the same reminder twice results in one stored reminder and one
  platform scheduling call
- the emitted notification payload preserves the intended deep-link context
- notification taps can be resolved into an in-app route deterministically
- category-specific routes land on the intended notification screen state
- completion awards points once and cancels the follow-up notification when the
  policy is `daily_until_done`
- stored reminders reload in chronological order from persistence

## Device-Only Manual Matrix

These checks still require a physical Android device because they depend on OS
notification presentation, launcher state, and notification-tap routing.

| Scenario | Steps | Expected |
| --- | --- | --- |
| Recording notification | Start a recording flow that schedules a reminder | OS notification appears with the expected title/body |
| Download progress | Trigger a local model download and background the app | Progress notification updates instead of duplicating |
| Completion | Let a download or recording complete | Completion notification replaces progress state cleanly |
| Failure | Force a failing download/recording path | Failure notification is visible and distinct from success |
| Deep link | Tap the notification from the shade | App opens the intended screen/state for that payload |
| Foreground suppression | Keep the app foregrounded during the same event | App does not spam duplicate visible notifications |

## Evidence to Attach Before Closing

Before issue `#515` can be closed, attach:

- output from `make test-notification-validation`
- `adb devices -l` output showing the Android device used for manual checks
- notes for the device-only matrix above, including any waivers or platform
  limitations
