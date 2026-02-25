# Phase 0: Quick Wins Implementation Guide

**Duration:** Week 1
**Expected APK Reduction:** 30-40% (323MB → ~110MB per ABI)

---

## ✅ Task 0.1: Enable Split-Per-ABI Builds

### Current Issue
Single APK bundles all 3 ABIs (arm64-v8a, armeabi-v7a, x86_64), tripling the native library size.

### Implementation

**1. Update CI build command:**

```yaml
# .github/workflows/ci.yml - Line ~254
- name: Build APK (Release)
  run: |
    cd app
    flutter build apk --release --split-per-abi --tree-shake-icons
```

**2. Update Makefile:**

```makefile
# Add to Makefile
build-release:
	cd app && flutter build apk --release --split-per-abi --tree-shake-icons --split-debug-info=build/debug-info

build-release-bundle:
	cd app && flutter build appbundle --release --tree-shake-icons --split-debug-info=build/debug-info
```

**3. Output files:**
```
app/build/app/outputs/flutter-apk/
├── app-arm64-v8a-release.apk    # ~110MB (most devices)
├── app-armeabi-v7a-release.apk  # ~100MB (older devices)
└── app-x86_64-release.apk       # ~115MB (emulators)
```

---

## ✅ Task 0.2: Enable Proguard Optimizations

### Current Status
✅ Already enabled in `app/android/app/build.gradle.kts`:
```kotlin
isMinifyEnabled = true
isShrinkResources = true
```

### Additional Optimization

**Add to `app/android/app/proguard-rules.pro`:**

```proguard
# Additional size optimizations
-optimizationpasses 5
-allowaccessmodification
-dontpreverify

# Remove logging in release
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}
```

---

## ✅ Task 0.3: Audit APK Contents

### Run Analysis

```powershell
# Windows PowerShell - Analyze APK
cd c:\Users\chauh\develop\airo_super_app

# Build release APK first
cd app
flutter build apk --release

# Use bundletool or Android Studio APK Analyzer
# Or use aapt2 to list contents
```

### Expected Heavy Contributors

| Component | Expected Size | Action |
|-----------|--------------|--------|
| libstockfish.so | ~70-80MB | Exclude from TV/streaming |
| ML Kit models | ~20-30MB | Exclude from TV |
| Flame assets | ~10-15MB | Exclude from TV/streaming |
| Flutter engine | ~15MB | Required |
| Firebase | ~8-10MB | Required |

---

## ✅ Task 0.4: Document Conditional Dependencies

### Dependencies by Feature

**Games Feature (exclude from TV/streaming):**
```yaml
# These add ~100MB combined
stockfish: 1.8.1      # Chess AI - 80MB native libs
flame: 1.35.0         # Game engine - 15MB
flame_audio: 2.11.13  # Game audio
chess: 0.8.1          # Chess logic
```

**ML/AI Feature (exclude from TV):**
```yaml
# These add ~30MB
google_mlkit_text_recognition: 0.15.1
```

**Audio Feature (exclude from TV):**
```yaml
# These add ~10MB
audio_service: ^0.18.18
just_audio: ^0.10.5
audioplayers: 6.5.1
```

---

## Implementation Checklist

- [ ] Update CI workflow with `--split-per-abi`
- [ ] Update Makefile with new build targets
- [ ] Add proguard optimizations
- [ ] Run APK analysis and document findings
- [ ] Build and verify split APKs work
- [ ] Update artifact upload to include all APKs

---

## Verification Commands

```powershell
# Build split APKs
cd app
flutter build apk --release --split-per-abi --tree-shake-icons

# Check sizes
Get-ChildItem "build\app\outputs\flutter-apk\*.apk" | `
  Select-Object Name, @{N='SizeMB';E={[math]::Round($_.Length/1MB,2)}}

# Expected output:
# app-arm64-v8a-release.apk    ~110MB
# app-armeabi-v7a-release.apk  ~100MB
# app-x86_64-release.apk       ~115MB
```

---

## Success Criteria

| Metric | Before | After | Status |
|--------|--------|-------|--------|
| Single APK size | 323MB | N/A | - |
| arm64 APK size | N/A | <115MB | ⏳ |
| armeabi APK size | N/A | <105MB | ⏳ |
| Build time | baseline | -10% | ⏳ |

