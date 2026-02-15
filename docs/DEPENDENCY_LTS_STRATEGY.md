# Dependency Management LTS Strategy
## Airo Super App - Comprehensive Dependency Audit & Stabilization Plan

**Date:** 2026-02-15  
**Status:** 🔴 CRITICAL - Multiple Stability Issues Identified  
**Priority:** P0 - Immediate Action Required

---

## Executive Summary

### Critical Findings

1. **Flutter Version Inconsistency** 🔴
   - Makefile: `3.24.0`
   - CI/CD Workflows: `3.35.7`
   - Local Checks: `3.24.0`
   - **Impact:** Build failures, inconsistent behavior across environments

2. **Beta/Unstable Dependencies** 🟡
   - `com.google.mlkit:genai-prompt:1.0.0-beta1` (Android)
   - Multiple packages using caret ranges (auto-upgrade to breaking changes)

3. **Dependabot Configuration Issues** 🟡
   - Only blocks major updates for Gradle plugin
   - Allows minor/patch updates that can introduce breaking changes
   - No version pinning strategy

4. **Missing Dependency Tracking** 🟡
   - No npm/Node.js dependencies in Dependabot (e2e tests)
   - No Python dependencies tracking (iptv-data)
   - No iOS CocoaPods tracking

---

## 1. Current Dependency Inventory

### 1.1 Flutter SDK

| Environment | Version | Status | Issue |
|------------|---------|--------|-------|
| Makefile | 3.24.0 | 🔴 Outdated | Inconsistent with CI |
| CI/CD (ci.yml) | 3.35.7 | 🟢 Latest Stable | - |
| CI/CD (build-and-release.yml) | 3.35.7 | 🟢 Latest Stable | - |
| CI/CD (pr-checks.yml) | 3.35.7 | 🟢 Latest Stable | - |
| CI/CD (smoke-tests.yml) | 3.35.7 | 🟢 Latest Stable | - |
| Local Checks | 3.24.0 | 🔴 Outdated | Inconsistent with CI |

**Recommendation:** Pin to `3.35.7` (current stable) across ALL environments.

### 1.2 Dart SDK

| Package | Constraint | Status |
|---------|-----------|--------|
| app | `^3.9.2` | 🟡 Caret range |
| core_domain | `^3.9.2` | 🟡 Caret range |
| core_data | `^3.9.2` | 🟡 Caret range |
| core_ui | `^3.9.2` | 🟡 Caret range |
| core_ai | `^3.9.2` | 🟡 Caret range |
| core_auth | `^3.9.2` | 🟡 Caret range |
| airo | `^3.9.2` | 🟡 Caret range |
| airomoney | `^3.9.2` | 🟡 Caret range |

**Recommendation:** Pin to exact version `3.9.2` or use `>=3.9.2 <4.0.0` for controlled updates.

### 1.3 Flutter Pub Dependencies (app/pubspec.yaml)

#### Routing & Navigation
| Package | Current | Latest Stable | Recommendation |
|---------|---------|---------------|----------------|
| go_router | ^17.1.0 | 17.1.0 | ✅ Pin to 17.1.0 |

#### State Management
| Package | Current | Latest Stable | Recommendation |
|---------|---------|---------------|----------------|
| riverpod | ^2.6.1 | 2.6.1 | ✅ Pin to 2.6.1 |
| flutter_riverpod | ^2.6.1 | 2.6.1 | ✅ Pin to 2.6.1 |

#### Storage & Persistence
| Package | Current | Latest Stable | Recommendation |
|---------|---------|---------------|----------------|
| shared_preferences | ^2.5.4 | 2.5.4 | ✅ Pin to 2.5.4 |
| drift | ^2.18.0 | 2.18.0 | ✅ Pin to 2.18.0 |
| sqlite3_flutter_libs | ^0.5.41 | 0.5.41 | ✅ Pin to 0.5.41 |
| hive | ^2.2.3 | 2.2.3 | ✅ Pin to 2.2.3 |
| hive_flutter | ^1.1.0 | 1.1.0 | ✅ Pin to 1.1.0 |
| path | ^1.9.0 | 1.9.0 | ✅ Pin to 1.9.0 |
| path_provider | ^2.1.1 | 2.1.1 | ✅ Pin to 2.1.1 |

#### Networking
| Package | Current | Latest Stable | Recommendation |
|---------|---------|---------------|----------------|
| dio | ^5.9.1 | 5.9.1 | ✅ Pin to 5.9.1 |
| connectivity_plus | ^7.0.0 | 7.0.0 | ✅ Pin to 7.0.0 |

