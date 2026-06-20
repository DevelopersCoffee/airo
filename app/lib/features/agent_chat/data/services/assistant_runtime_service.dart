import '../../../../core/services/gemini_api_service.dart';
import '../../../../core/services/gemini_nano_service.dart';
import '../../../../core/services/litert_lm_service.dart';
import '../../domain/models/assistant_runtime_ids.dart';

typedef GeminiNanoSupportCheck = Future<bool> Function();
typedef GeminiNanoInitializer = Future<bool> Function();
typedef GeminiNanoTextGenerator = Future<String> Function(String prompt);
typedef GeminiNanoStreamGenerator = Stream<String> Function(String prompt);
typedef LiteRtTextGenerator =
    Future<String?> Function(String prompt, {String? systemPrompt});
typedef CloudInitializer = Future<void> Function();
typedef CloudAvailabilityCheck = bool Function();
typedef CloudTextGenerator = Future<String?> Function(String prompt);

class AssistantRuntimeUnavailableException implements Exception {
  AssistantRuntimeUnavailableException(this.runtimeId, this.message);

  final String? runtimeId;
  final String message;

  @override
  String toString() => message;
}

class AssistantRuntimeService {
  AssistantRuntimeService({
    GeminiNanoService? geminiNano,
    LiteRtLmService? liteRtLm,
    GeminiApiService? geminiCloud,
    GeminiNanoSupportCheck? isGeminiNanoSupported,
    GeminiNanoInitializer? initializeGeminiNano,
    GeminiNanoTextGenerator? generateGeminiNanoText,
    GeminiNanoStreamGenerator? generateGeminiNanoStream,
    LiteRtTextGenerator? generateLiteRtText,
    CloudInitializer? initializeCloud,
    CloudAvailabilityCheck? isCloudAvailable,
    CloudTextGenerator? generateCloudText,
  }) : _geminiNano = geminiNano ?? GeminiNanoService(),
       _liteRtLm = liteRtLm ?? LiteRtLmService(),
       _geminiCloud = geminiCloud ?? geminiApiService,
       _isGeminiNanoSupportedOverride = isGeminiNanoSupported,
       _initializeGeminiNanoOverride = initializeGeminiNano,
       _generateGeminiNanoTextOverride = generateGeminiNanoText,
       _generateGeminiNanoStreamOverride = generateGeminiNanoStream,
       _generateLiteRtTextOverride = generateLiteRtText,
       _initializeCloudOverride = initializeCloud,
       _isCloudAvailableOverride = isCloudAvailable,
       _generateCloudTextOverride = generateCloudText;

  final GeminiNanoService _geminiNano;
  final LiteRtLmService _liteRtLm;
  final GeminiApiService _geminiCloud;
  final GeminiNanoSupportCheck? _isGeminiNanoSupportedOverride;
  final GeminiNanoInitializer? _initializeGeminiNanoOverride;
  final GeminiNanoTextGenerator? _generateGeminiNanoTextOverride;
  final GeminiNanoStreamGenerator? _generateGeminiNanoStreamOverride;
  final LiteRtTextGenerator? _generateLiteRtTextOverride;
  final CloudInitializer? _initializeCloudOverride;
  final CloudAvailabilityCheck? _isCloudAvailableOverride;
  final CloudTextGenerator? _generateCloudTextOverride;

  Future<String> generateText({
    required String? selectedModelId,
    required String prompt,
    String? systemPrompt,
  }) async {
    final runtimeId = _requireSelectedRuntime(selectedModelId);
    final fullPrompt = _withSystemPrompt(prompt, systemPrompt);

    switch (runtimeId) {
      case geminiNanoAssistantModelId:
        await _ensureGeminiNanoReady();
        return _nonEmptyOrUnavailable(
          runtimeId,
          await (_generateGeminiNanoTextOverride?.call(fullPrompt) ??
              _geminiNano.generateContentStrict(fullPrompt)),
          geminiNanoInitializationFailedMessage,
        );

      case litertGemmaAssistantModelId:
        return _nonEmptyOrUnavailable(
          runtimeId,
          await (_generateLiteRtTextOverride?.call(
                prompt,
                systemPrompt: systemPrompt,
              ) ??
              _liteRtLm.generateText(prompt, systemPrompt: systemPrompt)),
          litertGemmaUnavailableMessage,
        );

      case geminiCloudAssistantModelId:
        await (_initializeCloudOverride?.call() ?? _geminiCloud.initialize());
        final isAvailable =
            _isCloudAvailableOverride?.call() ?? _geminiCloud.isAvailable;
        if (!isAvailable) {
          throw AssistantRuntimeUnavailableException(
            runtimeId,
            geminiCloudUnavailableMessage,
          );
        }
        return _nonEmptyOrUnavailable(
          runtimeId,
          await (_generateCloudTextOverride?.call(fullPrompt) ??
              _geminiCloud.generateText(fullPrompt)),
          geminiCloudEmptyResponseMessage,
        );

      default:
        throw AssistantRuntimeUnavailableException(
          runtimeId,
          unsupportedAssistantRuntimeMessage,
        );
    }
  }

  Stream<String> generateTextStream({
    required String? selectedModelId,
    required String prompt,
  }) async* {
    final runtimeId = _requireSelectedRuntime(selectedModelId);

    if (runtimeId != geminiNanoAssistantModelId) {
      yield await generateText(selectedModelId: runtimeId, prompt: prompt);
      return;
    }

    await _ensureGeminiNanoReady();
    var yielded = false;
    final stream =
        _generateGeminiNanoStreamOverride?.call(prompt) ??
        _geminiNano.generateContentStreamStrict(prompt);
    await for (final chunk in stream) {
      if (chunk.trim().isEmpty) continue;
      yielded = true;
      yield chunk;
    }
    if (!yielded) {
      throw AssistantRuntimeUnavailableException(
        runtimeId,
        geminiNanoInitializationFailedMessage,
      );
    }
  }

  Future<void> _ensureGeminiNanoReady() async {
    final supported =
        await (_isGeminiNanoSupportedOverride?.call() ??
            _geminiNano.isSupported());
    if (!supported) {
      throw AssistantRuntimeUnavailableException(
        geminiNanoAssistantModelId,
        geminiNanoUnavailableMessage,
      );
    }

    if (_geminiNano.isInitialized && _initializeGeminiNanoOverride == null) {
      return;
    }

    final initialized =
        await (_initializeGeminiNanoOverride?.call() ??
            _geminiNano.initialize());
    if (!initialized) {
      throw AssistantRuntimeUnavailableException(
        geminiNanoAssistantModelId,
        geminiNanoInitializationFailedMessage,
      );
    }
  }

  String _requireSelectedRuntime(String? selectedModelId) {
    final runtimeId = selectedModelId?.trim();
    if (runtimeId == null || runtimeId.isEmpty) {
      throw AssistantRuntimeUnavailableException(
        null,
        noAssistantModelSelectedMessage,
      );
    }
    return runtimeId;
  }

  String _withSystemPrompt(String prompt, String? systemPrompt) {
    final trimmedSystemPrompt = systemPrompt?.trim();
    if (trimmedSystemPrompt == null || trimmedSystemPrompt.isEmpty) {
      return prompt;
    }
    return '$trimmedSystemPrompt\n\n$prompt';
  }

  String _nonEmptyOrUnavailable(
    String runtimeId,
    String? text,
    String message,
  ) {
    final trimmed = text?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      throw AssistantRuntimeUnavailableException(runtimeId, message);
    }
    return trimmed;
  }
}
