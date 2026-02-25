# Modular Super App Architecture - Sprint Plan

## Executive Summary

This document outlines the comprehensive sprint plan for transforming the Airo Super App from a monolithic 323MB APK into a modular platform architecture with platform-specific builds.

**Current State Analysis:**
- Release APK: **323MB** (Debug: 484MB)
- 17 features in `app/lib/features/`
- 8 packages in `packages/` (5 core, 2 feature, 1 template)
- Melos workspace already configured
- 70-80% loosely coupled (as claimed)
- TV infrastructure exists (`app/lib/core/tv/`)
- IPTV feature well-structured with application/domain/data/presentation layers

**Target State:**
- Android TV IPTV build: **<120MB**
- Mobile Streaming build: **<150MB**
- Mobile Full build: **<200MB**
- iPad optimized build with tablet UX

---

## Current Architecture Assessment

### ✅ Strengths (Already In Place)

| Component | Status | Location |
|-----------|--------|----------|
| Melos Workspace | ✅ Configured | `melos.yaml` |
| Core Packages | ✅ 5 packages | `packages/core_*` |
| Feature Packages | ✅ 2 packages | `packages/airo`, `packages/airomoney` |
| Template Feature | ✅ Available | `packages/template_feature` |
| TV Focus System | ✅ Implemented | `app/lib/core/tv/` |
| IPTV Feature | ✅ Well-structured | `app/lib/features/iptv/` |
| GoRouter Navigation | ✅ Centralized | `app/lib/core/routing/` |
| Riverpod State | ✅ Consistent | Throughout codebase |
| ADR Documentation | ✅ Exists | `docs/adr/0001-package-structure.md` |

### ⚠️ Gaps Requiring Work

| Gap | Impact | Priority |
|-----|--------|----------|
| Features still in app/lib/ | Not extracted to packages | P1 |
| No platform-specific entrypoints | Can't build TV-only APK | P0 |
| No feature registry pattern | Hardcoded feature inclusion | P1 |
| No --split-per-abi enabled | APK includes all ABIs | P0 |
| Heavy dependencies bundled | stockfish, flame, mlkit in all builds | P1 |
| No TV-specific design system | Shared with mobile | P2 |
| No asset CDN strategy | All assets bundled | P2 |

### 📊 APK Size Breakdown (Estimated)

| Component | Size Impact | Needed For TV? |
|-----------|-------------|----------------|
| Stockfish (Chess engine) | ~80MB | ❌ No |
| Flame (Game engine) | ~15MB | ❌ No |
| ML Kit | ~30MB | ❌ No |
| Firebase (Auth only) | ~10MB | ✅ Yes |
| Audio services | ~8MB | ❌ No |
| Video player | ~5MB | ✅ Yes |
| Core Flutter | ~15MB | ✅ Yes |
| Multi-ABI (3 ABIs) | 3x size | Reduce with split |

**Estimated TV-only build after optimization: ~80-120MB**

---

## Strategic Questions - Recommendations

### 1. Separate Store Listings vs One Brand?

**Recommendation: Separate Store Listings**

Rationale:
- TV users expect TV-optimized apps with TV-specific ratings/reviews
- Different user acquisition strategies per platform
- APK size requirements differ (TV users have limited storage)
- A/B testing and feature rollout can be independent
- Play Store TV category has different visibility rules

**Proposed Package IDs:**
```
io.airo.app          # Mobile full app
io.airo.streaming    # Mobile streaming-only
io.airo.tv           # Android TV / Fire TV
```

**Firebase Configuration Strategy:**
All package IDs will be registered under the SAME Firebase project (`devscoffee-airo`), sharing:
- Authentication (same user base across all platforms)
- Firestore (same database, filtered by platform if needed)
- Analytics (with platform dimension for segmentation)

See detailed Firebase setup in Phase 0.5 below.

### 2. Should Finance Remain in Workspace?

**Recommendation: Keep in Workspace (for now)**

Rationale:
- Finance (`airomoney`) shares core infrastructure (auth, storage, theme)
- Shared user identity across features is valuable
- Extraction to separate repo adds coordination overhead
- Can be excluded from TV/streaming builds via feature flags

