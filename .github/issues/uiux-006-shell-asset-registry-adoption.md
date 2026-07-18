## Agent

**Agent:** agent/mobile-ui

## Task Details

**Estimate (hours):** 12

**Priority:** P1

## Description

Finish adoption of the shared shell asset registry so shell-owned imagery,
icons, and branding references stop leaking into feature code as raw asset
paths.

## Critical Agent Gate

**Problem:** Shell asset centralization exists only partially in code. Raw
shell imagery references still appear in feature screens, which weakens UI
consistency and makes branding changes expensive.

**User / actor:** End users consuming shared app chrome and engineers updating
shell visuals.

**Framework or application layer:** Mixed

**Owning agent:** agent/mobile-ui

**Reviewing agents:** agent/core-architecture, agent/docs, agent/qa-testing

**Impacted modules/files:** `app/lib/shared/assets/shell_asset_registry.dart`,
`app/lib/shared/widgets/*.dart`, feature screens that still reference shell
imagery directly, and supporting standards docs if the contract changes.

**Base branch/worktree:** confirmed from latest `origin/main`: yes

**Open questions:** Which visuals are truly shell-owned versus feature-owned,
and do we need tokenized variants for light/dark or platform-specific
branding?

**Decision:** Ready

## Feature Packet

**Contract:** Shell-level assets are referenced through a shared
registry/access layer. Feature code may only consume named shell assets, not
embed raw shell asset paths.

**Deterministic use cases:**
- Shared shell backdrop/icon usage resolves through the registry
- Branding swaps do not require editing multiple feature screens
- Static analysis/search shows no remaining raw shell asset paths in app shell
  surfaces

**Automation flows:**
- Static verification or tests prove shell widgets compile against the registry
- Targeted grep-based verification is recorded in the issue or PR notes

**Security/privacy posture:** None beyond preserving safe local asset loading
behavior.

**Eval plan:** `flutter analyze`, targeted tests, and static verification of
raw asset path removal.

**Observability/traces:** Not required.

**Rollback/migration plan:** Registry aliases can remain while downstream
screens migrate in batches.

**Verification environment:** Host-only

**Android Emulator risk accepted?** No

## Acceptance Criteria
- [ ] Shell-owned imagery references use the shared asset registry/access layer
- [ ] Remaining raw shell asset paths in app shell surfaces are removed or
      explicitly exempted
- [ ] Ownership rules are reflected in standards/docs if the contract evolves
- [ ] Verification records which raw references were migrated

## CI Checklist
- [ ] `act` local run passed
- [ ] `flutter analyze` clean
- [ ] `flutter test` passes
- [ ] Device-only checks identify the exact environment used
- [x] Android Emulator was not used unless the issue explicitly accepts the
      risk
- [ ] Unit tests added
- [ ] Widget/golden tests added (if UI)
- [ ] Docs/ADRs updated (if applicable)

## Files to Modify
```
app/lib/shared/assets/shell_asset_registry.dart
app/lib/shared/widgets/*.dart
app/lib/features/**/presentation/screens/*.dart
app/test/**/*.dart
docs/standards/mobile-ui-ux-standards.md
```

## Dependencies

- `#400` shell asset governance groundwork
- `#399` theme tokens and navigation centralization

## Release Note Required?
no
