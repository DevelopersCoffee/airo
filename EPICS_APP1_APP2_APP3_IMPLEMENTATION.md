# AIRO Epics APP-1, APP-2, APP-3 Implementation Guide

## Overview

This document covers the implementation of the first 3 epics:
- **APP-1**: OCR & Image Recognition
- **APP-2**: Database & Offline Storage
- **APP-3**: Chat Interface

All features are integrated with **Gemini Nano** on-device AI for hardware-aware code execution.

---

## ✅ What Was Implemented

### Epic APP-1: OCR & Image Recognition

**Files Created:**
- `lib/services/ocr_service.dart` - ML Kit text recognition
- `lib/providers/food_provider.dart` - Food tracking state management

**Features:**
- ✅ Camera integration for food photos
- ✅ Gallery image selection
- ✅ Text extraction using Google ML Kit
- ✅ Nutritional information parsing
- ✅ Food item storage

**Key Methods:**
```dart
// Capture from camera
await ocrService.pickImageFromCamera();

// Extract text
final text = await ocrService.extractTextFromImage(imageFile);

// Parse nutrition
final nutrition = ocrService.parseNutritionalInfo(text);
```

---

### Epic APP-2: Database & Offline Storage

**Files Created:**
- `lib/services/database_service.dart` - SQLite database
- `lib/models/food_item.dart` - Food data model

**Features:**
- ✅ SQLite database with sqflite
- ✅ Food items table
- ✅ Messages table
- ✅ Reminders table
- ✅ CRUD operations
- ✅ Offline-first architecture

**Database Schema:**
```sql
-- Food Items
CREATE TABLE food_items (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  calories REAL,
  protein REAL,
  carbs REAL,
  fat REAL,
  fiber REAL,
  imagePath TEXT,
  extractedText TEXT,
  createdAt TEXT NOT NULL,
  userId TEXT NOT NULL
)

-- Messages
CREATE TABLE messages (
  id INTEGER PRIMARY KEY,
  content TEXT NOT NULL,
  role TEXT NOT NULL,
  createdAt TEXT NOT NULL,
  userId TEXT NOT NULL
)

-- Reminders
CREATE TABLE reminders (
  id INTEGER PRIMARY KEY,
  title TEXT NOT NULL,
  scheduledTime TEXT NOT NULL,
  reminderType TEXT NOT NULL,
  isCompleted INTEGER DEFAULT 0,
  userId TEXT NOT NULL
)
```

**Key Methods:**
```dart
// Food operations
await db.insertFoodItem(foodItem);
await db.getFoodItems(userId);
await db.updateFoodItem(foodItem);
await db.deleteFoodItem(id);

// Message operations
await db.insertMessage(userId, content, role);
await db.getMessages(userId);

// Reminder operations
await db.insertReminder(userId, title, scheduledTime, type);
await db.getReminders(userId);
```

---

### Epic APP-3: Chat Interface

**Files Created:**
- `lib/services/ai_service.dart` - On-device AI with Gemini Nano
- `lib/providers/chat_provider.dart` - Chat state management
- `lib/screens/chat_screen.dart` - Chat UI

**Features:**
- ✅ Real-time chat interface
- ✅ Message history storage
- ✅ AI-powered responses
- ✅ Gemini Nano integration (on-device)
- ✅ Hardware-aware code execution
- ✅ Offline-first messaging

**AI Service Features:**
```dart
// Initialize AI
await aiService.initialize();

// Check Gemini Nano availability
bool hasGemini = aiService.hasGeminiNano;

// Generate responses
final response = await aiService.generateChatResponse(message);

// Analyze food
final analysis = await aiService.analyzeFoodItem(name, nutrition);
```

---

## 🔧 Installation & Setup

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Android Configuration

Update `android/app/build.gradle.kts`:

```kotlin
android {
    compileSdk 34
    
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
}
```

### 3. iOS Configuration

Update `ios/Podfile`:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
  end
end
```

### 4. Web Configuration

No additional setup needed for web (uses local responses).

---

## 🚀 Running the App

### Chrome (Web)

```bash
flutter run -d chrome
```

### Android Pixel 9 Emulator

```bash
# Start emulator
emulator -avd Pixel_9_API_35

