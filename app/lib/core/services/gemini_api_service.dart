import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Gemini API Service for cloud-based AI processing
///
/// TODO: OPTIMIZATION - Replace with on-device Gemini Nano for:
/// - Offline support (no internet required)
/// - Privacy (data stays on device)
/// - Cost savings (no API calls)
/// - Lower latency (no network roundtrip)
///
/// Current: Uses Gemini Flash API for fast development
/// Target: Gemini Nano on-device with cloud fallback for complex tasks
class GeminiApiService {
  // TODO: Move API key to secure storage (env vars, secrets manager)
  // For development only - DO NOT commit real API keys
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta';

  final Dio _dio = Dio();
  String? _apiKey;

  /// Initialize with API key from secure storage
  /// TODO: Use Firebase Remote Config or secure key management
  Future<void> initialize({String? apiKey}) async {
    _apiKey = apiKey ?? const String.fromEnvironment('GEMINI_API_KEY');
    if (_apiKey == null || _apiKey!.isEmpty) {
      debugPrint(
        'Warning: GEMINI_API_KEY not set. Gemini API features disabled.',
      );
    }
  }

  bool get isAvailable => _apiKey != null && _apiKey!.isNotEmpty;

  /// Parse receipt image using Gemini Vision API
  ///
  /// TODO: OPTIMIZATION - Use on-device ML Kit + Gemini Nano instead:
  /// 1. ML Kit for OCR (on-device, fast)
  /// 2. Gemini Nano for parsing (on-device, private)
  /// Only fall back to cloud for complex/unclear receipts
  Future<Map<String, dynamic>?> parseReceiptImage(File imageFile) async {
    if (!isAvailable) {
      debugPrint('Gemini API not available, falling back to local parsing');
      return null;
    }

    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await _dio.post(
        '$_baseUrl/models/gemini-1.5-flash:generateContent?key=$_apiKey',
        options: Options(headers: {'Content-Type': 'application/json'}),
        data: {
          'contents': [
            {
              'parts': [
                {
                  'text': '''Extract items from this receipt image.
Return ONLY valid JSON with this structure:
{
  "vendor": "store name or null",
  "items": [{"name": "item name", "price": 45.00, "quantity": 1}],
  "subtotal": 123.00,
  "tax": 10.00,
  "total": 133.00,
  "date": "2024-01-15 or null"
}
Be accurate with prices. Extract currency values as decimal numbers without currency symbols.''',
                },
                {
                  'inline_data': {
                    'mime_type': 'image/jpeg',
                    'data': base64Image,
                  },
                },
              ],
            },
          ],
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        if (text != null) {
          // Extract JSON from response
          final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
          if (jsonMatch != null) {
            return jsonDecode(jsonMatch.group(0)!);
          }
        }
      } else {
        debugPrint(
          'Gemini API error: ${response.statusCode} - ${response.data}',
        );
      }
    } catch (e) {
      debugPrint('Gemini API exception: $e');
    }
    return null;
  }

  /// Generate text using Gemini API (for RAG, summaries, etc.)
  ///
  /// TODO: OPTIMIZATION - Use on-device Gemini Nano for:
  /// - Simple queries (< 1024 tokens)
  /// - Privacy-sensitive content
  /// - Offline scenarios
  Future<String?> generateText(String prompt) async {
    if (!isAvailable) return null;

    try {
      final response = await _dio.post(
        '$_baseUrl/models/gemini-1.5-flash:generateContent?key=$_apiKey',
        options: Options(headers: {'Content-Type': 'application/json'}),
        data: {
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.3, // Lower for factual extraction
            'maxOutputTokens': 1024,
          },
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return data['candidates']?[0]?['content']?['parts']?[0]?['text'];
      }
    } catch (e) {
      debugPrint('Gemini generateText error: $e');
    }
    return null;
  }
}

/// Singleton instance
final geminiApiService = GeminiApiService();
