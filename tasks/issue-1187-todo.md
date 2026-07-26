# Issue #1187 Task Checklist

## Task 1: Harden `ModuleRegistry`

**Description:** Make invalid product composition fail deterministically.

**Acceptance criteria:**

- [x] Duplicate enabled module IDs throw a stable error.
- [x] Duplicate route paths and names throw a stable error.
- [x] Disabled modules remain safe no-ops.

**Verification:**

- [x] `flutter test` in `packages/core_product_shell`
- [x] `flutter analyze` in `packages/core_product_shell`

**Dependencies:** None

**Files likely touched:**

- `packages/core_product_shell/lib/src/module_registry.dart`
- `packages/core_product_shell/test/module_registry_test.dart`

**Estimated scope:** Small

## Task 2: Migrate TV composition

**Description:** Build TV's IPTV module registry explicitly and pass it through
bootstrap/provider/startup seams.

**Acceptance criteria:**

- [x] TV entrypoint contains no `FeatureRegistry` access.
- [x] Production TV registry contains IPTV only.
- [x] IPTV paths/names and provider behavior are unchanged.

**Verification:**

- [x] Focused `app/test/main_tv_*` tests pass.
- [x] Targeted `flutter analyze` covers touched TV files.

**Dependencies:** Task 1

**Files likely touched:**

- `app/lib/main_tv.dart`
- `app/lib/features/iptv/iptv_feature_module.dart`
- `app/test/main_tv_shell_test.dart`

**Estimated scope:** Medium

## Task 3: Migrate super-app composition

**Description:** Route mobile module composition through a mobile-scoped
registry without changing existing navigation.

**Acceptance criteria:**

- [ ] Super-app registry includes allowed mobile modules.
- [ ] Stable routes and startup behavior have parity tests.
- [ ] Legacy static registry is removable or explicitly bounded.

**Verification:**

- [ ] Focused mobile router/startup/widget tests pass.
- [ ] Targeted analyze passes.

**Dependencies:** Tasks 1-2

**Estimated scope:** Medium

## Task 4: Enforce product ship policy

**Description:** Validate focused product dependencies against package module
manifests.

**Acceptance criteria:**

- [ ] TV rejects packages marked `Never Ship` for TV.
- [ ] Coins rejects TV-only product modules.
- [ ] Validation is deterministic and documented.

**Verification:**

- [ ] Host-only policy script tests pass.
- [ ] Focused product dependency checks pass.

**Dependencies:** Tasks 2-3

**Estimated scope:** Medium
