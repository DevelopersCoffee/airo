## Agent

**Agent:** agent/mobile-ui

## Task Details

**Estimate (hours):** 16

**Priority:** P1

## Description

Reduce wasted vertical chrome on phones by consolidating shell and native
header behavior into a compact shell-owned top bar model with centrally
managed overflow actions.

## Critical Agent Gate

**Problem:** The app can consume too much vertical space on mobile because
shell-level chrome, route-level headers, and per-screen actions are not
consistently budgeted or centralized.

**User / actor:** Mobile users navigating primary destinations and engineers
adding actions to shell-mounted screens.

**Framework or application layer:** Mixed

**Owning agent:** agent/mobile-ui

**Reviewing agents:** agent/core-architecture, agent/qa-testing

**Impacted modules/files:** `app/lib/core/app/app_shell.dart`,
`app/lib/core/app/app_shell_chrome.dart`,
`app/lib/core/providers/navigation_provider.dart`, route root screens under
`app/lib/features/**/presentation/screens/*.dart`

**Base branch/worktree:** confirmed from latest `origin/main`: yes

**Open questions:** Which root-route actions stay visible in the top bar, and
which move into overflow? Should phone overflow use a top-right menu, bottom
sheet, or drawer per route family?

**Decision:** Ready

## Feature Packet

**Contract:** Shell-owned routes must render a single compact header with a
bounded visible action budget. Secondary actions are declared centrally and
rendered through a shared overflow affordance.

**Deterministic use cases:**
- Shell root routes show only one visible top header on phones
- Root-route action sets are configured centrally instead of embedded in screen
  `AppBar`s
- Overflow actions remain reachable on narrow screens without reintroducing
  duplicate chrome
- Larger layouts can expand actions without changing route ownership rules

**Automation flows:**
- Widget tests for compact shell header rendering on phone widths
- Route/widget tests for overflow action availability on at least one
  shell-owned screen
- Explicit device verification notes for Android emulator or physical Android
  when validating touch density

**Security/privacy posture:** Preserve access to profile, notifications, and
auth actions without exposing hidden privileged actions.

**Eval plan:** `flutter analyze`, targeted widget tests, and explicit mobile
verification of header density.

**Observability/traces:** Not required.

**Rollback/migration plan:** Keep per-route compatibility shims while migrating
screens to shell-declared actions.

**Verification environment:** Host-only / Android Emulator with explicit opt-in

**Android Emulator risk accepted?** Yes (`AIRO_ALLOW_ANDROID_EMULATOR=true`)

## Acceptance Criteria
- [ ] Mobile shell routes render one compact top header with no duplicate
      native header
- [ ] Route action affordances are declared centrally for shell-owned roots
- [ ] Narrow-screen overflow behavior is shared and documented
- [ ] Widget tests cover compact header and overflow behavior

## CI Checklist
- [ ] `act` local run passed
- [ ] `flutter analyze` clean
- [ ] `flutter test` passes
- [ ] Device-only checks identify the exact environment used
- [ ] Android Emulator was not used unless the issue explicitly accepts the
      risk
- [ ] Unit tests added
- [ ] Widget/golden tests added (if UI)
- [ ] Docs/ADRs updated (if applicable)

## Files to Modify
```
app/lib/core/app/app_shell.dart
app/lib/core/app/app_shell_chrome.dart
app/lib/core/providers/navigation_provider.dart
app/lib/features/**/presentation/screens/*.dart
app/test/core/app/*.dart
app/test/core/providers/*.dart
```

## Dependencies

- `#398` header ownership consolidation
- `#399` theme tokens and navigation centralization

## Release Note Required?
yes - mobile shell chrome will become denser and more consistent across primary
destinations
