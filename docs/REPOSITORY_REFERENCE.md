# Repository Reference Guide for Airo Super App

## Classification System
Repositories are classified by:
- **Category**: Primary domain (AI/ML, UI/UX, Networking, etc.)
- **Use Case**: How it applies to Airo
- **Tech Stack**: Technologies used
- **Relevance**: High/Medium/Low for current project
- **Key Features**: Notable implementations

---

## 🤖 AI/ML & On-Device Processing

### 1. **Google Gemini Nano & ML Kit**
- **URL**: https://developer.android.com/ai/gemini-nano/ml-kit-genai
- **Category**: On-Device AI/LLM
- **Relevance**: ⭐⭐⭐⭐⭐ (CRITICAL)
- **Use Case**: 
  - Gemini Nano 1B model integration
  - On-device LLM for chat, summarization, image description
  - Private Compute Services for secure inference
- **Tech Stack**: Android, Kotlin, AICore SDK, ML Kit
- **Key Features**:
  - ~2.8GB model download via Private Compute Services
  - Int4 quantization for Pixel 9
  - Streaming generation support
  - Function calling capabilities
- **Airo Integration**: Core for diet plans, bill splitting, form filling

### 2. **Google ML Kit Samples (Android)**
- **URL**: https://github.com/googlesamples/mlkit/tree/master/android/genai
- **Category**: ML Kit Implementation Reference
- **Relevance**: ⭐⭐⭐⭐⭐ (CRITICAL)
- **Use Case**: 
  - Reference implementation for Gemini Nano
  - OCR with MediaPipe/ML Kit
  - Text recognition for form filling
- **Tech Stack**: Android, Kotlin, ML Kit, MediaPipe
- **Key Features**:
  - Chat, summarization, image description examples
  - Proper error handling for model availability
  - Download progress tracking
  - Streaming responses
- **Airo Integration**: Use as reference for plugin implementation

### 3. **Google AI Edge SDK**
- **URL**: https://github.com/stefanoamorelli/ai-edge-sdk
- **Category**: On-Device AI Framework
- **Relevance**: ⭐⭐⭐⭐⭐ (CRITICAL)
- **Use Case**: 
  - AICore SDK for Gemini Nano
  - Model preparation and inference
  - Download callbacks and progress tracking
- **Tech Stack**: Android, Kotlin, AICore 0.0.1-exp02
- **Key Features**:
  - GenerativeModel API
  - DownloadConfig with callbacks
  - GenerationConfig builder pattern
  - Error handling for NOT_AVAILABLE errors
- **Airo Integration**: Direct dependency for Gemini Nano plugin

---

## 🎨 UI/UX & Design Systems

### 4. **FluentUI System Icons**
- **URL**: https://github.com/microsoft/fluentui-system-icons
- **Category**: Design System / Icon Library
- **Relevance**: ⭐⭐⭐ (HIGH)
- **Use Case**: 
  - Consistent icon set for Airo UI
  - Material Design 3 compatible
  - Multi-platform support
- **Tech Stack**: SVG, Flutter compatible
- **Key Features**:
  - 5000+ icons
  - Multiple sizes and weights
  - Accessibility support
- **Airo Integration**: Use for diet plans, bill splitting, form filling tiles

### 5. **Awesome Flutter**
- **URL**: https://github.com/Solido/awesome-flutter
- **Category**: Flutter Resources & Best Practices
- **Relevance**: ⭐⭐⭐⭐ (HIGH)
- **Use Case**: 
  - Flutter package recommendations
  - Architecture patterns
  - Community best practices
- **Tech Stack**: Flutter, Dart
- **Key Features**:
  - Curated list of 1000+ packages
  - Architecture guides
  - Performance optimization tips
- **Airo Integration**: Reference for package selection and patterns

### 6. **Best Flutter UI Templates**
- **URL**: https://github.com/mitesh77/Best-Flutter-UI-Templates
- **Category**: UI/UX Templates
- **Relevance**: ⭐⭐⭐ (HIGH)
- **Use Case**: 
  - Chat UI for Gemini Nano chat tile
  - Form UI for bill splitting
  - Image gallery for image description
- **Tech Stack**: Flutter, Dart, Material Design 3
- **Key Features**:
  - Pre-built UI components
  - Responsive layouts
  - Animation examples
- **Airo Integration**: Inspiration for Airo tile designs

---

## 🔌 Networking & HTTP

### 7. **Dio - HTTP Client**
- **URL**: https://github.com/cfug/dio
- **Category**: Networking Library
- **Relevance**: ⭐⭐⭐⭐ (HIGH)
- **Use Case**: 
  - API calls for cloud services
  - File uploads (PDFs, images)
  - Interceptors for auth/logging
- **Tech Stack**: Flutter, Dart
- **Key Features**:
  - Request/response interceptors
  - File upload/download
  - Timeout handling
  - Retry logic
- **Airo Integration**: Use for cloud API calls and file uploads

### 8. **Telegram Package**
- **URL**: https://pub.dev/packages/telegram
- **Category**: Third-Party Integration
- **Relevance**: ⭐⭐ (MEDIUM)
- **Use Case**: 
  - Optional: Send notifications via Telegram
  - Alternative to Firebase Cloud Messaging
- **Tech Stack**: Flutter, Dart
- **Key Features**:
  - Bot API integration
  - Message sending
  - Webhook support
- **Airo Integration**: Optional for diet plan notifications

---

## 🎮 Game Engine & Graphics

