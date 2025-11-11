# Gemini Nano Integration Guide

## Overview

This guide explains how to use the Gemini Nano on-device AI integration in the Airo Super App, specifically targeting Pixel 9 devices.

## Architecture

### AI Provider System

The app now supports multiple AI providers with automatic routing:

1. **Gemini Nano** (On-device) - Runs locally on Pixel 9+ devices
2. **Gemini Cloud** (API) - Cloud-based AI via Google AI API
3. **Auto** - Automatically selects the best available provider

### Components

#### 1. Native Android Plugin (`GeminiNanoPlugin.kt`)

Location: `app/android/app/src/main/kotlin/com/airo/superapp/GeminiNanoPlugin.kt`

**Features:**
- Device compatibility detection (Pixel 9 series)
- AI Core availability checking
- Content generation (single and streaming)
- Device information retrieval
- Capability detection

**Methods:**
- `isAvailable()` - Check if Gemini Nano is available
- `initialize(config)` - Initialize with temperature, topK, maxTokens
- `generateContent(prompt)` - Generate single response
- `generateContentStream(prompt)` - Stream response chunks
- `getDeviceInfo()` - Get device details
- `getCapabilities()` - Get AI capabilities

#### 2. Flutter Service (`GeminiNanoService`)

Location: `app/lib/core/services/gemini_nano_service.dart`

**Features:**
- MethodChannel bridge to native code
- EventChannel for streaming responses
- Initialization management
- Error handling

**Usage:**
```dart
final nanoService = GeminiNanoService();

// Check availability
final isAvailable = await nanoService.isSupported();

// Initialize
if (isAvailable) {
  final initialized = await nanoService.initialize(
    temperature: 0.7,
    topK: 40,
    maxOutputTokens: 1024,
  );
}

// Generate content
final response = await nanoService.generateContent('Your prompt here');

// Stream content
await for (final chunk in nanoService.generateContentStream('Your prompt')) {
  print(chunk);
}
```

#### 3. AI Router Service

Location: `app/lib/core/ai/ai_router_service.dart`

**Features:**
- Provider selection (Nano, Cloud, Auto)
- Automatic fallback to Cloud if Nano unavailable
- Unified API for all providers
- Capability detection

**Usage:**
```dart
final router = AIRouterService();

// Check availability of all providers
await router.checkAvailability();

// Set preferred provider
router.setProvider(AIProvider.nano);

// Process query (automatically routes to best provider)
final response = await router.processQuery(
  'Create a diet plan',
  fileContext: extractedText,
  systemPrompt: 'You are a helpful assistant',
);

// Stream response
await for (final chunk in router.processQueryStream('Your query')) {
  print(chunk);
}
```

#### 4. AI Provider Selector Widget

Location: `app/lib/core/ai/widgets/ai_provider_selector.dart`

**Features:**
- Visual provider selection UI
- Shows availability status
- Displays capabilities (streaming, images, files)
- Error messages for unavailable providers

**Usage:**
```dart
// Show as bottom sheet
await showAIProviderSelector(context);

// Or embed in your UI
AIProviderSelector(
  onProviderSelected: () {
    print('Provider changed');
  },
)
```

#### 5. Layer-Based Navigation

Location: `app/lib/core/navigation/layer_navigation.dart`

**Features:**
- Modular bottom sheet navigation
- Stack-based layer management
- Multiple presentation styles (bottomSheet, fullScreen, dialog, drawer)
- Lazy loading of modules

**Usage:**
```dart
final controller = LayerNavigationController();

// Wrap your app
LayerNavigation(
  controller: controller,
  child: YourApp(),
)

// Push a layer
controller.pushLayer(
  LayerConfig(
    id: 'ai_selector',
    title: 'Select AI Provider',
    type: LayerType.bottomSheet,
    builder: (context) => AIProviderSelector(),
  ),
);

// Pop layer
controller.popLayer();

// Pop all layers
controller.popAllLayers();
```

## Device Requirements

### Pixel 9 Series Support