**Future consideration:** If Finance team grows independently, extract to separate repo.

### 3. Dynamic Feature Loading Preparation?

**Recommendation: Architect for it, don't implement yet**

Rationale:
- Flutter's Play Feature Delivery support is limited
- Focus on static modularization first (proven, stable)
- Design patterns (feature registry, DI) enable future dynamic loading
- Phase 1-2 focus on build-time feature selection

---

## Sprint Plan Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ Phase 0: Quick Wins (Week 1)                                               │
│ ├── Enable --split-per-abi                                                 │
│ ├── Enable tree-shake-icons                                                │
│ ├── Audit and document APK contents                                        │
│ └── Expected: 30-40% size reduction immediately                            │
├─────────────────────────────────────────────────────────────────────────────┤
│ Phase 1: Foundation (Weeks 2-3)                                            │
│ ├── Enhance melos.yaml with platform targets                               │
│ ├── Create feature registry pattern                                        │
│ ├── Create platform entrypoints (main_tv.dart, main_mobile.dart)           │
│ ├── Create app configuration per platform                                  │
│ └── Expected: Platform-aware build infrastructure                          │
├─────────────────────────────────────────────────────────────────────────────┤
│ Phase 2: TV Build (Weeks 4-5)                                              │
│ ├── Extract IPTV feature to package                                        │
│ ├── Create TV-specific design system                                       │
│ ├── Build Android TV app with IPTV only                                    │
│ ├── D-pad navigation polish                                                │
│ └── Expected: <120MB TV APK                                                │
├─────────────────────────────────────────────────────────────────────────────┤
│ Phase 3: Mobile Streaming (Weeks 6-7)                                      │
│ ├── Extract Music feature to package                                       │
│ ├── Create streaming-only entrypoint                                       │
│ ├── Optimize player infrastructure                                         │
│ └── Expected: <150MB streaming APK                                         │
├─────────────────────────────────────────────────────────────────────────────┤
│ Phase 4: Testing & iPad (Weeks 8-9)                                        │
│ ├── Platform-specific integration tests                                    │
│ ├── iPad tablet-optimized layouts                                          │
│ ├── CI/CD matrix builds                                                    │
│ └── Expected: Full platform coverage                                       │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Phase 0: Quick Wins (Week 1)

**Goal:** Reduce APK size by 30-40% without major refactoring

### Task 0.1: Enable Split-Per-ABI Builds

**File:** `.github/workflows/ci.yml`, `Makefile`

**Current:** Single APK with all ABIs (arm64-v8a, armeabi-v7a, x86_64)
**Target:** Separate APKs per ABI

**Implementation:**
```bash
# Build command change
flutter build apk --release --split-per-abi
```

**Expected Result:** 323MB → ~110MB per ABI (3 separate APKs)

**Effort:** 0.5 days
**Risk:** Low
**Dependencies:** None

### Task 0.2: Enable Tree Shaking and Icon Optimization

**Files:** `app/android/app/build.gradle.kts` (already has minify), build commands

**Implementation:**
```bash
flutter build apk --release --tree-shake-icons --split-debug-info=build/debug-info
```

**Expected Result:** Additional 5-10% reduction

**Effort:** 0.5 days
**Risk:** Low
**Dependencies:** None

### Task 0.3: Audit APK Contents

**Action:** Use Android Studio APK Analyzer or `apkanalyzer`

**Command:**
```bash
# Analyze APK breakdown
apkanalyzer -h files app/build/app/outputs/flutter-apk/app-release.apk
```

**Deliverable:** Document showing exact size breakdown by:
- Native libraries (which ones, sizes)
- Assets (audio, images, JSON)
- Dex files
- Resources

**Effort:** 0.5 days
**Risk:** None
**Dependencies:** None

### Task 0.4: Identify Conditional Dependencies

**Files:** `app/pubspec.yaml`

**Heavy dependencies to evaluate:**
```yaml
# Games (not needed for TV/streaming)
stockfish: 1.8.1      # ~80MB - Chess AI engine
flame: 1.35.0         # ~15MB - Game engine
chess: 0.8.1          # Chess logic

# AI/ML (not needed for TV)
google_mlkit_text_recognition: 0.15.1  # ~30MB

# May need conditional inclusion
audio_service: ^0.18.18  # Not for TV
just_audio: ^0.10.5      # Not for TV
```

