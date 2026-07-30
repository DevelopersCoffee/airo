import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:core_ai/core_ai.dart';
import '../services/gemini_nano_service.dart';
import '../services/gemini_api_service.dart';

/// AI Router Service - Routes queries to appropriate AI provider
class AIRouterService {
  static final AIRouterService _instance = AIRouterService._internal();
  factory AIRouterService() => _instance;
  AIRouterService._internal();

  AIProvider _selectedProvider = AIProvider.auto;
  final Map<AIProvider, AIProviderStatus> _providerStatus = {};
  OpenAICompatibleClient? _remoteClient;

  /// Configures an OpenAI-compatible local/private server such as Ollama,
  /// LM Studio, or llama.cpp server. Empty URL disables the remote backend.
  void configureRemoteServer({
    required String baseUrl,
    required String model,
    String? apiKey,
  }) {
    final normalizedUrl = baseUrl.trim();
    final normalizedModel = model.trim();
    _remoteClient = normalizedUrl.isEmpty || normalizedModel.isEmpty
        ? null
        : OpenAICompatibleClient(
            baseUrl: normalizedUrl,
            model: normalizedModel,
            apiKey: apiKey,
          );
  }

  Future<RemoteServerDiagnostics?> diagnoseRemoteServer() {
    return _remoteClient?.diagnose() ?? Future.value(null);
  }

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

    // Check Cloud API from the same initialized service used for requests.
    // Never advertise a backend that has no configured credentials.
    await geminiApiService.initialize();
    final cloudAvailable = geminiApiService.isAvailable;
    _providerStatus[AIProvider.cloud] = AIProviderStatus(
      provider: AIProvider.cloud,
      capabilities: cloudAvailable
          ? AICapabilities.fromCloud()
          : AICapabilities.unavailable('Gemini API key is not configured'),
      isInitialized: cloudAvailable,
      lastChecked: DateTime.now(),
    );
    debugPrint(
      'Gemini Cloud: ${cloudAvailable ? "Available" : "Unavailable (no API key)"}',
    );
  }

  /// Get the best available provider
  AIProvider getBestProvider() {
    // If user selected a specific provider, use it if available
    if (_selectedProvider != AIProvider.auto) {
      final status = _providerStatus[_selectedProvider];
      if (status?.isAvailable == true) {
        return _selectedProvider;
      }
      // Preserve an explicit local choice so the caller gets an actionable
      // unavailable-runtime message instead of silently sending data to the
      // cloud. Auto routing is the only mode allowed to choose a fallback.
      if (_selectedProvider.isOnDevice) return _selectedProvider;
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
      case AIProvider.gguf:
      case AIProvider.gemma:
      case AIProvider.phi:
      case AIProvider.llama:
      case AIProvider.custom:
        if (provider == AIProvider.auto) {
          return await _processWithCloud(
            query,
            fileContext: fileContext,
            systemPrompt: systemPrompt,
          );
        }
        final remote = _remoteClient;
        if (remote != null) {
          final result = await remote.generate(query);
          return result.fold(
            (error, _) => 'Remote model is unavailable: $error',
            (response) => response.text,
          );
        }
        return _unsupportedLocalProviderMessage(provider);
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
      case AIProvider.gguf:
      case AIProvider.gemma:
      case AIProvider.phi:
      case AIProvider.llama:
      case AIProvider.custom:
        if (provider == AIProvider.auto) {
          yield* _processStreamWithCloud(
            query,
            fileContext: fileContext,
            systemPrompt: systemPrompt,
          );
        } else {
          final remote = _remoteClient;
          if (remote != null) {
            yield* remote.generateStream(query);
          } else {
            yield _unsupportedLocalProviderMessage(provider);
          }
        }
        break;
    }
  }

  String _unsupportedLocalProviderMessage(AIProvider provider) {
    return '${provider.displayName} is selected, but its native local runtime '
        'is unavailable. Install a supported local backend or configure an '
        'OpenAI-compatible llama.cpp, Ollama, or LM Studio server.';
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
    var prompt = query;
    if (systemPrompt != null && systemPrompt.trim().isNotEmpty) {
      prompt = '$systemPrompt\n\n$prompt';
    }
    if (fileContext != null && fileContext.trim().isNotEmpty) {
      prompt = '$prompt\n\nContext:\n$fileContext';
    }
    final response = await geminiApiService.generateText(prompt);
    return response ??
        'Gemini Cloud is unavailable. Configure an API key or select an on-device runtime.';
  }

  Stream<String> _processStreamWithCloud(
    String query, {
    String? fileContext,
    String? systemPrompt,
  }) async* {
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
