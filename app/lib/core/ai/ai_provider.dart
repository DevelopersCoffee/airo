/// AI Provider types for query routing
enum AIProvider {
  /// On-device Gemini Nano (Pixel 9+)
  nano('Gemini Nano', 'On-device AI', 'Local processing on your Pixel 9'),
  
  /// Cloud-based Gemini API
  cloud('Gemini Cloud', 'Cloud AI', 'Powered by Google AI'),
  
  /// Auto-select based on availability
  auto('Auto', 'Smart Selection', 'Automatically choose best option');

  const AIProvider(this.displayName, this.shortName, this.description);

  final String displayName;
  final String shortName;
  final String description;
}

/// AI Provider capabilities
class AICapabilities {
  final bool isAvailable;
  final bool supportsStreaming;
  final bool supportsImages;
  final bool supportsFiles;
  final int maxTokens;
  final List<String> supportedLanguages;
  final String? errorMessage;

  const AICapabilities({
    required this.isAvailable,
    this.supportsStreaming = false,
    this.supportsImages = false,
    this.supportsFiles = false,
    this.maxTokens = 2048,
    this.supportedLanguages = const ['en'],
    this.errorMessage,
  });

  factory AICapabilities.unavailable(String reason) {
    return AICapabilities(
      isAvailable: false,
      errorMessage: reason,
    );
  }

  factory AICapabilities.fromNano(Map<String, dynamic> data) {
    return AICapabilities(
      isAvailable: true,
      supportsStreaming: true,
      supportsImages: data['imageDescription'] ?? false,
      supportsFiles: true,
      maxTokens: data['maxTokens'] ?? 2048,
      supportedLanguages: List<String>.from(data['supportedLanguages'] ?? ['en']),
    );
  }

  factory AICapabilities.fromCloud() {
    return const AICapabilities(
      isAvailable: true,
      supportsStreaming: true,
      supportsImages: true,
      supportsFiles: true,
      maxTokens: 8192,
      supportedLanguages: ['en', 'es', 'fr', 'de', 'it', 'pt', 'ja', 'ko', 'zh', 'hi', 'ar'],
    );
  }
}

/// AI Provider status
class AIProviderStatus {
  final AIProvider provider;
  final AICapabilities capabilities;
  final bool isInitialized;
  final DateTime? lastChecked;

  const AIProviderStatus({
    required this.provider,
    required this.capabilities,
    this.isInitialized = false,
    this.lastChecked,
  });

  bool get isAvailable => capabilities.isAvailable;

  AIProviderStatus copyWith({
    AIProvider? provider,
    AICapabilities? capabilities,
    bool? isInitialized,
    DateTime? lastChecked,
  }) {
    return AIProviderStatus(
      provider: provider ?? this.provider,
      capabilities: capabilities ?? this.capabilities,
      isInitialized: isInitialized ?? this.isInitialized,
      lastChecked: lastChecked ?? this.lastChecked,
    );
  }
}