#### Firebase & Authentication
| Package | Current | Latest Stable | Recommendation |
|---------|---------|---------------|----------------|
| firebase_core | ^4.2.1 | 4.2.1 | ✅ Pin to 4.2.1 |
| firebase_auth | ^6.1.4 | 6.1.4 | ✅ Pin to 6.1.4 |
| google_sign_in | ^7.2.0 | 7.2.0 | ✅ Pin to 7.2.0 |

#### Audio & Media
| Package | Current | Latest Stable | Recommendation |
|---------|---------|---------------|----------------|
| audio_service | ^0.18.14 | 0.18.14 | ✅ Pin to 0.18.14 |
| just_audio | ^0.10.5 | 0.10.5 | ✅ Pin to 0.10.5 |
| audioplayers | ^6.5.1 | 6.5.1 | ✅ Pin to 6.5.1 |
| video_player | ^2.10.1 | 2.10.1 | ✅ Pin to 2.10.1 |

#### Utilities
| Package | Current | Latest Stable | Recommendation |
|---------|---------|---------------|----------------|
| intl | ^0.20.2 | 0.20.2 | ✅ Pin to 0.20.2 |
| uuid | ^4.5.2 | 4.5.2 | ✅ Pin to 4.5.2 |
| equatable | ^2.0.8 | 2.0.8 | ✅ Pin to 2.0.8 |

#### UI & Widgets
| Package | Current | Latest Stable | Recommendation |
|---------|---------|---------------|----------------|
| cupertino_icons | ^1.0.8 | 1.0.8 | ✅ Pin to 1.0.8 |
| cached_network_image | ^3.4.1 | 3.4.1 | ✅ Pin to 3.4.1 |

#### Games & Entertainment
| Package | Current | Latest Stable | Recommendation |
|---------|---------|---------------|----------------|
| flame | ^1.35.0 | 1.35.0 | ✅ Pin to 1.35.0 |
| flame_audio | ^2.11.13 | 2.11.13 | ✅ Pin to 2.11.13 |
| chess | ^0.8.1 | 0.8.1 | ✅ Pin to 0.8.1 |
| stockfish | ^1.8.1 | 1.8.1 | ✅ Pin to 1.8.1 |

#### Platform Features
| Package | Current | Latest Stable | Recommendation |
|---------|---------|---------------|----------------|
| share_plus | ^12.0.1 | 12.0.1 | ✅ Pin to 12.0.1 |
| url_launcher | ^6.3.2 | 6.3.2 | ✅ Pin to 6.3.2 |
| file_picker | ^10.3.10 | 10.3.10 | ✅ Pin to 10.3.10 |
| flutter_local_notifications | ^19.5.0 | 19.5.0 | ✅ Pin to 19.5.0 |
| timezone | ^0.10.1 | 0.10.1 | ✅ Pin to 0.10.1 |
| flutter_contacts | ^1.1.9+2 | 1.1.9+2 | ✅ Pin to 1.1.9+2 |
| permission_handler | ^12.0.0+1 | 12.0.0+1 | ✅ Pin to 12.0.0+1 |
| image_picker | ^1.2.1 | 1.2.1 | ✅ Pin to 1.2.1 |
| wakelock_plus | ^1.4.0 | 1.4.0 | ✅ Pin to 1.4.0 |

#### ML & AI
| Package | Current | Latest Stable | Recommendation |
|---------|---------|---------------|----------------|
| google_mlkit_text_recognition | ^0.15.1 | 0.15.1 | ✅ Pin to 0.15.1 |
| flutter_tts | ^4.2.5 | 4.2.5 | ✅ Pin to 4.2.5 |

### 1.4 Dev Dependencies (app/pubspec.yaml)

#### Code Generation
| Package | Current | Latest Stable | Recommendation |
|---------|---------|---------------|----------------|
| build_runner | ^2.4.9 | 2.4.9 | ✅ Pin to 2.4.9 |
| drift_dev | ^2.18.0 | 2.18.0 | ✅ Pin to 2.18.0 |
| hive_generator | ^2.0.1 | 2.0.1 | ✅ Pin to 2.0.1 |
| riverpod_generator | ^2.4.0 | 2.4.0 | ✅ Pin to 2.4.0 |

#### Testing
| Package | Current | Latest Stable | Recommendation |
|---------|---------|---------------|----------------|
| mocktail | ^1.0.0 | 1.0.0 | ✅ Pin to 1.0.0 |
| golden_toolkit | ^0.15.0 | 0.15.0 | ✅ Pin to 0.15.0 |
| patrol | ^3.13.0 | 3.13.0 | ✅ Pin to 3.13.0 |

#### Linting
| Package | Current | Latest Stable | Recommendation |
|---------|---------|---------------|----------------|
| flutter_lints | ^6.0.0 | 6.0.0 | ✅ Pin to 6.0.0 |
| custom_lint | ^0.6.4 | 0.6.4 | ✅ Pin to 0.6.4 |
| riverpod_lint | ^2.3.10 | 2.3.10 | ✅ Pin to 2.3.10 |

