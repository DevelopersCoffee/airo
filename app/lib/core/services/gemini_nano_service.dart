import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Device information model
class DeviceInfo {
  final String manufacturer;
  final String model;
  final String androidVersion;
  final bool isPixel9Series;
  final bool isAiCoreAvailable;
  final String compatibilityStatus;

  DeviceInfo({
    required this.manufacturer,
    required this.model,
    required this.androidVersion,
    required this.isPixel9Series,
    required this.isAiCoreAvailable,
    required this.compatibilityStatus,
  });
}

/// Generation result model
class GenerationResult {
  final String content;
  final List<String> chunks;

  GenerationResult({required this.content, this.chunks = const []});
}

/// Wrapper service for Google's AI Edge SDK (Gemini Nano)
/// Provides on-device AI inference for Pixel 9 devices
///
/// Uses native Android implementation via MethodChannel
class GeminiNanoService {
  static final GeminiNanoService _instance = GeminiNanoService._internal();
  factory GeminiNanoService() => _instance;
  GeminiNanoService._internal();

  static const MethodChannel _channel = MethodChannel('com.airo.gemini_nano');
  static const EventChannel _eventChannel = EventChannel(
    'com.airo.gemini_nano/stream',
  );

  bool _isInitialized = false;
  bool _isSupported = false;
  DeviceInfo? _deviceInfo;

  bool get isInitialized => _isInitialized;

  /// Check if device is supported (Pixel 9 with AICore)
  /// Returns false on web platform
  Future<bool> isSupported() async {
    // Web platform doesn't support Gemini Nano
    if (kIsWeb) {
      _isSupported = false;
      return false;
    }

    try {
      // Call native Android method to check availability
      final bool available = await _channel.invokeMethod('isAvailable');
      _isSupported = available;
      return _isSupported;
    } catch (e) {
      debugPrint('Error checking device support: $e');
      return false;
    }
  }

  /// Get detailed device information
  /// Returns web platform info on web
  Future<Map<String, dynamic>> getDeviceInfo() async {
    // Web platform doesn't have native device info
    if (kIsWeb) {
      return {
        'manufacturer': 'Web',
        'model': 'Browser',
        'isPixel': false,
        'supportsGeminiNano': false,
        'platform': 'web',
      };
    }

    try {
      final Map<dynamic, dynamic> info = await _channel.invokeMethod(
        'getDeviceInfo',
      );
      return Map<String, dynamic>.from(info);
    } catch (e) {
      debugPrint('Error getting device info: $e');
      return {
        'manufacturer': 'Unknown',
        'model': 'Unknown',
        'isPixel': false,
        'supportsGeminiNano': false,
      };
    }
  }

  /// Initialize Gemini Nano model
  /// Returns true if initialization was successful
  Future<bool> initialize({
    String modelName = 'gemini-nano',
    double temperature = 0.8,
    int topK = 40,
    double topP = 0.95,
    int maxOutputTokens = 1024,
  }) async {
    if (_isInitialized) return true;

    try {
      // Check device support first
      if (!await isSupported()) {
        debugPrint('Device not supported for Gemini Nano');
        return false;
      }

      // Call native initialization
      final bool initialized = await _channel.invokeMethod('initialize', {
        'temperature': temperature,
        'topK': topK,
        'maxOutputTokens': maxOutputTokens,
      });

      _isInitialized = initialized;
      return _isInitialized;
    } catch (e) {
      debugPrint('Error initializing Gemini Nano: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Generate content from a prompt
  /// Returns the generated text response, or fallback message on web/uninitialized
  Future<String> generateContent(String prompt) async {
    // Web platform doesn't support Gemini Nano
    if (kIsWeb) {
      return _getWebFallbackResponse(prompt);
    }

    if (!_isInitialized) {
      debugPrint('GeminiNanoService not initialized');
      return _getWebFallbackResponse(prompt);
    }

    try {
      final String? response = await _channel.invokeMethod('generateContent', {
        'prompt': prompt,
      });
      return response ?? '';
    } catch (e) {
      debugPrint('Error generating content: $e');
      return _getWebFallbackResponse(prompt);
    }
  }

  /// Generate content with streaming support
  /// Returns a stream of accumulated text chunks
  /// On web, yields a single fallback response
  Stream<String> generateContentStream(String prompt) async* {
    // Web platform doesn't support Gemini Nano
    if (kIsWeb) {
      yield _getWebFallbackResponse(prompt);
      return;
    }

    if (!_isInitialized) {
      debugPrint('GeminiNanoService not initialized');
      yield _getWebFallbackResponse(prompt);
      return;
    }

    try {
      // Start streaming generation
      await _channel.invokeMethod('generateContentStream', {'prompt': prompt});

      // Listen to event channel for chunks
      await for (final chunk in _eventChannel.receiveBroadcastStream()) {
        yield chunk.toString();
      }
    } catch (e) {
      debugPrint('Error generating content stream: $e');
      yield _getWebFallbackResponse(prompt);
    }
  }

  /// Fallback response for web platform
  String _getWebFallbackResponse(String prompt) {
    final lowerPrompt = prompt.toLowerCase();
    if (lowerPrompt.contains('hi') || lowerPrompt.contains('hello')) {
      return 'Hello! 👋 I\'m Airo, your AI assistant. On web, I use cloud AI. How can I help you today?';
    }
    if (lowerPrompt.contains('diet') || lowerPrompt.contains('food')) {
      return 'I can help you create personalized diet plans! Try uploading a PDF or describing your dietary needs.';
    }
    if (lowerPrompt.contains('bill') || lowerPrompt.contains('split')) {
      return 'I can help split bills! Upload a receipt image or enter items manually to get started.';
    }
    return 'I\'m here to help! On web platform, some features use cloud AI. For full on-device AI, try the Android app on a Pixel 9 device.';
  }

  /// Process a query with optional file context
  /// Useful for diet plans, form filling, bill splitting, etc.
  /// Returns null on web platform or if not initialized
  Future<String?> processQuery(
    String query, {
    String? fileContext,
    String? systemPrompt,
  }) async {
    // Web platform doesn't support Gemini Nano
    if (kIsWeb) {
      debugPrint('Gemini Nano not available on web platform');
      return null;
    }

    if (!_isInitialized) {
      debugPrint('GeminiNanoService not initialized. Call initialize() first.');
      return null;
    }

    try {
      // Build the full prompt with context
      String fullPrompt = query;

      if (systemPrompt != null) {
        fullPrompt = '$systemPrompt\n\n$query';
      }

      if (fileContext != null) {
        fullPrompt = '$fullPrompt\n\nContext from uploaded file:\n$fileContext';
      }

      return await generateContent(fullPrompt);
    } catch (e) {
      debugPrint('Error processing query: $e');
      return null;
    }
  }

  /// Get current device info
  DeviceInfo? get deviceInfo => _deviceInfo;

  /// Dispose resources
  Future<void> dispose() async {
    try {
      // Mock dispose
      _isInitialized = false;
    } catch (e) {
      debugPrint('Error disposing Gemini Nano: $e');
    }
  }
}
