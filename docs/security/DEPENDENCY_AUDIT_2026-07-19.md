# Dependency Audit — 2026-07-19

Phase 3 (Security) item from RC stabilization tracking (issue #872): `flutter pub outdated` audit for `app/`.

## Method

`flutter pub outdated` in `app/`. Security/CVE scanning is already covered separately by Snyk in `ci.yml` (green on main); this audit is about staleness, not vulnerabilities.

## Findings

No critical or high-severity issues. Nothing here blocks the RC.

- **10 packages locked older than resolvable** via `pubspec.lock` (`drift`, `flutter_contacts`, `flutter_image_compress` + its platform packages, `record_use`, `sqlparser`, etc.) — routine drift, fixable with `flutter pub upgrade` when there's a stabilization window that isn't mid-RC.
- **4 packages constrained below a resolvable version** in `pubspec.yaml` (`_fe_analyzer_shared`, `flutter_rust_bridge`, `js`, `package_config` and similar) — require an explicit `pubspec.yaml` bump, not just `pub upgrade`.
- **`js` package is discontinued** (upstream: use `dart:js_interop` instead). Not urgent, but should be tracked as a follow-up migration since the package won't receive further updates.
- **Several packages are intentionally `overridden`** in `dependency_overrides` (`analyzer`, `dart_style`, `mockito`, `source_gen`, `flutter_chrome_cast`, `stockfish`) — these are deliberate pins for compatibility (e.g. `stockfish` overridden to a local path stub, `flutter_chrome_cast` overridden to the vendored `platform_player/third_party` copy). Do not bump these without checking why they were pinned first.

## Recommendation

Don't bump dependencies during RC stabilization — the goal right now is a stable, green baseline, and dependency bumps are exactly the kind of change that can reintroduce breakage. Revisit this list once `v0.0.3-rc.1` is stable and treat it as routine maintenance:

1. `flutter pub upgrade` for the 10 lockfile-drifted packages (low risk, patch/minor bumps).
2. Separately evaluate the 4 pubspec-constrained packages and the `js` → `dart:js_interop` migration as their own scoped changes, each with its own test pass.
3. Leave the `dependency_overrides` pins alone unless the underlying compatibility issue they work around is independently resolved.
