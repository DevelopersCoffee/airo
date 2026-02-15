# Dependency Update Runbook
## Airo Super App - Step-by-Step Update Procedures

**Version:** 1.0  
**Last Updated:** 2026-02-15  
**Owner:** DevOps Team

---

## Table of Contents

1. [Quick Reference](#quick-reference)
2. [Flutter/Dart Updates](#flutterdart-updates)
3. [Pub Package Updates](#pub-package-updates)
4. [Android Dependency Updates](#android-dependency-updates)
5. [Node.js/npm Updates](#nodejsnpm-updates)
6. [Python Package Updates](#python-package-updates)
7. [GitHub Actions Updates](#github-actions-updates)
8. [Emergency Procedures](#emergency-procedures)

---

## Quick Reference

### Update Frequency

| Type | Frequency | Auto-Merge | Approval Required |
|------|-----------|------------|-------------------|
| Security Patches | Immediate | No | Tech Lead |
| Patch Updates (x.y.Z) | Weekly | Yes (after CI) | No |
| Minor Updates (x.Y.0) | Monthly | No | Tech Lead |
| Major Updates (X.0.0) | Quarterly | No | Team Review |

### Commands Cheat Sheet

```bash
# Check for outdated packages
flutter pub outdated                    # Flutter/Dart
npm outdated                           # Node.js
pip list --outdated                    # Python

# Update dependencies
flutter pub upgrade                    # Flutter/Dart
npm update                            # Node.js
pip install --upgrade <package>       # Python

# Clean and rebuild
flutter clean && flutter pub get      # Flutter
rm -rf node_modules && npm install    # Node.js
rm -rf venv && python -m venv venv    # Python
```

---

## Flutter/Dart Updates

### 1. Check Current Version

```bash
# Check installed Flutter version
flutter --version

# Check required version in project
grep -r "FLUTTER_VERSION" .github/workflows/
grep "flutter:" app/pubspec.yaml
```

### 2. Update Flutter SDK

```bash
# Update Flutter to latest stable
flutter upgrade

# Or install specific version
git clone https://github.com/flutter/flutter.git -b 3.35.7

# Verify version
flutter --version
flutter doctor -v
```

### 3. Update Project Configuration

**Files to update:**
- `Makefile` (line 5)
- `.github/workflows/ci.yml` (line 21)
- `.github/workflows/build-and-release.yml` (line 19)
- `.github/workflows/pr-checks.yml` (line 20)
- `.github/workflows/smoke-tests.yml` (line 64, 96)
- `.github/workflows/local-checks.yml` (line 22)

```bash
# Use sed to update all at once (Linux/macOS)
NEW_VERSION="3.35.7"
find .github/workflows -name "*.yml" -exec sed -i "s/FLUTTER_VERSION: '[0-9.]*'/FLUTTER_VERSION: '$NEW_VERSION'/g" {} \;
sed -i "s/FLUTTER_VERSION := [0-9.]*/FLUTTER_VERSION := $NEW_VERSION/" Makefile
```

### 4. Test Flutter Update

```bash
# Clean all packages
make clean

# Get dependencies
make install-deps

# Run tests
make test

# Build for all platforms
make build-android
make build-web
```

### 5. Update Dart SDK Constraint

**File:** `app/pubspec.yaml` and all package `pubspec.yaml` files

```yaml
environment:
  sdk: ">=3.9.2 <4.0.0"  # Explicit range
  flutter: ">=3.35.7"     # Minimum Flutter version
```

---

## Pub Package Updates

### 1. Check for Outdated Packages

```bash
# Check all packages
cd app && flutter pub outdated
cd packages/core_domain && flutter pub outdated
cd packages/core_data && flutter pub outdated
cd packages/core_ui && flutter pub outdated
cd packages/core_ai && flutter pub outdated
cd packages/core_auth && flutter pub outdated
```

### 2. Review Update Impact

```bash
# Dry run to see what would change
flutter pub upgrade --dry-run

# Check dependency tree
flutter pub deps
```

### 3. Update Strategy by Package Type

#### Critical Packages (Manual Review Required)
- `firebase_core`, `firebase_auth`
- `drift`, `hive`, `hive_flutter`
- `riverpod`, `flutter_riverpod`
- `go_router`

**Process:**
1. Read changelog
2. Check for breaking changes
3. Update in feature branch
4. Full regression testing
5. PR review required

#### Standard Packages (Semi-Automated)
- UI libraries
- Utilities
- Dev dependencies

**Process:**
1. Review Dependabot PR
2. Check CI results
3. Merge if green

### 4. Update pubspec.yaml

**Option A: Pin to exact version (recommended for production)**
```yaml
dependencies:
  riverpod: 2.6.1  # Exact version
```

**Option B: Use explicit range**
```yaml
dependencies:
  riverpod: ">=2.6.1 <3.0.0"  # Explicit range
```

### 5. Update and Test

```bash
# Update dependencies
flutter pub get

# Run code generation if needed
dart run build_runner build --delete-conflicting-outputs

# Run tests
flutter test

# Check for issues
flutter analyze
```

---

## Android Dependency Updates

### 1. Check Current Versions

**File:** `app/android/app/build.gradle.kts`

```bash
# View current dependencies
cat app/android/app/build.gradle.kts | grep implementation
```

### 2. Check for Updates

Visit:
- https://developer.android.com/jetpack/androidx/releases
- https://github.com/Kotlin/kotlinx.coroutines/releases
- https://developers.google.com/ml-kit/release-notes

### 3. Update Gradle Dependencies

**File:** `app/android/app/build.gradle.kts`

```kotlin
dependencies {
    // Update versions here
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.10.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
}
```

### 4. Update Gradle Wrapper

```bash
cd app/android
./gradlew wrapper --gradle-version 8.13
```

### 5. Test Android Build

```bash
# Clean build
cd app
flutter clean

# Build APK
flutter build apk --debug
flutter build apk --release

# Build AAB
flutter build appbundle --release
```

---

## Node.js/npm Updates

### 1. Check for Outdated Packages

```bash
cd e2e
npm outdated
```

### 2. Review Package Updates

```bash
# Check what would be updated
npm update --dry-run

# View dependency tree
npm list
```

### 3. Update Packages

**Option A: Update all to latest (risky)**
```bash
npm update
```

**Option B: Update specific package**
```bash
npm install @playwright/test@1.50.0 --save-dev
```

**Option C: Update package.json manually (recommended)**
```json
{
  "devDependencies": {
    "@playwright/test": "1.50.0",
    "@types/node": "20.17.0",
    "ts-node": "10.9.2",
    "typescript": "5.7.3"
  }
}
```

Then run:
```bash
npm install
```

### 4. Test E2E Updates

```bash
# Install Playwright browsers
npx playwright install

# Run tests
npm test

# Run specific browser
npm run test:chromium
```

---

## Python Package Updates

### 1. Check for Outdated Packages

```bash
cd iptv-data
pip list --outdated
```

### 2. Update requirements.txt

**Current (using >=):**
```txt
aiohttp>=3.9.0
requests>=2.31.0
```

**Recommended (pinned versions):**
```txt
aiohttp==3.11.11
requests==2.32.3
pyyaml==6.0.2
jsonschema==4.23.0
python-dateutil==2.9.0
pytest==8.3.4
pytest-asyncio==0.25.2
pytest-cov==6.0.0
aioresponses==0.7.8
ruff==0.9.3
mypy==1.14.1
types-PyYAML==6.0.12.20240917
types-requests==2.32.0.20241016
types-python-dateutil==2.9.0.20241003
```

### 3. Update and Test

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # Linux/macOS
# or
venv\Scripts\activate  # Windows

# Install updated dependencies
pip install -r requirements.txt

# Run tests
pytest

# Run linting
ruff check .
mypy .
```

---

## GitHub Actions Updates

### 1. Check Current Versions

```bash
# Find all GitHub Actions
grep -r "uses:" .github/workflows/
```

### 2. Update Actions

**Before (using @master - BAD):**
```yaml
- uses: aquasecurity/trivy-action@master
```

**After (pinned to version - GOOD):**
```yaml
- uses: aquasecurity/trivy-action@0.28.0
```

### 3. Common Actions to Update

```yaml
# Checkout
- uses: actions/checkout@v6

# Setup Java
- uses: actions/setup-java@v5
  with:
    java-version: '17'
    distribution: 'temurin'

# Setup Node
- uses: actions/setup-node@v6
  with:
    node-version: '20'

# Setup Flutter
- uses: subosito/flutter-action@v2
  with:
    flutter-version: '3.35.7'
    channel: 'stable'
    cache: true

# Cache
- uses: actions/cache@v5

# Upload/Download Artifacts
- uses: actions/upload-artifact@v6
- uses: actions/download-artifact@v7

# Security Scanning
- uses: aquasecurity/trivy-action@0.28.0
- uses: github/codeql-action/upload-sarif@v4
- uses: snyk/actions@0.4.0
```

### 4. Test Workflow Updates

```bash
# Trigger workflow manually
gh workflow run ci.yml

# Or push to test branch
git checkout -b test/update-actions
git add .github/workflows/
git commit -m "ci: update GitHub Actions to pinned versions"
git push origin test/update-actions
```

---

## Emergency Procedures

### Scenario 1: Broken Build After Update

**Symptoms:**
- CI/CD failing
- Build errors
- Test failures

**Immediate Actions:**

```bash
# 1. Revert the problematic commit
git revert <commit-hash>
git push origin main

# 2. Or restore previous pubspec.lock
git checkout HEAD~1 -- pubspec.lock
flutter pub get
git commit -m "fix: revert dependency update"
git push origin main

# 3. Clean and rebuild
flutter clean
flutter pub get
flutter test
```

### Scenario 2: Dependency Conflict

**Symptoms:**
- "version solving failed"
- Incompatible version constraints

**Resolution:**

```bash
# 1. Check dependency tree
flutter pub deps

# 2. Identify conflicting packages
flutter pub outdated

# 3. Override dependency (temporary fix)
# Add to pubspec.yaml:
dependency_overrides:
  conflicting_package: 1.2.3

# 4. Get dependencies
flutter pub get

# 5. File issue to resolve properly
```

### Scenario 3: Security Vulnerability

**Symptoms:**
- Dependabot security alert
- Snyk vulnerability report

**Immediate Actions:**

```bash
# 1. Assess severity
# Check GitHub Security tab or Snyk dashboard

# 2. Update affected package immediately
# Edit pubspec.yaml
dependencies:
  vulnerable_package: 1.2.4  # Updated version

# 3. Test thoroughly
flutter pub get
flutter test
flutter build apk --release

# 4. Deploy hotfix
git checkout -b hotfix/security-update
git add pubspec.yaml pubspec.lock
git commit -m "security: update vulnerable_package to 1.2.4"
git push origin hotfix/security-update

# 5. Create PR and merge ASAP
```

### Scenario 4: Beta Dependency Breaks

**Symptoms:**
- Gemini Nano features failing
- ML Kit errors

**Resolution:**

```bash
# 1. Check for stable release
# Visit: https://developers.google.com/ml-kit/release-notes

# 2. If no stable release, implement fallback
# Edit code to disable Gemini Nano features

# 3. Update build.gradle.kts
# Comment out beta dependency
// implementation("com.google.mlkit:genai-prompt:1.0.0-beta1")

# 4. Rebuild
flutter clean
flutter build apk --release

# 5. Document in release notes
```

---

## Rollback Checklist

Use this checklist when rolling back a dependency update:

- [ ] Identify the problematic commit
- [ ] Create rollback branch
- [ ] Revert changes to pubspec.yaml / package.json / requirements.txt
- [ ] Restore previous .lock files
- [ ] Clean build artifacts
- [ ] Run full test suite
- [ ] Build for all platforms
- [ ] Update CHANGELOG.md
- [ ] Create PR with rollback
- [ ] Document issue in GitHub Issues
- [ ] Plan proper fix

---

## Post-Update Verification

After any dependency update, verify:

### 1. Build Verification
```bash
# Android
flutter build apk --release
flutter build appbundle --release

# iOS (macOS only)
flutter build ios --release --no-codesign

# Web
flutter build web --release

# Desktop
flutter build windows --release  # Windows
flutter build linux --release    # Linux
flutter build macos --release    # macOS
```

### 2. Test Verification
```bash
# Unit tests
flutter test

# Integration tests
flutter test integration_test/

# E2E tests
cd e2e && npm test
```

### 3. Code Quality
```bash
# Analysis
flutter analyze

# Formatting
dart format --set-exit-if-changed .

# Linting
flutter pub run custom_lint
```

### 4. Performance Check
```bash
# Build size
ls -lh app/build/app/outputs/flutter-apk/app-release.apk

# Startup time (manual testing)
# Launch app and measure time to first screen
```

---

## Appendix: Useful Commands

### Flutter

```bash
# Clean everything
flutter clean
rm -rf pubspec.lock
rm -rf .dart_tool

# Reset dependencies
flutter pub get
flutter pub upgrade --major-versions

# Check for issues
flutter doctor -v
flutter pub deps
flutter pub outdated
```

### Git

```bash
# View dependency update history
git log --oneline --grep="deps"

# Compare pubspec.lock
git diff HEAD~1 pubspec.lock

# Restore previous version
git checkout <commit> -- pubspec.yaml pubspec.lock
```

### Debugging

```bash
# Verbose output
flutter pub get --verbose
flutter build apk --verbose

# Trace dependency resolution
flutter pub deps --style=compact
flutter pub deps --style=tree
```

---

**End of Runbook**

For questions or issues, contact:
- Tech Lead: @ucguy4u
- DevOps Team: TBD


