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
  Future<bool> isSupported() async {
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
  Future<Map<String, dynamic>> getDeviceInfo() async {
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
  /// Returns the generated text response
  Future<String> generateContent(String prompt) async {
    if (!_isInitialized) {
      throw Exception(
        'GeminiNanoService not initialized. Call initialize() first.',
      );
    }

    try {
      final String? response = await _channel.invokeMethod('generateContent', {
        'prompt': prompt,
      });
      return response ?? '';
    } catch (e) {
      debugPrint('Error generating content: $e');
      rethrow;
    }
  }

  /// Generate content with streaming support
  /// Returns a stream of accumulated text chunks
  Stream<String> generateContentStream(String prompt) async* {
    if (!_isInitialized) {
      throw Exception(
        'GeminiNanoService not initialized. Call initialize() first.',
      );
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
      rethrow;
    }
  }

  /// Process a query with optional file context
  /// Useful for diet plans, form filling, bill splitting, etc.
  Future<String> processQuery(
    String query, {
    String? fileContext,
    String? systemPrompt,
  }) async {
    if (!_isInitialized) {
      throw Exception(
        'GeminiNanoService not initialized. Call initialize() first.',
      );
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
      rethrow;
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
