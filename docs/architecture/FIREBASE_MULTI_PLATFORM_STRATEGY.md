# Firebase Multi-Platform Configuration Strategy

## Executive Summary

This document provides a phased plan for configuring Firebase across multiple app variants
(Mobile Full, Mobile Streaming, Android TV) while maintaining a single Firebase project.

**Key Decision:** Use **ONE Firebase project** with **multiple Android app registrations**.

---

## Phase-wise Implementation Plan

### Phase 0.5: Firebase Setup (Week 1, alongside Quick Wins)

**Goal:** Register all package IDs in Firebase, configure flavor-specific configs

#### Task 0.5.1: Register App Variants in Firebase Console

**Time:** 30 minutes
**No code changes required**

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Open project `devscoffee-airo`
3. Click ⚙️ → Project Settings → Your apps → Add app → Android
4. Register each variant:

| Variant | Package Name | App Nickname |
|---------|-------------|--------------|
| Mobile Full | `io.airo.app` | Airo Mobile (existing) |
| Mobile Streaming | `io.airo.app.streaming` | Airo Streaming |
| Android TV | `io.airo.app.tv` | Airo TV |

5. **DO NOT** download individual files - proceed to next step

#### Task 0.5.2: Download Combined google-services.json

**Time:** 10 minutes

After registering all apps:
1. In Firebase Console → Project Settings → Your apps
2. Click **"Download latest config file"** (downloads combined JSON)
3. The combined file includes ALL registered package IDs:

```json
{
  "client": [
    {
      "client_info": {
        "android_client_info": { "package_name": "io.airo.app" }
      }
    },
    {
      "client_info": {
        "android_client_info": { "package_name": "io.airo.app.streaming" }
      }
    },
    {
      "client_info": {
        "android_client_info": { "package_name": "io.airo.app.tv" }
      }
    }
  ]
}
```

4. Save as `app/android/app/google-services.json`

**Result:** Single file works for ALL flavors automatically!

#### Task 0.5.3: Update firebase_options.dart

**Time:** 30 minutes
**File:** `app/lib/firebase_options.dart`

```dart
/// Platform-aware Firebase options supporting multiple app variants
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _getAndroidOptions();
      case TargetPlatform.iOS:
        return ios;
      // ... other platforms
    }
  }
  
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
  
  // Mobile Full (existing)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCBhj62CjX9G7-QNbF3e-53BiM3FYcWNxw',
    appId: '1:906799550225:android:8052938d459ef9832206b0',
    messagingSenderId: '906799550225',
    projectId: 'devscoffee-airo',
    storageBucket: 'devscoffee-airo.firebasestorage.app',
  );
  
  // Android TV (get appId from Firebase after registering)
  static const FirebaseOptions androidTv = FirebaseOptions(
    apiKey: 'AIzaSyCBhj62CjX9G7-QNbF3e-53BiM3FYcWNxw',
    appId: '1:906799550225:android:TV_APP_ID_HERE', // From Firebase Console
    messagingSenderId: '906799550225',
    projectId: 'devscoffee-airo',
    storageBucket: 'devscoffee-airo.firebasestorage.app',
  );
  
  // Mobile Streaming (get appId from Firebase after registering)
  static const FirebaseOptions androidStreaming = FirebaseOptions(
    apiKey: 'AIzaSyCBhj62CjX9G7-QNbF3e-53BiM3FYcWNxw',
    appId: '1:906799550225:android:STREAMING_APP_ID_HERE', // From Firebase Console
    messagingSenderId: '906799550225',
    projectId: 'devscoffee-airo',
    storageBucket: 'devscoffee-airo.firebasestorage.app',
  );
  
  // Web (existing)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAXwAHFzEmvM0VMq_OVR-J_rm3aemlmq5A',
    appId: '1:906799550225:web:28533fb091ebbb3d2206b0',
    messagingSenderId: '906799550225',
    projectId: 'devscoffee-airo',
    authDomain: 'devscoffee-airo.firebaseapp.com',
    storageBucket: 'devscoffee-airo.firebasestorage.app',
  );
}
```

#### Task 0.5.4: Update Build Commands

**Time:** 15 minutes

Add `--dart-define=APP_VARIANT=X` to build commands:

```bash
# Mobile Full (default)
flutter build apk --release --dart-define=APP_VARIANT=full

# Android TV
flutter build apk --release --dart-define=APP_VARIANT=tv --dart-define=APP_PLATFORM=androidTv

# Mobile Streaming
flutter build apk --release --dart-define=APP_VARIANT=streaming --dart-define=APP_PLATFORM=mobileStreaming
```

---

### Phase 0.5 Checklist

- [ ] Register `io.airo.app.streaming` in Firebase Console
- [ ] Register `io.airo.app.tv` in Firebase Console
- [ ] Download combined `google-services.json`
- [ ] Update `firebase_options.dart` with new app IDs
- [ ] Update melos.yaml build scripts with `--dart-define`
- [ ] Test Firebase initialization on each variant

---

## Alternative: Flavor-Specific Config Files (Optional)

If you prefer separate files per flavor:

```
app/android/app/
├── src/
│   ├── main/
│   │   └── google-services.json    # Fallback (mobile full)
│   ├── tv/
│   │   └── google-services.json    # TV-specific
│   └── streaming/
│       └── google-services.json    # Streaming-specific
```

**build.gradle.kts:**
```kotlin
android {
    flavorDimensions += "platform"
    productFlavors {
        create("mobile") { dimension = "platform" }
        create("tv") { dimension = "platform"; applicationIdSuffix = ".tv" }
        create("streaming") { dimension = "platform"; applicationIdSuffix = ".streaming" }
    }
}
```

**Note:** The combined JSON approach (Task 0.5.2) is simpler and recommended.

---

## What Stays Shared Across All Variants

| Firebase Service | Behavior |
|-----------------|----------|
| **Authentication** | Same user can sign in on any app variant |
| **Firestore** | Same database, use collection groups or filters |
| **Analytics** | Separate streams per app, can be merged in BigQuery |
| **Crashlytics** | Separate crash reports per app variant |
| **Cloud Messaging** | Can target by app or broadcast to all |

---

## Next Steps After Phase 0.5

1. **Phase 1:** Create platform entrypoints (main_tv.dart, etc.)
2. **Phase 2:** Add product flavors to build.gradle.kts
3. **Phase 2:** Create TV-specific AndroidManifest.xml
