# 📝 Changelog v1.1.0 - Bill Split & E2E Testing

**Date**: 2025-11-29  
**Status**: Development

---

## 🆕 New Features

### 1. Bill Split Feature (Splitwise-style)
**New Files**:
- `app/lib/features/bill_split/` - Complete bill splitting feature

**Key Capabilities**:
- 📸 **Receipt OCR Scanning** - Scan receipts using ML Kit + Gemini Nano hybrid
- 🧮 **Itemized Splitting** - Assign individual items to different people
- 👥 **Multi-participant Support** - Split bills among any number of people
- 📋 **WhatsApp Sharing** - Copy formatted itemized summary for sharing
- 💰 **Price Correction** - Automatically fixes OCR errors (₹45 read as 745)
- 🏪 **Vendor Detection** - Recognizes Instamart, Zepto, BigBasket, Blinkit

**Dependencies Added** (`pubspec.yaml`):
```yaml
flutter_contacts: ^1.1.9+2      # Contact picker for participants
permission_handler: ^12.0.0+1   # Permission management
image_picker: ^1.2.1            # Camera/Gallery image selection
google_mlkit_text_recognition: ^0.15.0  # On-device OCR
```

### 2. E2E Testing Infrastructure
**New Files**:
- `e2e/` - Playwright browser E2E tests
- `app/integration_test/patrol_test.dart` - Patrol device tests
- `app/test/features/bill_split/` - Unit tests for bill split

**Testing Strategy**:
```
1. Playwright tests (browser) → 2. Patrol tests (device) → 3. Deploy
```

**Unit Tests Added** (14 tests):
- Receipt Parser - Instamart Format (9 tests)
- WhatsApp Message Generation (3 tests)
- Per-user Total Calculation (2 tests)

---

## 🔧 Modified Files

### Routing (`app/lib/core/routing/`)
- **app_router.dart** - Added `/money/split` route for bill split screen
- **route_names.dart** - Added `billSplit` constant

### Money Feature (`app/lib/features/money/`)
- **money_overview_screen.dart** - Added Quick Actions (Split Bill, Scan Receipt, Send Money, Request)

### Chess Game (`app/lib/features/games/`)
- **chess_engine.dart** - Added `ChessEngineAsync` mixin for async initialization
- **real_chess_engine.dart** - Implemented `ChessEngineAsync` mixin
- **chess_game.dart** - Updated to use `ChessEngineFactory` for platform compatibility

**New Platform-specific Files**:
- `chess_engine_factory.dart` - Factory for creating platform-specific engines
- `chess_engine_factory_native.dart` - Native platform (Stockfish)
- `chess_engine_factory_web.dart` - Web platform (stub engine)
- `chess_engine_stub.dart` - Stub engine for unsupported platforms

### Build Configuration
- **Makefile** - Added E2E testing commands (52 new lines)
- **AndroidManifest.xml** - Added `READ_CONTACTS` permission

### Generated Plugin Registrations (Auto-generated)
- `linux/flutter/generated_plugin_registrant.cc` - Added file_selector_linux
- `linux/flutter/generated_plugins.cmake` - Added file_selector_linux
- `macos/Flutter/GeneratedPluginRegistrant.swift` - Added file_selector_macos
- `windows/flutter/generated_plugin_registrant.cc` - Added file_selector_windows, permission_handler_windows
- `windows/flutter/generated_plugins.cmake` - Added file_selector_windows, permission_handler_windows

---

## 📋 Makefile Commands Added

```makefile
# E2E Testing
make test-e2e              # Run all E2E tests (browser + device)
make test-browser          # Run Playwright browser tests
make test-browser-headless # Run headless (CI)
make test-browser-debug    # Debug with Playwright UI
make test-browser-report   # Show test report
make test-device           # Run Patrol device tests
make test-device-android   # Android only
make test-device-ios       # iOS only
make run-chrome-html       # Flutter Web with HTML renderer
make setup-e2e             # Setup all E2E dependencies
```

---

## 🧪 Test Coverage

| Component | Tests | Status |
|-----------|-------|--------|
| Receipt Parser (Instamart) | 9 | ✅ Pass |
| WhatsApp Message Generation | 3 | ✅ Pass |
| Per-user Total Calculation | 2 | ✅ Pass |
| **Total** | **14** | ✅ **All Pass** |

---

## 📦 New Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| flutter_contacts | ^1.1.9+2 | Contact picker |
| permission_handler | ^12.0.0+1 | Runtime permissions |
| image_picker | ^1.2.1 | Camera/Gallery |
| google_mlkit_text_recognition | ^0.15.0 | On-device OCR |

**Transitive Dependencies Added**:
- file_selector_linux/macos/windows
- permission_handler_android/apple/html/windows
- image_picker_android/ios/web/linux/macos/windows
- google_mlkit_commons

---

## 🚀 How to Use

### Bill Split
1. Go to **Coins** tab → **Split Bill**
2. Add participants
3. Click **Split by items** → **Upload Receipt**
4. OCR scans and extracts items
5. Assign items to participants
6. Confirm and copy summary for WhatsApp

### Run Tests
```bash
# Unit tests
cd app && flutter test test/features/bill_split/

# Playwright browser tests
make run-chrome-html  # Terminal 1
make test-browser     # Terminal 2

# Patrol device tests
make test-device
```

---

## 📌 Git Summary

**Modified**: 15 files  
**New (Untracked)**: 13 files/directories

```
M  Makefile (+52 lines)
M  app/android/app/src/main/AndroidManifest.xml (+3 lines)
M  app/lib/core/routing/app_router.dart (+8 lines)
M  app/lib/core/routing/route_names.dart (+3 lines)
M  app/lib/features/games/domain/services/chess_engine.dart (+5 lines)
M  app/lib/features/games/domain/services/real_chess_engine.dart (+2 lines)
M  app/lib/features/games/presentation/flame/chess_game.dart (+6 lines)
M  app/lib/features/money/presentation/screens/money_overview_screen.dart (+105 lines)
M  app/pubspec.yaml (+4 dependencies)
+  Auto-generated plugin registrations (6 files)
```

