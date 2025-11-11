# Gemini Nano Quick Start Guide

## 🚀 Quick Setup for Pixel 9 Testing

### Prerequisites

- Pixel 9 device at `192.168.1.77:42529`
- Flutter installed
- ADB configured

### 1. Connect to Device

```bash
# Connect via wireless ADB
adb connect 192.168.1.77:42529

# Verify
adb devices
# Should show: 192.168.1.77:42529    device
```

### 2. Build Dependencies

```bash
cd app

# Get Flutter dependencies
flutter pub get

# Build Android dependencies
cd android
./gradlew build
cd ..
```

### 3. Run on Device

```bash
# Run in debug mode
flutter run -d 192.168.1.77:42529

# Or build and install APK
flutter build apk --debug
flutter install -d 192.168.1.77:42529
```

### 4. Test Gemini Nano Integration

#### Step 1: Open Quest Feature
1. Launch the app
2. Navigate to Quest feature
3. Create a new quest or open existing one

#### Step 2: Check AI Provider
1. Look for AI provider icon in AppBar (top-right)
2. Icon shows current provider:
   - 🤖 Phone = Gemini Nano (on-device)
   - ☁️ Cloud = Gemini Cloud (API)
   - ✨ Star = Auto-select

#### Step 3: Select Provider
1. Tap the AI provider icon
2. Bottom sheet opens showing available providers
3. Check if "Gemini Nano" shows as available
4. If available, you'll see:
   - ✅ Green checkmark
   - "On-device AI" description
   - Capability chips (Streaming, Files)

#### Step 4: Test Query
1. Select Gemini Nano (if available)
2. Type a query: "Create a 7-day diet plan"
3. Send the message
4. Response should come from on-device AI

### 5. Verify It's Working

#### Check Logs

```bash
# Terminal 1: Watch Flutter logs
flutter logs

# Terminal 2: Watch Android logs
adb logcat | grep -E "GeminiNano|AIRouter"
```

#### Expected Log Output

```
✅ Success:
I/flutter: Checking AI provider availability...
I/flutter: Gemini Nano: Available
I/flutter: Device: Google Pixel 9
I/flutter: AI Provider changed to: Gemini Nano
I/flutter: Processing query with: Gemini Nano

❌ Not Available (fallback to Cloud):
I/flutter: Checking AI provider availability...
I/flutter: Gemini Nano: Not supported on this device
I/flutter: Gemini Cloud: Available
I/flutter: Processing query with: Gemini Cloud
```

## 🎯 Features to Test

### 1. Provider Selection
- [ ] Open provider selector
- [ ] See all three options (Nano, Cloud, Auto)
- [ ] Check availability status
- [ ] Switch between providers
- [ ] Verify selection persists

### 2. On-Device AI (if available)
- [ ] Select Gemini Nano
- [ ] Send simple query
- [ ] Verify response
- [ ] Test streaming response
- [ ] Check response time (<3s target)

### 3. Fallback Behavior
- [ ] Set to Auto mode
- [ ] Verify it selects Nano if available
- [ ] If Nano unavailable, verify Cloud fallback
- [ ] Check error messages are clear

### 4. Layer Navigation
- [ ] Provider selector opens as bottom sheet
- [ ] Can drag to resize
- [ ] Can dismiss by swiping down
- [ ] Back button works correctly
- [ ] Multiple layers stack properly

### 5. Quest Integration
- [ ] Upload PDF/image
- [ ] Ask questions about content
- [ ] Create diet plan
- [ ] Split bill
- [ ] Fill form
- [ ] Create reminder

## 🔧 Troubleshooting

### Device Not Found

```bash
# Check ADB connection
adb devices

# Reconnect
adb disconnect
adb connect 192.168.1.77:42529

# Enable wireless debugging on device
# Settings > Developer Options > Wireless Debugging
```

### Build Errors

```bash
# Clean build
cd app
flutter clean
flutter pub get

# Rebuild
flutter build apk --debug
```

### Gemini Nano Not Available

**This is expected!** The current implementation includes:
- ✅ Native Android plugin structure
- ✅ Provider selection UI
- ✅ Auto-routing logic
- ⏳ Actual AI Core SDK integration (pending)

The plugin will:
1. Check device compatibility ✅
2. Attempt to initialize AI Core ⏳
3. Fall back to Cloud API if unavailable ✅

### App Crashes

```bash
# Check crash logs
adb logcat | grep -E "AndroidRuntime|FATAL"

# Common issues:
# - Missing dependencies: Run `flutter pub get`
# - Gradle sync: Open android/ in Android Studio and sync
# - Kotlin version: Check build.gradle.kts
```

## 📊 Performance Targets

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Response Time | <3s | Time from send to first token |
| Accuracy | F1≥0.9 | Compare with expected output |
| Battery Usage | <5% per workflow | Android Battery Stats |
| Memory Footprint | <1.2GB | Android Memory Profiler |
| Offline Accuracy | 90% | Test without network |

## 🎨 UI/UX Flow

```
Main Screen
  ↓
Tap Quest
  ↓
Quest Chat Screen
  ↓
Tap AI Provider Icon (top-right)
  ↓
Bottom Sheet Opens (Layer Navigation)
  ↓
Select Provider (Nano/Cloud/Auto)
  ↓
Sheet Closes
  ↓
Send Query
  ↓
Response from Selected Provider
```

## 📝 Next Steps

### Immediate (Testing Phase)
1. ✅ Test on Pixel 9 device
2. ✅ Verify provider selection works
3. ✅ Check fallback to Cloud
4. ✅ Test layer navigation
5. ✅ Validate UI/UX flow

### Short-term (Integration Phase)
1. ⏳ Integrate actual AI Core SDK
2. ⏳ Implement Cloud API (replace mock)
3. ⏳ Add model download management
4. ⏳ Implement offline detection
5. ⏳ Add performance monitoring

### Long-term (Optimization Phase)
1. 🔮 Fine-tune for use cases
2. 🔮 Multi-modal support
3. 🔮 Battery optimization
4. 🔮 Advanced caching
5. 🔮 Analytics integration

## 🆘 Support

### Documentation
- [Full Integration Guide](docs/integration/GEMINI_NANO_INTEGRATION.md)
- [Architecture Docs](docs/architecture/)
- [API Reference](docs/api/)

### Reference Implementation
- Google AI Samples: `C:\Users\chauh\develop\ai-samples\ai-catalog\app`
- Official Docs: https://developer.android.com/ai/gemini-nano

### Debug Commands

```bash
# Device info
adb shell getprop | grep -E "ro.product|ro.build"

# Check AI Core
adb shell pm list packages | grep -i ai

# App logs
adb logcat -s flutter,GeminiNano,AIRouter

# Clear app data
adb shell pm clear com.airo.superapp

# Reinstall
flutter clean && flutter run -d 192.168.1.77:42529
```

## ✅ Success Criteria

You'll know it's working when:

1. ✅ App builds without errors
2. ✅ Runs on Pixel 9 device
3. ✅ Provider selector opens smoothly
4. ✅ Shows Nano availability status
5. ✅ Can switch between providers
6. ✅ Queries get responses
7. ✅ Fallback works if Nano unavailable
8. ✅ UI is responsive and smooth
9. ✅ No crashes or errors
10. ✅ Logs show correct provider usage

---

**Ready to test?** Run `flutter run -d 192.168.1.77:42529` and start exploring! 🚀