### 1.5 Core Package Dependencies

#### core_domain
| Package | Current | Latest Stable | Recommendation |
|---------|---------|---------------|----------------|
| equatable | ^2.0.7 | 2.0.8 | 🔄 Update to 2.0.8 |
| meta | ^1.12.0 | 1.12.0 | ✅ Pin to 1.12.0 |
| flutter_lints | >=5.0.0 <7.0.0 | 6.0.0 | 🔄 Pin to 6.0.0 |
| mocktail | ^1.0.0 | 1.0.0 | ✅ Pin to 1.0.0 |

#### core_data
| Package | Current | Latest Stable | Recommendation |
|---------|---------|---------------|----------------|
| dio | ^5.4.0 | 5.9.1 | 🔄 Update to 5.9.1 |
| shared_preferences | ^2.2.2 | 2.5.4 | 🔄 Update to 2.5.4 |
| flutter_secure_storage | >=9.2.2 <11.0.0 | 10.x.x | 🔄 Pin to specific version |
| connectivity_plus | >=5.0.2 <8.0.0 | 7.0.0 | 🔄 Pin to 7.0.0 |
| path | ^1.9.0 | 1.9.0 | ✅ Pin to 1.9.0 |
| path_provider | ^2.1.1 | 2.1.1 | ✅ Pin to 2.1.1 |
| flutter_lints | >=5.0.0 <7.0.0 | 6.0.0 | 🔄 Pin to 6.0.0 |
| mocktail | ^1.0.0 | 1.0.0 | ✅ Pin to 1.0.0 |

#### core_ui
| Package | Current | Latest Stable | Recommendation |
|---------|---------|---------------|----------------|
| cupertino_icons | ^1.0.8 | 1.0.8 | ✅ Pin to 1.0.8 |
| flutter_lints | >=5.0.0 <7.0.0 | 6.0.0 | 🔄 Pin to 6.0.0 |
| golden_toolkit | ^0.15.0 | 0.15.0 | ✅ Pin to 0.15.0 |

#### core_ai
| Package | Current | Latest Stable | Recommendation |
|---------|---------|---------------|----------------|
| meta | ^1.12.0 | 1.12.0 | ✅ Pin to 1.12.0 |
| flutter_lints | >=5.0.0 <7.0.0 | 6.0.0 | 🔄 Pin to 6.0.0 |
| mocktail | ^1.0.0 | 1.0.0 | ✅ Pin to 1.0.0 |

#### core_auth
| Package | Current | Latest Stable | Recommendation |
|---------|---------|---------------|----------------|
| meta | ^1.12.0 | 1.12.0 | ✅ Pin to 1.12.0 |
| flutter_lints | >=5.0.0 <7.0.0 | 6.0.0 | 🔄 Pin to 6.0.0 |
| mocktail | ^1.0.0 | 1.0.0 | ✅ Pin to 1.0.0 |

#### airo & airomoney
| Package | Current | Latest Stable | Recommendation |
|---------|---------|---------------|----------------|
| flutter_lints | ^5.0.0 | 6.0.0 | 🔄 Update to 6.0.0 |

### 1.6 Android Dependencies (Gradle)

#### Build Tools
| Dependency | Current | Latest Stable | Recommendation |
|-----------|---------|---------------|----------------|
| Gradle | 8.13 | 8.13 | ✅ Pin to 8.13 |
| Google Services Plugin | 4.4.4 | 4.4.4 | ✅ Pin to 4.4.4 |
| compileSdk | 36 | 36 (Android 15) | ✅ Keep at 36 |
| targetSdk | 36 | 36 | ✅ Keep at 36 |
| minSdk | 26 | - | ✅ Keep at 26 |

#### Android Libraries
| Dependency | Current | Latest Stable | Status | Recommendation |
|-----------|---------|---------------|--------|----------------|
| desugar_jdk_libs | 2.1.5 | 2.1.5 | ✅ Stable | Pin to 2.1.5 |
| genai-prompt | 1.0.0-beta1 | 1.0.0-beta1 | 🔴 BETA | ⚠️ Monitor for stable release |
| lifecycle-runtime-ktx | 2.10.0 | 2.10.0 | ✅ Stable | Pin to 2.10.0 |
| kotlinx-coroutines-android | 1.10.2 | 1.10.2 | ✅ Stable | Pin to 1.10.2 |
| kotlinx-coroutines-core | 1.10.2 | 1.10.2 | ✅ Stable | Pin to 1.10.2 |
| kotlinx-coroutines-play-services | 1.10.2 | 1.10.2 | ✅ Stable | Pin to 1.10.2 |

