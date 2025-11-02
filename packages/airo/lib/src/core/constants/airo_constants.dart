class AiroConstants {
  // Private constructor to prevent instantiation
  AiroConstants._();

  // App Information
  static const String packageName = 'airo';
  static const String packageVersion = '0.0.1';
  static const String packageDescription = 'AI-powered assistant package';

  // API Endpoints
  static const String aiApiEndpoint = '/api/ai';
  static const String chatEndpoint = '/api/chat';
  static const String voiceEndpoint = '/api/voice';
  static const String tasksEndpoint = '/api/tasks';

  // Feature Flags
  static const bool enableVoiceCommands = true;
  static const bool enableChatHistory = true;
  static const bool enableAnalytics = true;
  static const bool enableOfflineMode = false;

  // Limits
  static const int maxChatHistory = 100;
  static const int maxVoiceRecordingDuration = 60; // seconds
  static const int maxTasksPerUser = 50;

  // AI Configuration
  static const String defaultAiModel = 'gpt-3.5-turbo';
  static const int maxTokensPerRequest = 2048;
  static const double defaultTemperature = 0.7;

  // UI Constants
  static const double cardElevation = 4.0;
  static const double buttonBorderRadius = 8.0;
  static const Duration animationDuration = Duration(milliseconds: 300);

  // Colors (Material 3 compatible)
  static const int primaryColorValue = 0xFF2196F3;
  static const int secondaryColorValue = 0xFF03DAC6;
  static const int errorColorValue = 0xFFB00020;

  // Asset Paths
  static const String iconsPath = 'packages/airo/assets/icons/';
  static const String imagesPath = 'packages/airo/assets/images/';
  static const String soundsPath = 'packages/airo/assets/sounds/';

  // Storage Keys
  static const String chatHistoryKey = 'airo_chat_history';
  static const String userPreferencesKey = 'airo_user_preferences';
  static const String aiModelKey = 'airo_ai_model';
  static const String voiceSettingsKey = 'airo_voice_settings';
}
