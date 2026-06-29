# UI Responsiveness Validation

Use this runbook for issue `#519` and for release candidates that touch shared
layout, navigation, dialogs, or screen-state handling.

## Deterministic Local Checks

Run the shared responsiveness suite:

```bash
make test-ui-responsive
```

Current automated coverage proves:

- compact layouts use bottom navigation instead of desktop rail patterns
- wider layouts switch to navigation rail behavior
- large font scaling does not break the shared adaptive navigation shell
- adaptive dialogs use mobile bottom-sheet presentation on narrow widths
- adaptive dialogs preserve bottom keyboard insets on mobile
- adaptive dialogs use centered desktop dialogs on wide layouts

## Manual Device Matrix

The following still require manual verification because they depend on
device-only behavior, full-screen system UI, or feature-specific states:

| Area | What to verify | Preferred environment |
| --- | --- | --- |
| Orientation changes | Portrait to landscape transitions keep navigation and app bars usable | Physical Android tablet or phone |
| Split screen | Bottom navigation and dialogs remain tappable at reduced width | Android tablet / desktop window resize |
| Foldables | Hinge/posture changes do not clip shell chrome or dialogs | Foldable emulator or device |
| Tablets | Wide layouts keep all major destinations visible and readable | Tablet or large desktop window |
| Dynamic font scaling | Text at 150%-200% remains readable without blocked actions | Android accessibility settings |
| Dark mode | Contrast remains acceptable and icons/text remain visible | Android or iOS dark mode |
| Accessibility | Screen reader order, labels, and focus traversal remain correct | TalkBack / VoiceOver |
| Keyboard handling | Inputs and submit buttons stay above the software keyboard | Physical Android/iOS |
| Offline state | Shell and feature screens show explicit offline messaging | Device with network disabled |
| Empty state | Core screens show usable empty-state copy and actions | Feature-specific manual flows |
| Error state | Recoverable failures show actionable retry/error UI | Feature-specific manual flows |
| Loading state | Long-running operations show progress without layout jumps | Feature-specific manual flows |

## Suggested Android Checks

Use a connected Android device when possible:

```bash
make run-android-auto
```

Then manually verify:

1. Enable large display text and navigate through the primary tabs.
2. Open any keyboard-driven dialog or form and confirm the submit action stays
   visible.
3. Rotate the device and confirm shell chrome and primary content remain usable.
4. Use Android split screen and confirm compact navigation still exposes all
   destinations through overflow when width shrinks.

## Release Rule

Do not mark UI responsiveness validation complete until:

1. `make test-ui-responsive` passes.
2. The manual matrix items relevant to the changed feature have been checked.
3. Any skipped device-only check is explicitly waived in the release notes or PR.