**Effort:** 0.5 days
**Risk:** Low
**Dependencies:** Task 0.3

### Phase 0 Success Metrics

| Metric | Before | Target | Measurement |
|--------|--------|--------|-------------|
| Release APK (fat) | 323MB | N/A | apkanalyzer |
| Release APK (arm64) | N/A | <115MB | apkanalyzer |
| Build time | baseline | -10% | CI logs |

---

## Phase 0.5: Firebase Multi-Platform Setup (Week 1, Day 3-5)

**Goal:** Configure Firebase to support all app variants with single project

> **Key Insight:** Firebase supports multiple Android apps per project.
> You do NOT need separate Firebase projects for separate package IDs.

### Task 0.5.1: Register App Variants in Firebase Console

**Time:** 30 minutes | **Risk:** Low | **Dependencies:** None

1. Open [Firebase Console](https://console.firebase.google.com/) → `devscoffee-airo`
2. Go to ⚙️ Project Settings → Your apps → Add app → Android
3. Register each variant:

| Package Name | App Nickname | SHA-1 Required? |
|-------------|--------------|-----------------|
| `io.airo.app` | Airo Mobile | ✅ (existing) |
| `io.airo.streaming` | Airo Streaming | ✅ (for Google Sign-In) |
| `io.airo.tv` | Airo TV | ✅ (for Google Sign-In) |

**SHA-1 fingerprints** (same keystore for all variants):
```bash
# Debug
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Release (use your release keystore)
keytool -list -v -keystore <your-keystore.jks> -alias <your-alias>
```

### Task 0.5.2: Download Combined google-services.json

**Time:** 10 minutes | **Risk:** Low | **Dependencies:** Task 0.5.1

After registering all apps, download the combined config:
1. Firebase Console → Project Settings → Your apps
2. Click **"Download latest config file"** for any Android app
3. The JSON includes ALL registered package IDs automatically
4. Save to `app/android/app/google-services.json`

**Result:** Single file handles all flavors - Gradle plugin auto-selects correct config!

### Task 0.5.3: Update firebase_options.dart with Variant Support

**File:** `app/lib/firebase_options.dart`

**Time:** 30 minutes | **Risk:** Low | **Dependencies:** Task 0.5.1

```dart
/// Get Android options based on current build variant
static FirebaseOptions _getAndroidOptions() {
  const appVariant = String.fromEnvironment('APP_VARIANT', defaultValue: 'full');

  switch (appVariant) {
    case 'tv':
      return androidTv;
    case 'streaming':
      return androidStreaming;
    default:
      return android;
  }
}

// Add new FirebaseOptions for TV and Streaming
// (appId values come from Firebase Console after registration)
```

See `docs/architecture/FIREBASE_MULTI_PLATFORM_STRATEGY.md` for complete implementation.

### Task 0.5.4: Update Build Scripts with Variant Defines

**Files:** `melos.yaml`, `Makefile`

```bash
# TV Build
flutter build apk --release \
  --dart-define=APP_VARIANT=tv \
  --dart-define=APP_PLATFORM=androidTv \
  --target=lib/main_tv.dart \
  --split-per-abi

# Streaming Build
flutter build apk --release \
  --dart-define=APP_VARIANT=streaming \
  --dart-define=APP_PLATFORM=mobileStreaming \
  --target=lib/main_mobile_streaming.dart \
  --split-per-abi
```

### Phase 0.5 Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Firebase apps registered | 3 (mobile, streaming, tv) | Console check |
| google-services.json | Contains all 3 package names | JSON inspection |
| Firebase init works | All variants | Manual test |

---

## Phase 1: Foundation (Weeks 2-3)

**Goal:** Create infrastructure for platform-specific builds

### Task 1.1: Create Platform Configuration System

**New File:** `app/lib/core/config/platform_features.dart`

```dart
/// Platform feature configuration for selective feature inclusion
enum AppPlatform {
  mobileFull,      // All features
  mobileStreaming, // Music + IPTV only
  androidTv,       // IPTV only
  iPad,            // Streaming + tablet UX
}

/// Features that can be enabled/disabled per platform
enum AppFeature {
  finance,       // Coins, AiroMoney
  chat,          // Agent Chat, AI
  iptv,          // IPTV streaming
  music,         // Music/audio streaming
  games,         // Chess, Flame games
  reader,        // Tales/Manga reader
  ocr,           // ML Kit text recognition
}

/// Configuration for current build target
class PlatformFeatures {
  static const AppPlatform current = AppPlatform.values.byName(
    String.fromEnvironment('APP_PLATFORM', defaultValue: 'mobileFull'),
  );

  static const Set<AppFeature> enabledFeatures = {
    // Populated based on platform
  };

  static bool isEnabled(AppFeature feature) => enabledFeatures.contains(feature);
}
```

**Effort:** 1 day
**Risk:** Low
**Dependencies:** None

### Task 1.2: Create Feature Registry Pattern

**New File:** `app/lib/core/features/feature_registry.dart`

```dart
/// Abstract feature that can register routes and providers
abstract class AppFeatureModule {
  String get name;
  List<RouteBase> get routes;
  List<ProviderOrFamily> get providers;
  bool get isEnabledForPlatform;

  void initialize();
  void dispose();
}

/// Central registry for all features
class FeatureRegistry {
  static final List<AppFeatureModule> _features = [];

  static void register(AppFeatureModule feature) {
    if (feature.isEnabledForPlatform) {
      _features.add(feature);
      feature.initialize();
    }
  }

  static List<RouteBase> get allRoutes =>
    _features.expand((f) => f.routes).toList();

  static List<ProviderOrFamily> get allProviders =>
    _features.expand((f) => f.providers).toList();
}
```

**Effort:** 1.5 days
**Risk:** Medium (requires router refactor)
**Dependencies:** Task 1.1

### Task 1.3: Create Platform-Specific Entrypoints

**New Files:**
- `app/lib/main_tv.dart`
- `app/lib/main_mobile_streaming.dart`
- `app/lib/main_mobile_full.dart`

**Example: `app/lib/main_tv.dart`**
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/config/platform_features.dart';
import 'features/iptv/iptv_feature_module.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TV-specific setup
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Register only TV features
  FeatureRegistry.register(IptvFeatureModule());

  // Simplified initialization - no audio service, no ML Kit
  runApp(const AiroTvApp());
}
```

**Build Command:**
```bash
flutter build apk --release --target=lib/main_tv.dart \
  --dart-define=APP_PLATFORM=androidTv \
  --split-per-abi
