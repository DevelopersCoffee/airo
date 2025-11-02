import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service for integrating with Gemini Nano on Pixel 9 and compatible devices
class GeminiNanoService {
  static const MethodChannel _channel = MethodChannel('com.airo.gemini_nano');
  
  static GeminiNanoService? _instance;
  static GeminiNanoService get instance => _instance ??= GeminiNanoService._();
  
  GeminiNanoService._();

  /// Check if Gemini Nano is available on the current device
  Future<bool> isAvailable() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final bool available = await _channel.invokeMethod('isAvailable');
        return available;
      }
      return false;
    } catch (e) {
      debugPrint('Error checking Gemini Nano availability: $e');
      return false;
    }
  }

  /// Initialize Gemini Nano with configuration
  Future<bool> initialize({
    double temperature = 0.7,
    int topK = 40,
    int maxOutputTokens = 1024,
  }) async {
    try {
      if (!await isAvailable()) {
        return false;
      }

      final bool initialized = await _channel.invokeMethod('initialize', {
        'temperature': temperature,
        'topK': topK,
        'maxOutputTokens': maxOutputTokens,
      });
      
      return initialized;
    } catch (e) {
      debugPrint('Error initializing Gemini Nano: $e');
      return false;
    }
  }

  /// Generate content using Gemini Nano
  Future<String?> generateContent(String prompt) async {
    try {
      if (!await isAvailable()) {
        throw Exception('Gemini Nano is not available on this device');
      }

      final String? response = await _channel.invokeMethod('generateContent', {
        'prompt': prompt,
      });
      
      return response;
    } catch (e) {
      debugPrint('Error generating content: $e');
      rethrow;
    }
  }

  /// Generate content with streaming response
  Stream<String> generateContentStream(String prompt) async* {
    try {
      if (!await isAvailable()) {
        throw Exception('Gemini Nano is not available on this device');
      }

      // Set up event channel for streaming
      const EventChannel eventChannel = EventChannel('com.airo.gemini_nano/stream');
      
      // Start streaming generation
      await _channel.invokeMethod('generateContentStream', {
        'prompt': prompt,
      });

      // Listen to streaming responses
      await for (final dynamic event in eventChannel.receiveBroadcastStream()) {
        if (event is String) {
          yield event;
        } else if (event is Map) {
          final String? text = event['text'] as String?;
          final String? error = event['error'] as String?;
          
          if (error != null) {
            throw Exception(error);
          }
          
          if (text != null) {
            yield text;
          }
        }
      }
    } catch (e) {
      debugPrint('Error in streaming generation: $e');
      rethrow;
    }
  }

  /// Update generation configuration
  Future<bool> updateConfig({
    double? temperature,
    int? topK,
    int? maxOutputTokens,
  }) async {
    try {
      final Map<String, dynamic> config = {};
      
      if (temperature != null) config['temperature'] = temperature;
      if (topK != null) config['topK'] = topK;
      if (maxOutputTokens != null) config['maxOutputTokens'] = maxOutputTokens;

      if (config.isEmpty) return true;

      final bool updated = await _channel.invokeMethod('updateConfig', config);
      return updated;
    } catch (e) {
      debugPrint('Error updating config: $e');
      return false;
    }
  }

  /// Close the Gemini Nano model and free resources
  Future<void> close() async {
    try {
      await _channel.invokeMethod('close');
    } catch (e) {
      debugPrint('Error closing Gemini Nano: $e');
    }
  }

  /// Get device information for Gemini Nano compatibility
  Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      final Map<dynamic, dynamic> info = await _channel.invokeMethod('getDeviceInfo');
      return Map<String, dynamic>.from(info);
    } catch (e) {
      debugPrint('Error getting device info: $e');
      return {};
    }
  }

  /// Check if the device is a Pixel 9 or compatible
  Future<bool> isPixel9Compatible() async {
    try {
      final deviceInfo = await getDeviceInfo();
      final String? model = deviceInfo['model'] as String?;
      final String? brand = deviceInfo['brand'] as String?;
      final int? sdkVersion = deviceInfo['sdkVersion'] as int?;

      // Check for Pixel 9 or compatible devices
      if (brand?.toLowerCase() == 'google' && model?.contains('Pixel') == true) {
        // Pixel 9 series or newer
        if (model!.contains('9') || (sdkVersion != null && sdkVersion >= 31)) {
          return true;
        }
      }

      // Check for other compatible devices with Android 12+ (API 31+)
      return sdkVersion != null && sdkVersion >= 31;
    } catch (e) {
      debugPrint('Error checking Pixel 9 compatibility: $e');
      return false;
    }
  }
}

/// Configuration class for Gemini Nano
class GeminiNanoConfig {
  final double temperature;
  final int topK;
  final int maxOutputTokens;

  const GeminiNanoConfig({
    this.temperature = 0.7,
    this.topK = 40,
    this.maxOutputTokens = 1024,
  });

  Map<String, dynamic> toMap() {
    return {
      'temperature': temperature,
      'topK': topK,
      'maxOutputTokens': maxOutputTokens,
    };
  }

  GeminiNanoConfig copyWith({
    double? temperature,
    int? topK,
    int? maxOutputTokens,
  }) {
    return GeminiNanoConfig(
      temperature: temperature ?? this.temperature,
      topK: topK ?? this.topK,
      maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
    );
  }
}

/// Exception thrown when Gemini Nano operations fail
class GeminiNanoException implements Exception {
  final String message;
  final String? code;

  const GeminiNanoException(this.message, [this.code]);

  @override
  String toString() => 'GeminiNanoException: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Utility class for Gemini Nano operations
class GeminiNanoUtils {
  /// Check if the current platform supports Gemini Nano
  static bool get isPlatformSupported {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  }

  /// Get recommended configuration for different use cases
  static GeminiNanoConfig getConfigForUseCase(String useCase) {
    switch (useCase.toLowerCase()) {
      case 'chat':
        return const GeminiNanoConfig(
          temperature: 0.8,
          topK: 40,
          maxOutputTokens: 512,
        );
      case 'creative':
        return const GeminiNanoConfig(
          temperature: 0.9,
          topK: 50,
          maxOutputTokens: 1024,
        );
      case 'factual':
        return const GeminiNanoConfig(
          temperature: 0.3,
          topK: 20,
          maxOutputTokens: 256,
        );
      case 'code':
        return const GeminiNanoConfig(
          temperature: 0.2,
          topK: 10,
          maxOutputTokens: 2048,
        );
      default:
        return const GeminiNanoConfig();
    }
  }

  /// Validate prompt for Gemini Nano
  static bool isValidPrompt(String prompt) {
    if (prompt.trim().isEmpty) return false;
    if (prompt.length > 8192) return false; // Reasonable limit
    return true;
  }

  /// Sanitize prompt for Gemini Nano
  static String sanitizePrompt(String prompt) {
    return prompt.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}
