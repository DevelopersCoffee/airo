# AI Edge SDK Implementation Guide

## Quick Start

### 1. Current Status
✅ **App builds and runs successfully on Pixel 9**
- Mock implementation in place
- All UI components working
- File upload functional
- Ready for real Gemini Nano integration

### 2. Architecture Overview

```
User Interface (Quest Tab)
    ↓
DeviceCompatibilityBanner (Shows device status)
    ↓
QuestChatScreen (File upload + chat)
    ↓
GeminiQuestService (AI processing)
    ↓
GeminiNanoService (Device wrapper)
    ↓
AI Edge SDK (Real Gemini Nano - when available)
```

## How to Use the Current Implementation

### Check Device Support
```dart
final geminiNano = GeminiNanoService();
final isSupported = await geminiNano.isSupported();
if (isSupported) {
  print('Gemini Nano is available!');
}
```

### Initialize and Generate Content
```dart
// Initialize the service
final initialized = await geminiNano.initialize();

if (initialized) {
  // Generate content
  final response = await geminiNano.generateContent(
    'Create a healthy diet plan for someone with gluten allergy'
  );
  print(response);
}
```

### Process Queries with File Context
```dart
final response = await geminiNano.processQuery(
  'Analyze this diet plan and suggest improvements',
  fileContext: 'User uploaded PDF with diet plan',
  systemPrompt: 'You are a nutritionist expert',
);
```

### Use in Quest Feature
```dart
// The Quest feature automatically uses GeminiNanoService
// Just upload a file and ask a question
// The service handles everything:
// 1. Detects device support
// 2. Initializes Gemini Nano
// 3. Processes query with file context
// 4. Returns AI response
// 5. Falls back to mock if unavailable
```

## Integration Points

### 1. Quest Provider
**File**: `lib/features/quest/application/providers/quest_provider.dart`

```dart
final questServiceProvider = Provider<QuestService>((ref) {
  return GeminiQuestService();
});
```

### 2. App Shell
**File**: `lib/core/app/app_shell.dart`

```dart
DeviceCompatibilityBanner(
  showBanner: navigationShell.currentIndex == 1,
  child: navigationShell,
)
```

### 3. Quest Chat Screen
**File**: `lib/features/quest/presentation/screens/quest_chat_screen.dart`

- Displays device compatibility banner
- Shows file attachments
- Sends queries to GeminiQuestService
- Displays AI responses

## Mock vs Real Implementation

### Current (Mock)
```dart
Future<String> generateContent(String prompt) async {
  await Future.delayed(const Duration(milliseconds: 500));
  return 'Mock response to: $prompt';
}
```

### Future (Real)
```dart
Future<String> generateContent(String prompt) async {
  final result = await _sdk.generateContent(prompt);
  return result.content;
}
```

**To swap**: Just replace the method implementation when AI Edge SDK is available.

## Extending the Service

### Add New Methods
```dart
/// Example: Analyze document
Future<String> analyzeDocument(String filePath) async {
  // Implementation here
}

/// Example: Extract text from PDF
Future<String> extractPdfText(String filePath) async {
  // Implementation here
}
```

### Add New Models
```dart
class AnalysisResult {
  final String summary;
  final List<String> keyPoints;
  final double confidence;
  
  AnalysisResult({
    required this.summary,
    required this.keyPoints,
    required this.confidence,
  });
}
```

## Testing

### Unit Test Example
```dart
test('GeminiNanoService is singleton', () {
  final service1 = GeminiNanoService();
  final service2 = GeminiNanoService();
  expect(identical(service1, service2), true);
});

test('Device info returns mock data', () async {
  final service = GeminiNanoService();
  final info = await service.getDeviceInfo();
  expect(info, isNotNull);
  expect(info?.manufacturer, 'Google');
});
```

### Integration Test Example
```dart
testWidgets('Quest feature shows compatibility banner', (tester) async {
  await tester.pumpWidget(const MyApp());
  
  // Navigate to Quest tab
  await tester.tap(find.byIcon(Icons.help));
  await tester.pumpAndSettle();
  
  // Verify banner is shown
  expect(find.byType(DeviceCompatibilityBanner), findsOneWidget);
});
```

## Performance Optimization

### Caching
```dart
class GeminiNanoService {
  final Map<String, String> _responseCache = {};
  
  Future<String> generateContent(String prompt) async {
    if (_responseCache.containsKey(prompt)) {
      return _responseCache[prompt]!;
    }
    
    final response = await _generateContentImpl(prompt);
    _responseCache[prompt] = response;
    return response;
  }
}
```

### Streaming
```dart
Future<void> generateContentStream(
  String prompt, {
  void Function(String chunk)? onChunk,
}) async {
  // Stream chunks as they arrive
  // Call onChunk for each token
}
```

## Troubleshooting

### Issue: "Device not supported"
**Solution**: 
- Ensure running on Pixel 9 series
- Check Android version is up to date
- Verify AICore is installed

### Issue: "Service not initialized"
**Solution**:
```dart
// Always call initialize() first
await geminiNano.initialize();
// Then use other methods
```

### Issue: "Mock responses instead of real AI"
**Solution**:
- This is expected until AI Edge SDK dependency is resolved
- Mock responses are for testing
- Real Gemini Nano will be used when SDK is available

## Next Steps

1. **Resolve AI Edge SDK Dependency**
   - Fix Maven repository configuration
   - Add GitHub authentication token
   - Re-add `ai_edge_sdk` to pubspec.yaml

2. **Implement Real Processing**
   - Replace mock with real Gemini Nano calls
   - Add PDF text extraction
   - Implement image OCR

3. **Enhance Features**
   - Multi-turn conversations
   - Function calling for calculations
   - Response streaming UI
   - Offline caching

4. **Optimize Performance**
   - Response caching
   - Batch processing
   - Memory management
   - Battery optimization

## References

- **AI Edge SDK**: https://github.com/stefanoamorelli/ai-edge-sdk
- **Google AI Edge**: https://developer.android.com/ai/gemini-nano/ai-edge-sdk
- **Gemini Nano**: https://developer.android.com/ai/gemini-nano
- **Android AI Samples**: https://github.com/android/ai-samples

## Support

For issues or questions:
1. Check `GEMINI_NANO_INTEGRATION.md`
2. Review code comments in service files
3. Check device requirements
4. Verify build configuration

## Summary

✅ **What's Working**:
- Device compatibility detection
- Mock AI responses
- File upload and attachment
- Reminder creation
- UI components
- App builds successfully

⏳ **What's Pending**:
- Real Gemini Nano integration
- PDF text extraction
- Image OCR
- Streaming responses
- Performance optimization

🎯 **Goal**: Provide on-device AI processing for diet plans, bill splitting, and form filling on Pixel 9 devices without internet connectivity.

