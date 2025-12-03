import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ai_provider.dart';
import '../services/gemini_nano_service.dart';

/// AI Router Service - Routes queries to appropriate AI provider
class AIRouterService {
  static final AIRouterService _instance = AIRouterService._internal();
  factory AIRouterService() => _instance;
  AIRouterService._internal();

  AIProvider _selectedProvider = AIProvider.auto;
  final Map<AIProvider, AIProviderStatus> _providerStatus = {};

  /// Get current selected provider
  AIProvider get selectedProvider => _selectedProvider;

  /// Set selected provider
  void setProvider(AIProvider provider) {
    _selectedProvider = provider;
    debugPrint('AI Provider changed to: ${provider.displayName}');
  }

  /// Get status for a specific provider
  AIProviderStatus? getProviderStatus(AIProvider provider) {
    return _providerStatus[provider];
  }

  /// Get all provider statuses
  Map<AIProvider, AIProviderStatus> getAllProviderStatuses() {
    return Map.unmodifiable(_providerStatus);
  }

  /// Check availability of all providers
  Future<void> checkAvailability() async {
    debugPrint('Checking AI provider availability...');

    // Check Gemini Nano
    try {
      final nanoService = GeminiNanoService();
      final isNanoAvailable = await nanoService.isSupported();

      if (isNanoAvailable) {
        final isInitialized = await nanoService.initialize();
        final deviceInfo = await nanoService.getDeviceInfo();

        _providerStatus[AIProvider.nano] = AIProviderStatus(
          provider: AIProvider.nano,
          capabilities: AICapabilities(
            isAvailable: isInitialized,
            supportsStreaming: true,
            supportsImages: false,
            supportsFiles: true,
            maxTokens: 2048,
            supportedLanguages: const ['en'],
          ),
          isInitialized: isInitialized,
          lastChecked: DateTime.now(),
        );

        debugPrint(
          'Gemini Nano: ${isInitialized ? "Available" : "Unavailable"}',
        );
        debugPrint(
          'Device: ${deviceInfo['manufacturer']} ${deviceInfo['model']}',
        );
      } else {
        _providerStatus[AIProvider.nano] = AIProviderStatus(
          provider: AIProvider.nano,
          capabilities: AICapabilities.unavailable(
            'Not supported on this device',
          ),
          isInitialized: false,
          lastChecked: DateTime.now(),
        );
        debugPrint('Gemini Nano: Not supported on this device');
      }
    } catch (e) {
      _providerStatus[AIProvider.nano] = AIProviderStatus(
        provider: AIProvider.nano,
        capabilities: AICapabilities.unavailable('Error: $e'),
        isInitialized: false,
        lastChecked: DateTime.now(),
      );
      debugPrint('Gemini Nano check failed: $e');
    }

    // Check Cloud API (always available if API key is configured)
    _providerStatus[AIProvider.cloud] = AIProviderStatus(
      provider: AIProvider.cloud,
      capabilities: AICapabilities.fromCloud(),
      isInitialized: true,
      lastChecked: DateTime.now(),
    );
    debugPrint('Gemini Cloud: Available');
  }

  /// Get the best available provider
  AIProvider getBestProvider() {
    // If user selected a specific provider, use it if available
    if (_selectedProvider != AIProvider.auto) {
      final status = _providerStatus[_selectedProvider];
      if (status?.isAvailable == true) {
        return _selectedProvider;
      }
    }

    // Auto-select: prefer Nano if available, fallback to Cloud
    final nanoStatus = _providerStatus[AIProvider.nano];
    if (nanoStatus?.isAvailable == true) {
      return AIProvider.nano;
    }

    return AIProvider.cloud;
  }

