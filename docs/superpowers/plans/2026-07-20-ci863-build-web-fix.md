# CI-863 build-web Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix `flutter build web` failing on `core_native/lib/src/frb_generated.dart:57` (`RustLibWire.fromExternalLibrary` tear-off type mismatch against `flutter_rust_bridge` 2.11.1's web platform types), so the `build-web` CI job and `flutter run -d chrome -t lib/main_tv.dart` both succeed.

**Architecture:** `packages/core_native/lib/src/frb_generated.dart:57` assigns `RustLibWire.fromExternalLibrary` (a tear-off) to the `wireConstructor` getter. `packages/core_native/lib/src/frb_generated.web.dart:279` declares `RustLibWire.fromExternalLibrary(ExternalLibrary lib)` taking one (ignored) parameter — the generated web binding class. The mismatch means the currently committed codegen output disagrees with what `flutter_rust_bridge` 2.11.1's web platform types expect at the call site. Fix path: regenerate the bindings with the pinned `flutter_rust_bridge_codegen` version; if the regen output is identical to what's committed, the disagreement is a genuine version skew and the `flutter_rust_bridge` pin must move to a version whose web wire-constructor shape matches.

**Tech Stack:** Dart, `flutter_rust_bridge_codegen` CLI, Rust (`core_native`'s companion crate), Flutter web target.

## Global Constraints

- Scoped to `packages/core_native` only — no unrelated core_native changes (per #863: "Not caused by CV-032/CV-012/airo-pro slice work — was already failing on main").
- No test changes expected — this is a codegen/build-config fix; the acceptance signal is the `build-web` CI job and local `flutter run -d chrome` both succeeding.
- Worktree: `.claude/worktrees/ci-build-web-863`, branch `worktree-ci-build-web-863`.

---

### Task 1: Reproduce locally and attempt codegen regen

**Files:**
- Regenerated (may or may not change): `packages/core_native/lib/src/frb_generated.dart`, `packages/core_native/lib/src/frb_generated.web.dart`, `packages/core_native/lib/src/frb_generated.io.dart`
- Reference: `packages/core_native/pubspec.yaml:13` (`flutter_rust_bridge: 2.11.1`)

**Interfaces:**
- Consumes: nothing.
- Produces: either a clean regen (no further changes needed) or confirmation that the pin must move, consumed by Task 2.

- [ ] **Step 1: Reproduce the failure locally**

Run:
```bash
cd app && flutter run -d chrome -t lib/main_tv.dart
```
Expected: FAILS with the same error as #863 — `frb_generated.dart:57:7: Error: A value of type 'RustLibWire Function()' can't be returned from a function with return type 'RustLibWire Function(ExternalLibrary)'.`

If it does NOT reproduce (e.g. already fixed by an unrelated dependency bump since the issue was filed), stop here — check `flutter pub deps | grep flutter_rust_bridge` for the resolved version and report back rather than proceeding on a fix for a bug that's no longer present.

- [ ] **Step 2: Confirm the installed codegen CLI version matches the pin**

Run:
```bash
flutter_rust_bridge_codegen --version
grep "flutter_rust_bridge:" packages/core_native/pubspec.yaml
```
These must match (2.11.1). If the installed CLI is a different version, install the matching one first:
```bash
cargo install flutter_rust_bridge_codegen --version 2.11.1 --force
```

- [ ] **Step 3: Regenerate**

Run:
```bash
cd packages/core_native && flutter_rust_bridge_codegen generate
```
This reads whatever `flutter_rust_bridge.yaml` config exists in `packages/core_native` (check it first with `cat packages/core_native/flutter_rust_bridge.yaml` if present, to confirm output paths match the files listed above).

- [ ] **Step 4: Diff the regen output against git**

Run:
```bash
git diff --stat packages/core_native/lib/src/
```

Two outcomes:
- **Diff is non-empty and changes `frb_generated.dart:57`'s wire-constructor assignment or `frb_generated.web.dart`'s `RustLibWire.fromExternalLibrary` signature** → the committed code was stale codegen output. Proceed to Task 2 (verify) — Task 3 (pin bump) is not needed.
- **Diff is empty, or non-empty but does not touch the mismatched declarations** → the regen reproduces the same broken output; the disagreement is upstream (the pinned `flutter_rust_bridge` package version's web platform types don't match what 2.11.1's own codegen emits — a real upstream version-skew bug). Revert any unrelated regen diff (`git checkout -- packages/core_native/lib/src/`) and proceed to Task 3.

- [ ] **Step 5: Commit only if Step 4 produced a real fix**

```bash
git add packages/core_native/lib/src/
git commit -m "fix(core_native): regenerate flutter_rust_bridge web bindings"
```

---

### Task 2: Verify the regen fix (skip if Task 3 is needed instead)

**Files:** none (verification task)

**Interfaces:**
- Consumes: Task 1's regenerated files.
- Produces: pass/fail signal for the PR in Task 4.

- [ ] **Step 1: Re-run the web build**

```bash
cd app && flutter run -d chrome -t lib/main_tv.dart
```
Expected: builds and launches without the `frb_generated.dart` compilation error.

- [ ] **Step 2: Confirm other targets still build**

```bash
cd app && flutter build apk --debug -t lib/main_tv.dart
```
Expected: succeeds (regenerated bindings must not break the Android/io path — `frb_generated.io.dart`'s `RustLibWire.fromExternalLibrary` factory is a separate declaration from the web one, confirm it wasn't altered in a breaking way by the diff in Task 1 Step 4).

---

### Task 3: Bump the `flutter_rust_bridge` pin (only if Task 1's regen reproduced the same broken output)

**Files:**
- Modify: `packages/core_native/pubspec.yaml:13`
- Modify: `packages/core_native/rust/Cargo.toml` (the companion Rust crate's `flutter_rust_bridge` dependency — check its current pinned version first: `grep flutter_rust_bridge packages/core_native/rust/Cargo.toml`)
- Regenerated: same files as Task 1

**Interfaces:**
- Consumes: Task 1's finding that the pin itself needs to move.
- Produces: a new committed pin + regenerated bindings, consumed by Task 4's PR.

- [ ] **Step 1: Identify a compatible version**

Check the `flutter_rust_bridge` changelog for the nearest version (above or below 2.11.1) whose web `ExternalLibrary`/wire-constructor shape is documented as `RustLibWire Function(ExternalLibrary)`-compatible with what codegen emits — check `https://pub.dev/packages/flutter_rust_bridge/changelog` for entries mentioning "web" or "wire constructor" around the 2.11.x line.

- [ ] **Step 2: Bump the Dart pin**

Edit `packages/core_native/pubspec.yaml:13`:
```yaml
  flutter_rust_bridge: <new-version>
```
Run: `cd packages/core_native && flutter pub get`

- [ ] **Step 3: Bump the Rust companion crate pin**

Edit `packages/core_native/rust/Cargo.toml`'s `flutter_rust_bridge` dependency line to the matching version. Run: `cd packages/core_native/rust && cargo update -p flutter_rust_bridge`

- [ ] **Step 4: Regenerate against the new pin**

```bash
cd packages/core_native && flutter_rust_bridge_codegen generate
```

- [ ] **Step 5: Verify (repeat Task 2's two build commands)**

```bash
cd app && flutter run -d chrome -t lib/main_tv.dart
cd app && flutter build apk --debug -t lib/main_tv.dart
```
Both must succeed.

- [ ] **Step 6: Commit**

```bash
git add packages/core_native/pubspec.yaml packages/core_native/rust/Cargo.toml packages/core_native/rust/Cargo.lock packages/core_native/lib/src/
git commit -m "fix(core_native): bump flutter_rust_bridge pin to fix build-web type mismatch"
```

---

### Task 4: Open PR

**Files:** none (process task)

**Interfaces:**
- Consumes: Task 2 or Task 3's verified fix.
- Produces: nothing further downstream.

- [ ] **Step 1: Push and open PR**

```bash
git push -u origin worktree-ci-build-web-863
gh pr create --repo DevelopersCoffee/airo \
  --title "fix(ci): resolve build-web frb_generated.dart type mismatch" \
  --body "Fixes #863. <Regenerated flutter_rust_bridge web bindings against the pinned 2.11.1 codegen OR bumped the flutter_rust_bridge pin — fill in whichever path Task 1 took>.

## Test plan
- [x] flutter run -d chrome -t lib/main_tv.dart builds and launches
- [x] flutter build apk --debug -t lib/main_tv.dart still builds (Android path unaffected)
- [x] CI build-web job passes"
```

- [ ] **Step 2: Route through platform-architect review, merge**

`core_native` is native-bridge/FFI territory per the Engineering Council roster.