```

**Effort:** 2 days
**Risk:** Medium
**Dependencies:** Task 1.1, 1.2

### Task 1.4: Update Melos with Platform Scripts

**File:** `melos.yaml`

**Add:**
```yaml
scripts:
  # Platform-specific builds
  build:tv:
    description: Build Android TV APK
    run: |
      cd app
      flutter build apk --release \
        --target=lib/main_tv.dart \
        --dart-define=APP_PLATFORM=androidTv \
        --split-per-abi \
        --tree-shake-icons

  build:streaming:
    description: Build Mobile Streaming APK
    run: |
      cd app
      flutter build apk --release \
        --target=lib/main_mobile_streaming.dart \
        --dart-define=APP_PLATFORM=mobileStreaming \
        --split-per-abi

  build:full:
    description: Build Full Mobile APK
    run: |
      cd app
      flutter build apk --release \
        --target=lib/main_mobile_full.dart \
        --dart-define=APP_PLATFORM=mobileFull \
        --split-per-abi
```

**Effort:** 0.5 days
**Risk:** Low
**Dependencies:** Task 1.3

### Task 1.5: Create TV-Specific App Shell

**New File:** `app/lib/core/app/airo_tv_app.dart`

**Key differences from mobile:**
- Landscape-only orientation
- No bottom navigation (use sidebar)
- D-pad focus management enabled
- Larger touch targets (min 48dp → 64dp)
- No audio service initialization

**Effort:** 1 day
**Risk:** Low
**Dependencies:** Task 1.3

### Phase 1 Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Separate entrypoints | 3 files | Code review |
| Feature registry | Implemented | Unit tests |
| Melos scripts | 3 new scripts | `melos run --list` |
| TV build compiles | ✓ | CI |

---

## Phase 2: TV Build (Weeks 4-5)

**Goal:** Create production-ready Android TV IPTV app <120MB

### Task 2.1: Extract IPTV to Standalone Package

**Current Location:** `app/lib/features/iptv/`
**Target Location:** `packages/feature_iptv/`

**Structure:**
```
packages/feature_iptv/
├── lib/
│   ├── feature_iptv.dart           # Public exports
│   ├── src/
│   │   ├── application/            # Providers
│   │   ├── domain/                 # Models, services
│   │   ├── data/                   # Data sources
│   │   └── presentation/           # Screens, widgets
│   └── iptv_feature_module.dart    # Feature registration
├── test/
└── pubspec.yaml
```

**pubspec.yaml:**
```yaml
name: feature_iptv
dependencies:
  flutter:
    sdk: flutter
  core_domain:
    path: ../core_domain
  core_ui:
    path: ../core_ui
  core_data:
    path: ../core_data
  video_player: 2.10.1
  flutter_riverpod: 2.6.1
  # NO audio_service, stockfish, flame, mlkit