# Run app
flutter run
```

### Desktop (Windows/Linux/macOS)

```bash
flutter run -d windows
# or
flutter run -d linux
# or
flutter run -d macos
```

---

## 📱 Features Walkthrough

### 1. Capture Food Photo

1. Open app
2. Click menu → "Capture Food"
3. Take photo of food
4. App extracts text and nutritional info
5. Food item saved to database

### 2. Select from Gallery

1. Click menu → "Select from Gallery"
2. Choose image
3. App processes image
4. Food item saved

### 3. Chat with AI

1. Type message in chat input
2. Click send button
3. AI generates response (on-device with Gemini Nano if available)
4. Message history saved to database
5. Offline access to all messages

### 4. View Food History

- All captured food items stored in database
- Accessible offline
- Nutritional information tracked

---

## 🤖 Gemini Nano Integration

### Hardware-Aware Code

The app automatically detects and uses Gemini Nano on Android:

```dart
// In AIService
if (defaultTargetPlatform == TargetPlatform.android) {
  _hasGeminiNano = await _checkGeminiNanoAvailability();
}

// Use Gemini Nano if available
if (_hasGeminiNano) {
  return await _generateWithGeminiNano(prompt);
} else {
  return _generateLocalResponse(foodName, nutritionalInfo);
}
```

### Benefits

- ✅ No network required
- ✅ Low latency responses
- ✅ Privacy-preserving (data stays on device)
- ✅ Reduced battery usage
- ✅ Works offline

### Supported Platforms

- ✅ Android 12+ with Gemini Nano
- ✅ Fallback to local responses on other platforms
- ✅ Chrome (local responses)
- ✅ Desktop (local responses)

---

## 📊 Data Models

### FoodItem

```dart
class FoodItem {
  final int? id;
  final String name;
  final double? calories;
  final double? protein;
  final double? carbs;
  final double? fat;
  final double? fiber;
  final String? imagePath;
  final String? extractedText;
  final DateTime createdAt;
  final String userId;
}
```

### ChatMessage

```dart
class ChatMessage {
  final String id;
  final String content;
  final String role; // 'user' or 'assistant'
  final DateTime timestamp;
}
```

---

## 🧪 Testing

### Test Capture & Analysis

```dart
// Test OCR
final ocrService = OCRService();
final imageFile = await ocrService.pickImageFromCamera();
final text = await ocrService.extractTextFromImage(imageFile);
final nutrition = ocrService.parseNutritionalInfo(text);
```

### Test Database

```dart
// Test database
final db = DatabaseService();
final foodItem = FoodItem(...);
final id = await db.insertFoodItem(foodItem);
final items = await db.getFoodItems(userId);
```

### Test Chat

```dart
// Test chat
final chatProvider = ChatProvider();
await chatProvider.initialize(userId);
await chatProvider.sendMessage('What is protein?');
```

---

## 🐛 Troubleshooting

### Camera Not Working

- Check permissions in `AndroidManifest.xml`
- Ensure camera permission granted
- Try on physical device

### Database Errors

- Check database path
- Ensure write permissions
- Clear app data and retry

### AI Service Issues

- Check Gemini Nano availability
- Verify Android version (12+)
- Check device hardware support

### Chat Not Responding

- Check internet connection (for cloud AI)
- Verify database is initialized
- Check logs: `flutter run -v`

---

## 📚 File Structure

```
lib/
├── models/
│   └── food_item.dart
├── services/
│   ├── database_service.dart
│   ├── ocr_service.dart
│   └── ai_service.dart
├── providers/
│   ├── auth_provider.dart
│   ├── chat_provider.dart
│   └── food_provider.dart
├── screens/
│   ├── login_screen.dart
│   └── chat_screen.dart
└── main.dart
```

---

## ✨ Next Steps

### Phase 2: Advanced Features

1. **Notifications & Reminders** (APP-6)
   - flutter_local_notifications
   - Reminder scheduling
   - Seed-soak logic

2. **Privacy & Settings** (APP-7)
   - SQLCipher encryption
   - Settings page
   - Cloud sync toggle

3. **Testing & Release** (APP-8)
   - Unit tests
   - E2E tests
   - Release APK

---

## 📞 Support

For issues:
1. Check TROUBLESHOOTING.md
2. Review logs: `flutter run -v`
3. Check AUTH_DEBUGGING_GUIDE.md
4. See AIRO_BUILDING_BLOCKS_ROADMAP.md

---

## 🎉 Summary

✅ **APP-1**: OCR & Image Recognition - COMPLETE
✅ **APP-2**: Database & Offline Storage - COMPLETE
✅ **APP-3**: Chat Interface - COMPLETE
✅ **Gemini Nano Integration** - COMPLETE
✅ **Hardware-Aware Code** - COMPLETE

**Status**: Ready for testing on Chrome and Android Pixel 9!

Run: `flutter run -d chrome` or `flutter run`