**⚠️ CRITICAL:** `com.google.mlkit:genai-prompt:1.0.0-beta1` is in BETA. This is a stability risk.

### 1.7 E2E Testing Dependencies (Node.js/npm)

| Package | Current | Latest Stable | Recommendation |
|---------|---------|---------------|----------------|
| @playwright/test | ^1.40.0 | 1.50.0 | 🔄 Update to 1.50.0 |
| @types/node | ^20.10.0 | 20.17.0 | 🔄 Update to 20.17.0 |
| ts-node | ^10.9.2 | 10.9.2 | ✅ Pin to 10.9.2 |
| typescript | ^5.3.0 | 5.7.3 | 🔄 Update to 5.7.3 |

### 1.8 Python Dependencies (iptv-data)

| Package | Current | Latest Stable | Recommendation |
|---------|---------|---------------|----------------|
| aiohttp | >=3.9.0 | 3.11.11 | 🔄 Pin to 3.11.11 |
| requests | >=2.31.0 | 2.32.3 | 🔄 Pin to 2.32.3 |
| pyyaml | >=6.0.1 | 6.0.2 | 🔄 Pin to 6.0.2 |
| jsonschema | >=4.20.0 | 4.23.0 | 🔄 Pin to 4.23.0 |
| python-dateutil | >=2.8.2 | 2.9.0 | 🔄 Pin to 2.9.0 |
| pytest | >=7.4.0 | 8.3.4 | 🔄 Pin to 8.3.4 |
| pytest-asyncio | >=0.21.0 | 0.25.2 | 🔄 Pin to 0.25.2 |
| pytest-cov | >=4.1.0 | 6.0.0 | 🔄 Pin to 6.0.0 |
| aioresponses | >=0.7.6 | 0.7.8 | 🔄 Pin to 0.7.8 |
| ruff | >=0.1.0 | 0.9.3 | 🔄 Pin to 0.9.3 |
| mypy | >=1.7.0 | 1.14.1 | 🔄 Pin to 1.14.1 |

### 1.9 GitHub Actions

| Action | Current | Latest Stable | Recommendation |
|--------|---------|---------------|----------------|
| actions/checkout | v6 | v6 | ✅ Pin to v6 |
| actions/setup-java | v5 | v5 | ✅ Pin to v5 |
| actions/setup-node | v6 | v6 | ✅ Pin to v6 |
| actions/cache | v5 | v5 | ✅ Pin to v5 |
| actions/upload-artifact | v6 | v6 | ✅ Pin to v6 |
| actions/download-artifact | v7 | v7 | ✅ Pin to v7 |
| subosito/flutter-action | v2 | v2 | ✅ Pin to v2 |
| codecov/codecov-action | v5 | v5 | ✅ Pin to v5 |
| orhun/git-cliff-action | v4 | v4 | ✅ Pin to v4 |
| softprops/action-gh-release | v2 | v2 | ✅ Pin to v2 |
| amannn/action-semantic-pull-request | v6 | v6 | ✅ Pin to v6 |
| dorny/paths-filter | v3 | v3 | ✅ Pin to v3 |
| actions/github-script | v8 | v8 | ✅ Pin to v8 |
| aquasecurity/trivy-action | master | master | 🔴 Pin to specific tag |
| github/codeql-action/upload-sarif | v4 | v4 | ✅ Pin to v4 |
| SonarSource/sonarqube-scan-action | master | master | 🔴 Pin to specific tag |
| SonarSource/sonarqube-quality-gate-action | master | master | 🔴 Pin to specific tag |
| snyk/actions | master | master | 🔴 Pin to specific tag |

---

## 2. Identified Stability Issues

### 2.1 Critical Issues (P0)

#### Issue #1: Flutter Version Mismatch
**Severity:** 🔴 CRITICAL
**Impact:** Build failures, inconsistent behavior, developer confusion

**Details:**
- Makefile specifies Flutter 3.24.0
- All CI/CD workflows use Flutter 3.35.7
- Local checks workflow uses Flutter 3.24.0
- Developers may have different versions locally

**Risk:**
- Code that works in CI may fail locally
- Features available in 3.35.7 may not work in 3.24.0
- Dependency resolution differences

**Resolution:**
1. Update Makefile to use 3.35.7
2. Update local-checks.yml to use 3.35.7
3. Document required Flutter version in README
4. Add version check to setup scripts

#### Issue #2: Beta Dependency in Production
**Severity:** 🔴 CRITICAL
**Impact:** Potential crashes, API changes, unsupported features

**Details:**
- `com.google.mlkit:genai-prompt:1.0.0-beta1` is used for Gemini Nano integration
- Beta software is not production-ready
- API may change without notice
- No LTS support

**Risk:**
- Breaking changes in future releases
- Bugs and stability issues
- Limited support from Google

