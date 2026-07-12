## Feature Packet

**Problem:** Package-by-package `flutter pub get` on the latest `origin/main` dirties the worktree in a few package directories because they do not ignore generated `pubspec.lock` files.
**User / actor:** Release and DevEx Agent maintaining workspace dependency health.
**Expected outcome:** Sequential `flutter pub get` succeeds across the workspace, tracked lockfile refresh is limited to intentional files, and package directories no longer emit stray untracked lockfiles.
**Impacted modules:** `app/third_party/flutter_chrome_cast`, `packages/stubs/package_info_plus_stub`, `packages/stubs/wakelock_plus_stub`, `packages/template_feature`.
**Constraints:** Keep the scope limited to dependency-resolution hygiene. No runtime behavior or public API changes.

### Critical Agent Gate

**Problem:** Running `flutter pub get` package by package reveals no resolver failures, but it does create untracked lockfiles in package directories that are missing standard Flutter/Dart ignore rules.
**User / actor:** Repository maintainers and automation flows that validate dependency resolution.
**Framework or application layer:** Framework/package maintenance.
**Owning agent:** Release and DevEx Agent.
**Reviewing agents:** QA Automation Agent.
**Impacted modules/files:** `app/third_party/flutter_chrome_cast/.gitignore`, `packages/stubs/package_info_plus_stub/.gitignore`, `packages/stubs/wakelock_plus_stub/.gitignore`, `packages/template_feature/pubspec.lock`.
**Base branch/worktree:** confirmed from latest `origin/main`: yes (`06b894e7f44675838beef3f1772d0c36a1406f10`).
**Open questions:** None. Source breakages were not reproduced; this slice is package hygiene only.
**Decision:** Ready

## Cross-Agent Contract

- Package maintenance may add standard ignore rules and refresh tracked lockfiles when generated outputs are deterministic and no product behavior changes.
- Validation for this slice is sequential `flutter pub get` plus verification that the resulting git status contains only the intended tracked changes.

## Deterministic Validation Flow

1. Run `flutter pub get` sequentially for every `pubspec.yaml` in `app` and `packages`.
2. Verify no resolver failures occur.
3. Verify `git status --short` shows only the tracked lockfile refresh and the new ignore/docs files.
