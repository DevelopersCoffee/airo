# Gemini Nano Integration Guide

This document describes the integration of Google's AI Edge SDK (Gemini Nano) into the Airo super app for on-device AI processing.

## Overview

Gemini Nano brings Google's most efficient AI model directly to Pixel 9 devices, enabling:
- **Private AI**: All processing happens on-device, no data sent to servers
- **Fast Inference**: <3 second response times for typical queries
- **Offline Capability**: Works without internet connectivity
- **Battery Efficient**: Optimized for mobile devices

## Architecture

### Core Components

#### 1. **GeminiNanoService** (`lib/core/services/gemini_nano_service.dart`)
Singleton wrapper around the AI Edge SDK providing:
- Device compatibility checking
- Model initialization
- Content generation (single and streaming)
- Query processing with context

```dart
final geminiNano = GeminiNanoService();

// Check device support
if (await geminiNano.isSupported()) {
  await geminiNano.initialize();
  final response = await geminiNano.generateContent('Your prompt here');
  print(response);
}
```

#### 2. **GeminiQuestService** (`lib/features/quest/domain/services/gemini_quest_service.dart`)
Implements the `QuestService` interface using Gemini Nano for:
- Diet plan generation
- Bill splitting calculations
- Form filling assistance
- Document analysis

Falls back to mock responses if Gemini Nano is unavailable.

#### 3. **DeviceCompatibilityBanner** (`lib/features/quest/presentation/widgets/device_compatibility_banner.dart`)
UI widget that displays:
- ✅ Green banner if Gemini Nano is available
- ⚠️ Orange banner if device not supported
- Device information dialog

## Integration Points

### Quest Feature
The Quest feature now uses Gemini Nano for AI-powered responses:

```dart
// In quest_provider.dart
final questServiceProvider = Provider<QuestService>((ref) {
  return GeminiQuestService(); // Uses Gemini Nano when available
});
```

### Use Cases

#### 1. **Diet Plan Generation**
```
User: "Create a 7-day anti-inflammatory diet plan"
Gemini Nano: Generates personalized diet plan with meals and reminders
```

#### 2. **Bill Splitting**
```
User: "Split a $150 bill between 3 people with 18% tip"
Gemini Nano: Calculates individual amounts and tip distribution
```

#### 3. **Form Filling**
```
User: "Help me fill out this tax form"
Gemini Nano: Provides guidance and suggestions based on uploaded document
```

#### 4. **Document Analysis**
```
User: "Summarize this PDF"
Gemini Nano: Extracts and summarizes key information
```

## Device Requirements

- **Device**: Pixel 9, Pixel 9 Pro, Pixel 9 Pro XL, or Pixel 9 Pro Fold
- **Android**: With AICore system module installed
- **Flutter**: 3.0.0 or higher

## Installation

The AI Edge SDK is already added to `pubspec.yaml`:

```yaml
dependencies:
  ai_edge_sdk: ^1.0.0
```

## Usage Examples

### Basic Content Generation

```dart
import 'package:airo_app/core/services/gemini_nano_service.dart';

final geminiNano = GeminiNanoService();

// Initialize
if (await geminiNano.isSupported()) {
  await geminiNano.initialize();
  
  // Generate content
  final response = await geminiNano.generateContent(
    'Rewrite this professionally: hey whats up'
  );
  print(response.content);
}
```

### Streaming Responses

```dart
final response = await geminiNano.generateContentStream(
  'Write a poem about Flutter',
  onChunk: (chunk) {
    print('Received: $chunk');
  },
);
```

### Processing Queries with Context

```dart
final response = await geminiNano.processQuery(
  'Create a meal plan',
  fileContext: 'User has gluten allergy and prefers vegetarian meals',
  systemPrompt: 'You are a nutritionist',
);
```

### Device Information

```dart
final deviceInfo = await geminiNano.getDeviceInfo();
print('Device: ${deviceInfo.manufacturer} ${deviceInfo.model}');
print('Pixel 9 Series: ${deviceInfo.isPixel9Series}');
print('AICore Available: ${deviceInfo.isAiCoreAvailable}');
```

## Error Handling

The service gracefully handles unsupported devices:

```dart
try {
  if (await geminiNano.isSupported()) {
    await geminiNano.initialize();
    // Use Gemini Nano
  } else {
    // Use fallback (mock responses or cloud API)
  }
} catch (e) {
  print('Error: $e');
  // Handle error
}
```

## Performance Metrics

Target metrics for Airo:
- **Response Time**: <3 seconds for typical queries
- **Accuracy**: F1 ≥ 0.9 for extraction tasks
- **Battery**: <5% per workflow
- **Footprint**: <1.2GB total app size

## Testing

### On Physical Device
```bash
cd app
flutter run -d <device_id>
```

### Check Device Support
The app displays a compatibility banner on the Quest tab showing:
- Device model and Android version
- Pixel 9 series status
- AICore availability
- Overall compatibility status

### Manual Testing Checklist
- [ ] App launches on Pixel 9
- [ ] Compatibility banner shows green (supported)
- [ ] Quest feature initializes Gemini Nano
- [ ] Diet plan generation works
- [ ] Responses appear within 3 seconds
- [ ] Offline mode works (no internet required)

## Troubleshooting

### "Device not supported"
- Ensure you're using Pixel 9 series device
- Check that AICore system module is installed
- Verify Android version is up to date

### "Gemini Nano not initialized"
- Call `initialize()` before using `generateContent()`
- Check device support with `isSupported()` first

### Slow Responses
- First inference may be slower (model loading)
- Subsequent calls should be <3 seconds
- Check device temperature (may throttle if hot)

## Future Enhancements

1. **PDF Text Extraction**: Integrate `pdf_text` package for document analysis
2. **Image OCR**: Use MediaPipe for image text extraction
3. **Streaming UI**: Real-time token display in chat
4. **Multi-turn Conversations**: Maintain context across messages
5. **Function Calling**: Structured outputs for calculations
6. **Caching**: Cache responses for repeated queries

## References

- [Google AI Edge SDK Documentation](https://developer.android.com/ai/gemini-nano/ai-edge-sdk)
- [Gemini Nano Experimental Access](https://developer.android.com/ai/gemini-nano/experimental)
- [Android AI Samples](https://github.com/android/ai-samples/tree/main/gemini-nano)
- [AI Edge SDK Flutter Plugin](https://github.com/stefanoamorelli/ai-edge-sdk)

## License

This integration uses the MIT-licensed AI Edge SDK Flutter plugin.

