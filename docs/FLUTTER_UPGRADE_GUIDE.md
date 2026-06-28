# Flutter Release Baseline Upgrade Guide

This guide documents the deterministic process to upgrade the Airo monorepo to a new Flutter release baseline.

## 1. Preparation
1. Ensure you are on the latest `main` branch:
   ```bash
   git fetch origin main
   git checkout -b feature/flutter-release-baseline-upgrade origin/main
   ```
2. Verify the current Flutter version being used matches the target upgrade version.
3. Update `README.md` and `RELEASE_NOTES.md` to document the new target Flutter version, Android compileSdk, and Gradle targets.

## 2. Upgrade Packages
Use Melos to upgrade all packages across the monorepo workspace to their latest compatible versions.
```bash
melos run upgrade
```

## 3. Fix Breaking API Changes
Review the `flutter analyze` logs or IDE errors for breaking changes in dependencies. Common examples include:
- `share_plus`: Replaced positional string arguments with the `ShareParams` object.
- `flutter_riverpod`: Migrated `StateNotifier` to `Notifier` and `AsyncNotifier`.
Use simple Python regex replacement scripts for bulk refactoring to ensure accuracy across the monorepo.

## 4. Address Static Analysis Issues
New Flutter SDKs often introduce stricter linting rules. 
1. **Exclude irrelevant folders**: Ensure `build/`, `.dart_tool/`, and generated files are excluded in `analysis_options.yaml`.
2. **Handle structural widget constraints**: (e.g. Flutter 3.24+ requires `ListTile` inside a `Material` widget before a background color `DecoratedBox` is applied. Wrap `ListTile` in `Material(type: MaterialType.transparency, child: ListTile(...))`).
3. **Configure custom rules**: Add `ignore` rules in specific package `analysis_options.yaml` files if legacy code or third-party stubs trigger non-critical warnings (e.g., `non_constant_identifier_names`).

## 5. Build and Test Verification
Run the standard validation suite:
```bash
# Format
melos run format:fix

# Analyze (must be 0 errors)
melos run analyze

# Test
melos run test

# Compile native apps
melos run build:full
cd app && flutter build ios --release --no-codesign
```

## 6. Commit and Merge
Commit all changes in logical steps, create a PR, and merge to `main`.
