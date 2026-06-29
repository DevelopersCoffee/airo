# Background Processing Validation

Deterministic validation runbook for issue `#518` and release candidates that
depend on background sync, background downloads, or restart-safe work
execution.

This runbook separates host-runnable checks from Android/device-only lifecycle
cases that depend on OS process management, reboot handling, and battery
policies.

## Automated Checks

Run the shared background-processing validation suite from the repository root:

```sh
make test-background-processing
```

This command currently covers:

- `app/test/core/sync/background_sync_service_test.dart`
  - platform registration argument wiring
  - cancel/re-register behavior
  - foreground `syncNow()` delegation
  - sync status stream exposure
  - battery-saver configuration defaults
- `packages/core_data/test/sync/sync_service_test.dart`
  - immediate high-priority sync while online
  - offline no-op behavior
  - failure accounting and retry metadata
  - connectivity-triggered processing
  - duplicate/concurrent processing suppression
  - stopped service no longer scheduling work

## Host-Runnable Acceptance

The automated portion passes when:

- the test command succeeds with no failing tests
- no duplicate sync processing occurs under concurrent calls
- offline mode leaves queued work pending instead of attempting sync
- failed syncs record retry metadata instead of being dropped silently
- battery-saver defaults preserve the slower charging-only cadence

## Device-Only Manual Matrix

These checks still require a physical Android device or an explicitly approved
emulator path because they depend on OS lifecycle behavior outside host tests.

| Scenario | Steps | Expected |
| --- | --- | --- |
| App killed | Queue syncable work, force-stop app, relaunch | Pending work is still present and can be processed |
| Device reboot | Queue work, reboot device, relaunch app | Pending work survives reboot and can be processed |
| Battery optimization | Enable battery saver / optimization | Background processing behavior matches documented constraints |
| Background restrictions | Apply OS background restriction | App degrades safely without duplicate work or crashes |
| Work rescheduling | Register, cancel, and register again | Only one effective registration remains |
| Duplicate workers | Trigger sync from resume/connectivity/manual paths quickly | No duplicate processing of the same pending operation |
| Progress persistence | Start long-running work, background app, resume | Progress/pending count remains consistent |

## Suggested Android Checks

Use a connected device when possible:

```sh
make run-android-auto
```

Then manually verify:

1. Start a sync or download-related task, background the app, and relaunch it.
2. Force-stop the app and confirm the next eligible launch or worker pass does
   not duplicate the scheduled work.
3. Reboot the device and confirm expected work is re-registered.
4. Enable battery saver or app restrictions and record any scheduler
   degradation.
5. Confirm any visible progress state matches the persisted or native worker
   state.

## Evidence to Attach Before Closing

Before issue `#518` can be closed, attach:

- output from `make test-background-processing`
- device notes for the manual matrix above
- any deviations, waivers, or known platform limitations for the release

## Release Rule

Do not mark background-processing validation complete until:

1. `make test-background-processing` passes.
2. The relevant Android/device matrix items have been exercised for the changed
   feature.
3. Any skipped device-only check is explicitly waived in the PR or release
   notes.