**Resolution:**
1. Monitor for stable 1.0.0 release
2. Consider fallback implementation
3. Add extensive error handling
4. Document beta status in release notes
5. Set up alerts for new releases

#### Issue #3: GitHub Actions Using 'master' Branch
**Severity:** 🟡 HIGH
**Impact:** Unexpected breaking changes in CI/CD

**Details:**
- `aquasecurity/trivy-action@master`
- `SonarSource/sonarqube-scan-action@master`
- `SonarSource/sonarqube-quality-gate-action@master`
- `snyk/actions@master`

**Risk:**
- Actions can change without notice
- Breaking changes can break CI/CD
- No version control

**Resolution:**
Pin all actions to specific tags/versions

### 2.2 High Priority Issues (P1)

#### Issue #4: Inconsistent Package Versions Across Modules
**Severity:** 🟡 HIGH
**Impact:** Dependency conflicts, build failures

**Details:**
- `equatable`: 2.0.7 (core_domain) vs 2.0.8 (app)
- `dio`: 5.4.0 (core_data) vs 5.9.1 (app)
- `shared_preferences`: 2.2.2 (core_data) vs 2.5.4 (app)
- `flutter_lints`: Range constraints vs specific versions
- `connectivity_plus`: Range constraints vs specific versions
- `flutter_secure_storage`: Wide range constraint

**Risk:**
- Dependency resolution conflicts
- Different behavior in different modules
- Difficult to debug issues

**Resolution:**
Standardize all package versions across all modules

#### Issue #5: Caret (^) Version Constraints
**Severity:** 🟡 HIGH
**Impact:** Automatic updates to potentially breaking versions

**Details:**
- All Dart SDK constraints use `^3.9.2`
- Most pub dependencies use caret constraints
- Allows automatic minor/patch updates
- Can introduce breaking changes (especially in pre-1.0 packages)

**Risk:**
- `flutter pub upgrade` can break builds
- Different developers may have different versions
- CI may use different versions than local

**Resolution:**
Replace caret constraints with exact versions or explicit ranges

#### Issue #6: Outdated E2E Testing Dependencies
**Severity:** 🟡 MEDIUM
**Impact:** Missing features, security vulnerabilities

**Details:**
- Playwright: 1.40.0 → 1.50.0 (10 minor versions behind)
- TypeScript: 5.3.0 → 5.7.3
- @types/node: 20.10.0 → 20.17.0

**Risk:**
- Missing bug fixes
- Missing features
- Potential security vulnerabilities

**Resolution:**
Update to latest stable versions

### 2.3 Medium Priority Issues (P2)

#### Issue #7: Python Dependencies Using Minimum Constraints
**Severity:** 🟡 MEDIUM
**Impact:** Unpredictable behavior, security risks

**Details:**
- All Python packages use `>=` constraints
- No upper bounds specified
- Can install any future version

**Risk:**
- Breaking changes in major updates
- Security vulnerabilities
- Incompatible combinations

**Resolution:**
Pin to specific versions or use `~=` for compatible releases

#### Issue #8: Missing Dependabot Coverage
**Severity:** 🟡 MEDIUM
**Impact:** Manual dependency management overhead

**Details:**
- No npm/Node.js tracking for e2e tests
- No Python tracking for iptv-data
- No iOS CocoaPods tracking (if used)

**Risk:**
- Dependencies become outdated
- Security vulnerabilities not detected
- Manual update burden

**Resolution:**
Add Dependabot configurations for all ecosystems

---

## 3. LTS Strategy & Recommendations

### 3.1 Version Pinning Philosophy

**Principle:** Explicit is better than implicit.

1. **Flutter SDK:** Pin to exact stable version (3.35.7)
2. **Dart SDK:** Use explicit range `>=3.9.2 <4.0.0`
3. **Pub Packages:** Pin to exact versions for production dependencies
4. **Dev Dependencies:** Can use caret for non-critical tools
5. **Android Dependencies:** Pin to exact versions
6. **GitHub Actions:** Pin to major version tags (v6, v5, etc.)
7. **Python Dependencies:** Use `==` for exact versions
8. **Node.js Dependencies:** Pin to exact versions in package-lock.json

### 3.2 Update Strategy

#### Quarterly Review Cycle
- **Q1 (Jan-Mar):** Security updates only
- **Q2 (Apr-Jun):** Minor updates + security
- **Q3 (Jul-Sep):** Security updates only
- **Q4 (Oct-Dec):** Major updates + planning

#### Emergency Updates
- Security vulnerabilities: Immediate
- Critical bugs: Within 1 week
- Breaking changes: Planned migration

### 3.3 Dependabot Configuration Strategy

**Current Issues:**
- Only blocks major Gradle updates
- Allows all minor/patch updates
- Missing ecosystems

