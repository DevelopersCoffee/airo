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

## Airo TV Browser Viewport Qualification

For Airo TV IPTV release candidates, capture browser or qualification-app
screenshots for the viewports below before closing the UI release audit:

| Viewport | Qualification profile | Required result |
| --- | --- | --- |
| `1920x1080` | `Android TV 1080p` | TV shell renders without overflow, clipped actions, or hidden channel browsing |
| `1280x720` | `Android TV 720p` | At least one full channel row remains visible with a clear scroll affordance |
| `1024x576` | `Android TV Compact Browser` | Compact TV layout keeps primary actions and browsing reachable |
| `390x844` | `Mobile Browser Fallback` | The responsive mobile IPTV surface is used instead of the 10-foot TV shell |

Use `app/lib/main_qualification.dart` with
`packages/platform_device_qualification` when device screenshots are required.
The reusable `SimulatedDevice` profiles include this matrix so QA can capture
consistent evidence without adding Airo-TV-only viewport logic.

For repeatable browser evidence, run:

```bash
scripts/validate_airo_tv_browser_viewports.sh
```

The script builds the Airo TV web profile bundle from `app/lib/main_tv.dart`,
serves the deterministic IPTV fixture, checks the viewport matrix with
Playwright, and writes screenshots under
`artifacts/airo-tv-browser-viewports/`.

If the local Playwright browser cache is unavailable but Google Chrome is
installed, set `AIRO_TV_USE_SYSTEM_CHROME=1` for local evidence capture. CI
should continue to install and use the standard Playwright browser package.

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