Gemini Nano is available on:
- Pixel 9
- Pixel 9 Pro
- Pixel 9 Pro XL
- Pixel 9 Pro Fold

### Android Requirements

- **Minimum SDK:** API 31 (Android 12)
- **Target SDK:** API 36 (Android 15)
- **AI Core:** System component must be installed

### Detection Logic

The plugin detects Pixel 9 devices by checking:
```kotlin
Build.MANUFACTURER == "Google"
Build.MODEL contains "pixel 9"
Build.DEVICE in ["komodo", "caiman", "tokay", "comet"]
```

## Integration in Quest Feature

The Quest chat screen now includes AI provider selection:

1. **AppBar Icon** - Shows current provider with visual indicator
2. **Provider Selector** - Tap icon to open provider selection sheet
3. **Auto-routing** - Queries automatically use the best available provider

### Visual Indicators

- 🤖 **Phone Icon** - Gemini Nano (on-device)
- ☁️ **Cloud Icon** - Gemini Cloud (API)
- ✨ **Auto Icon** - Auto-select mode
- 🟢 **Green Dot** - Nano is active and available

## Testing on Pixel 9

### Connect to Device

```bash
# Connect via ADB
adb connect 192.168.1.77:42529

# Verify connection
adb devices

# Check device info
adb shell getprop ro.product.model
adb shell getprop ro.product.device
```

### Build and Deploy

```bash
# From project root
cd app

# Build and install
flutter build apk --debug
flutter install

# Or run directly
flutter run -d 192.168.1.77:42529
```

### Verify Gemini Nano

1. Open Quest feature
2. Tap AI provider icon in AppBar
3. Check if "Gemini Nano" shows as available
4. Select Gemini Nano
5. Send a query
6. Verify response comes from on-device AI

### Debug Logs

```bash
# Watch logs
adb logcat | grep -E "GeminiNano|AIRouter|Flutter"

# Check for:
# - "Gemini Nano: Available" or "Gemini Nano: Not supported"
# - "AI Provider changed to: Gemini Nano"
# - "Processing query with: Gemini Nano"
```

## Fallback Behavior

If Gemini Nano is not available:

1. **Auto mode** - Automatically falls back to Cloud API
2. **Manual selection** - Shows "Not available" with reason
3. **Error handling** - Graceful degradation to Cloud API

## Future Enhancements

### Phase 1 (Current)
- ✅ Native Android bridge
- ✅ Provider selection UI
- ✅ Layer-based navigation
- ✅ Auto-routing

### Phase 2 (Planned)
- [ ] Actual AI Core SDK integration (replace mock)
- [ ] Cloud API implementation (replace mock)
- [ ] Offline capability detection
- [ ] Model download management

### Phase 3 (Future)
- [ ] Multi-modal support (images, audio)
- [ ] Fine-tuning for specific use cases
- [ ] Performance metrics and monitoring
- [ ] Battery usage optimization

## Troubleshooting

### Gemini Nano Not Available

**Symptoms:** Provider shows as unavailable on Pixel 9

**Solutions:**
1. Verify device is Pixel 9 series
2. Check Android version (must be 14+)
3. Ensure AI Core is installed: `adb shell pm list packages | grep aicore`
4. Update Google Play Services
5. Check logs for specific error messages

### Initialization Fails

**Symptoms:** Provider available but initialization fails

**Solutions:**
1. Check temperature/topK/maxTokens parameters
2. Verify sufficient device memory
3. Restart app
4. Clear app data and retry

### Streaming Not Working

**Symptoms:** Single responses work but streaming fails

**Solutions:**
1. Verify EventChannel is properly set up
2. Check for errors in native logs
3. Ensure stream is properly consumed in Flutter

## References

- [Google AI Gemini Nano Documentation](https://developer.android.com/ai/gemini-nano)
- [AI Samples Repository](https://github.com/google/ai-samples)
- [Flutter Platform Channels](https://docs.flutter.dev/platform-integration/platform-channels)
- [Pixel 9 Specifications](https://store.google.com/product/pixel_9_specs)