### 9. **Flame Engine**
- **URL**: https://github.com/flame-engine/flame
- **Category**: 2D Game Engine
- **Relevance**: ⭐⭐ (LOW)
- **Use Case**: 
  - Optional: Animated UI elements
  - Gesture handling
  - Particle effects
- **Tech Stack**: Flutter, Dart
- **Key Features**:
  - 2D rendering
  - Collision detection
  - Animation system
- **Airo Integration**: Optional for enhanced UI animations

---

## 📦 Flutter Ecosystem

### 10. **Flutter Packages (Official)**
- **URL**: https://github.com/flutter/packages
- **Category**: Official Flutter Packages
- **Relevance**: ⭐⭐⭐⭐⭐ (CRITICAL)
- **Use Case**: 
  - Official plugins for Android/iOS
  - Camera, file picker, notifications
  - Platform channels
- **Tech Stack**: Flutter, Dart, Kotlin, Swift
- **Key Features**:
  - camera plugin
  - file_picker plugin
  - local_notifications plugin
  - shared_preferences plugin
- **Airo Integration**: Core dependencies for multi-platform support

### 11. **FlutterFire (Firebase)**
- **URL**: https://github.com/firebase/flutterfire
- **Category**: Firebase Integration
- **Relevance**: ⭐⭐⭐ (HIGH)
- **Use Case**: 
  - Cloud Firestore for data sync
  - Firebase Auth (optional)
  - Cloud Storage for PDFs/images
  - Analytics
- **Tech Stack**: Flutter, Dart, Firebase
- **Key Features**:
  - Real-time database
  - Cloud storage
  - Authentication
  - Analytics
- **Airo Integration**: Optional for cloud backup and sync

### 12. **Google ML Kit Flutter**
- **URL**: https://github.com/flutter-ml/google_ml_kit_flutter
- **Category**: ML Kit Wrapper
- **Relevance**: ⭐⭐⭐⭐ (HIGH)
- **Use Case**: 
  - OCR for form filling
  - Text recognition
  - Face detection
  - Barcode scanning
- **Tech Stack**: Flutter, Dart, ML Kit
- **Key Features**:
  - Text recognition
  - Document scanning
  - Face detection
- **Airo Integration**: Use for PDF/image text extraction

---

## 📱 Reference Apps

### 13. **PicaComic**
- **URL**: https://github.com/wgh136/PicaComic
- **Category**: Reference App (Media Viewer)
- **Relevance**: ⭐⭐ (MEDIUM)
- **Use Case**: 
  - Image gallery implementation
  - Pagination patterns
  - Caching strategies
- **Tech Stack**: Flutter, Dart
- **Key Features**:
  - Image caching
  - Lazy loading
  - Pagination
- **Airo Integration**: Reference for image description tile

### 14. **PikaPika**
- **URL**: https://github.com/ComicSparks/pikapika
- **Category**: Reference App (Media Viewer)
- **Relevance**: ⭐⭐ (MEDIUM)
- **Use Case**: 
  - Similar to PicaComic
  - UI/UX patterns
  - Performance optimization
- **Tech Stack**: Flutter, Dart
- **Key Features**:
  - Efficient image loading
  - Smooth scrolling
  - Memory management
- **Airo Integration**: Reference for performance optimization

---

## 📊 Priority Implementation Order

### Phase 1 (Critical - Week 1-2)
1. Google Gemini Nano & ML Kit (fix current blocker)
2. Google ML Kit Samples (reference implementation)
3. Flutter Packages (core dependencies)

### Phase 2 (High - Week 3-4)
1. Dio (networking)
2. Google ML Kit Flutter (OCR)
3. FluentUI Icons (UI)
4. Best Flutter UI Templates (design)

### Phase 3 (Medium - Week 5-6)
1. FlutterFire (optional cloud sync)
2. PicaComic/PikaPika (reference apps)
3. Telegram (optional notifications)

### Phase 4 (Low - Future)
1. Flame Engine (optional animations)

---

## 🎯 Airo Super App Architecture Mapping

```
┌─────────────────────────────────────────┐
│         Airo Super App                  │
├─────────────────────────────────────────┤
│ UI Layer (Flutter)                      │
│ ├─ FluentUI Icons                       │
│ ├─ Best Flutter UI Templates            │
│ └─ Flame Engine (optional)              │
├─────────────────────────────────────────┤
│ AI/ML Layer                             │
│ ├─ Gemini Nano (chat, summarization)    │
│ ├─ ML Kit (OCR, text recognition)       │
│ └─ Google ML Kit Flutter (wrapper)      │
├─────────────────────────────────────────┤
│ Networking Layer                        │
│ ├─ Dio (HTTP client)                    │
│ └─ Telegram (optional notifications)    │
├─────────────────────────────────────────┤
│ Data Layer                              │
│ ├─ SQLCipher (local encryption)         │
│ ├─ FlutterFire (optional cloud)         │
│ └─ Shared Preferences                   │
├─────────────────────────────────────────┤
│ Platform Layer                          │
│ ├─ Flutter Packages (core)              │
│ ├─ AICore SDK (Gemini Nano)             │
│ └─ MediaPipe (OCR)                      │
└─────────────────────────────────────────┘
```

---

## 📝 Notes for Future Reference

- **Gemini Nano Blocker**: Model not available on device - check Private Compute Services
- **OCR Strategy**: Use ML Kit + MediaPipe for form field extraction
- **Offline-First**: All processing on-device, cloud sync optional
- **Performance**: Target <3s PDF extraction, <1.2GB footprint
- **Security**: SQLCipher for local data, Private Compute Services for AI