**Recommended Configuration:**

```yaml
version: 2
updates:
  # Flutter/Dart - Patch updates only
  - package-ecosystem: "pub"
    directory: "/app"
    schedule:
      interval: "monthly"
    open-pull-requests-limit: 5
    ignore:
      - dependency-name: "*"
        update-types: ["version-update:semver-major", "version-update:semver-minor"]
    groups:
      flutter-patches:
        patterns: ["*"]
        update-types: ["patch"]

  # Android - Security updates only
  - package-ecosystem: "gradle"
    directory: "/app/android"
    schedule:
      interval: "monthly"
    ignore:
      - dependency-name: "*"
        update-types: ["version-update:semver-major", "version-update:semver-minor"]

  # GitHub Actions - Major version updates only
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "monthly"
    ignore:
      - dependency-name: "*"
        update-types: ["version-update:semver-minor", "version-update:semver-patch"]

  # Node.js/npm - Security updates only
  - package-ecosystem: "npm"
    directory: "/e2e"
    schedule:
      interval: "monthly"
    ignore:
      - dependency-name: "*"
        update-types: ["version-update:semver-major", "version-update:semver-minor"]

  # Python - Security updates only
  - package-ecosystem: "pip"
    directory: "/iptv-data"
    schedule:
      interval: "monthly"
    ignore:
      - dependency-name: "*"
        update-types: ["version-update:semver-major", "version-update:semver-minor"]
```

### 3.4 Recommended Stable Versions (as of 2026-02-15)

#### Core Infrastructure
- **Flutter SDK:** `3.35.7` (stable)
- **Dart SDK:** `>=3.9.2 <4.0.0`
- **Gradle:** `8.13`
- **Java:** `17` (LTS)
- **Node.js:** `20.x` (LTS)
- **Python:** `3.11+`

#### Critical Dependencies - DO NOT AUTO-UPDATE
These require manual testing before updates:
- `firebase_core`, `firebase_auth` (authentication critical)
- `drift`, `hive` (data persistence critical)
- `riverpod`, `flutter_riverpod` (state management critical)
- `go_router` (navigation critical)
- `patrol` (testing infrastructure)

#### Safe to Auto-Update (Patch Only)
- UI libraries (`cupertino_icons`, `cached_network_image`)
- Utilities (`intl`, `uuid`, `path`)
- Dev tools (`flutter_lints`, `mocktail`)

---

## 4. Migration Plan

### Phase 1: Immediate Fixes (Week 1)
**Priority:** P0 Issues

**Tasks:**
1. ✅ Update Makefile Flutter version to 3.35.7
2. ✅ Update local-checks.yml Flutter version to 3.35.7
3. ✅ Pin GitHub Actions to specific versions (remove @master)
4. ✅ Document Flutter version requirement in README
5. ✅ Add version check script