```

**Effort:** 2 days
**Risk:** Medium (may have hidden dependencies)
**Dependencies:** Phase 1 complete

### Task 2.2: Create TV Design System

**New Package:** `packages/design_system_tv/`

**Key Components:**
```dart
// TV-specific focus indicators
class TvFocusDecoration extends BoxDecoration {
  // Larger, more visible focus rings
}

// TV card sizes (larger for 10-foot UI)
class TvCardDimensions {
  static const double cardWidth = 300;
  static const double cardHeight = 180;
  static const double focusPadding = 8;
}

// TV typography (larger, readable from distance)
class TvTypography {
  static const double titleSize = 28;
  static const double bodySize = 20;
}
```

**Effort:** 1.5 days
**Risk:** Low
**Dependencies:** Task 2.1

### Task 2.3: Configure TV Android Manifest

**New File:** `app/android/app/src/tv/AndroidManifest.xml`

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-feature android:name="android.software.leanback" android:required="true" />
    <uses-feature android:name="android.hardware.touchscreen" android:required="false" />

    <application
        android:label="Airo TV"
        android:icon="@mipmap/ic_launcher_tv"
        android:banner="@drawable/tv_banner">

        <activity
            android:name=".MainActivity"
            android:screenOrientation="landscape"
            android:configChanges="orientation|screenSize">

            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LEANBACK_LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

**Effort:** 0.5 days
**Risk:** Low
**Dependencies:** None

### Task 2.4: Create TV-Specific Build Configuration

**File:** `app/android/app/build.gradle.kts`

**Add product flavors:**
```kotlin
android {
    flavorDimensions += "platform"

    productFlavors {
        create("mobile") {
            dimension = "platform"
            applicationIdSuffix = ""
        }
        create("tv") {
            dimension = "platform"
            applicationIdSuffix = ".tv"
            // TV-specific manifest
            sourceSets.getByName("tv") {
                manifest.srcFile("src/tv/AndroidManifest.xml")
            }
        }
    }
}
```

**Effort:** 1 day
**Risk:** Medium
**Dependencies:** Task 2.3

### Task 2.5: Optimize Video Player for TV

**File:** `packages/feature_iptv/lib/src/presentation/widgets/tv_video_player.dart`

**Optimizations:**
- Hardware acceleration enabled by default
- Preload buffer: 10 seconds
- Disable gesture controls
- Enable D-pad scrubbing
- Large playback controls

**Effort:** 1 day
**Risk:** Low
**Dependencies:** Task 2.1

### Task 2.6: Build and Test TV APK

**Commands:**
```bash
# Build TV APK
melos run build:tv

# Install on TV
adb install -r app/build/app/outputs/flutter-apk/app-tv-arm64-v8a-release.apk

