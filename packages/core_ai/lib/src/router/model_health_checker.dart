import '../llm/chat_llm_client.dart';
import '../provider/ai_provider.dart';

class ModelHealthStatus {
  const ModelHealthStatus({
    required this.provider,
    required this.isHealthy,
    this.reason,
  });

  final AIProvider provider;
  final bool isHealthy;
  final String? reason;
}

/// Checks whether a routed model target can be attempted safely.
class ModelHealthChecker {
  const ModelHealthChecker();

  Future<ModelHealthStatus> check(
    AIProvider provider,
    ChatLLMClient? client,
  ) async {
    if (client == null) {
      return ModelHealthStatus(
        provider: provider,
        isHealthy: false,
        reason: 'No client configured',
      );
    }

    final available = await client.isAvailable();
    return ModelHealthStatus(
      provider: provider,
      isHealthy: available,
      reason: available ? null : 'Client unavailable',
    );
  }
}
