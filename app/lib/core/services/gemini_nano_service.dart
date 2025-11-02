import 'package:flutter/foundation.dart';

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
/// Note: This is a mock implementation that can be swapped with the real
/// AI Edge SDK when the dependency resolution is fixed.
class GeminiNanoService {
  static final GeminiNanoService _instance = GeminiNanoService._internal();
  factory GeminiNanoService() => _instance;
  GeminiNanoService._internal();

  bool _isInitialized = false;
  bool _isSupported = false;
  DeviceInfo? _deviceInfo;

  /// Check if device is supported (Pixel 9 with AICore)
  /// Mock implementation - returns false for now
  /// Will be replaced with real AI Edge SDK when dependency is resolved
  Future<bool> isSupported() async {
    try {
      // Mock: Check if running on Android
      // In production, this would use the real AI Edge SDK
      _isSupported = false; // Default to false for now
      return _isSupported;
    } catch (e) {
      debugPrint('Error checking device support: $e');
      return false;
    }
  }

  /// Get detailed device information
  /// Mock implementation
  Future<DeviceInfo?> getDeviceInfo() async {
    try {
      _deviceInfo = DeviceInfo(
        manufacturer: 'Google',
        model: 'Pixel 9',
        androidVersion: '15',
        isPixel9Series: false,
        isAiCoreAvailable: false,
        compatibilityStatus: 'Gemini Nano not available on this device',
      );
      return _deviceInfo;
    } catch (e) {
      debugPrint('Error getting device info: $e');
      return null;
    }
  }

  /// Initialize Gemini Nano model
  /// Returns true if initialization was successful
  /// Mock implementation - always returns false for now
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

      // Mock initialization
      _isInitialized = false; // Mock: not supported
      return _isInitialized;
    } catch (e) {
      debugPrint('Error initializing Gemini Nano: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Generate content from a prompt
  /// Returns the generated text response
  /// Mock implementation
  Future<String> generateContent(String prompt) async {
    if (!_isInitialized) {
      throw Exception(
        'GeminiNanoService not initialized. Call initialize() first.',
      );
    }

    try {
      // Mock response
      await Future.delayed(const Duration(milliseconds: 500));
      return 'Mock response to: $prompt';
    } catch (e) {
      debugPrint('Error generating content: $e');
      rethrow;
    }
  }

  /// Generate content with streaming support
  /// Calls [onChunk] for each token chunk received
  /// Mock implementation
  Future<String> generateContentStream(
    String prompt, {
    void Function(String chunk)? onChunk,
  }) async {
    if (!_isInitialized) {
      throw Exception(
        'GeminiNanoService not initialized. Call initialize() first.',
      );
    }

    try {
      // Mock streaming response
      await Future.delayed(const Duration(milliseconds: 500));
      return 'Mock streaming response to: $prompt';
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

  /// Check if Gemini Nano is initialized
  bool get isInitialized => _isInitialized;

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