# Test with TV remote emulation
adb shell input keyevent KEYCODE_DPAD_DOWN
```

**Effort:** 1 day
**Risk:** Medium (device testing required)
**Dependencies:** All Phase 2 tasks

### Phase 2 Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| TV APK size | <120MB | apkanalyzer |
| Cold start time | <3s | Stopwatch |
| D-pad navigation | All screens | Manual test |
| Video playback | Smooth 1080p | Visual inspection |
| Focus states | Visible | Visual inspection |

---

## Phase 3: Mobile Streaming (Weeks 6-7)

**Goal:** Create streaming-only mobile app <150MB

### Task 3.1: Extract Music Feature to Package

**Current Location:** `app/lib/features/music/`
**Target Location:** `packages/feature_music/`

**Structure matches IPTV pattern**

**Key Dependencies:**
```yaml
dependencies:
  audio_service: ^0.18.18
  just_audio: ^0.10.5
  # Shared with IPTV: core_*, flutter_riverpod
```

**Effort:** 2 days
**Risk:** Medium
**Dependencies:** Phase 1 complete

### Task 3.2: Create Streaming Player Abstraction

**New Package:** `packages/core_player/`

**Purpose:** Unified player interface for audio and video

```dart
/// Abstract media player interface
abstract class MediaPlayer {
  Future<void> play(MediaSource source);
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);

  Stream<PlayerState> get stateStream;
  Stream<Duration> get positionStream;
}

/// Audio implementation
class AudioMediaPlayer implements MediaPlayer { ... }

/// Video implementation
class VideoMediaPlayer implements MediaPlayer { ... }
```

**Effort:** 2 days
**Risk:** Medium
**Dependencies:** Task 3.1

### Task 3.3: Create Streaming-Only Entrypoint

**File:** `app/lib/main_mobile_streaming.dart`

**Features included:**
- ✅ IPTV (video streaming)
- ✅ Music (audio streaming)
- ✅ Auth (login)
- ❌ Finance (excluded)
- ❌ Games (excluded)
- ❌ Reader (excluded)
- ❌ AI Chat with OCR (excluded)

**Effort:** 1 day
**Risk:** Low
**Dependencies:** Tasks 3.1, 3.2

### Task 3.4: Background Audio Support

**Ensure proper configuration:**
- `audio_service` notification channel
- Lock screen controls
- Bluetooth/headphone controls
- Mini-player integration

**Effort:** 1 day
**Risk:** Low
**Dependencies:** Task 3.1

### Phase 3 Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Streaming APK size | <150MB | apkanalyzer |
| Background audio | Works | Manual test |
| IPTV playback | Works | Manual test |
| Mini-player | Works | Manual test |

---

## Phase 4: Testing & iPad (Weeks 8-9)

**Goal:** Full test coverage and iPad optimization

### Task 4.1: Platform-Specific Integration Tests

**New Directory Structure:**
```
app/integration_test/
├── mobile/
│   └── full_app_test.dart
├── streaming/
│   └── streaming_app_test.dart
├── tv/
│   └── tv_app_test.dart
└── tablet/
    └── ipad_app_test.dart
```

**Effort:** 2 days
**Risk:** Low
**Dependencies:** Phases 2, 3

### Task 4.2: CI/CD Matrix Builds

**File:** `.github/workflows/ci.yml`

**Add matrix strategy:**
```yaml
jobs:
  build-platforms:
    strategy:
      matrix:
        platform: [mobile-full, mobile-streaming, tv]
        include:
          - platform: mobile-full
            target: lib/main_mobile_full.dart
            flavor: mobile
          - platform: mobile-streaming
            target: lib/main_mobile_streaming.dart
            flavor: mobile
          - platform: tv
            target: lib/main_tv.dart
            flavor: tv
