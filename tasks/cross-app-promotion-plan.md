# Plan: Cross-App Promotion (Airo Family Showcase)

Spec: [SPEC.md](../SPEC.md)

## Components

1. **`SiblingApp` model + registry** (`packages/core_product_shell`) — data
   shape, static manifest of 4 shipped apps, `isPublished` per platform,
   `ShellId`-based self-exclusion + qualification/patrol suppression.
2. **Shared icon assets** — copy each flavor's 1024px app icon into
   `packages/core_product_shell/assets/sibling_icons/`, wire into
   `pubspec.yaml`.
3. **`AppInfoTile` widget** — reads `package_info_plus`, renders
   version/build, tap reveals full detail (package name).
4. **`SiblingAppCard` widget** — icon + pitch + CTA (store link or
   disabled "Coming soon"), shared across phone/TV/coins/mind layouts.
5. **Settings hub wiring** — insert `AppInfoTile` + sibling-apps section
   into `settings_hub_screen.dart` (phone/coins/mind share this file per
   flavor pubspec override — verify) and `tv_settings_screen.dart` (TV
   rail/detail layout).
6. **Tests** — unit (registry filtering/exclusion), widget (tile + card
   rendering, CTA tap behavior), manual device verification.

## Dependency order

```
1 (model+registry) ──┬──> 3 (AppInfoTile)      [independent of registry]
                      └──> 4 (SiblingAppCard) ──> 5 (settings wiring)
2 (icon assets) ─────────────────────────────────> 4 (needs assets to render)
6 (tests) follows each component as it lands, not batched at the end
```

- Task 1 and Task 3 can run in parallel (no shared files).
- Task 2 (asset copy) must land before Task 4 references the asset paths.
- Task 5 depends on both 3 and 4 existing.
- Every task's own unit/widget tests are written alongside it (TDD), not
  deferred to a final task — Task 6 in the todo list covers only the
  cross-cutting manual device verification pass.

## Risks

- **Icon licensing/consistency**: reusing 1024px platform icons at small
  card size may need a resize/export step per flavor — check output looks
  correct before wiring, don't assume.
- **`settings_hub_screen.dart` reuse across flavors**: need to confirm via
  `pubspec_overrides.yaml`/entrypoint whether phone, coins, and mind
  literally share this one file or each flavor has its own copy — changes
  the file list in Task 5. Verify first, don't assume single-file reuse.
- **Store URLs unverified**: if Play Store/App Store listing URLs for
  Coins/Mind aren't confirmed live, Task 1's `isPublished` flags must
  default to `false` until confirmed — do not guess a URL.
- **No existing golden tests for this settings section** — new widgets skip
  goldens per spec Boundaries; if Chief UX Officer requests them at review,
  add as a follow-up task, not blocking v1.

## Verification checkpoints

- After Task 1: `flutter test` on `core_product_shell` passes, registry
  correctly excludes current flavor + suppresses qualification/patrol.
- After Task 4: widget test renders all non-self entries with correct
  published/coming-soon state.
- After Task 5: `flutter analyze` clean on `app/`; manual run on phone
  emulator/device confirms section appears without breaking existing
  settings flows.
- Final: physical Pixel 9 (phone/Coins/Mind) + Fire TV Stick 4K (TV) per
  spec Success Criteria — installed and not-installed sibling states both
  checked.