  /// Process query with selected provider
  Future<String> processQuery(
    String query, {
    String? fileContext,
    String? systemPrompt,
  }) async {
    final provider = getBestProvider();
    debugPrint('Processing query with: ${provider.displayName}');

    switch (provider) {
      case AIProvider.nano:
        return await _processWithNano(
          query,
          fileContext: fileContext,
          systemPrompt: systemPrompt,
        );
      case AIProvider.cloud:
        return await _processWithCloud(
          query,
          fileContext: fileContext,
          systemPrompt: systemPrompt,
        );
      case AIProvider.auto:
        // This shouldn't happen as getBestProvider() resolves auto
        return await _processWithCloud(
          query,
          fileContext: fileContext,
          systemPrompt: systemPrompt,
        );
    }
  }

  /// Process query with streaming response
  Stream<String> processQueryStream(
    String query, {
    String? fileContext,
    String? systemPrompt,
  }) async* {
    final provider = getBestProvider();
    debugPrint('Processing streaming query with: ${provider.displayName}');

    switch (provider) {
      case AIProvider.nano:
        yield* _processStreamWithNano(
          query,
          fileContext: fileContext,
          systemPrompt: systemPrompt,
        );
        break;
      case AIProvider.cloud:
        yield* _processStreamWithCloud(
          query,
          fileContext: fileContext,
          systemPrompt: systemPrompt,
        );
        break;
      case AIProvider.auto:
        yield* _processStreamWithCloud(
          query,
          fileContext: fileContext,
          systemPrompt: systemPrompt,
        );
        break;
    }
  }

  // Private methods for provider-specific processing

  Future<String> _processWithNano(
    String query, {
    String? fileContext,
    String? systemPrompt,
  }) async {
    final nanoService = GeminiNanoService();
    final result = await nanoService.processQuery(
      query,
      fileContext: fileContext,
      systemPrompt: systemPrompt,
    );
    return result ?? 'Gemini Nano is not available on this platform.';
  }

  Stream<String> _processStreamWithNano(
    String query, {
    String? fileContext,
    String? systemPrompt,
  }) async* {
    final nanoService = GeminiNanoService();

    // Build full prompt
    String fullPrompt = query;
    if (systemPrompt != null) {
      fullPrompt = '$systemPrompt\n\n$query';
    }
    if (fileContext != null) {
      fullPrompt = '$fullPrompt\n\nContext:\n$fileContext';
    }

    yield* nanoService.generateContentStream(fullPrompt);
  }

  Future<String> _processWithCloud(
    String query, {
    String? fileContext,
    String? systemPrompt,
  }) async {
    // TODO: Implement actual Gemini Cloud API call
    // For now, return a mock response
    await Future.delayed(const Duration(seconds: 1));

    return '''[Cloud AI Response]

I'm processing your query using Gemini Cloud API.

Query: $query

${fileContext != null ? 'File context provided: Yes\n' : ''}
${systemPrompt != null ? 'System prompt: Yes\n' : ''}

This is a placeholder response. Implement actual Gemini API integration here.''';
  }

  Stream<String> _processStreamWithCloud(
    String query, {
    String? fileContext,
    String? systemPrompt,
  }) async* {
    // TODO: Implement actual Gemini Cloud API streaming
    final response = await _processWithCloud(
      query,
      fileContext: fileContext,
      systemPrompt: systemPrompt,
    );

    // Simulate streaming
    final words = response.split(' ');
    String accumulated = '';
    for (final word in words) {
      accumulated += '$word ';
      yield accumulated.trim();
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }
}

/// Riverpod providers for AI routing

final aiRouterServiceProvider = Provider<AIRouterService>((ref) {
  return AIRouterService();
});

final selectedAIProviderProvider = StateProvider<AIProvider>((ref) {
  return AIProvider.auto;
});

final aiProviderStatusProvider =
    FutureProvider<Map<AIProvider, AIProviderStatus>>((ref) async {
      final router = ref.watch(aiRouterServiceProvider);
      await router.checkAvailability();
      return router.getAllProviderStatuses();
    });

final bestAIProviderProvider = Provider<AIProvider>((ref) {
  final router = ref.watch(aiRouterServiceProvider);
  return router.getBestProvider();
});
