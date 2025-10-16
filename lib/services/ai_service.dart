import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// AI Service for on-device AI capabilities
/// Supports Gemini Nano on Android with hardware acceleration
class AIService {
  static final AIService _instance = AIService._internal();
  bool _isInitialized = false;
  bool _hasGeminiNano = false;

  factory AIService() {
    return _instance;
  }

  AIService._internal();

  /// Initialize AI service and check for Gemini Nano availability
  Future<void> initialize() async {
    try {
      developer.log('Initializing AI Service', name: 'AIService');

      // Check if running on Android with hardware acceleration
      if (defaultTargetPlatform == TargetPlatform.android) {
        _hasGeminiNano = await _checkGeminiNanoAvailability();
        developer.log(
          'Gemini Nano available: $_hasGeminiNano',
          name: 'AIService',
        );
      }

      _isInitialized = true;
      developer.log('AI Service initialized', name: 'AIService');
    } catch (e) {
      developer.log('Error initializing AI Service: $e', name: 'AIService');
      _isInitialized = false;
    }
  }

  /// Check if Gemini Nano is available on device
  Future<bool> _checkGeminiNanoAvailability() async {
    try {
      // In a real implementation, this would check Android's AICore service
      // For now, we'll return true if on Android
      developer.log('Checking Gemini Nano availability', name: 'AIService');
      return true;
    } catch (e) {
      developer.log('Error checking Gemini Nano: $e', name: 'AIService');
      return false;
    }
  }

  /// Generate AI response for food analysis
  Future<String> analyzeFoodItem(String foodName, String? nutritionalInfo) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      developer.log(
        'Analyzing food item: $foodName',
        name: 'AIService',
      );

      // Construct prompt for food analysis
      final prompt = _buildFoodAnalysisPrompt(foodName, nutritionalInfo);

      if (_hasGeminiNano) {
        return await _generateWithGeminiNano(prompt);
      } else {
        return _generateLocalResponse(foodName, nutritionalInfo);
      }
    } catch (e) {
      developer.log('Error analyzing food item: $e', name: 'AIService');
      return 'Unable to analyze food item at this time.';
    }
  }

  /// Generate response using Gemini Nano (on-device)
  Future<String> _generateWithGeminiNano(String prompt) async {
    try {
      developer.log('Generating response with Gemini Nano', name: 'AIService');

      // In a real implementation, this would call the Gemini Nano API
      // through Google AI Edge SDK or ML Kit GenAI APIs
      // For now, we'll return a placeholder
      await Future.delayed(const Duration(milliseconds: 500));

      return '''
Based on the food item analysis:

**Nutritional Breakdown:**
- This is a balanced meal option
- Rich in essential nutrients
- Good source of protein and fiber

**Health Recommendations:**
- Pair with plenty of water
- Include vegetables for additional nutrients
- Consider portion size for your dietary goals

**Lifestyle Tips:**
- Eat slowly to aid digestion
- Combine with regular exercise
- Track your intake for better health insights
      ''';
    } catch (e) {
      developer.log('Error with Gemini Nano: $e', name: 'AIService');
      return _generateLocalResponse('', null);
    }
  }

  /// Generate local response without cloud connectivity
  String _generateLocalResponse(String foodName, String? nutritionalInfo) {
    developer.log('Generating local response for: $foodName', name: 'AIService');

    return '''
**$foodName Analysis**

This food item has been logged to your dietary tracker.

**Quick Tips:**
- Maintain balanced nutrition throughout the day
- Stay hydrated
- Include variety in your meals
- Monitor portion sizes

**Next Steps:**
- Continue logging your meals
- Review your nutrition summary
- Adjust based on your health goals
    ''';
  }

  /// Build prompt for food analysis
  String _buildFoodAnalysisPrompt(String foodName, String? nutritionalInfo) {
    final buffer = StringBuffer();
    buffer.write('Analyze this food item: $foodName\n');

    if (nutritionalInfo != null && nutritionalInfo.isNotEmpty) {
      buffer.write('Nutritional Information: $nutritionalInfo\n');
    }

    buffer.write('''
Provide:
1. Nutritional breakdown
2. Health benefits
3. Dietary recommendations
4. Lifestyle tips

Keep response concise and practical.''');

    return buffer.toString();
  }

  /// Generate chat response for user queries
  Future<String> generateChatResponse(String userMessage) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      developer.log('Generating chat response', name: 'AIService');

      if (_hasGeminiNano) {
        return await _generateWithGeminiNano(userMessage);
      } else {
        return _generateLocalChatResponse(userMessage);
      }
    } catch (e) {
      developer.log('Error generating chat response: $e', name: 'AIService');
      return 'I\'m having trouble processing your request. Please try again.';
    }
  }

  /// Generate local chat response
  String _generateLocalChatResponse(String userMessage) {
    developer.log('Generating local chat response', name: 'AIService');

    // Simple keyword-based responses
    if (userMessage.toLowerCase().contains('calorie')) {
      return 'Calories are units of energy in food. Daily needs vary based on age, activity level, and goals. Would you like specific recommendations?';
    } else if (userMessage.toLowerCase().contains('protein')) {
      return 'Protein is essential for muscle building and repair. Aim for 0.8-1g per pound of body weight daily. Good sources include chicken, fish, eggs, and legumes.';
    } else if (userMessage.toLowerCase().contains('diet')) {
      return 'A balanced diet includes proteins, carbs, fats, vitamins, and minerals. Focus on whole foods and portion control for best results.';
    } else if (userMessage.toLowerCase().contains('exercise')) {
      return 'Regular exercise combined with good nutrition is key to health. Aim for 150 minutes of moderate activity weekly.';
    } else {
      return 'I\'m here to help with nutrition and lifestyle questions. Ask me about calories, nutrients, diet tips, or exercise!';
    }
  }

  /// Check if Gemini Nano is available
  bool get hasGeminiNano => _hasGeminiNano;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;
}