**Deliverables:**
- Updated Makefile
- Updated .github/workflows/local-checks.yml
- Updated .github/workflows/*.yml (pin actions)
- Updated README.md
- New script: scripts/check-versions.sh

### Phase 2: Dependency Standardization (Week 2)
**Priority:** P1 Issues

**Tasks:**
1. ✅ Standardize package versions across all modules
2. ✅ Update core_domain dependencies
3. ✅ Update core_data dependencies
4. ✅ Update core_ui, core_ai, core_auth dependencies
5. ✅ Update airo and airomoney dependencies
6. ✅ Run full test suite
7. ✅ Update pubspec.lock files

**Deliverables:**
- Updated pubspec.yaml files (all packages)
- Updated pubspec.lock files
- Test results report

### Phase 3: Version Pinning (Week 3)
**Priority:** P1 Issues

**Tasks:**
1. ✅ Replace caret constraints with exact versions
2. ✅ Update Dart SDK constraints
3. ✅ Pin Android dependencies
4. ✅ Update E2E testing dependencies
5. ✅ Pin Python dependencies
6. ✅ Run full build and test suite

**Deliverables:**
- Updated pubspec.yaml files (pinned versions)
- Updated requirements.txt (pinned versions)
- Updated package.json (pinned versions)
- Build and test results

### Phase 4: Dependabot Enhancement (Week 4)
**Priority:** P2 Issues

**Tasks:**
1. ✅ Update Dependabot configuration
2. ✅ Add npm ecosystem tracking
3. ✅ Add pip ecosystem tracking
4. ✅ Configure update strategies
5. ✅ Set up PR auto-labeling
6. ✅ Document update process

**Deliverables:**
- Updated .github/dependabot.yml
- Documentation: docs/DEPENDENCY_UPDATE_PROCESS.md

### Phase 5: Monitoring & Documentation (Week 5)
**Priority:** P2 Issues

**Tasks:**
1. ✅ Create dependency dashboard
2. ✅ Set up automated version checks
3. ✅ Document LTS strategy
4. ✅ Create update runbook
5. ✅ Train team on new process

**Deliverables:**
- Dependency dashboard (GitHub Actions)
- scripts/check-outdated.sh
- docs/DEPENDENCY_LTS_STRATEGY.md (this document)
- docs/DEPENDENCY_UPDATE_RUNBOOK.md

---

## 5. Maintenance Strategy

### 5.1 Regular Maintenance Tasks

#### Weekly
- [ ] Review Dependabot PRs
- [ ] Check for security advisories
- [ ] Monitor beta dependency status (genai-prompt)

#### Monthly
- [ ] Run `flutter pub outdated` across all packages
- [ ] Run `npm outdated` in e2e directory
- [ ] Run `pip list --outdated` in iptv-data
- [ ] Review and merge approved Dependabot PRs
- [ ] Update dependency dashboard

#### Quarterly
- [ ] Major dependency review
- [ ] Security audit
- [ ] Performance testing with new versions
- [ ] Update LTS strategy document
- [ ] Plan major updates for next quarter

### 5.2 Update Approval Process

#### Patch Updates (x.y.Z)
- **Approval:** Automated (Dependabot)
- **Testing:** CI/CD only
- **Timeline:** Merge within 1 week

#### Minor Updates (x.Y.0)
- **Approval:** Tech lead review
- **Testing:** CI/CD + manual smoke tests
- **Timeline:** Merge within 2 weeks

#### Major Updates (X.0.0)
- **Approval:** Team review + planning
- **Testing:** Full regression suite
- **Timeline:** Planned migration (1-4 weeks)

### 5.3 Rollback Strategy

If an update causes issues:

1. **Immediate:** Revert the PR
2. **Within 24h:** Identify root cause
3. **Within 1 week:** Fix or pin to previous version
4. **Document:** Add to known issues

### 5.4 Beta Dependency Monitoring

**Current Beta Dependencies:**
- `com.google.mlkit:genai-prompt:1.0.0-beta1`

**Monitoring Plan:**
1. Check Google ML Kit releases weekly
2. Test new versions in separate branch
3. Maintain fallback implementation
4. Document migration path to stable

**Fallback Strategy:**
- If beta becomes unstable: Disable Gemini Nano features
- Use cloud-based Gemini API as fallback
- Graceful degradation for users

---

## 6. Rationale for Pinned Versions

### 6.1 Flutter 3.35.7
- **Why:** Latest stable release as of Feb 2026
- **LTS:** Supported until Flutter 4.0
- **Benefits:** Latest features, bug fixes, performance improvements
- **Risk:** Low - stable release with extensive testing

### 6.2 Dart 3.9.2
- **Why:** Matches Flutter 3.35.7 requirement
- **LTS:** Supported with Flutter
- **Benefits:** Latest language features, null safety improvements
- **Risk:** Low - stable release

### 6.3 Firebase (4.2.1 / 6.1.4)
- **Why:** Latest stable versions
- **LTS:** Google provides long-term support
- **Benefits:** Security updates, bug fixes
- **Risk:** Low - critical for auth, well-tested

### 6.4 Riverpod 2.6.1
- **Why:** Latest stable version
- **LTS:** Active maintenance
- **Benefits:** Performance improvements, bug fixes
- **Risk:** Low - mature library

### 6.5 Drift 2.18.0
- **Why:** Latest stable version
- **LTS:** Active development
- **Benefits:** Database performance, new features
- **Risk:** Medium - database changes require careful testing

### 6.6 Android Dependencies
- **Gradle 8.13:** Latest stable, required for Android 15
- **compileSdk 36:** Android 15 support for Pixel 9
- **targetSdk 36:** Latest Android features
- **minSdk 26:** Android 8.0 - balances compatibility and features

---

## 7. Risk Assessment

### 7.1 Current Risk Level: 🔴 HIGH

**Factors:**
- Flutter version inconsistency
- Beta dependency in production
- Unpinned GitHub Actions
- Wide version ranges in core packages

### 7.2 Post-Migration Risk Level: 🟢 LOW

**After implementing this strategy:**
- All versions pinned and consistent
- Controlled update process
- Automated monitoring
- Clear rollback procedures

### 7.3 Ongoing Risks

#### Beta Dependency Risk
- **Likelihood:** Medium
- **Impact:** High
- **Mitigation:** Fallback implementation, monitoring, graceful degradation

#### Breaking Changes Risk
- **Likelihood:** Low (with pinning)
- **Impact:** Medium
- **Mitigation:** Controlled updates, testing, rollback plan

#### Security Vulnerability Risk
- **Likelihood:** Medium
- **Impact:** High
- **Mitigation:** Monthly security reviews, Dependabot alerts, rapid patching

---

## 8. Success Metrics

### 8.1 Key Performance Indicators

**Build Stability:**
- Target: 99% CI/CD success rate
- Current: ~95% (estimated)
- Measure: GitHub Actions success rate

**Dependency Freshness:**
- Target: <3 months behind latest stable
- Current: Mixed (some packages 6+ months old)
- Measure: `flutter pub outdated` report

**Security Posture:**
- Target: 0 high/critical vulnerabilities
- Current: Unknown
- Measure: Snyk/Dependabot security alerts

**Update Velocity:**
- Target: Patch updates within 1 week
- Current: Ad-hoc
- Measure: PR merge time

### 8.2 Success Criteria

✅ **Phase 1 Complete:**
- All environments use same Flutter version
- All GitHub Actions pinned to versions
- Version check script in place

✅ **Phase 2 Complete:**
- All packages use consistent versions
- All tests passing
- No dependency conflicts

✅ **Phase 3 Complete:**
- All dependencies pinned
- pubspec.lock files committed
- Build reproducible across environments

✅ **Phase 4 Complete:**
- Dependabot covers all ecosystems
- PRs auto-labeled and organized
- Update process documented

✅ **Phase 5 Complete:**
- Team trained on new process
- Monitoring in place
- Documentation complete

---

## 9. Next Steps

### Immediate Actions (This Week)

1. **Review & Approve:** Get team sign-off on this strategy
2. **Create Issues:** Break down migration plan into GitHub issues
3. **Assign Owners:** Assign each phase to team members
4. **Schedule:** Set timeline for 5-week migration
5. **Communicate:** Share plan with stakeholders

### Week 1 Tasks

- [ ] Update Makefile Flutter version
- [ ] Update local-checks.yml Flutter version
- [ ] Pin GitHub Actions versions
- [ ] Create version check script
- [ ] Update README with version requirements

### Week 2 Tasks

- [ ] Audit all pubspec.yaml files
- [ ] Standardize package versions
- [ ] Update core package dependencies
- [ ] Run full test suite
- [ ] Commit updated pubspec.lock files

---

## 10. Appendices

### Appendix A: Version Check Script

Location: `scripts/check-versions.sh`

```bash
#!/bin/bash
# Check Flutter and Dart versions across all configuration files

EXPECTED_FLUTTER="3.35.7"
EXPECTED_DART="3.9.2"

echo "Checking Flutter version consistency..."
grep -r "FLUTTER_VERSION" .github/workflows/ Makefile
grep -r "flutter-version" .github/workflows/

echo ""
echo "Checking Dart SDK constraints..."
find . -name "pubspec.yaml" -exec grep -H "sdk:" {} \;

echo ""
echo "Expected versions:"
echo "  Flutter: $EXPECTED_FLUTTER"
echo "  Dart: >=$EXPECTED_DART <4.0.0"
```

### Appendix B: Dependency Update Checklist

```markdown
## Dependency Update Checklist

### Before Update
- [ ] Check changelog for breaking changes
- [ ] Review migration guide (if major update)
- [ ] Create feature branch
- [ ] Backup current pubspec.lock

### During Update
- [ ] Update pubspec.yaml
- [ ] Run `flutter pub get`
- [ ] Run `flutter pub upgrade --dry-run`
- [ ] Review dependency tree changes
- [ ] Update code for breaking changes

### Testing
- [ ] Run `flutter analyze`
- [ ] Run `flutter test`
- [ ] Run integration tests
- [ ] Build for all platforms
- [ ] Manual smoke testing

### After Update
- [ ] Commit pubspec.lock
- [ ] Update CHANGELOG.md
- [ ] Create PR with detailed description
- [ ] Request review from tech lead
- [ ] Monitor CI/CD results
```

### Appendix C: Emergency Rollback Procedure

```bash
# 1. Identify the problematic PR
git log --oneline --grep="deps"

# 2. Revert the PR
git revert <commit-hash>

# 3. Restore previous pubspec.lock
git checkout <previous-commit> -- pubspec.lock

# 4. Clean and rebuild
flutter clean
flutter pub get
flutter pub upgrade --dry-run

# 5. Test
flutter test
flutter build apk --debug

# 6. Push fix
git push origin main
```

### Appendix D: Contact & Resources

**Team Contacts:**
- Tech Lead: @ucguy4u
- DevOps: TBD
- Security: TBD

**Resources:**
- Flutter Releases: https://docs.flutter.dev/release/archive
- Pub.dev: https://pub.dev
- Dependabot Docs: https://docs.github.com/en/code-security/dependabot
- Security Advisories: https://github.com/advisories

---

**Document Version:** 1.0
**Last Updated:** 2026-02-15
**Next Review:** 2026-05-15 (Quarterly)
**Owner:** @ucguy4u