```

**Effort:** 1 day
**Risk:** Low
**Dependencies:** Task 4.1

### Task 4.3: iPad Tablet Layout Optimization

**Target:** `app/lib/core/platform/tablet_layout.dart`

**Key Changes:**
- Multi-pane layouts (master-detail)
- Landscape-first experience
- Sidebar navigation instead of bottom nav
- Split-view support (iOS)

**Effort:** 2 days
**Risk:** Medium
**Dependencies:** None

### Task 4.4: Performance Benchmarks

**Create performance test suite:**
```dart
// app/test/performance/
void main() {
  testWidgets('IPTV startup < 3s', (tester) async {
    final stopwatch = Stopwatch()..start();
    await tester.pumpWidget(const AiroTvApp());
    await tester.pumpAndSettle();
    expect(stopwatch.elapsedMilliseconds, lessThan(3000));
  });
}
```

**Effort:** 1 day
**Risk:** Low
**Dependencies:** Phases 2, 3

### Phase 4 Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Test coverage | >70% | lcov |
| CI builds | 3 platforms | GitHub Actions |
| iPad layout | Tablet-optimized | Manual test |
| Performance | Benchmarks pass | Test results |

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Hidden cross-feature dependencies | High | Medium | Thorough dependency analysis in Phase 0 |
| TV device testing availability | Medium | High | Use Android TV emulator, Fire TV Stick |
| Feature extraction breaks functionality | Medium | High | Comprehensive test coverage before extraction |
| CI build time increases | High | Low | Parallel builds, caching |
| App Store TV approval | Low | Medium | Follow Android TV guidelines strictly |

---

## Resource Requirements

| Role | Phase 0 | Phase 1 | Phase 2 | Phase 3 | Phase 4 |
|------|---------|---------|---------|---------|---------|
| Flutter Dev | 1 | 1 | 1 | 1 | 1 |
| QA | 0.5 | 0.5 | 1 | 1 | 1 |
| DevOps | 0.5 | 0.5 | 0.5 | 0.5 | 1 |

**Total Duration:** 9 weeks
**Total Effort:** ~45 person-days

---

## Appendix A: File Paths Reference

### New Files to Create

```
# Phase 1
app/lib/core/config/platform_features.dart
app/lib/core/features/feature_registry.dart
app/lib/main_tv.dart
app/lib/main_mobile_streaming.dart
app/lib/main_mobile_full.dart
app/lib/core/app/airo_tv_app.dart

# Phase 2
packages/feature_iptv/pubspec.yaml
packages/feature_iptv/lib/feature_iptv.dart
packages/feature_iptv/lib/iptv_feature_module.dart
packages/design_system_tv/pubspec.yaml
app/android/app/src/tv/AndroidManifest.xml

# Phase 3
packages/feature_music/pubspec.yaml
packages/core_player/pubspec.yaml

# Phase 4
app/integration_test/tv/tv_app_test.dart
```

### Files to Modify

```
melos.yaml                           # Add platform scripts
app/pubspec.yaml                     # Add package references
app/android/app/build.gradle.kts     # Add flavors
.github/workflows/ci.yml             # Add matrix builds
```

---

## Appendix B: Build Commands Quick Reference

```bash
# Phase 0 - Quick wins
flutter build apk --release --split-per-abi --tree-shake-icons

# Phase 2 - TV build
flutter build apk --release \
  --target=lib/main_tv.dart \
  --dart-define=APP_PLATFORM=androidTv \
  --split-per-abi

# Phase 3 - Streaming build
flutter build apk --release \
  --target=lib/main_mobile_streaming.dart \
  --dart-define=APP_PLATFORM=mobileStreaming \
  --split-per-abi

# Analyze APK size
apkanalyzer files app/build/app/outputs/flutter-apk/app-release.apk

# Test on TV
adb connect <tv-ip>:5555
adb install -r app-tv-arm64-v8a-release.apk
```

---

## Appendix C: Alignment with Existing Conventions

### ADR-0001 Compliance

This sprint plan extends ADR-0001 (Package Structure) by:
- Adding feature packages (`feature_iptv`, `feature_music`)
- Adding platform packages (`design_system_tv`, `core_player`)
- Maintaining dependency direction: `apps → features → core`

### DEPENDENCY_LTS_STRATEGY Compliance

All new packages will:
- Pin exact versions (no caret ranges)
- Use same dependency versions as existing packages
- Be added to Dependabot coverage

### .augment/rules.md Compliance

- Riverpod for state management in all new packages
- GoRouter for navigation
- Domain-Driven Design structure
- Responsive design using existing breakpoints

---

**Document Version:** 1.0
**Created:** 2026-02-17
**Author:** Augment Agent
**Status:** Ready for Review

