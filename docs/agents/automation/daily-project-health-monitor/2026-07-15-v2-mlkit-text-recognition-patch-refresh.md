## Critical Agent Gate

**Problem:** The v2 app profiles pin `google_mlkit_text_recognition` below the latest resolvable stable release, leaving mobile OCR support behind a safe native library refresh and creating avoidable lockfile drift.
**User / actor:** Release and DevEx Agent maintaining v2 dependency health.
**Framework or application layer:** Mixed. The application host declares the dependency in all v2 build profiles, while bill-split OCR behavior consumes it in the app runtime.
**Owning agent:** Release and DevEx Agent.
**Reviewing agents:** Framework Agent, QA Automation Agent.
**Impacted modules/files:** `app/pubspec.yaml`, `app/pubspec_streaming.yaml`, `app/pubspec_tv.yaml`, `app/pubspec_ios_spm.yaml`, `app/pubspec.lock`.
**Base branch/worktree:** confirmed from latest `origin/main`: yes (`e59f15d65aee9ce8dfee80c044a840754486a2e2`) in worktree `maintenance/health-20260715-090230`.
**Open questions:** Broader dependency drift remains, but the currently resolvable direct upgrade surface is intentionally limited to `google_mlkit_text_recognition` because `riverpod`, `drift`, and `custom_lint` major/minor jumps are still blocked by migration scope.
**Decision:** Ready

## Cross-Agent Contract

- Release and DevEx may refresh stable dependency constraints across v2 app profiles when the pub resolver confirms compatibility and no Dart API rewrite is required.
- Application behavior for receipt OCR remains unchanged because the package changelog for `0.16.0` only reports native ML Kit library version bumps.
- QA validation for this slice is profile contract checks, variant dependency resolution, app analyze, and a representative shared package test run.

## Automation Flow

1. Run `python3 scripts/check-build-profiles.py`.
2. Run `bash scripts/check-variant-pubspecs.sh`.
3. Run `bash scripts/check-bundled-model-artifacts.sh`.
4. Run `cd app && flutter pub outdated` to identify resolvable stable dependency updates.
5. Update v2 app profile pubspecs for the selected dependency, then run `cd app && flutter pub get`.
6. Run `cd app && flutter analyze --no-fatal-infos --no-fatal-warnings`.
7. Run `cd packages/core_data && flutter test --reporter=compact`.

## Outcome

- Upgraded `google_mlkit_text_recognition` from `0.15.1` to `0.16.0` in the full, streaming, TV, and iOS-SPM v2 app profiles.
- Refreshed `app/pubspec.lock`, which also moved `google_mlkit_commons` from `0.11.1` to `0.12.0`.
- Kept the maintenance slice minimal because the other outdated direct dependencies are still non-resolvable within current constraints or require broader migration work.

## Validation

- `python3 scripts/check-build-profiles.py` ✅
- `bash scripts/check-variant-pubspecs.sh` ✅
- `bash scripts/check-bundled-model-artifacts.sh` ✅
- `cd app && flutter pub outdated` ✅
- `cd app && flutter pub get` ✅
- `cd app && flutter analyze --no-fatal-infos --no-fatal-warnings` ✅ with 33 pre-existing info-level lint findings and no fatal analyzer errors
- `cd packages/core_data && flutter test --reporter=compact` ✅

## Follow-up Health Notes

- Local Android build validation is still blocked on this machine because no Java runtime is installed.
- `flutter pub outdated` still reports larger unresolved drifts for `riverpod`, `drift`, `build_runner`, and `custom_lint`; those should be handled as scoped migrations, not folded into this patch refresh.
